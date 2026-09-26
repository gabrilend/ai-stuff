/*
 * 027-primitives.c — the bodies of the engine's small tools.
 *
 * General description: byte copying, a checksum, a spin lock that serves
 * cores in arrival order, and a line formatter — written here because the
 * kernel links no standard library, and written once so the handheld and
 * the laptop twin run exactly the same versions of them.
 */
#include "025-platform.h"
#include "027-primitives.h"

/* {{{ spin_lock */
void spin_lock(spin_lock_t *lock)
{
    uint32_t mine = __atomic_fetch_add(&lock->next, 1, __ATOMIC_RELAXED);
    /* Wait until our number is served. The acquire load is what makes
     * everything the previous holder wrote visible to us once we are in. */
    while (atomic_load_acquire(&lock->serving) != mine) {
#if defined(__aarch64__)
        __asm__ volatile("yield");
#elif defined(__x86_64__)
        __asm__ volatile("pause");
#endif
    }
}
/* }}} */

/* {{{ spin_unlock */
void spin_unlock(spin_lock_t *lock)
{
    /* Only the holder writes `serving`, so a plain increment published
     * with release ordering is enough. */
    uint32_t next = atomic_load_relaxed(&lock->serving) + 1;
    atomic_store_release(&lock->serving, next);
}
/* }}} */

/* {{{ spin_trylock */
int spin_trylock(spin_lock_t *lock)
{
    uint32_t serving = atomic_load_acquire(&lock->serving);
    uint32_t expected = serving;
    /* Taken only when the next ticket to hand out is the one being
     * served: nobody holds it and nobody is queued. */
    return __atomic_compare_exchange_n(&lock->next, &expected, serving + 1, 0,
                                       __ATOMIC_ACQUIRE, __ATOMIC_RELAXED);
}
/* }}} */

/* {{{ bytes_copy */
void bytes_copy(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    /* Two paths: both pointers share 8-byte alignment (copy whole words,
     * then the tail), or they do not (copy bytes). Values in ports and
     * tasks are laid out on 8-byte boundaries, so the first path is the
     * ordinary one. */
    if ((((uintptr_t)d | (uintptr_t)s) & 7) == 0) {
        while (n >= 8) {
            *(uint64_t *)d = *(const uint64_t *)s;
            d += 8; s += 8; n -= 8;
        }
    }
    while (n--) {
        *d++ = *s++;
    }
}
/* }}} */

/* {{{ bytes_zero */
void bytes_zero(void *dst, size_t n)
{
    uint8_t *d = dst;
    if (((uintptr_t)d & 7) == 0) {
        while (n >= 8) {
            *(uint64_t *)d = 0;
            d += 8; n -= 8;
        }
    }
    while (n--) {
        *d++ = 0;
    }
}
/* }}} */

