/*
 * 042-platform-device.c — the handheld's answers to the portable code's
 * hardware questions (declared in src/engine/025-platform.h).
 *
 * UNVERIFIED ON HARDWARE. Everything in this file was written against the
 * ARM architecture manual and the phase 1 drivers without running on the
 * device. It compiles into every kernel image so the cross-compiler checks
 * it, but the ordinary boot never calls it: only a kernel built with the
 * engine flag (scripts/build --engine) runs it. Issue 200 describes the
 * split; issues 201 and 202 own the parts most likely to be wrong.
 *
 * General description: the chip's four cores are released by asking the
 * secure firmware that sits below the kernel (the standard power-control
 * call); each core keeps its number in a per-core register the
 * architecture provides for exactly that; a core sleeps with the
 * wait-for-event instruction and is woken by any core's send-event; time
 * is the ARM generic timer's counter; the memory pool is one large
 * contiguous run taken from phase 1's page allocator at startup; text goes
 * out through phase 1's debug channel (USB serial, falling through to the
 * SD-card log when no host is attached).
 */
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"

extern void     debug_write(const char *text);
extern void     led_set_stage(int stage);
extern uint64_t alloc_pages(uint64_t n);
extern uint64_t memory_pool_size(void);
extern void     mmu_enable_on_this_core(void);          /* 044-identity-map.c */
extern void     secondary_entry(void);                  /* 043-cores.s */
extern int      guard_snapshot_take(uint64_t *buffer);  /* 043-cores.s: 0 first time, 1 on return */
extern void     guard_snapshot_return(uint64_t *buffer);/* 043-cores.s */

#define STAGE_PANIC_GENERIC 1
#define ENGINE_POOL_BYTES   ((uint64_t)1 << 30)          /* 1 GB of the 3 GB for the engine */
#define STRIPE              ((uint64_t)2 * 1024 * 1024)
#define CORE_STACK_PAGES    16                           /* 64 KB per core; see issue 202's open question */

/* The MPIDR affinity of each core on this chip, from the device tree
 * (cpu@0, cpu@100, cpu@200, cpu@300). */
static const uint64_t core_affinity[4] = { 0x000, 0x100, 0x200, 0x300 };

static int       cores_running = 1;
static void    (*core_entry)(int core);
static uint64_t  pool_base;
static uint64_t  pool_bytes;
static uint64_t  timer_hz;
static spin_lock_t write_lock = SPIN_LOCK_INIT;

/* Read by 043-cores.s: where each secondary core's stack starts. */
uint64_t core_stack_top[PLATFORM_MAX_CORES];

/* Fault catcher state, one per core (issue 214, debug builds). */
static uint64_t guard_buffer[PLATFORM_MAX_CORES][16];
static volatile int guard_armed[PLATFORM_MAX_CORES];
static volatile uint64_t guard_detail[PLATFORM_MAX_CORES];

/* {{{ read_counter */
static inline uint64_t read_counter(void)
{
    uint64_t v;
    __asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(v));
    return v;
}
/* }}} */

/* {{{ device_platform_init */
/* Called once from kernel_main on the boot core, before the engine. */
void device_platform_init(void)
{
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(timer_hz));
    if (timer_hz == 0) {
        /* The firmware is required to set this. Guessing the crystal
         * would make every time the engine keeps quietly wrong. */
        platform_halt("platform: the generic timer's frequency register is zero");
    }
    /* Not yet a core: the boot code acts as the engine's outside owner
     * until platform_start_cores makes it core 0. */
    uint64_t outside = ~0ull;
    __asm__ volatile("msr tpidr_el1, %0" :: "r"(outside));

    /* The engine's pool: one contiguous run from phase 1's allocator,
     * over-allocated by one stripe so it can be aligned to 2 MB. */
    uint64_t pages = (ENGINE_POOL_BYTES + STRIPE) / 4096;
    uint64_t raw = alloc_pages(pages);
    if (!raw) {
        platform_halt("platform: phase 1's allocator has no contiguous gigabyte for the engine");
    }
    pool_base  = (raw + STRIPE - 1) & ~(STRIPE - 1);
    pool_bytes = ENGINE_POOL_BYTES;

    /* A periodic event from the generic timer, so a core parked in
     * wait-for-event wakes on its own a few thousand times a second and
     * can look at the clock. This is how platform_wait_until keeps time
     * without an interrupt handler — see the note there. Event stream on,
     * trigger on bit 12 of the counter (24 MHz / 8192 ≈ 2.9 kHz). */
    uint64_t kctl;
    __asm__ volatile("mrs %0, cntkctl_el1" : "=r"(kctl));
    kctl |= (1u << 2);                 /* EVNTEN */
    kctl = (kctl & ~(0xFull << 4)) | (12ull << 4);   /* EVNTI */
    __asm__ volatile("msr cntkctl_el1, %0; isb" :: "r"(kctl));
}
/* }}} */

