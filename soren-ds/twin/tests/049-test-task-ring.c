/*
 * 049-test-task-ring.c — issue 204.
 *
 * General description: first, a ring whose contents have already wrapped
 * round the end is made to grow, because unwrapping is the part that goes
 * wrong first; the order must survive. Then four cores push and pop at
 * once, each push carrying (who pushed, how many it had pushed before), and
 * every consumer checks that from any one producer the numbers it sees
 * only go up — nothing lost, nothing duplicated, nothing reordered.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/engine/030-task-ring.h"
#include "../026-platform-twin.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdatomic.h>

#define CORES 4
#define PER_CORE 250000

static struct task_ring ring;
static _Atomic uint64_t seen_total;
static _Atomic int order_broken;
static uint8_t *seen_flags[CORES];
static _Atomic int done_pushing;

/* {{{ as_task */
static void *as_task(int producer, uint64_t n)
{
    return (void *)(uintptr_t)(((uint64_t)(producer + 1) << 40) | (n + 1));
}
/* }}} */

/* {{{ entry */
static void entry(int core)
{
    uint64_t last_seen[CORES];
    for (int p = 0; p < CORES; p++) {
        last_seen[p] = 0;
    }
    uint64_t pushed = 0;
    for (;;) {
        if (pushed < PER_CORE) {
            ring_push(&ring, core, as_task(core, pushed));
            pushed++;
            if (pushed == PER_CORE) {
                atomic_fetch_add(&done_pushing, 1);
            }
        }
        void *t = ring_pop(&ring);
        if (t) {
            uint64_t v = (uint64_t)(uintptr_t)t;
            int producer = (int)(v >> 40) - 1;
            uint64_t n = v & ((1ull << 40) - 1);
            if (n <= last_seen[producer]) {
                atomic_fetch_add(&order_broken, 1);
            }
            last_seen[producer] = n;
            if (seen_flags[producer][n - 1]++) {
                atomic_fetch_add(&order_broken, 1000);
            }
            atomic_fetch_add(&seen_total, 1);
        } else if (atomic_load(&done_pushing) == CORES) {
            break;
        }
    }
}
/* }}} */

int main(void)
{
    twin_platform_init(CORES, (size_t)128 << 20);
    twin_platform_set_log(NULL, 0);
    stripes_init(CORES, 4);

    /* Part one: wrap, then grow. Capacity 8; push 6, pop 4, push 7 more —
     * the contents now straddle the end — and the ring must grow while
     * handing them back in the order they went in. */
    struct task_ring small;
    ring_init(&small, OWNER_OUTSIDE, 8);
    uint64_t next_in = 1, next_out = 1;
    int wrong = 0;
    for (int i = 0; i < 6; i++) ring_push(&small, OWNER_OUTSIDE, (void *)(uintptr_t)next_in++);
    for (int i = 0; i < 4; i++) wrong += (uintptr_t)ring_pop(&small) != next_out++;
    for (int i = 0; i < 7; i++) ring_push(&small, OWNER_OUTSIDE, (void *)(uintptr_t)next_in++);
    int count, capacity, high, growths;
    uint64_t pushed;
    ring_stats(&small, &count, &capacity, &high, &growths, &pushed);
    CHECK(growths == 1 && capacity == 16, "a wrapped, full ring doubled once (growths %d, capacity %d)", growths, capacity);
    void *t;
    while ((t = ring_pop(&small))) {
        wrong += (uintptr_t)t != next_out++;
    }
    CHECK(wrong == 0 && next_out == next_in, "every value came out in the order it went in across the growth");

    /* Part two: four cores at once. */
    for (int c = 0; c < CORES; c++) {
        seen_flags[c] = calloc(PER_CORE, 1);
    }
    ring_init(&ring, OWNER_OUTSIDE, 8);
    uint64_t start = platform_now_ns();
    platform_start_cores(CORES, entry);
    uint64_t elapsed = platform_now_ns() - start;
    CHECK(atomic_load(&seen_total) == (uint64_t)CORES * PER_CORE,
          "nothing lost: %llu of %llu popped", (unsigned long long)atomic_load(&seen_total),
          (unsigned long long)CORES * PER_CORE);
    CHECK(atomic_load(&order_broken) == 0, "nothing duplicated or reordered per producer (%d problems)",
          atomic_load(&order_broken));
    ring_stats(&ring, &count, &capacity, &high, &growths, &pushed);

    metrics_open("049-task-ring");
    metric_record("ring.push_pop_ns", (double)elapsed / (double)(CORES * PER_CORE), "ns", "ring-cost",
                  "one push and one pop, four cores contending for the one ring");
    metric_record("ring.high_water", high, "tasks", "ring-high-water",
                  "most tasks waiting at once during the four-core run");
    metric_record("ring.growths", growths, "doublings", "ring-growth",
                  "how many times the ring doubled from its starting 8 slots");
    metrics_close();
    CHECK_DONE("049 task ring");
}
