/*
 * 067-values.c — reading and writing values as text.
 *
 * General description: a small recursive reader over the text, guided by
 * the catalogue's type row for what is expected next: an integer of a
 * given width, a quoted string for a text field, or a brace list for a
 * value type (one entry per field, in order) or an integer array. The
 * writer walks the same rows the other way.
 */
#include "027-primitives.h"
#include "070-catalogue.h"
#include "067-values.h"

struct cursor {
    const char *s;
    size_t      at;
    char       *why;
    size_t      why_size;
    int         failed;
};

/* {{{ fail */
static int fail(struct cursor *c, const char *fmt, const char *detail)
{
    if (!c->failed) {
        text_format(c->why, c->why_size, fmt, detail ? detail : "");
    }
    c->failed = 1;
    return 1;
}
/* }}} */

/* {{{ skip */
static void skip(struct cursor *c)
{
    while (c->s[c->at] == ' ' || c->s[c->at] == '\t' || c->s[c->at] == '\n' || c->s[c->at] == '\r') c->at++;
}
/* }}} */

/* {{{ read_integer_text */
/* A decimal or hexadecimal integer, optionally negative, or a character
 * in single quotes. */
static int read_integer_text(struct cursor *c, int64_t *out, uint64_t *magnitude, int *negative)
{
    skip(c);
    const char *s = c->s + c->at;
    *negative = 0;
    if (s[0] == '\'') {
        if (!s[1] || s[2] != '\'') return fail(c, "a character is written as one character in single quotes", 0);
        *out = (unsigned char)s[1];
        *magnitude = (unsigned char)s[1];
        c->at += 3;
        return 0;
    }
    size_t i = 0;
    if (s[i] == '-') { *negative = 1; i++; }
    uint64_t v = 0;
    int digits = 0;
    if (s[i] == '0' && (s[i + 1] == 'x' || s[i + 1] == 'X')) {
        i += 2;
        for (;; i++) {
            char ch = s[i];
            int d = ch >= '0' && ch <= '9' ? ch - '0' : ch >= 'a' && ch <= 'f' ? ch - 'a' + 10 : ch >= 'A' && ch <= 'F' ? ch - 'A' + 10 : -1;
            if (d < 0) break;
            if (v >> 60) return fail(c, "a number too large for 64 bits", 0);
            v = v * 16 + (uint64_t)d;
            digits++;
        }
    } else {
        for (; s[i] >= '0' && s[i] <= '9'; i++) {
            if (v > (~0ull - 9) / 10) return fail(c, "a number too large for 64 bits", 0);
            v = v * 10 + (uint64_t)(s[i] - '0');
            digits++;
        }
    }
    if (!digits) {
        char seen[24];
        size_t k = 0;
        while (s[k] && s[k] != ',' && s[k] != '}' && k + 1 < sizeof seen) { seen[k] = s[k]; k++; }
        seen[k] = 0;
        return fail(c, "expected a number, found \"%s\"", seen);
    }
    c->at += i;
    *magnitude = v;
    *out = *negative ? -(int64_t)v : (int64_t)v;
    return 0;
}
/* }}} */

/* {{{ store_integer */
/* Check the number fits `size` bytes as signed or unsigned, and store it
 * little-endian. */
static int store_integer(struct cursor *c, int is_signed, size_t size, uint8_t *out)
{
    int64_t v;
    uint64_t magnitude;
    int negative;
    if (read_integer_text(c, &v, &magnitude, &negative)) return 1;
    if (size > 8) return fail(c, "an integer wider than 64 bits", 0);
    int bits = (int)size * 8;
    if (is_signed) {
        uint64_t limit = bits == 64 ? (1ull << 63) : (1ull << (bits - 1));
        if ((negative && magnitude > limit) || (!negative && magnitude >= limit)) {
            return fail(c, "the number does not fit a signed integer this wide", 0);
        }
    } else {
        if (negative) return fail(c, "a negative number cannot go into an unsigned integer", 0);
        if (bits < 64 && magnitude >> bits) return fail(c, "the number does not fit an unsigned integer this wide", 0);
    }
    uint64_t bitsv = (uint64_t)v;
    for (size_t i = 0; i < size; i++) {
        out[i] = (uint8_t)(bitsv >> (8 * i));
    }
    return 0;
}
/* }}} */

/* {{{ store_text */
static int store_text(struct cursor *c, size_t size, uint8_t *out)
{
    skip(c);
    if (c->s[c->at] != '"') return fail(c, "a text field is written in double quotes", 0);
    c->at++;
    size_t n = 0;
    bytes_zero(out, size);
    while (c->s[c->at] && c->s[c->at] != '"') {
        char ch = c->s[c->at++];
        if (ch == '\\' && c->s[c->at]) {
            char e = c->s[c->at++];
            ch = e == 'n' ? '\n' : e == 't' ? '\t' : e;
        }
        if (n + 1 >= size) return fail(c, "the text is too long for its field", 0);
        out[n++] = (uint8_t)ch;
    }
    if (c->s[c->at] != '"') return fail(c, "the text's closing quote is missing", 0);
    c->at++;
    return 0;
}
/* }}} */

