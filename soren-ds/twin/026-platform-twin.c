/*
 * 026-platform-twin.c — the laptop's answers to the portable code's
 * hardware questions (declared in src/engine/025-platform.h).
 *
 * General description: the handheld has four cores, a one-bit "wake up"
 * flag per core built into the chip, a free-running clock, and a slab of
 * RAM below the kernel. The laptop has none of those in that form, so
 * this file builds each out of what the operating system offers: a thread
 * per core, a word per core that a thread can sleep on, the monotonic
 * clock, and one big anonymous memory mapping. The portable code asks the
 * same questions either way and cannot tell the difference — which is the
 * point, because it is then the same code that is tested here and flashed
 * there.
 */
#define _GNU_SOURCE
#include "../src/engine/025-platform.h"
#include "026-platform-twin.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/futex.h>
#include <pthread.h>
#include <setjmp.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#define STRIPE_BYTES ((size_t)2 * 1024 * 1024)

/* One core's wake flag, alone on its cache line so that setting one core's
 * flag never takes the line away from another core — the same false-
 * sharing rule issues 203 and 205 state for the device. */
struct twin_event {
    _Atomic uint32_t flag;      /* 1 = an event is pending for this core */
    char pad[64 - sizeof(uint32_t)];
};

static int                 core_total;
static struct twin_event   events[PLATFORM_MAX_CORES];
static void               *pool_base;
static size_t              pool_size;
static int                 log_fd = -1;
static int                 log_to_stdout = 1;
static uint64_t            clock_origin_ns;
static pthread_mutex_t     write_lock = PTHREAD_MUTEX_INITIALIZER;

/* Which core this thread is. -1 for any thread the platform did not
 * start, which is exactly what platform_core_id promises. */
static __thread int        this_core = -1;

/* The fault catcher (issue 214, debug builds). One per thread, so two
 * cores faulting at once each come back to their own snapshot. */
static __thread sigjmp_buf guard_snapshot;
static __thread volatile int guard_armed;
static __thread volatile uint64_t guard_detail;

/* {{{ raw_clock_ns */
static uint64_t raw_clock_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
/* }}} */

/* {{{ fault_handler */
/* A segmentation fault or bus error while a guard is armed returns to the
 * snapshot; any other fault is a real crash and is let through by
 * restoring the default action and returning (the instruction re-faults
 * and the process dies with the ordinary message). */
static void fault_handler(int signo, siginfo_t *info, void *context)
{
    (void)context;
    if (guard_armed) {
        guard_armed = 0;
        uint64_t addr = (uint64_t)(uintptr_t)info->si_addr;
        guard_detail = addr ? addr : 1;
        siglongjmp(guard_snapshot, 1);
    }
    signal(signo, SIG_DFL);
}
/* }}} */

/* {{{ install_alternate_stack */
/* A box that overflows its stack faults with no stack left to run the
 * handler on; each thread therefore gets a small separate stack for
 * signal handling. */
static void install_alternate_stack(void)
{
    stack_t ss;
    ss.ss_size  = 64 * 1024;
    ss.ss_sp    = malloc(ss.ss_size);
    ss.ss_flags = 0;
    if (!ss.ss_sp) {
        platform_halt("twin: no memory for a signal stack");
    }
    sigaltstack(&ss, NULL);
}
/* }}} */

