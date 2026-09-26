/*
 * 050-test-boxes.h — shorthand for declaring small boxes inside a test.
 *
 * General description: a box is a C function plus a record of its
 * parameters and an adapter the engine calls. Tests need many tiny ones,
 * so these macros write the record and adapter for the common shapes:
 * one 64-bit number in and one out, two in and one out, one in and none
 * out. Each expands to a `static const struct box NAME`.
 */
#ifndef SOREN_TEST_BOXES_H
#define SOREN_TEST_BOXES_H

#include "../../src/engine/031-engine.h"

/* one int64 in, one int64 out: BOX_1_1(name, expression using v) */
#define BOX_1_1(NAME, EXPR)                                                        \
    static int64_t NAME##_fn(int64_t v) { return (EXPR); }                         \
    static void NAME##_call(const void *in, void *out)                             \
    { *(int64_t *)out = NAME##_fn(*(const int64_t *)in); }                         \
    static const struct box_param NAME##_params[] = { { "v", "int64_t", 8, 0 } };  \
    static const struct box NAME = { #NAME, __FILE__, NAME##_call, 1, NAME##_params, 8, 8, "int64_t" }

/* two int64 in, one out: BOX_2_1(name, expression using a and b) */
#define BOX_2_1(NAME, EXPR)                                                        \
    static int64_t NAME##_fn(int64_t a, int64_t b) { return (EXPR); }              \
    static void NAME##_call(const void *in, void *out)                             \
    { const int64_t *x = in; *(int64_t *)out = NAME##_fn(x[0], x[1]); }            \
    static const struct box_param NAME##_params[] = {                              \
        { "a", "int64_t", 8, 0 }, { "b", "int64_t", 8, 8 } };                      \
    static const struct box NAME = { #NAME, __FILE__, NAME##_call, 2, NAME##_params, 16, 8, "int64_t" }

/* three int64 in, one out */
#define BOX_3_1(NAME, EXPR)                                                        \
    static int64_t NAME##_fn(int64_t a, int64_t b, int64_t c) { return (EXPR); }   \
    static void NAME##_call(const void *in, void *out)                             \
    { const int64_t *x = in; *(int64_t *)out = NAME##_fn(x[0], x[1], x[2]); }      \
    static const struct box_param NAME##_params[] = {                              \
        { "a", "int64_t", 8, 0 }, { "b", "int64_t", 8, 8 }, { "c", "int64_t", 8, 16 } }; \
    static const struct box NAME = { #NAME, __FILE__, NAME##_call, 3, NAME##_params, 24, 8, "int64_t" }

/* one int64 in, nothing out: BOX_1_0(name, statement using v) */
#define BOX_1_0(NAME, STATEMENT)                                                   \
    static void NAME##_fn(int64_t v) { (void)v; STATEMENT; }                       \
    static void NAME##_call(const void *in, void *out)                             \
    { (void)out; NAME##_fn(*(const int64_t *)in); }                                \
    static const struct box_param NAME##_params[] = { { "v", "int64_t", 8, 0 } };  \
    static const struct box NAME = { #NAME, __FILE__, NAME##_call, 1, NAME##_params, 8, 0, "void" }

#define ONE_WIRE(to_station, to_port) (struct destination[]){ { (to_station), (to_port) } }, 1

/* Place, or fail the test on the spot with the engine's own words. */
#define PLACE(box, name, kind, exits) ({                                           \
    int32_t _s = engine_place(&(box), (name), (kind), (exits));                    \
    if (_s < 0) { fprintf(stderr, "place %s: %s\n", (name), engine_error_text(_s)); exit(1); } \
    _s; })

#define MUST(call) do { int _r = (call);                                           \
    if (_r < 0) { fprintf(stderr, "%s:%d: %s: %s\n", __FILE__, __LINE__, #call,   \
                          engine_error_text(_r)); exit(1); } } while (0)

static inline int configure_static(int32_t station, int port, int64_t value)
{
    return engine_configure(station, port, PORT_STATIC, &value, sizeof value);
}

static inline int configure_ring(int32_t station, int port)
{
    return engine_configure(station, port, PORT_RING, (void *)0, 0);
}

#endif