static int store_typed(struct cursor *c, const struct catalogue_type *t, uint8_t *out, int allow_bare);

/* {{{ store_field */
static int store_field(struct cursor *c, const struct catalogue_field *f, uint8_t *out)
{
    /* Five kinds of field, each read its own way. */
    switch (f->kind) {
    case CATALOGUE_SIGNED:   return store_integer(c, 1, f->size, out);
    case CATALOGUE_UNSIGNED: return store_integer(c, 0, f->size, out);
    case CATALOGUE_TEXT:     return store_text(c, f->size, out);
    case CATALOGUE_STRUCT: {
        const struct catalogue_type *t = catalogue_type_named(f->type);
        if (!t) return fail(c, "no value type named %s", f->type);
        return store_typed(c, t, out, 1);
    }
    case CATALOGUE_ARRAY: {
        skip(c);
        if (c->s[c->at] != '{') return fail(c, "an array field is written as { n, n, ... }", 0);
        c->at++;
        size_t count = f->element ? f->size / f->element : 0;
        const char *ftype = f->type;
        int is_signed = !(ftype[0] == 'u' || (text_length(ftype) > 8 && ftype[0] == 'u')) &&
                        !text_equal(ftype, "size_t") && !text_equal(ftype, "uintptr_t");
        if (ftype[0] == 'u') is_signed = 0;
        bytes_zero(out, f->size);
        for (size_t i = 0;; i++) {
            skip(c);
            if (c->s[c->at] == '}') { c->at++; return 0; }
            if (i >= count) return fail(c, "more numbers than the array holds", 0);
            if (store_integer(c, is_signed, f->element, out + i * f->element)) return 1;
            skip(c);
            if (c->s[c->at] == ',') c->at++;
        }
    }
    }
    return fail(c, "a field of a kind the reader does not know", 0);
}
/* }}} */

/* {{{ store_typed */
static int store_typed(struct cursor *c, const struct catalogue_type *t, uint8_t *out, int allow_bare)
{
    if (t->kind == CATALOGUE_SIGNED || t->kind == CATALOGUE_UNSIGNED) {
        return store_integer(c, t->kind == CATALOGUE_SIGNED, t->size, out);
    }
    skip(c);
    /* A value type: a brace list, one entry per field in order — or, for
     * a type with exactly one field, that field's value alone. */
    if (c->s[c->at] != '{') {
        if (allow_bare && t->n_fields == 1) {
            bytes_zero(out, t->size);
            return store_field(c, &t->fields[0], out + t->fields[0].offset);
        }
        return fail(c, "%s is written as { field, field, ... }", t->name);
    }
    c->at++;
    bytes_zero(out, t->size);
    for (int i = 0; i < t->n_fields; i++) {
        if (store_field(c, &t->fields[i], out + t->fields[i].offset)) return 1;
        skip(c);
        if (i + 1 < t->n_fields) {
            if (c->s[c->at] != ',') {
                char why[160];
                text_format(why, sizeof why, "%s has %d fields and the value stops after %d", t->name, t->n_fields, i + 1);
                return fail(c, "%s", why);
            }
            c->at++;
        }
    }
    skip(c);
    if (c->s[c->at] == ',') {
        char why[160];
        text_format(why, sizeof why, "%s has %d fields and the value has more", t->name, t->n_fields);
        return fail(c, "%s", why);
    }
    if (c->s[c->at] != '}') return fail(c, "a '}' was expected after the last field", 0);
    c->at++;
    return 0;
}
/* }}} */

/* {{{ value_parse */
int value_parse(const char *type, const char *text, void *out, size_t size, char *why, size_t why_size)
{
    struct cursor c = { text, 0, why, why_size, 0 };
    const struct catalogue_type *t = catalogue_type_named(type);
    if (!t) {
        return fail(&c, "the catalogue has no type named %s", type);
    }
    if (t->size != size) {
        return fail(&c, "internal: the port is not the width of its type %s", type);
    }
    if (store_typed(&c, t, out, 1)) {
        return 1;
    }
    skip(&c);
    if (text[c.at]) {
        return fail(&c, "something follows the value: \"%s\"", text + c.at);
    }
    return 0;
}
/* }}} */

/* {{{ the writer */
struct out_text {
    char  *s;
    size_t size;
    size_t n;
};

/* {{{ put */
static void put(struct out_text *o, const char *s)
{
    while (*s) {
        if (o->n + 1 < o->size) o->s[o->n] = *s;
        o->n++;
        s++;
    }
    if (o->size) o->s[o->n < o->size ? o->n : o->size - 1] = 0;
}
/* }}} */

