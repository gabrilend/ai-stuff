/*
 * 025-platform.h — the handful of hardware questions the portable code asks.
 *
 * General description: everything under src/engine/ and src/system/ is
 * compiled twice — once into the kernel image for the handheld, once into
 * an ordinary program on the laptop (the "twin", issue 200). Neither copy
 * knows which one it is in. Whenever it needs a fact only the machine can
 * answer — how many cores, which one am I, what time is it, where is the
 * memory, how does a core sleep and get woken, where does a line of text
 * go — it asks through the calls declared here, and each build links in
 * its own answers: src/device/ for the handheld, twin/ for the laptop.
 *
 * Declarations only. Nothing in this file has a body.
 */
#ifndef SOREN_PLATFORM_H
#define SOREN_PLATFORM_H

#include <stdint.h>
#include <stddef.h>

/* The most cores any build will ever run. The handheld has four; the twin
 * may be asked for fewer (one, to answer "does the engine parallelise") or
 * the same four. Arrays sized per core use this, so it is a hard ceiling
 * rather than a hint. */
#define PLATFORM_MAX_CORES 16

/* {{{ cores */
/* How many cores this run has. Fixed once the cores are started. */
int platform_core_count(void);

/* Which core is asking: 0 .. platform_core_count()-1. On the device this
 * is read from the per-core register the core's startup stub filled in
 * (issue 202); on the twin it is a per-thread variable. Calling this from
 * a thread the platform did not start answers -1 — the twin's main thread
 * before the gate opens is such a caller. */
int platform_core_id(void);

/* Start `count` cores, each entering `entry(core_number)` on its own
 * stack. The calling core becomes core 0 and enters `entry(0)` itself, so
 * this call does not return until every core's entry has returned. On the
 * device, entry never returns (the run loop is forever); on the twin it
 * returns when the engine is shut down, which is how a test ends. */
void platform_start_cores(int count, void (*entry)(int core));
/* }}} */

/* {{{ sleeping and waking (issue 206) */
/* Park this core until its event flag is set, then consume the flag.
 * A flag set BEFORE this call makes it return immediately — that is the
 * whole point: a wake that lands between "the ring looked empty" and "go
 * to sleep" is not lost. The device uses the chip's one-bit event register
 * (wait-for-event); the twin uses a per-core word and a kernel wait. */
void platform_wait_for_event(void);

/* The same, but also return once the clock reaches `deadline_ns`. The
 * device arms the core's own timer and waits for its pending flag with
 * interrupts masked, so no handler runs; the twin uses a timed wait. */
void platform_wait_until(uint64_t deadline_ns);

/* Set every core's event flag and wake any that are parked. Cheap and
 * unconditional: a redundant one costs a parked core one extra look. */
void platform_send_event(void);
/* }}} */

/* {{{ time */
/* Nanoseconds since some fixed point in this run. Monotonic. */
uint64_t platform_now_ns(void);
/* }}} */

/* {{{ entropy */
/* 64 unpredictable bits, for seeding. The device reads the chip's random
 * number generator; the twin asks the operating system. Called once per
 * core at startup, never per value: per-value randomness comes from a
 * small generator each core keeps, seeded from this (issue 308's open
 * question about whether the chip's generator is cheap enough per value). */
uint64_t platform_entropy(void);
/* }}} */

/* {{{ memory */
/* The one pool of memory the page allocator (issue 203) carves up. Its
 * base is aligned to at least 2 MB and its size is a whole number of 2 MB
 * stripes, because a stripe is one cache line of allocator bitmap. */
void  *platform_pool_base(void);
size_t platform_pool_size(void);
/* }}} */

/* {{{ the developer's line */
/* Write `len` bytes of text where the developer will see it: the USB
 * serial line and the SD-card log on the device; standard output and
 * tmp/shared-memory/ on the twin. Safe from any core; lines from two
 * cores may interleave at line granularity but are never torn mid-line
 * because the caller hands over whole lines. */
void platform_write(const char *text, size_t len);

/* Something is wrong below the level any box could have caused. Say so
 * and never return: red LED and park on the device, abort on the twin. */
void platform_halt(const char *why) __attribute__((noreturn));
/* }}} */

/* {{{ screens */
/* The two panels: 0 is the top screen, 1 the bottom. Each is 640 by 480
 * pixels, one 32-bit word per pixel laid out 0xAARRGGBB (the display
 * controller's ARGB8888, alpha always 0xFF), rows `stride` words apart.
 * On the device these are the framebuffers the display controller scans
 * out (issue 111d); on the twin, memory that can be saved as a picture or
 * shown in a window. */
#define PLATFORM_SCREEN_COUNT 2
struct platform_screen {
    uint32_t *pixels;
    int       width;
    int       height;
    int       stride;            /* words from one row to the next */
};
struct platform_screen platform_screen(int which);

/* The pixels of a screen are finished for this frame: make sure they reach
 * the panel (the device cleans its cache over the framebuffer so the
 * display controller, which does not look in the cache, sees them; the
 * twin counts a frame and may show or record it). */
void platform_screen_present(int which);
/* }}} */

/* {{{ surviving a box that faults (issue 214, debug builds only) */
/* A snapshot is a place to come back to. The engine takes one before
 * calling into a box; if the box faults, the platform returns to it with
 * a nonzero answer instead of the fault becoming a panic. Only the debug
 * build pays for this, on every single run, which is why the ordinary
 * build has none of it. Where the snapshot lives is the platform's
 * business: one per core, never shared. */

/* Arm a fault catcher for this core and run `call(in, out)` under it.
 * Answers 0 if the call returned normally, or the fault's address-ish
 * detail (never 0) if it faulted and control came back here. */
uint64_t platform_guarded_call(void (*call)(const void *in, void *out),
                               const void *in, void *out);
/* }}} */

#endif
