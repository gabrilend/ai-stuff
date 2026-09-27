/*
 * 063-text.c — text as a value (issues 301, 310, 312).
 *
 * General description: a box may not pass a string — a pointer would share
 * memory nobody owns — so text travels as a value type: a fixed array of
 * 64 characters, ended by a zero. It is copied like any other value, so
 * two stations holding "the same text" hold two copies. A map writes one
 * as a quoted string ("world"); the field table below is what turns that
 * into the 64 bytes. The boxes here make, change, compare and say text.
 */
#include <stdint.h>
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"

#define TEXT_CHARS 64

struct text {
    char chars[TEXT_CHARS];
};

/* {{{ text__compare */
/* The ordering a comparator over text uses: dictionary order, byte by
 * byte, the shorter text first when one is the start of the other. */
int text__compare(struct text a, struct text b)
{
    for (int i = 0; i < TEXT_CHARS; i++) {
        unsigned char x = (unsigned char)a.chars[i], y = (unsigned char)b.chars[i];
        if (x != y) {
            return x < y ? -1 : 1;
        }
        if (x == 0) {
            return 0;
        }
    }
    return 0;
}
/* }}} */

/* {{{ constant_text */
struct text constant_text(struct text value)
{
    return value;
}
/* }}} */

/* {{{ to_upper */
struct text to_upper(struct text t)
{
    for (int i = 0; i < TEXT_CHARS && t.chars[i]; i++) {
        if (t.chars[i] >= 'a' && t.chars[i] <= 'z') {
            t.chars[i] = (char)(t.chars[i] - 'a' + 'A');
        }
    }
    return t;
}
/* }}} */

/* {{{ say */
/* One line out the developer's channel: the text. A sink. */
void say(struct text t)
{
    t.chars[TEXT_CHARS - 1] = 0;
    say_line("%s", t.chars);
}
/* }}} */

/* {{{ join */
/* Two texts, one after the other, cut to fit. */
struct text join(struct text left, struct text right)
{
    int n = 0;
    while (n < TEXT_CHARS - 1 && left.chars[n]) n++;
    for (int i = 0; n < TEXT_CHARS - 1 && right.chars[i]; i++) {
        left.chars[n++] = right.chars[i];
    }
    left.chars[n] = 0;
    return left;
}
/* }}} */

/* {{{ number_text */
/* A number written out in decimal. */
struct text number_text(int64_t v)
{
    struct text t;
    text_format(t.chars, TEXT_CHARS, "%lld", (long long)v);
    return t;
}
/* }}} */
