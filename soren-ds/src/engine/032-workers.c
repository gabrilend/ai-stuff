/*
 * 032-workers.c — the cores: the starting gate, the run loop, sleeping
 * and waking, and time (issues 202's gate, 205, 206).
 *
 * General description: every core runs the same loop forever — take the
 * oldest task off the ring, run its box, carry the returned value to
 * wherever the station's exit points, free the task, go again. A core that
 * finds the ring empty parks itself until another core pushes something
 * (which wakes every parked core) or, if every core is parked and a timer
 * is waiting, until that timer is due. Nothing polls, nothing supervises:
 * core 0 is an ordinary worker once the gate opens.
 *
 * A worker knows nothing about boxes. It reads one field of a task — the
 * function to call — and calls it. Everything about what a task means
 * lives on the delivery path, so nothing about a program can make the
 * engine unfair.
 */
#include "031-engine-internal.h"

struct engine engine;

/* {{{ engine_init */
void engine_init(int cores)
{
    if (cores < 1 || cores > PLATFORM_MAX_CORES) {
        platform_halt("engine_init: impossible core count");
    }
    bytes_zero(&engine, sizeof engine);
    engine.cores = cores;
    engine.next_deadline = ~0ull;
    for (int o = 0; o < OWNER_COUNT; o++) {
        engine.ctx[o].number = o;
        engine.ctx[o].inside = -1;
    }

    /* Each owner starts with a slice of stripes; the rest are handed out
     * one at a time to whoever runs dry (see 028-page-stripes.c). A
     * quarter of the pool is dealt out up front, the rest held back. */
    int stripes = (int)(platform_pool_size() / STRIPE_BYTES_TOTAL);
    int each = stripes / ((cores + 1) * 4);
    stripes_init(cores, each > 0 ? each : 1);

    engine.free_capacity = 1024;
    engine.free_places = block_alloc(OWNER_OUTSIDE, (size_t)engine.free_capacity * sizeof(int32_t));
    ring_init(&engine.ring, OWNER_OUTSIDE, 256);
#ifdef SOREN_DEBUG
    /* A debug build's last words are its recent history (issue 311). */
    platform_set_last_words(transcript_dump);
#endif
    if (!engine.free_places) {
        platform_halt("engine_init: no memory for the free-place list");
    }
}
/* }}} */

/* {{{ engine_here */
/* The context of whoever is asking: this core's, or the outside owner's
 * for a caller that is not a core. The outside context is only safe to
 * use while holding the outside lock, which engine_enter takes. */
struct core_ctx *engine_here(void)
{
    int id = platform_core_id();
    return &engine.ctx[id >= 0 ? id : OWNER_OUTSIDE];
}
/* }}} */

/* {{{ engine_enter */
/* Every public engine call begins here. Two things happen: a caller that
 * is not a core takes its turn as the outside owner, and — unless the
 * caller is already inside a task or another engine call — its epoch goes
 * odd, so a sweep of the scrapyard (033) knows not to free anything this
 * caller might be reading. */
struct core_ctx *engine_enter(void)
{
    int id = platform_core_id();
    struct core_ctx *c;
    if (id < 0) {
        /* A caller already holding the outside turn (a loader calling the
         * engine's own operations) goes straight in; any other waits its
         * turn. Reading the holder without the lock is safe: it can only
         * equal our token if we wrote it ourselves. */
        uintptr_t token = platform_caller_token();
        if (atomic_load_acquire(&engine.outside_holder) != token) {
            spin_lock(&engine.outside_lock);
            atomic_store_release(&engine.outside_holder, token);
        }
        c = &engine.ctx[OWNER_OUTSIDE];
    } else {
        c = &engine.ctx[id];
    }
    if (c->depth++ == 0 && !c->in_task) {
        atomic_add(&c->epoch, 1);
    }
    return c;
}
/* }}} */

/* {{{ engine_leave */
void engine_leave(struct core_ctx *c)
{
    if (--c->depth == 0 && !c->in_task) {
        atomic_add(&c->epoch, 1);
    }
    if (c->number == OWNER_OUTSIDE && c->depth == 0) {
        atomic_store_release(&engine.outside_holder, (uintptr_t)0);
        spin_unlock(&engine.outside_lock);
    }
}
/* }}} */

/* {{{ recompute_deadline */
/* Called holding the timer lock. */
static void recompute_deadline(void)
{
    uint64_t next = ~0ull;
    for (int i = 0; i < MAX_TIMERS; i++) {
        if (engine.timers[i].active && engine.timers[i].due_ns < next) {
            next = engine.timers[i].due_ns;
        }
    }
    atomic_store_release(&engine.next_deadline, next);
}
/* }}} */

/* {{{ engine_fire_due_timers */
/* Deliver every timer whose moment has come. Whichever core gets here
 * first does it; the others see the lock taken and carry on, because
 * losing that race means the job is already being done. */
