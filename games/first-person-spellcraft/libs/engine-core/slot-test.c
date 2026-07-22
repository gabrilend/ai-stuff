/* slot-test.c — proves the slot store: single-thread contract (mirrors the Lua
 * reference test) plus the reason we dropped to C at all — that the per-slot
 * lock actually holds under real concurrent threads. Temporary prover; compile
 * and run from the Makefile / a run script.
 */
#include "slot.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

static int failures = 0;
/* {{{ check() */
static void check(const char *name, int cond)
{
    if (cond) { printf("  ok  %s\n", name); }
    else      { printf("  FAIL %s\n", name); failures++; }
}
/* }}} */

/* {{{ single-thread contract */
static void test_contract(void)
{
    slot_store_t *s = slot_store_create();
    check("store created", s != NULL);

    /* QUEUE of int32, capacity 3: FIFO + full-backlog signal */
    slot_id_t q = slot_alloc(s, SLOT_QUEUE, sizeof(int32_t), 3);
    int32_t v = 10;
    check("push a", slot_push(s, q, &v) == 0);
    v = 20; check("push b", slot_push(s, q, &v) == 0);
    v = 30; check("push c", slot_push(s, q, &v) == 0);
    v = 40; check("push d refused (full = backlog signal)", slot_push(s, q, &v) == -1);
    int32_t out = 0;
    check("pop oldest = 10", slot_pop(s, q, &out) == 1 && out == 10);
    v = 40; check("push d lands after pop", slot_push(s, q, &v) == 0);

    /* drain-and-sum */
    slot_id_t dq = slot_alloc(s, SLOT_QUEUE, sizeof(int32_t), 5);
    int32_t d;
    d = 4;  slot_push(s, dq, &d);
    d = -2; slot_push(s, dq, &d);
    d = 7;  slot_push(s, dq, &d);
    int32_t buf[5];
    int32_t took = slot_drain(s, dq, buf, 5);
    int32_t sum = 0;
    for (int32_t i = 0; i < took; i++) sum += buf[i];
    check("drain took 3", took == 3);
    check("drain-and-sum = 9", sum == 9);
    check("drained ring empty", slot_fill(s, dq) == 0);

    /* LATEST: overwrite + peek newest, never full */
    slot_id_t L = slot_alloc(s, SLOT_LATEST, sizeof(int32_t), 99 /*ignored*/);
    v = 1; slot_push(s, L, &v);
    v = 2; slot_push(s, L, &v);
    out = 0;
    check("latest peek = newest 2", slot_peek(s, L, &out) == 1 && out == 2);
    v = 3; check("latest push always ok", slot_push(s, L, &v) == 0);

    /* COUNTER: distinct index per read, wraps at mod */
    slot_id_t c = slot_alloc(s, SLOT_COUNTER, 0, 0);
    check("counter 0", slot_read_inc(s, c, 3) == 0);
    check("counter 1", slot_read_inc(s, c, 3) == 1);
    check("counter 2", slot_read_inc(s, c, 3) == 2);
    check("counter wraps to 0", slot_read_inc(s, c, 3) == 0);

    /* wrong-flavor is a caught no-op, not a crash */
    check("pop on counter = 0", slot_pop(s, c, &out) == 0);
    check("push on counter = -1", slot_push(s, c, &v) == -1);

    slot_store_destroy(s);
}
/* }}} */

/* {{{ threaded QUEUE: nothing lost, nothing duplicated */
#define NPROD 8
#define PER   50000
typedef struct { slot_store_t *s; slot_id_t id; } qarg_t;

static void *producer(void *a)
{
    qarg_t *q = a;
    for (int i = 0; i < PER; i++) {
        int32_t one = 1;
        while (slot_push(q->s, q->id, &one) == -1) { /* ring full: retry */ }
    }
    return NULL;
}

static void test_threaded_queue(void)
{
    slot_store_t *s = slot_store_create();
    slot_id_t id = slot_alloc(s, SLOT_QUEUE, sizeof(int32_t), 64);
    qarg_t arg = { s, id };
    pthread_t prod[NPROD];
    for (int i = 0; i < NPROD; i++) pthread_create(&prod[i], NULL, producer, &arg);

    /* Consumer drains on the main thread while producers push. */
    long total = 0;
    long target = (long)NPROD * PER;
    while (total < target) {
        int32_t got;
        if (slot_pop(s, id, &got)) total += got;
    }
    for (int i = 0; i < NPROD; i++) pthread_join(prod[i], NULL);

    int32_t leftover;
    while (slot_pop(s, id, &leftover)) total += leftover; /* drain stragglers */
    check("threaded queue: every pushed value popped exactly once",
          total == target && slot_fill(s, id) == 0);
    slot_store_destroy(s);
}
/* }}} */

/* {{{ threaded LATEST: the reader never sees a torn struct */
typedef struct { uint32_t a, b; } pair_t;   /* invariant: a == b, always */
typedef struct { slot_store_t *s; slot_id_t id; volatile int *stop; } larg_t;

static void *writer(void *a)
{
    larg_t *l = a;
    for (uint32_t i = 1; !*l->stop; i++) {
        pair_t p = { i, i };            /* built whole, a == b */
        slot_push(l->s, l->id, &p);
    }
    return NULL;
}

static void test_threaded_latest(void)
{
    slot_store_t *s = slot_store_create();
    slot_id_t id = slot_alloc(s, SLOT_LATEST, sizeof(pair_t), 1);
    pair_t seed = { 0, 0 };
    slot_push(s, id, &seed);

    volatile int stop = 0;
    larg_t arg = { s, id, &stop };
    pthread_t w1, w2;
    pthread_create(&w1, NULL, writer, &arg);
    pthread_create(&w2, NULL, writer, &arg);

    /* Peek a few million times; a torn read would show a != b. */
    long torn = 0;
    for (long i = 0; i < 3000000; i++) {
        pair_t got;
        if (slot_peek(s, id, &got) && got.a != got.b) torn++;
    }
    stop = 1;
    pthread_join(w1, NULL);
    pthread_join(w2, NULL);

    check("threaded latest: zero torn reads under two concurrent writers", torn == 0);
    slot_store_destroy(s);
}
/* }}} */

/* {{{ main() */
int main(void)
{
    printf("contract:\n");        test_contract();
    printf("threaded queue:\n");  test_threaded_queue();
    printf("threaded latest:\n"); test_threaded_latest();
    printf(failures ? "\n%d FAILURE(S)\n" : "\nall checks passed\n", failures);
    return failures ? 1 : 0;
}
/* }}} */