/* {{{ platform_caller_token */
/* The boot code is the only caller on the device that is not a core. */
uintptr_t platform_caller_token(void)
{
    return 1;
}
/* }}} */

/* {{{ platform_core_count */
int platform_core_count(void)
{
    return cores_running;
}
/* }}} */

/* {{{ platform_core_id */
int platform_core_id(void)
{
    uint64_t id;
    __asm__ volatile("mrs %0, tpidr_el1" : "=r"(id));
    return id == ~0ull ? -1 : (int)id;
}
/* }}} */

/* {{{ device_secondary_main */
/* Reached from 043-cores.s on a freshly released core, with its stack,
 * vector table, caches and number already set. */
void device_secondary_main(uint64_t core)
{
    core_entry((int)core);
    for (;;) {
        __asm__ volatile("wfe");
    }
}
/* }}} */

/* {{{ psci_cpu_on */
/* The standard power-control call to the secure firmware: turn this core
 * on and start it at this address with this argument. Answers the
 * firmware's status (0 is success). */
static int64_t psci_cpu_on(uint64_t affinity, uint64_t entry, uint64_t argument)
{
    register uint64_t x0 __asm__("x0") = 0xC4000003ull;      /* CPU_ON, 64-bit calling convention */
    register uint64_t x1 __asm__("x1") = affinity;
    register uint64_t x2 __asm__("x2") = entry;
    register uint64_t x3 __asm__("x3") = argument;
    __asm__ volatile("smc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3) : "memory");
    return (int64_t)x0;
}
/* }}} */

/* {{{ platform_start_cores */
void platform_start_cores(int count, void (*entry)(int core))
{
    if (count < 1 || count > 4) {
        platform_halt("platform: this chip has four cores");
    }
    core_entry = entry;
    for (int c = 1; c < count; c++) {
        uint64_t stack = alloc_pages(CORE_STACK_PAGES);
        if (!stack) {
            platform_halt("platform: no memory for a core's stack");
        }
        core_stack_top[c] = stack + CORE_STACK_PAGES * 4096;
    }
    __asm__ volatile("dsb ish" ::: "memory");
    int arrived = 1;
    for (int c = 1; c < count; c++) {
        int64_t status = psci_cpu_on(core_affinity[c], (uint64_t)(uintptr_t)secondary_entry, (uint64_t)c);
        /* A core that fails to start is reported loudly and the boot
         * stops (issue 202's third open question, answered: a silent
         * three-out-of-four is the performance mystery nobody finds). */
        if (status != 0) {
            char line[96];
            text_format(line, sizeof line, "platform: core %d did not start (firmware said %lld)\n",
                        c, (long long)status);
            debug_write(line);
            platform_halt("platform: not every core started");
        }
        arrived++;
    }
    cores_running = arrived;
    uint64_t zero = 0;
    __asm__ volatile("msr tpidr_el1, %0" :: "r"(zero));
    entry(0);
}
/* }}} */

/* {{{ platform_wait_for_event */
void platform_wait_for_event(void)
{
    /* The chip's event register does the whole job: a send-event that
     * landed before this instruction left the bit set, and wait-for-event
     * consumes it and returns at once. The timer's event stream also
     * wakes it now and then; callers treat every wake as a rumour. */
    __asm__ volatile("wfe" ::: "memory");
}
/* }}} */

/* {{{ platform_wait_until */
void platform_wait_until(uint64_t deadline_ns)
{
    /* Issue 206 describes waking on the core's own timer with interrupts
     * masked, via wait-for-interrupt. That needs the interrupt controller
     * to route the timer's interrupt to the core, which nothing has set
     * up yet. Until it has, this waits for events — its own or the
     * timer's periodic event stream — and returns when either a real
     * event arrives or the deadline passes. The difference is invisible
     * to the engine; the cost is a few thousand wakes a second while
     * fully idle, which is the thing issue 206's power question measures. */
    if (platform_now_ns() >= deadline_ns) {
        return;
    }
    __asm__ volatile("wfe" ::: "memory");
}
/* }}} */

/* {{{ platform_send_event */
void platform_send_event(void)
{
    /* The barrier makes the pushed task visible before any woken core
     * can look for it. */
    __asm__ volatile("dsb ish; sev" ::: "memory");
}
/* }}} */

/* {{{ platform_now_ns */
uint64_t platform_now_ns(void)
{
    uint64_t ticks = read_counter();
    uint64_t whole = ticks / timer_hz;
    uint64_t part  = ticks % timer_hz;
    return whole * 1000000000ull + part * 1000000000ull / timer_hz;
}
/* }}} */

/* {{{ platform_entropy */
uint64_t platform_entropy(void)
{
    /* UNVERIFIED and WEAK: the chip's true random number generator is
     * not brought up yet (issue 110p's sweep measures it). Until it is,
     * the seed is the counter's low bits mixed with which core is asking
     * — distinct per core and per boot, not unpredictable. Recorded in
     * 110p as the thing to replace. */
    uint64_t mpidr;
    __asm__ volatile("mrs %0, mpidr_el1" : "=r"(mpidr));
    uint64_t x = read_counter() ^ (mpidr << 32) ^ 0x9e3779b97f4a7c15ull;
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdull;
    x ^= x >> 33;
    return x | 1;
}
/* }}} */

/* {{{ platform_pool_base */
void *platform_pool_base(void)
{
    return (void *)(uintptr_t)pool_base;
}
/* }}} */

/* {{{ platform_pool_size */
size_t platform_pool_size(void)
{
    return (size_t)pool_bytes;
}
/* }}} */

/* {{{ platform_write */
void platform_write(const char *text, size_t len)
{
    char line[512];
    size_t n = len < sizeof line - 1 ? len : sizeof line - 1;
    bytes_copy(line, text, n);
    line[n] = '\0';
    spin_lock(&write_lock);
    debug_write(line);
    spin_unlock(&write_lock);
}
/* }}} */

static void (*last_words)(void);
static int halting;

/* {{{ platform_set_last_words */
void platform_set_last_words(void (*words)(void))
{
    last_words = words;
}
/* }}} */

/* {{{ platform_halt */
void platform_halt(const char *why)
{
    if (__atomic_exchange_n(&halting, 1, __ATOMIC_ACQ_REL) == 0 && last_words) {
        last_words();
    }
    debug_write("HALT: ");
    debug_write(why);
    debug_write("\n");
    led_set_stage(STAGE_PANIC_GENERIC);
    for (;;) {
        __asm__ volatile("wfi");
    }
}
/* }}} */

extern uint64_t display_fb_top;          /* 024-display.c */
extern uint64_t display_fb_bottom;

/* {{{ platform_screen */
struct platform_screen platform_screen(int which)
{
    uint64_t fb = which == 0 ? display_fb_top : display_fb_bottom;
    if (which < 0 || which >= PLATFORM_SCREEN_COUNT || fb == 0) {
        platform_halt("platform: a screen was asked for before the display was brought up");
    }
    struct platform_screen s = { (uint32_t *)(uintptr_t)fb, 640, 480, 640 };
    return s;
}
/* }}} */

/* {{{ platform_screen_present */
void platform_screen_present(int which)
{
    /* The display controller reads DRAM directly and never looks in the
     * cache, so every line of the framebuffer is cleaned out to memory. */
    struct platform_screen s = platform_screen(which);
    uintptr_t start = (uintptr_t)s.pixels;
    uintptr_t end = start + (uintptr_t)s.stride * (uintptr_t)s.height * 4u;
    for (uintptr_t line = start & ~(uintptr_t)63; line < end; line += 64) {
        __asm__ volatile("dc cvac, %0" :: "r"(line) : "memory");
    }
    __asm__ volatile("dsb sy" ::: "memory");
}
/* }}} */

/* {{{ platform_guarded_call */
uint64_t platform_guarded_call(void (*call)(const void *in, void *out),
                               const void *in, void *out)
{
    int core = platform_core_id();
    if (core < 0) {
        platform_halt("platform: a box was run by something that is not a core");
    }
    /* Two paths out of the snapshot: 0 the first time (arm and call the
     * box), 1 when the exception path jumped back here (the box faulted). */
    if (guard_snapshot_take(guard_buffer[core]) != 0) {
        return guard_detail[core];
    }
    guard_detail[core] = 0;
    guard_armed[core] = 1;
    call(in, out);
    guard_armed[core] = 0;
    return 0;
}
/* }}} */

/* {{{ platform_fault_return */
/* Called first thing by phase 1's panic handler. If this core had a box
 * running under a guard, jump back to the guard with the faulting
 * address; otherwise return, and the panic proceeds as it always has. */
void platform_fault_return(uint64_t faulting_pc, uint64_t syndrome)
{
    (void)syndrome;
    int core = platform_core_id();
    if (core < 0 || core >= PLATFORM_MAX_CORES || !guard_armed[core]) {
        return;
    }
    guard_armed[core] = 0;
    uint64_t far;
    __asm__ volatile("mrs %0, far_el1" : "=r"(far));
    guard_detail[core] = far ? far : (faulting_pc ? faulting_pc : 1);
    guard_snapshot_return(guard_buffer[core]);
}
/* }}} */
