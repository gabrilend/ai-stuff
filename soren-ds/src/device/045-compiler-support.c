/*
 * 045-compiler-support.c — the four routines the C compiler assumes exist.
 *
 * General description: even with no standard library, GCC is allowed to
 * turn an ordinary loop or a large struct assignment into a call to
 * memcpy, memset, memmove or memcmp. The kernel links no library that
 * provides them, so the kernel provides them here. The laptop twin does
 * not compile this file (it is under src/device/), because its C library
 * already has them.
 */
#include <stddef.h>
#include <stdint.h>

/* {{{ memcpy */
void *memcpy(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (n--) {
        *d++ = *s++;
    }
    return dst;
}
/* }}} */

/* {{{ memmove */
void *memmove(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    /* Two directions: copying down (front to back is safe) or up over
     * itself (back to front, so nothing is overwritten before it is read). */
    if (d < s) {
        while (n--) {
            *d++ = *s++;
        }
    } else {
        d += n;
        s += n;
        while (n--) {
            *--d = *--s;
        }
    }
    return dst;
}
/* }}} */

/* {{{ memset */
void *memset(void *dst, int value, size_t n)
{
    uint8_t *d = dst;
    while (n--) {
        *d++ = (uint8_t)value;
    }
    return dst;
}
/* }}} */

/* {{{ memcmp */
int memcmp(const void *a, const void *b, size_t n)
{
    const uint8_t *x = a, *y = b;
    for (size_t i = 0; i < n; i++) {
        if (x[i] != y[i]) {
            return x[i] < y[i] ? -1 : 1;
        }
    }
    return 0;
}
/* }}} */
