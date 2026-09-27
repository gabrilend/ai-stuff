/*
 * 067-values.h — a value written as text, and back (issue 303's field
 * tables in use).
 *
 * General description: a map writes fixed values as text — `42`, `-7`,
 * `0x1f`, `'a'`, `"world"`, `{ 5, "hey" }`, `{ 1, 2, 3 }` — and a port holds
 * bytes. These two calls turn one into the other using the catalogue's
 * type rows: integers by their width and signedness, text fields as quoted
 * strings, value types field by field in declaration order, with every
 * offset the one the compiler worked out. A value type with exactly one
 * field may be written without its braces. Anything that does not fit —
 * too many fields, a number too wide, a string too long — is refused with
 * a reason, never partly filled.
 */
#ifndef SOREN_VALUES_H
#define SOREN_VALUES_H

#include <stddef.h>

/* Parse `text` as a value of the type named `type` (as a box parameter
 * names it: "int64_t", "struct text") into `out`, which is `size` bytes.
 * Answers 0, or a nonzero code with a sentence in `why`. */
int value_parse(const char *type, const char *text, void *out, size_t size, char *why, size_t why_size);

/* Write `bytes` (a value of type `type`) as text value_parse reads back
 * to the same bytes. Answers the length written, or -1 for an unknown
 * type. */
int value_print(const char *type, const void *bytes, size_t size, char *out, size_t out_size);

/* The weighted kind's weights: `{ 1, 2, 3 }`, one unsigned 32-bit number
 * per exit. */
int value_parse_weights(const char *text, unsigned int *weights, int count, char *why, size_t why_size);
int value_print_weights(const unsigned int *weights, int count, char *out, size_t out_size);

#endif
