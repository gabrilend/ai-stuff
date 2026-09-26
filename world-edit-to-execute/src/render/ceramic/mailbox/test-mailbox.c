/*
 * test-mailbox.c - proves the mailbox never lets the reader see a half-written state (issue 515c)
 *
 * What this is: the mailbox's tests. First the plain order of events, one
 * thread, step by step. Then races: writers publish states as fast as they
 * can while the reader takes and inspects every one. A state is a buffer of
 * thousands of 64-bit words, every word stamped with the same number (which
 * writer, which state), so a buffer written over while the reader looks
 * shows two different stamps, and a state taken out of order shows a number
 * going down.
 *
 * The same races are run against a deliberately broken mailbox, which
 * publishes a buffer but lets the writer keep writing into it. The tests
 * must catch it; if they didn't, passing on the real one would prove
 * nothing.
 *
 * Usage: test-mailbox [STATES]         the real mailbox; exits 1 on any failure
 *        test-mailbox --broken [STATES] the broken one; prints "torn" or
 *                                       "out of order" and exits 1 when caught
 * STATES is how many each writer publishes in a race (default 300000).
 */
#include "mailbox.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#define WORDS 1024     /* 8 KB a state: long enough for a writer to overlap a reader's look */

static int failures = 0;

/* {{{ static void expect(int ok, const char *what) */
static void expect(int ok, const char *what)
{
    printf("%s  %s\n", ok ? "pass" : "FAIL", what);
    if (!ok) failures++;
}
/* }}} */

/* {{{ static void publish_broken(mailbox *mb, int writer) */
/* The broken mailbox: the buffer goes to the middle, but the writer isn't
 * handed a new one, so it goes on writing the buffer the reader may take. */
static void publish_broken(mailbox *mb, int writer)
{
    atomic_store_explicit(&mb->middle, mb->writing[writer] | MAILBOX_FRESH, memory_order_release);
}
/* }}} */

/* {{{ static void publish_real(mailbox *mb, int writer) */
static void publish_real(mailbox *mb, int writer)
{
    mailbox_publish(mb, writer);
}
/* }}} */

typedef void (*publish_fn)(mailbox *, int);

/* {{{ static void stamp(uint64_t *words, uint64_t mark) */
/* A state: every word the same mark, (writer << 40) | state number. */
static void stamp(uint64_t *words, uint64_t mark)
{
    for (int i = 0; i < WORDS; i++) words[i] = mark;
}
/* }}} */

/* {{{ static void test_order(void) */
/* One thread, step by step: what each call hands back. */
static void test_order(void)
{
    mailbox *mb = mailbox_create(WORDS * sizeof(uint64_t), 1);
    if (!mb) { expect(0, "created"); return; }
    int is_new;
    const uint64_t *seen = mailbox_take(mb, &is_new);
    expect(!is_new && seen[0] == 0, "nothing new before the first publish");

    stamp(mailbox_writing(mb, 0), 1);
    mailbox_publish(mb, 0);
    seen = mailbox_take(mb, &is_new);
    expect(is_new && seen[0] == 1, "a publish is taken");
    const uint64_t *again = mailbox_take(mb, &is_new);
    expect(!is_new && again == seen && again[0] == 1, "taken once: the next take keeps it");

    stamp(mailbox_writing(mb, 0), 2);
    mailbox_publish(mb, 0);
    stamp(mailbox_writing(mb, 0), 3);
    mailbox_publish(mb, 0);
    seen = mailbox_take(mb, &is_new);
    expect(is_new && seen[0] == 3, "of two publishes, the newer is taken");

    uint64_t *next = mailbox_writing(mb, 0);
    expect(next != seen, "the writer is never handed the buffer being read");
    mailbox_destroy(mb);

    expect(mailbox_create(64, 0) == NULL && mailbox_create(64, MAILBOX_MOST_WRITERS + 1) == NULL,
           "writer counts outside 1..most are refused");
}
/* }}} */

typedef struct {
    mailbox     *mb;
    publish_fn   publish;
    int          writer;
    long         states;
    atomic_int  *writers_left;
} writer_job;

/* {{{ static void *writer_run(void *arg) */
static void *writer_run(void *arg)
{
    writer_job *j = arg;
    for (long s = 1; s <= j->states; s++) {
        stamp(mailbox_writing(j->mb, j->writer), ((uint64_t)j->writer << 40) | (uint64_t)s);
        j->publish(j->mb, j->writer);
    }
    atomic_fetch_sub(j->writers_left, 1);
    return NULL;
}
/* }}} */

typedef struct { long taken, torn, backwards; } race_result;

/* {{{ static race_result race(int writers, long states, publish_fn publish) */
/* Writers publish; this thread reads until they're done, inspecting every
 * take, new or not (a buffer kept must stay whole too). */
static race_result race(int writers, long states, publish_fn publish)
{
    race_result r = { 0, 0, 0 };
    mailbox *mb = mailbox_create(WORDS * sizeof(uint64_t), writers);
    if (!mb) { r.torn = -1; return r; }
    atomic_int left;
    atomic_init(&left, writers);
    pthread_t threads[MAILBOX_MOST_WRITERS];
    writer_job jobs[MAILBOX_MOST_WRITERS];
    uint64_t last[MAILBOX_MOST_WRITERS] = { 0 };
    for (int w = 0; w < writers; w++) {
        jobs[w] = (writer_job){ mb, publish, w, states, &left };
        pthread_create(&threads[w], NULL, writer_run, &jobs[w]);
    }
    while (atomic_load(&left) > 0) {
        int is_new;
        const uint64_t *words = mailbox_take(mb, &is_new);
        uint64_t mark = words[0];
        for (int i = 1; i < WORDS; i++)
            if (words[i] != mark) { r.torn++; break; }
        if (is_new && mark) {
            int w = (int)(mark >> 40);
            uint64_t n = mark & ((1ull << 40) - 1);
            /* a writer's states are published in order, so they're taken in order */
            if (w >= writers || n <= last[w]) r.backwards++;
            else last[w] = n;
            r.taken++;
        }
    }
    for (int w = 0; w < writers; w++) pthread_join(threads[w], NULL);
    mailbox_destroy(mb);
    return r;
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    int broken = argc > 1 && strcmp(argv[1], "--broken") == 0;
    long states = 300000;
    if (argc > 1 + broken) states = atol(argv[1 + broken]);
    publish_fn publish = broken ? publish_broken : publish_real;
    char what[160];

    /* Two paths: the broken mailbox only races; the real one also steps. */
    if (!broken) test_order();
    const int counts[2] = { 1, 4 };
    for (int c = 0; c < 2; c++) {
        race_result r = race(counts[c], states, publish);
        snprintf(what, sizeof what, "%d writer(s) x %ld states, one reader: %ld taken, %ld torn, %ld out of order",
                 counts[c], states, r.taken, r.torn, r.backwards);
        if (broken) {
            printf("broken  %s\n", what);
            if (r.torn) printf("torn\n");
            if (r.backwards) printf("out of order\n");
            if (r.torn || r.backwards) failures++;
        } else {
            expect(r.torn == 0 && r.backwards == 0 && r.taken > 0, what);
        }
    }
    return failures ? 1 : 0;
}
/* }}} */