/* {{{ put_integer */
static void put_integer(struct out_text *o, int is_signed, size_t size, const uint8_t *in)
{
    uint64_t v = 0;
    for (size_t i = 0; i < size && i < 8; i++) v |= (uint64_t)in[i] << (8 * i);
    char buf[32];
    if (is_signed && size < 8) {
        uint64_t sign = 1ull << (size * 8 - 1);
        v = (v ^ sign) - sign;
    }
    if (is_signed) text_format(buf, sizeof buf, "%lld", (long long)(int64_t)v);
    else text_format(buf, sizeof buf, "%llu", (unsigned long long)v);
    put(o, buf);
}
/* }}} */

static void put_typed(struct out_text *o, const struct catalogue_type *t, const uint8_t *in, int bare);

/* {{{ put_field */
static void put_field(struct out_text *o, const struct catalogue_field *f, const uint8_t *in)
{
    switch (f->kind) {
    case CATALOGUE_SIGNED:   put_integer(o, 1, f->size, in); return;
    case CATALOGUE_UNSIGNED: put_integer(o, 0, f->size, in); return;
    case CATALOGUE_TEXT: {
        put(o, "\"");
        char one[3] = { 0, 0, 0 };
        for (size_t i = 0; i < f->size && in[i]; i++) {
            char ch = (char)in[i];
            if (ch == '"' || ch == '\\') { one[0] = '\\'; one[1] = ch; }
            else if (ch == '\n') { one[0] = '\\'; one[1] = 'n'; }
            else { one[0] = ch; one[1] = 0; }
            put(o, one);
        }
        put(o, "\"");
        return;
    }
    case CATALOGUE_STRUCT: {
        const struct catalogue_type *t = catalogue_type_named(f->type);
        if (t) put_typed(o, t, in, 0);
        return;
    }
    case CATALOGUE_ARRAY: {
        size_t count = f->element ? f->size / f->element : 0;
        /* Trailing zeroes are not written; the reader fills them back. */
        size_t last = count;
        while (last > 0) {
            int zero = 1;
            for (size_t b = 0; b < f->element; b++) if (in[(last - 1) * f->element + b]) zero = 0;
            if (!zero) break;
            last--;
        }
        put(o, "{ ");
        for (size_t i = 0; i < last; i++) {
            if (i) put(o, ", ");
            put_integer(o, f->type[0] != 'u', f->element, in + i * f->element);
        }
        put(o, last ? " }" : "}");
        return;
    }
    }
}
/* }}} */

/* {{{ put_typed */
static void put_typed(struct out_text *o, const struct catalogue_type *t, const uint8_t *in, int bare)
{
    if (t->kind == CATALOGUE_SIGNED || t->kind == CATALOGUE_UNSIGNED) {
        put_integer(o, t->kind == CATALOGUE_SIGNED, t->size, in);
        return;
    }
    /* A one-field value type is written bare at the top level, the way a
     * person would write it ("world", not { "world" }). */
    if (bare && t->n_fields == 1) {
        put_field(o, &t->fields[0], in + t->fields[0].offset);
        return;
    }
    put(o, "{ ");
    for (int i = 0; i < t->n_fields; i++) {
        if (i) put(o, ", ");
        put_field(o, &t->fields[i], in + t->fields[i].offset);
    }
    put(o, " }");
}
/* }}} */

/* {{{ value_print */
int value_print(const char *type, const void *bytes, size_t size, char *out, size_t out_size)
{
    const struct catalogue_type *t = catalogue_type_named(type);
    if (!t || t->size != size) {
        return -1;
    }
    struct out_text o = { out, out_size, 0 };
    put_typed(&o, t, bytes, 1);
    return (int)o.n;
}
/* }}} */
/* }}} */

/* {{{ value_parse_weights */
int value_parse_weights(const char *text, unsigned int *weights, int count, char *why, size_t why_size)
{
    struct cursor c = { text, 0, why, why_size, 0 };
    skip(&c);
    if (text[c.at] != '{') return fail(&c, "weights are written as { n, n, ... }, one per exit", 0);
    c.at++;
    for (int i = 0; i < count; i++) {
        uint8_t four[4];
        if (store_integer(&c, 0, 4, four)) return 1;
        weights[i] = (unsigned int)four[0] | (unsigned int)four[1] << 8 | (unsigned int)four[2] << 16 | (unsigned int)four[3] << 24;
        skip(&c);
        if (i + 1 < count) {
            if (text[c.at] != ',') return fail(&c, "there must be one weight per exit", 0);
            c.at++;
        }
    }
    skip(&c);
    if (text[c.at] != '}') return fail(&c, "there must be exactly one weight per exit", 0);
    return 0;
}
/* }}} */

/* {{{ value_print_weights */
int value_print_weights(const unsigned int *weights, int count, char *out, size_t out_size)
{
    struct out_text o = { out, out_size, 0 };
    put(&o, "{ ");
    for (int i = 0; i < count; i++) {
        char buf[16];
        text_format(buf, sizeof buf, i ? ", %u" : "%u", weights[i]);
        put(&o, buf);
    }
    put(&o, " }");
    return (int)o.n;
}
/* }}} */
