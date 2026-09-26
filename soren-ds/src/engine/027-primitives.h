/*
 * 027-primitives.h — the few small tools every other engine file leans on.
 *
 * General description: the kernel has no standard library, so the engine
 * brings its own: a way to copy and compare bytes, a way to format a line
 * of text for the developer, a spin lock that hands itself over in the
 * order cores asked for it, and a handful of named atomic operations. The
 * atomics are thin names over the compiler's own built-ins — on the
 * handheld those become the chip's exclusive-access or single-instruction
 * atomic instructions, which is why issue 201 (turning the caches on) has
 * to come first: on memory the chip treats as "device" memory those
 * instructions are undefined.
 */
#ifndef SOREN_PRIMITIVES_H
#define SOREN_PRIMITIVES_H

#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>

/* The cache moves memory in 64-byte lines. Two things written by two
 * different cores must not share one, or every write by one takes the
 * line away from the other even though nothing is racing (false sharing —
 * the rule issues 203, 205 and 208 each state in their own place). */
#define CACHE_LINE 64
#define LINE_ALIGNED __attribute__((aligned(CACHE_LINE)))

#define PAGE_BYTES ((size_t)4096)
#define PAGE_SHIFT_BITS 12

/* {{{ atomics */
/* Every atomic in the engine goes through these names, so the ordering
 * each one promises is written once. "acquire" on a load means nothing
 * after it can be seen to happen before it; "release" on a store means
 * everything before it is visible to whoever acquires it. The engine's
 * one ordering rule — build a thing completely, then publish it — is a
 * release store of the thing's address or count. */
#define atomic_load_relaxed(p)      __atomic_load_n((p), __ATOMIC_RELAXED)
#define atomic_load_acquire(p)      __atomic_load_n((p), __ATOMIC_ACQUIRE)
#define atomic_store_relaxed(p, v)  __atomic_store_n((p), (v), __ATOMIC_RELAXED)
#define atomic_store_release(p, v)  __atomic_store_n((p), (v), __ATOMIC_RELEASE)
#define atomic_add(p, v)            __atomic_add_fetch((p), (v), __ATOMIC_ACQ_REL)
#define atomic_sub(p, v)            __atomic_sub_fetch((p), (v), __ATOMIC_ACQ_REL)
#define atomic_fetch_add_rel(p, v)  __atomic_fetch_add((p), (v), __ATOMIC_ACQ_REL)
#define atomic_or(p, v)             __atomic_fetch_or((p), (v), __ATOMIC_ACQ_REL)
#define atomic_and(p, v)            __atomic_fetch_and((p), (v), __ATOMIC_ACQ_REL)
#define atomic_swap(p, v)           __atomic_exchange_n((p), (v), __ATOMIC_ACQ_REL)
/* Compare-and-swap: if *p equals *expected, write v and answer 1;
 * otherwise copy the value found into *expected and answer 0. */
#define atomic_cas(p, expected, v)  __atomic_compare_exchange_n((p), (expected), (v), 0, \
                                        __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)
/* }}} */

/* {{{ spin lock */
/* A ticket lock: taking it draws the next number, and the lock is held by
 * whoever's number is being served. Cores are therefore served in the
 * order they arrived, so a core that just released cannot immediately
 * take it again ahead of one that has been waiting (issue 204's second
 * open question — the simple test-and-set lock allows exactly that).
 *
 * Only ever held for a bounded, short stretch, and never on the delivery
 * path. Nothing interrupts a core holding one, because no interrupt
 * handler in this design touches the engine. */
typedef struct {
    uint32_t next;      /* the next ticket to hand out */
    uint32_t serving;   /* the ticket that currently holds the lock */
} spin_lock_t;

#define SPIN_LOCK_INIT { 0, 0 }

void spin_lock(spin_lock_t *lock);
void spin_unlock(spin_lock_t *lock);
/* Take it only if nobody holds it and nobody is waiting. Answers 1 if
 * taken. Used where losing the race means "somebody else is already
 * doing this job", such as firing due timers. */
int  spin_trylock(spin_lock_t *lock);
/* }}} */

/* {{{ bytes */
/* The kernel has no memcpy of its own; these are the engine's. They are
 * plain loops over words where alignment allows and bytes elsewhere. */
void   bytes_copy(void *dst, const void *src, size_t n);
void   bytes_zero(void *dst, size_t n);
int    bytes_equal(const void *a, const void *b, size_t n);
size_t text_length(const char *s);
int    text_equal(const char *a, const char *b);
/* A 64-bit FNV-1a checksum. Used by parking (issue 213) to notice whether
 * released memory was handed to somebody else while it was away. */
uint64_t bytes_checksum(const void *p, size_t n, uint64_t seed);
/* }}} */

/* {{{ text */
/* A small formatter for lines the developer reads. Understands %d %i %u
 * %x %s %c %p %%, the length prefixes l and ll, a field width, and a
 * leading zero for zero-padding. Always terminates the output and answers
 * how many characters were written (not counting the terminator). */
int text_format(char *out, size_t size, const char *fmt, ...);
int text_format_va(char *out, size_t size, const char *fmt, va_list args);

/* Format one line and hand it to the developer's line (platform_write).
 * A newline is appended if the text does not end in one. */
void say(const char *fmt, ...);
/* }}} */

/* {{{ small arithmetic */
/* How many bits are set. Written out rather than left to the compiler's
 * built-in, because on the kernel's integer-only build that built-in
 * becomes a call into a support library the kernel does not link. */
static inline int bits_set(uint64_t x)
{
    x = x - ((x >> 1) & 0x5555555555555555ull);
    x = (x & 0x3333333333333333ull) + ((x >> 2) & 0x3333333333333333ull);
    x = (x + (x >> 4)) & 0x0f0f0f0f0f0f0f0full;
    return (int)((x * 0x0101010101010101ull) >> 56);
}

static inline size_t round_up(size_t x, size_t to)
{
    return (x + to - 1) / to * to;
}

static inline size_t round_up_pow2(size_t x, size_t to)
{
    return (x + to - 1) & ~(to - 1);
}
/* }}} */

#endif