void engine_fire_due_timers(struct core_ctx *c)
{
    if (!spin_trylock(&engine.timer_lock)) {
        return;
    }
    uint64_t now = platform_now_ns();
    for (int i = 0; i < MAX_TIMERS; i++) {
        struct timer *t = &engine.timers[i];
        if (!t->active || t->due_ns > now) {
            continue;
        }
        deliver_value(c, t->station, t->port, t->value, (size_t)t->size);
        c->stats.timer_fires++;
        /* Two paths: a one-shot timer is done; a periodic one moves on to
         * its next moment, skipping (and counting) any it already missed
         * so a late core does not fire a burst of stale frames. */
        if (t->period_ns == 0) {
            t->active = 0;
        } else {
            t->due_ns += t->period_ns;
            while (t->due_ns <= now) {
                t->due_ns += t->period_ns;
                t->missed++;
            }
        }
    }
    recompute_deadline();
    spin_unlock(&engine.timer_lock);
}
/* }}} */

/* {{{ engine_timer */
int engine_timer(int32_t station, int port, const void *value, size_t size,
                 uint64_t first_ns, uint64_t period_ns)
{
    if (size > TIMER_VALUE_BYTES) {
        return ENGINE_TOO_BIG;
    }
    struct core_ctx *c = engine_enter();
    int answer = ENGINE_FULL;
    spin_lock(&engine.timer_lock);
    for (int i = 0; i < MAX_TIMERS; i++) {
        struct timer *t = &engine.timers[i];
        if (t->active) {
            continue;
        }
        t->station   = station;
        t->port      = port;
        t->size      = (int32_t)size;
        t->due_ns    = first_ns;
        t->period_ns = period_ns;
        t->missed    = 0;
        bytes_copy(t->value, value, size);
        t->active    = 1;
        answer = i;
        break;
    }
    recompute_deadline();
    spin_unlock(&engine.timer_lock);
    engine_leave(c);
    /* A parked core may be waiting with no deadline at all; tell it there
     * is one now. */
    platform_send_event();
    return answer;
}
/* }}} */

/* {{{ engine_timer_cancel */
int engine_timer_cancel(int timer)
{
    if (timer < 0 || timer >= MAX_TIMERS) {
        return ENGINE_NO_STATION;
    }
    spin_lock(&engine.timer_lock);
    engine.timers[timer].active = 0;
    recompute_deadline();
    spin_unlock(&engine.timer_lock);
    return ENGINE_OK;
}
/* }}} */

/* {{{ engine_timer_missed */
uint64_t engine_timer_missed(int timer)
{
    if (timer < 0 || timer >= MAX_TIMERS) {
        return 0;
    }
    return engine.timers[timer].missed;
}
/* }}} */

/* {{{ run_task */
/* One whole task: run the box, carry its value on, free it. The core's
 * epoch is odd for the whole of it — not just the delivery — because
 * phase 4 needs to know whether a core might be inside a *box* before it
 * frees code somebody just recompiled (issue 207). */
static void run_task(struct core_ctx *c, struct task *t)
{
    atomic_add(&c->epoch, 1);
    c->in_task = 1;
    c->inside  = t->station;
    c->refused = 0;
    struct station *s = station_at(t->station);

#ifdef SOREN_DEBUG
    uint64_t started_ns = platform_now_ns();
    transcript_record(TRANSCRIPT_STARTED, t->station, c->number, 0, 0, s->name);
    /* Debug builds survive a box that faults: the platform returns here
     * instead of panicking, the station is named from `inside`, and it is
     * taken out of service. Ordinary builds pay nothing for this. */
    uint64_t fault = platform_guarded_call(t->box->call, t->in, t->out);
    if (fault) {
        error_record(s, t->station, ERROR_TRAPPED, fault);
        error_take_out_of_service(c, s, t->station);
        c->refused = 2;
    }
#else
    t->box->call(t->in, t->out);
#endif

    /* Three outcomes: the box refused (record it; the station takes
     * itself out of service; its value goes nowhere), it faulted (already
     * handled above), or it returned normally (deliver). */
    if (c->refused == 1) {
        error_record(s, t->station, ERROR_REFUSED, c->refused_detail);
        error_take_out_of_service(c, s, t->station);
    } else if (c->refused == 0) {
        deliver_task(c, t);
    }
#ifdef SOREN_DEBUG
    transcript_record(TRANSCRIPT_FINISHED, t->station, (int32_t)t->out_bytes, c->refused,
                      (int64_t)(platform_now_ns() - started_ns), s->name);
#endif
    atomic_add(&s->runs, 1);
    atomic_sub(&s->in_flight, 1);
    task_free(c, t);
    c->inside  = -1;
    c->in_task = 0;
    c->stats.ran++;
    atomic_add(&c->epoch, 1);
}
/* }}} */