/* {{{ twin_platform_init */
void twin_platform_init(int cores, size_t pool_bytes)
{
    if (cores < 1 || cores > PLATFORM_MAX_CORES) {
        fprintf(stderr, "twin: %d cores requested; must be 1..%d\n",
                cores, PLATFORM_MAX_CORES);
        exit(2);
    }
    core_total = cores;
    for (int i = 0; i < PLATFORM_MAX_CORES; i++) {
        atomic_store(&events[i].flag, 0);
    }

    /* Round the pool up to whole stripes, then over-map by one stripe so
     * the base can be moved up to a 2 MB boundary like the device's. */
    pool_size = (pool_bytes + STRIPE_BYTES - 1) & ~(STRIPE_BYTES - 1);
    if (pool_size == 0) {
        pool_size = STRIPE_BYTES;
    }
    size_t mapped = pool_size + STRIPE_BYTES;
    void *raw = mmap(NULL, mapped, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
    if (raw == MAP_FAILED) {
        fprintf(stderr, "twin: could not map a %zu-byte pool: %s\n",
                mapped, strerror(errno));
        exit(2);
    }
    uintptr_t aligned = ((uintptr_t)raw + STRIPE_BYTES - 1) & ~(uintptr_t)(STRIPE_BYTES - 1);
    pool_base = (void *)aligned;

    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = fault_handler;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_NODEFER;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    install_alternate_stack();

    clock_origin_ns = raw_clock_ns();
}
/* }}} */

/* {{{ twin_platform_set_log */
void twin_platform_set_log(const char *path, int also_stdout)
{
    if (log_fd >= 0) {
        close(log_fd);
        log_fd = -1;
    }
    if (path) {
        log_fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (log_fd < 0) {
            fprintf(stderr, "twin: cannot open log %s: %s\n", path, strerror(errno));
            exit(2);
        }
    }
    log_to_stdout = also_stdout;
}
/* }}} */

/* {{{ twin_platform_shutdown */
void twin_platform_shutdown(void)
{
    /* The mapping was made one stripe larger than the pool; the original
     * address is not kept, so the whole reservation is simply left to the
     * process exit. Only the log needs closing. */
    if (log_fd >= 0) {
        close(log_fd);
        log_fd = -1;
    }
}
/* }}} */

/* {{{ platform_caller_token */
static __thread char caller_token_home;
uintptr_t platform_caller_token(void)
{
    return (uintptr_t)&caller_token_home;
}
/* }}} */

/* {{{ platform_core_count */
int platform_core_count(void)
{
    return core_total;
}
/* }}} */

/* {{{ platform_core_id */
int platform_core_id(void)
{
    return this_core;
}
/* }}} */

struct core_start {
    void (*entry)(int core);
    int core;
};

/* {{{ core_thread */
static void *core_thread(void *arg)
{
    struct core_start *start = arg;
    this_core = start->core;
    install_alternate_stack();
    start->entry(start->core);
    return NULL;
}
/* }}} */

/* {{{ platform_start_cores */
void platform_start_cores(int count, void (*entry)(int core))
{
    if (count != core_total) {
        platform_halt("platform_start_cores: count differs from the configured core total");
    }
    pthread_t threads[PLATFORM_MAX_CORES];
    struct core_start starts[PLATFORM_MAX_CORES];
    for (int c = 1; c < count; c++) {
        starts[c].entry = entry;
        starts[c].core  = c;
        if (pthread_create(&threads[c], NULL, core_thread, &starts[c]) != 0) {
            platform_halt("platform_start_cores: could not start a thread");
        }
    }
    /* The calling thread becomes core 0, exactly as on the device where
     * the boot core becomes an ordinary worker once the gate opens. */
    int previous = this_core;
    this_core = 0;
    entry(0);
    this_core = previous;
    for (int c = 1; c < count; c++) {
        pthread_join(threads[c], NULL);
    }
}
/* }}} */

/* {{{ futex_wait */
static void futex_wait(_Atomic uint32_t *word, uint32_t expected, const struct timespec *timeout)
{
    syscall(SYS_futex, (uint32_t *)word, FUTEX_WAIT_PRIVATE, expected, timeout, NULL, 0);
}
/* }}} */

/* {{{ futex_wake_all */
static void futex_wake_all(_Atomic uint32_t *word)
{
    syscall(SYS_futex, (uint32_t *)word, FUTEX_WAKE_PRIVATE, 0x7fffffff, NULL, NULL, 0);
}
/* }}} */

/* {{{ platform_wait_for_event */
void platform_wait_for_event(void)
{
    int core = this_core;
    if (core < 0) {
        platform_halt("platform_wait_for_event: called from outside a core");
    }
    _Atomic uint32_t *flag = &events[core].flag;
    /* Two paths: the flag was already set (a wake arrived before we got
     * here — consume it and return, the lost-wakeup window closed), or it
     * was clear (sleep until someone sets it; the kernel re-checks the
     * word before sleeping, which is the twin's version of the chip doing
     * the same inside wait-for-event). */
    while (atomic_exchange(flag, 0) == 0) {
        futex_wait(flag, 0, NULL);
    }
}
/* }}} */

/* {{{ platform_wait_until */
void platform_wait_until(uint64_t deadline_ns)
{
    int core = this_core;
    if (core < 0) {
        platform_halt("platform_wait_until: called from outside a core");
    }
    _Atomic uint32_t *flag = &events[core].flag;
    for (;;) {
        if (atomic_exchange(flag, 0) != 0) {
            return;                        /* woken by an event */
        }
        uint64_t now = platform_now_ns();
        if (now >= deadline_ns) {
            return;                        /* woken by the deadline */
        }
        uint64_t wait = deadline_ns - now;
        struct timespec ts = { (time_t)(wait / 1000000000ull), (long)(wait % 1000000000ull) };
        futex_wait(flag, 0, &ts);
    }
}
/* }}} */

/* {{{ platform_send_event */
void platform_send_event(void)
{
    for (int c = 0; c < core_total; c++) {
        /* Set first, then wake: a core that checks between the two finds
         * the flag set and never sleeps. */
        if (atomic_exchange(&events[c].flag, 1) == 0) {
            futex_wake_all(&events[c].flag);
        }
    }
}
/* }}} */

/* {{{ platform_now_ns */
uint64_t platform_now_ns(void)
{
    return raw_clock_ns() - clock_origin_ns;
}
/* }}} */

/* {{{ platform_entropy */
uint64_t platform_entropy(void)
{
    uint64_t bits = 0;
    /* A twin run may ask for a repeatable sequence by setting
     * SOREN_SEED; otherwise the operating system's generator answers. */
    const char *fixed = getenv("SOREN_SEED");
    if (fixed) {
        static _Atomic uint64_t calls;
        return strtoull(fixed, NULL, 0) * 0x9e3779b97f4a7c15ull + atomic_fetch_add(&calls, 1) + 1;
    }
    if (syscall(SYS_getrandom, &bits, sizeof bits, 0) != (long)sizeof bits) {
        platform_halt("twin: the operating system would not give random bits");
    }
    return bits | 1;
}
/* }}} */

/* {{{ platform_pool_base */
void *platform_pool_base(void)
{
    return pool_base;
}
/* }}} */

/* {{{ platform_pool_size */
size_t platform_pool_size(void)
{
    return pool_size;
}
/* }}} */

/* {{{ platform_write */
void platform_write(const char *text, size_t len)
{
    pthread_mutex_lock(&write_lock);
    if (log_to_stdout) {
        ssize_t r = write(1, text, len);
        (void)r;
    }
    if (log_fd >= 0) {
        ssize_t r = write(log_fd, text, len);
        (void)r;
    }
    pthread_mutex_unlock(&write_lock);
}
/* }}} */

static void (*last_words)(void);
static _Atomic int halting;

/* {{{ platform_set_last_words */
void platform_set_last_words(void (*words)(void))
{
    last_words = words;
}
/* }}} */

/* {{{ platform_halt */
void platform_halt(const char *why)
{
    if (atomic_exchange(&halting, 1) == 0 && last_words) {
        last_words();
    }
    fprintf(stderr, "HALT (core %d): %s\n", this_core, why);
    fflush(stderr);
    abort();
}
/* }}} */

/* The two screens: plain memory, the same shape as the device's
 * framebuffers. Saved as pictures by 057-screens-twin.c. */
#define TWIN_SCREEN_W 640
#define TWIN_SCREEN_H 480
static uint32_t twin_pixels[PLATFORM_SCREEN_COUNT][TWIN_SCREEN_W * TWIN_SCREEN_H];
static _Atomic uint64_t twin_presents[PLATFORM_SCREEN_COUNT];

/* {{{ platform_screen */
struct platform_screen platform_screen(int which)
{
    if (which < 0 || which >= PLATFORM_SCREEN_COUNT) {
        platform_halt("twin: no such screen");
    }
    struct platform_screen s = { twin_pixels[which], TWIN_SCREEN_W, TWIN_SCREEN_H, TWIN_SCREEN_W };
    return s;
}
/* }}} */

/* {{{ platform_screen_present */
void platform_screen_present(int which)
{
    atomic_fetch_add(&twin_presents[which], 1);
}
/* }}} */

/* {{{ twin_screen_presents */
uint64_t twin_screen_presents(int which)
{
    return atomic_load(&twin_presents[which]);
}
/* }}} */

/* {{{ platform_guarded_call */
uint64_t platform_guarded_call(void (*call)(const void *in, void *out),
                               const void *in, void *out)
{
    /* Two paths back out of sigsetjmp: 0 the first time through (arm the
     * guard and call the box), nonzero when the fault handler jumped back
     * here (the box faulted; report what it touched). */
    if (sigsetjmp(guard_snapshot, 1) != 0) {
        return guard_detail;
    }
    guard_detail = 0;
    guard_armed = 1;
    call(in, out);
    guard_armed = 0;
    return 0;
}
/* }}} */