/* {{{ bytes_equal */
int bytes_equal(const void *a, const void *b, size_t n)
{
    const uint8_t *x = a, *y = b;
    for (size_t i = 0; i < n; i++) {
        if (x[i] != y[i]) {
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ text_length */
size_t text_length(const char *s)
{
    size_t n = 0;
    while (s[n]) {
        n++;
    }
    return n;
}
/* }}} */

/* {{{ text_equal */
int text_equal(const char *a, const char *b)
{
    while (*a && *a == *b) {
        a++; b++;
    }
    return *a == *b;
}
/* }}} */

/* {{{ bytes_checksum */
uint64_t bytes_checksum(const void *p, size_t n, uint64_t seed)
{
    const uint8_t *b = p;
    uint64_t h = seed ^ 0xcbf29ce484222325ull;
    for (size_t i = 0; i < n; i++) {
        h ^= b[i];
        h *= 0x100000001b3ull;
    }
    return h;
}
/* }}} */

/* The formatter writes into a bounded buffer and keeps counting past the
 * end, so the caller can tell a line was cut. */
struct text_sink {
    char  *out;
    size_t size;
    size_t used;
};

/* {{{ sink_put */
static void sink_put(struct text_sink *s, char c)
{
    if (s->used + 1 < s->size) {
        s->out[s->used] = c;
    }
    s->used++;
}
/* }}} */

/* {{{ sink_number */
static void sink_number(struct text_sink *s, uint64_t value, int negative,
                        unsigned base, int width, char pad)
{
    char digits[24];
    int n = 0;
    do {
        unsigned d = (unsigned)(value % base);
        digits[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10);
        value /= base;
    } while (value);
    int total = n + negative;
    /* Zero padding goes after the sign; space padding goes before it. */
    if (negative && pad == '0') {
        sink_put(s, '-');
    }
    for (int i = total; i < width; i++) {
        sink_put(s, pad);
    }
    if (negative && pad != '0') {
        sink_put(s, '-');
    }
    while (n--) {
        sink_put(s, digits[n]);
    }
}
/* }}} */

/* {{{ text_format_va */
int text_format_va(char *out, size_t size, const char *fmt, va_list args)
{
    struct text_sink s = { out, size, 0 };
    for (const char *f = fmt; *f; f++) {
        if (*f != '%') {
            sink_put(&s, *f);
            continue;
        }
        f++;
        char pad = ' ';
        int width = 0;
        int longs = 0;
        if (*f == '0') {
            pad = '0';
            f++;
        }
        while (*f >= '0' && *f <= '9') {
            width = width * 10 + (*f - '0');
            f++;
        }
        while (*f == 'l') {
            longs++;
            f++;
        }
        if (*f == 'z') {           /* size_t: same width as a long here */
            longs = 1;
            f++;
        }
        /* One conversion per character; an unknown one is printed as is,
         * so a mistake in a format is visible in the output rather than
         * silently swallowed. */
        switch (*f) {
        case 'd':
        case 'i': {
            int64_t v = longs ? va_arg(args, long long) : va_arg(args, int);
            sink_number(&s, v < 0 ? (uint64_t)(-(v + 1)) + 1 : (uint64_t)v, v < 0, 10, width, pad);
            break;
        }
        case 'u': {
            uint64_t v = longs ? va_arg(args, unsigned long long) : va_arg(args, unsigned);
            sink_number(&s, v, 0, 10, width, pad);
            break;
        }
        case 'x': {
            uint64_t v = longs ? va_arg(args, unsigned long long) : va_arg(args, unsigned);
            sink_number(&s, v, 0, 16, width, pad);
            break;
        }
        case 'p': {
            uintptr_t v = (uintptr_t)va_arg(args, void *);
            sink_put(&s, '0');
            sink_put(&s, 'x');
            sink_number(&s, v, 0, 16, width, pad);
            break;
        }
        case 's': {
            const char *str = va_arg(args, const char *);
            size_t len = text_length(str);
            for (size_t i = len; i < (size_t)width; i++) {
                sink_put(&s, ' ');
            }
            while (*str) {
                sink_put(&s, *str++);
            }
            break;
        }
        case 'c':
            sink_put(&s, (char)va_arg(args, int));
            break;
        case '%':
            sink_put(&s, '%');
            break;
        case '\0':
            f--;
            break;
        default:
            sink_put(&s, '%');
            sink_put(&s, *f);
            break;
        }
    }
    if (size) {
        out[s.used < size ? s.used : size - 1] = '\0';
    }
    return (int)s.used;
}
/* }}} */

/* {{{ text_format */
int text_format(char *out, size_t size, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    int n = text_format_va(out, size, fmt, args);
    va_end(args);
    return n;
}
/* }}} */

/* {{{ say */
void say(const char *fmt, ...)
{
    char line[512];
    va_list args;
    va_start(args, fmt);
    int n = text_format_va(line, sizeof line - 1, fmt, args);
    va_end(args);
    size_t len = (size_t)n < sizeof line - 2 ? (size_t)n : sizeof line - 2;
    if (len == 0 || line[len - 1] != '\n') {
        line[len++] = '\n';
    }
    platform_write(line, len);
}
/* }}} */