/* {{{ engine_wake_sleepers */
/* Called after every push. Wakes the parked cores — but only if there are
 * any, because a wake nobody needs still costs every core a cache line.
 *
 * Skipping it is only safe because go_idle mirrors this exactly: here, the
 * task is published and THEN the parked count is read; there, the parked
 * count is raised and THEN the ring is read. With a full barrier between
 * each write and read, at least one of the two sides sees the other: either
 * this push sees a parked core and wakes it, or the parking core sees the
 * task and does not park. Found while measuring the endurance demo: the
 * unconditional wake was the largest single cost per run on the twin. */
void engine_wake_sleepers(void)
{
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
    if (atomic_load_relaxed(&engine.asleep_count) > 0) {
        platform_send_event();
    }
}
/* }}} */

/* {{{ go_idle */
/* The ring is empty. Park until something changes. The last core to park
 * asks one more question — is anything scheduled to arrive? — and if so
 * sleeps only until then. Every core asleep is never "finished" on this
 * device; it is the user not having pressed anything yet (issue 206). */
static void go_idle(struct core_ctx *c)
{
    c->asleep = 1;
    int32_t parked = __atomic_add_fetch(&engine.asleep_count, 1, __ATOMIC_SEQ_CST);
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
    /* The other half of engine_wake_sleepers' agreement: a push that read
     * the parked count before we raised it did not wake us, so look once
     * more before parking. */
    if (atomic_load_acquire(&engine.ring.count) > 0) {
        atomic_sub(&engine.asleep_count, 1);
        c->asleep = 0;
        return;
    }
    c->stats.sleeps++;
    transcript_drain_some();
    uint64_t deadline = atomic_load_acquire(&engine.next_deadline);
    if (parked == engine.cores && deadline != ~0ull) {
        platform_wait_until(deadline);
    } else {
        platform_wait_for_event();
    }
    atomic_sub(&engine.asleep_count, 1);
    c->asleep = 0;
    /* A wake is a rumour: several cores wake for one task. The loop looks
     * at the ring again before believing anything. */
}
/* }}} */

/* {{{ engine_core_main */
void engine_core_main(int core)
{
    struct core_ctx *c = &engine.ctx[core];
    c->number = core;
    c->inside = -1;
    c->random = platform_entropy();

    /* The starting gate: nothing runs until every core exists and whoever
     * is building the first program has said go. */
    while (!atomic_load_acquire(&engine.gate_open) && !atomic_load_acquire(&engine.shutting_down)) {
        platform_wait_for_event();
    }

    while (!atomic_load_acquire(&engine.shutting_down)) {
        uint64_t deadline = atomic_load_acquire(&engine.next_deadline);
        if (deadline != ~0ull && platform_now_ns() >= deadline) {
            atomic_add(&c->epoch, 1);
            engine_fire_due_timers(c);
            atomic_add(&c->epoch, 1);
        }
        struct task *t = ring_pop(&engine.ring);
        if (t) {
            run_task(c, t);
            continue;
        }
        go_idle(c);
    }
}
/* }}} */

/* {{{ engine_open_gate */
void engine_open_gate(void)
{
    atomic_store_release(&engine.gate_open, 1);
    platform_send_event();
}
/* }}} */

/* {{{ engine_shutdown */
void engine_shutdown(void)
{
    atomic_store_release(&engine.shutting_down, 1);
    platform_send_event();
}
/* }}} */

/* {{{ engine_is_idle */
int engine_is_idle(void)
{
    struct task_ring *r = &engine.ring;
    return atomic_load_acquire(&r->count) == 0 &&
           atomic_load_acquire(&engine.asleep_count) == engine.cores &&
           atomic_load_acquire(&engine.ctx[OWNER_OUTSIDE].depth) == 0;
}
/* }}} */

/* {{{ engine_refuse */
void engine_refuse(uint64_t detail)
{
    struct core_ctx *c = engine_here();
    if (!c->in_task) {
        platform_halt("engine_refuse: called outside a box");
    }
    c->refused = 1;
    c->refused_detail = detail;
}
/* }}} */

/* {{{ engine_current_station */
int32_t engine_current_station(void)
{
    return engine_here()->inside;
}
/* }}} */

/* {{{ engine_core_stats */
void engine_core_stats(int core, struct engine_core_stats *out)
{
    *out = engine.ctx[core].stats;
}
/* }}} */

/* {{{ engine_totals */
void engine_totals(struct engine_totals *out)
{
    bytes_zero(out, sizeof *out);
    out->cores = engine.cores;
    out->stations = atomic_load_acquire(&engine.count);
    for (int32_t i = 0; i < out->stations; i++) {
        struct station *s = station_at(i);
        if (s && atomic_load_acquire(&s->state) == STATION_LIVE) {
            out->live_stations++;
        }
    }
    ring_stats(&engine.ring, &out->ring_count, &out->ring_capacity,
               &out->ring_high_water, &out->ring_growths, &out->ring_pushed);
    out->port_growths = atomic_load_relaxed(&engine.port_growths);
    out->scrap_waiting = scrap_waiting();
    out->scrap_freed   = scrap_freed();
    out->pages_total   = stripes_total_pages();
    out->pages_free    = stripes_free_pages();
}
/* }}} */
