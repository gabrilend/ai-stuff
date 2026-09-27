/*
 * 059-endurance.c — phase 2's capstone: an ordinary program, run for as
 * long as somebody lets it, reporting what it did (issue 215).
 *
 * General description: a value is fanned out to one chain of incrementing
 * stations per core, and the chains rejoin at a sink that counts and sums
 * what arrives. The laptop pumps values in for the requested number of
 * seconds, keeping a bounded number in flight. Because every value's
 * journey is known, the right count and sum are arithmetic, not a
 * recorded golden number: a count too low is a lost value, too high a
 * doubled one, and a right count with a wrong sum is a torn copy.
 *
 * Before the endurance run it measures the design question the phase was
 * built to answer — what one run of one box costs in units of real work —
 * by pushing the same total work through a long chain of small boxes and
 * through one big one. Partway through the run it parks the whole program
 * and restarts it, lets one chain's box refuse a value and then rewires
 * it back into service, and feeds one station unevenly so its port has to
 * grow. At the end it draws its totals on the two screens, writes them as
 * a picture, records every number for the documentation, and says PASS or
 * FAIL.
 *
 * Usage: 059-endurance [--cores N] [--seconds S] [--png path] [--quiet]
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "catalogue-boxes.h"
#include "../../src/engine/038-tallies.h"
#include "../../src/system/058-draw.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../057-screens-twin.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CHAIN_LENGTH 24          /* increments per chain */
#define IN_FLIGHT 2048           /* values allowed between the pump and the sink */
#define CHEW_TOTAL 262144        /* rounds of work in the fine/coarse comparison */
#define FINE_STEPS 64            /* the fine arrangement splits it over this many boxes */

static int cores = 4;
static int seconds = 10;
static const char *png_path;
static int quiet;

/* {{{ sleep_us */
static void sleep_us(long us)
{
    struct timespec ts = { us / 1000000, (us % 1000000) * 1000 };
    nanosleep(&ts, NULL);
}
/* }}} */

/* {{{ sink_totals */
static void sink_totals(int32_t sink, uint64_t *count, int64_t *sum)
{
    tally_read(sink, count, sum);
}
/* }}} */

/* {{{ measure_box_cost */
/* The same CHEW_TOTAL rounds of work, arranged two ways, run for a batch of
 * values each: one chew box doing all of it per value, and FINE_STEPS chew
 * boxes in a chain doing a slice each. The extra time of the fine one,
 * divided by its extra runs, is what one run of one box costs; set
 * against the time one round of work takes, it says how much work a box
 * should do per run before the engine's cost stops mattering. Answers the
 * cost per run in nanoseconds. */
static double measure_box_cost(double *round_ns, double *pass_ns)
{
    const int VALUES = 400;
    /* coarse */
    int32_t coarse_sink = engine_place(&box__arithmetic__discard, "coarse-sink", KIND_PLAIN, 0);
    int32_t coarse = engine_place(&box__arithmetic__chew, "coarse", KIND_PLAIN, 1);
    engine_wire(coarse, 0, (struct destination[]){ { coarse_sink, 0 } }, 1);
    engine_configure(coarse_sink, 0, PORT_RING, NULL, 0);
    int64_t rounds = CHEW_TOTAL;
    engine_configure(coarse, 1, PORT_STATIC, &rounds, sizeof rounds);
    engine_configure(coarse, 0, PORT_RING, NULL, 0);
    uint64_t t0 = platform_now_ns();
    for (int64_t v = 0; v < VALUES; v++) {
        engine_deliver(coarse, 0, &v, sizeof v);
    }
    twin_engine_settle(60000);
    uint64_t coarse_ns = platform_now_ns() - t0;

    /* fine */
    int32_t fine_sink = engine_place(&box__arithmetic__discard, "fine-sink", KIND_PLAIN, 0);
    engine_configure(fine_sink, 0, PORT_RING, NULL, 0);
    int32_t next = fine_sink;
    int32_t first = -1;
    int64_t slice = CHEW_TOTAL / FINE_STEPS;
    for (int i = 0; i < FINE_STEPS; i++) {
        int32_t s = engine_place(&box__arithmetic__chew, "fine-step", KIND_PLAIN, 1);
        engine_wire(s, 0, (struct destination[]){ { next, 0 } }, 1);
        engine_configure(s, 1, PORT_STATIC, &slice, sizeof slice);
        engine_configure(s, 0, PORT_RING, NULL, 0);
        next = s;
        first = s;
    }
    t0 = platform_now_ns();
    for (int64_t v = 0; v < VALUES; v++) {
        engine_deliver(first, 0, &v, sizeof v);
    }
    twin_engine_settle(60000);
    uint64_t fine_ns = platform_now_ns() - t0;

    /* pure engine: a chain of pass boxes, no work at all */
    int32_t pass_sink = engine_place(&box__arithmetic__discard, "pass-sink", KIND_PLAIN, 0);
    engine_configure(pass_sink, 0, PORT_RING, NULL, 0);
    next = pass_sink;
    for (int i = 0; i < FINE_STEPS; i++) {
        int32_t s = engine_place(&box__arithmetic__pass, "pass-step", KIND_PLAIN, 1);
        engine_wire(s, 0, (struct destination[]){ { next, 0 } }, 1);
        engine_configure(s, 0, PORT_RING, NULL, 0);
        next = s;
    }
    const int PASS_VALUES = 20000;
    t0 = platform_now_ns();
    for (int64_t v = 0; v < PASS_VALUES; v++) {
        engine_deliver(next, 0, &v, sizeof v);
    }
    twin_engine_settle(60000);
    uint64_t pass_total = platform_now_ns() - t0;

    /* Rounds of work per second of one core, from the coarse run: every
     * core was busy chewing, so wall time × cores is core time. */
    *round_ns = (double)coarse_ns * cores / ((double)VALUES * CHEW_TOTAL);
    *pass_ns = (double)pass_total * cores / ((double)PASS_VALUES * FINE_STEPS);
    /* The fine arrangement's extra time over the coarse one was the first
     * idea for measuring a run's cost; on a laptop it drowns in noise,
     * because the fine chain also pipelines across cores. The pass chain —
     * all engine, no work — is the cleaner number, and is what is
     * answered. Both arrangements' times are reported beside it. */
    printf("same %d rounds of work: one box %.1f ms, %d boxes in a chain %.1f ms\n",
           CHEW_TOTAL, (double)coarse_ns / 1e6, FINE_STEPS, (double)fine_ns / 1e6);
    metric_record(cores == 1 ? "endurance.1core.coarse_ms" : "endurance.ncore.coarse_ms", (double)coarse_ns / 1e6, "ms",
                  "endurance-coarseness", "400 values through one chew box doing all the work");
    metric_record(cores == 1 ? "endurance.1core.fine_ms" : "endurance.ncore.fine_ms", (double)fine_ns / 1e6, "ms",
                  "endurance-coarseness", "400 values through 64 chew boxes doing a slice each");
    return *pass_ns;
}
/* }}} */

struct program {
    int32_t head;                 /* a pass station every value enters through */
    int32_t sink;
    int32_t chain_first[16];
    int32_t picky;                /* the refusing box, in chain 0 */
    int32_t uneven;               /* the station fed unevenly */
    int32_t uneven_sink;
    int32_t all[16 * (CHAIN_LENGTH + 2) + 8];
    int     n_all;
};

/* {{{ build_program */
/*            ┌─ picky ─ inc ─ inc ... ─┐
 *  pass ─────┼─ inc ─ inc ─ inc ...  ──┼─── discard
 *    │       └─ inc ─ inc ─ inc ...  ──┘
 *    └───────── uneven.0         uneven.1 ←── (every 4th value, from a timer)
 */
static void build_program(struct program *p, int64_t limit)
{
    memset(p, 0, sizeof *p);
    p->sink = engine_place(&box__arithmetic__discard, "endurance-sink", KIND_PLAIN, 0);
    engine_configure(p->sink, 0, PORT_RING, NULL, 0);
    p->all[p->n_all++] = p->sink;
    struct destination fan[17];
    for (int c = 0; c < cores; c++) {
        int32_t next = p->sink;
        for (int i = 0; i < CHAIN_LENGTH; i++) {
            int32_t s = engine_place(&box__arithmetic__increment, "inc", KIND_PLAIN, 1);
            engine_wire(s, 0, (struct destination[]){ { next, 0 } }, 1);
            engine_configure(s, 0, PORT_RING, NULL, 0);
            p->all[p->n_all++] = s;
            next = s;
        }
        if (c == 0) {
            p->picky = engine_place(&box__arithmetic__picky, "picky", KIND_PLAIN, 1);
            engine_wire(p->picky, 0, (struct destination[]){ { next, 0 } }, 1);
            engine_configure(p->picky, 1, PORT_STATIC, &limit, sizeof limit);
            engine_configure(p->picky, 0, PORT_RING, NULL, 0);
            p->all[p->n_all++] = p->picky;
            next = p->picky;
        }
        p->chain_first[c] = next;
        fan[c].station = next;
        fan[c].port = 0;
    }
    p->uneven_sink = engine_place(&box__arithmetic__discard, "uneven-sink", KIND_PLAIN, 0);
    engine_configure(p->uneven_sink, 0, PORT_RING, NULL, 0);
    p->uneven = engine_place(&box__arithmetic__add, "uneven", KIND_PLAIN, 1);
    engine_wire(p->uneven, 0, (struct destination[]){ { p->uneven_sink, 0 } }, 1);
    engine_configure(p->uneven, 0, PORT_RING, NULL, 0);
    engine_configure(p->uneven, 1, PORT_RING, NULL, 0);
    p->all[p->n_all++] = p->uneven_sink;
    p->all[p->n_all++] = p->uneven;
    fan[cores].station = p->uneven;
    fan[cores].port = 0;

    p->head = engine_place(&box__arithmetic__pass, "head", KIND_PLAIN, 1);
    engine_wire(p->head, 0, fan, cores + 1);
    engine_configure(p->head, 0, PORT_RING, NULL, 0);
    p->all[p->n_all++] = p->head;
}
/* }}} */

/* {{{ park_and_restart */
static int park_and_restart(struct program *p, int *lost)
{
    int handle = engine_park_begin(p->all, p->n_all);
    if (handle < 0) {
        return handle;
    }
    int state = 0;
    for (int tries = 0; tries < 20000 && state != PARK_PARKED; tries++) {
        state = engine_park_step(handle);
        sleep_us(200);
    }
    if (state != PARK_PARKED) {
        return ENGINE_STOPPED;
    }
    sleep_us(100000);             /* a tenth of a second parked, costing nothing */
    return engine_restart(handle, lost);
}
/* }}} */

/* {{{ draw_report */
static void draw_report(int pass, uint64_t count, uint64_t expect_count, double runs_per_s,
                        const uint64_t *per_core, double cost_ns, double round_ns, uint64_t growths,
                        long pages_drift, int restarted, int rewired)
{
    struct canvas top = canvas_of_screen(0);
    struct canvas bottom = canvas_of_screen(1);
    char line[128];
    draw_fill(top, COLOUR_PAPER);
    draw_text(top, 24, 20, "ENDURANCE  per-core runs", 2, COLOUR_ACCENT, 0);
    uint64_t most = 1;
    for (int c = 0; c < cores; c++) {
        if (per_core[c] > most) most = per_core[c];
    }
    int bar_h = cores > 8 ? 20 : 40;
    for (int c = 0; c < cores; c++) {
        int y = 90 + c * (bar_h + 16);
        int w = (int)((uint64_t)520 * per_core[c] / most);
        snprintf(line, sizeof line, "core %d", c);
        draw_text(top, 24, y + bar_h / 2 - 8, line, 1, COLOUR_QUIET, 0);
        draw_rect(top, 90, y, 520, bar_h, COLOUR_PANEL);
        draw_rect(top, 90, y, w, bar_h, COLOUR_BLUE);
        snprintf(line, sizeof line, "%llu", (unsigned long long)per_core[c]);
        draw_text(top, 96, y + bar_h / 2 - 8, line, 1, COLOUR_INK, 0);
    }
    platform_screen_present(0);

    draw_fill(bottom, COLOUR_PAPER);
    draw_text(bottom, 24, 20, pass ? "PASS" : "FAIL", 4, pass ? COLOUR_GOOD : COLOUR_BAD, 0);
    int y = 110;
    snprintf(line, sizeof line, "values in sink  %llu / %llu", (unsigned long long)count,
             (unsigned long long)expect_count);
    draw_text(bottom, 24, y, line, 2, COLOUR_INK, 0); y += 40;
    snprintf(line, sizeof line, "runs per second %.0f", runs_per_s);
    draw_text(bottom, 24, y, line, 2, COLOUR_INK, 0); y += 40;
    snprintf(line, sizeof line, "one run costs   %.0f ns = %.0f rounds", cost_ns, round_ns > 0 ? cost_ns / round_ns : 0);
    draw_text(bottom, 24, y, line, 2, COLOUR_INK, 0); y += 40;
    snprintf(line, sizeof line, "port growths    %llu", (unsigned long long)growths);
    draw_text(bottom, 24, y, line, 2, COLOUR_INK, 0); y += 40;
    snprintf(line, sizeof line, "pages drift     %ld after warm-up", pages_drift);
    draw_text(bottom, 24, y, line, 2, COLOUR_INK, 0); y += 40;
    snprintf(line, sizeof line, "parked %s  refused+rewired %s", restarted ? "yes" : "NO",
             rewired ? "yes" : "NO");
    draw_text(bottom, 24, y, line, 2, restarted && rewired ? COLOUR_GOOD : COLOUR_BAD, 0);
    platform_screen_present(1);
}
/* }}} */

int main(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--cores") && i + 1 < argc) cores = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--seconds") && i + 1 < argc) seconds = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--png") && i + 1 < argc) png_path = argv[++i];
        else if (!strcmp(argv[i], "--quiet")) quiet = 1;
        else {
            fprintf(stderr, "usage: %s [--cores N] [--seconds S] [--png path] [--quiet]\n", argv[0]);
            return 2;
        }
    }
    if (cores < 1 || cores > 16) {
        fprintf(stderr, "endurance: 1 to 16 cores\n");
        return 2;
    }
    twin_engine_start(cores, (size_t)1 << 30);
    engine_open_gate();
    char metrics_name[64];
    snprintf(metrics_name, sizeof metrics_name, "059-endurance-%dcore", cores);
    metrics_open(metrics_name);

    printf("endurance: %d cores, %d seconds, %d chains of %d stations\n", cores, seconds, cores, CHAIN_LENGTH);

    /* --- the design question, answered first ---------------------------- */
    double round_ns = 0, pass_ns = 0;
    double cost_ns = measure_box_cost(&round_ns, &pass_ns);
    printf("one run of one box costs about %.0f ns of core time; one round of work %.2f ns;\n"
           "so a box should do at least ~%.0f rounds per run for the engine to be under half its time\n"
           "(a pass box alone: %.0f ns per run)\n",
           cost_ns, round_ns, round_ns > 0 ? cost_ns / round_ns : 0, pass_ns);

    /* --- the endurance program ------------------------------------------ */
    struct program p;
    int64_t limit = 1ll << 62;
    build_program(&p, limit);
    int64_t sent = 0;
    int64_t sum_sent = 0;
    int64_t refused_value = -1;
    int restarted = 0, rewired = 0;
    int64_t uneven_fed = 0;
    size_t pages_warm = 0, pages_end = 0;
    uint64_t t_start = platform_now_ns();
    uint64_t t_end = t_start + (uint64_t)seconds * 1000000000ull;
    uint64_t next_report = t_start + 1000000000ull;
    int phase_marks = 0;
    for (;;) {
        uint64_t now = platform_now_ns();
        if (now >= t_end) {
            break;
        }
        uint64_t in_sink;
        int64_t ignore;
        sink_totals(p.sink, &in_sink, &ignore);
        /* Keep a bounded number of values between pump and sink. */
        if ((uint64_t)(sent * cores) - in_sink < (uint64_t)IN_FLIGHT * cores) {
            for (int k = 0; k < 64; k++) {
                sent++;
                sum_sent += sent;
                engine_deliver(p.head, 0, &sent, sizeof sent);
                /* The uneven station's second input gets a value only for
                 * every fourth value its first input gets. */
                if (sent % 4 == 0) {
                    int64_t z = 0;
                    engine_deliver(p.uneven, 1, &z, sizeof z);
                    uneven_fed++;
                }
            }
        } else {
            sleep_us(50);
        }
        double elapsed = (double)(now - t_start) / (double)(t_end - t_start);
        /* A quarter of the way: memory has warmed up. */
        if (phase_marks == 0 && elapsed > 0.25) {
            phase_marks = 1;
            pages_warm = stripes_free_pages();
        }
        /* A third: the picky box starts refusing anything past this point. */
        if (phase_marks == 1 && elapsed > 0.33) {
            phase_marks = 2;
            int64_t tight = sent + 10;
            engine_configure(p.picky, 1, PORT_STATIC, &tight, sizeof tight);
        }
        /* Half way: park everything, then restart it. */
        if (phase_marks == 2 && elapsed > 0.5) {
            phase_marks = 3;
            int lost = -1;
            int r = park_and_restart(&p, &lost);
            restarted = r == RESTART_RESUMED;
            printf("  parked and restarted: %s, %d values lost\n",
                   r == RESTART_RESUMED ? "resumed in place" : (r == RESTART_REBUILT ? "REBUILT" : engine_error_text(r)), lost);
        }
        /* Two thirds: the refused chain is fixed and given its input back. */
        if (phase_marks == 3 && elapsed > 0.66) {
            phase_marks = 4;
            struct engine_error_report er;
            engine_read_error(p.picky, &er, 1);
            if (er.kind == ERROR_REFUSED) {
                refused_value = (int64_t)er.detail;
                engine_configure(p.picky, 1, PORT_STATIC, &limit, sizeof limit);
                engine_configure(p.picky, 0, PORT_RING, NULL, 0);
                rewired = 1;
                printf("  picky refused %lld, took itself out; rewired and back in service\n", (long long)refused_value);
            } else {
                printf("  picky never refused (kind %d) — the refusal scene did not happen\n", er.kind);
            }
        }
        if (!quiet && now >= next_report) {
            next_report += 1000000000ull;
            struct engine_totals t;
            engine_totals(&t);
            printf("  t=%2.0fs sent %lld in sink %llu ring %d/%d port-growths %llu free-pages %zu\n",
                   (double)(now - t_start) / 1e9, (long long)sent, (unsigned long long)in_sink,
                   t.ring_count, t.ring_capacity, (unsigned long long)t.port_growths, t.pages_free);
        }
    }
    uint64_t t_pump_end = platform_now_ns();
    twin_engine_settle(60000);
    uint64_t t_settled = platform_now_ns();
    pages_end = stripes_free_pages();

    /* --- the arithmetic ------------------------------------------------- */
    /* Every value v reaches the sink once per chain, having gained
     * CHAIN_LENGTH on the way; the refused value is the one exception on
     * chain 0 (and it is the only value chain 0 lost). */
    uint64_t count;
    int64_t sum;
    sink_totals(p.sink, &count, &sum);
    /* The refused values never reach the sink. More than one may have been
     * refused: runs of picky already queued when the first refusal took it
     * out of service refuse too — each such value was claimed before the
     * station stopped, and is correctly turned away. picky writes every
     * one it turns away to an outside tally, so the loss is exact. */
    uint64_t refused_count;
    int64_t refused_sum;
    tally_refusals(p.picky, &refused_count, &refused_sum);
    uint64_t expect_count = (uint64_t)sent * (uint64_t)cores - refused_count;
    int64_t expect_sum = (sum_sent + sent * CHAIN_LENGTH) * cores
                       - (refused_sum + (int64_t)refused_count * CHAIN_LENGTH);
    uint64_t per_core[16];
    uint64_t least = ~0ull, most = 0, total_runs = 0;
    for (int c = 0; c < cores; c++) {
        struct engine_core_stats s;
        engine_core_stats(c, &s);
        per_core[c] = s.ran;
        total_runs += s.ran;
        if (s.ran < least) least = s.ran;
        if (s.ran > most) most = s.ran;
    }
    struct engine_totals t;
    engine_totals(&t);
    struct station *us = station_at(p.uneven);
    uint64_t growths = us->ports[0].growths;
    int unmatched = port_waiting(&us->ports[0]);
    int expected_growth = (unmatched + us->ports[0].cells_per_page - 1) / us->ports[0].cells_per_page - 1;
    long drift = (long)pages_warm - (long)pages_end;
    double runs_per_s = (double)total_runs * 1e9 / (double)(t_settled - t_start);

    int ok_count = count == expect_count;
    int ok_sum = sum == expect_sum;
    int ok_spread = cores == 1 || (most > 0 && (double)least / (double)most > 0.2);
    int ok_growth = (int)growths >= expected_growth && growths > 0;
    /* Memory flat after warm-up: the unmatched values the uneven station is
     * made to hold are the only thing that should keep growing. */
    long allowed = (long)(growths + 64);
    int ok_memory = drift <= allowed;
    int pass = ok_count && ok_sum && ok_spread && ok_growth && ok_memory && restarted && rewired;

    printf("\nvalues refused by picky while it was going out of service: %llu\n", (unsigned long long)refused_count);
    printf("values sent %lld; sink count %llu (expected %llu) %s; sum %lld (expected %lld) %s\n",
           (long long)sent, (unsigned long long)count, (unsigned long long)expect_count, ok_count ? "ok" : "WRONG",
           (long long)sum, (long long)expect_sum, ok_sum ? "ok" : "WRONG");
    printf("runs %llu at %.0f per second; per core:", (unsigned long long)total_runs, runs_per_s);
    for (int c = 0; c < cores; c++) printf(" %llu", (unsigned long long)per_core[c]);
    printf(" %s\n", ok_spread ? "ok" : "UNEVEN");
    printf("uneven station: %d values waiting unmatched, port grew %llu pages (at least %d expected) %s\n",
           unmatched, (unsigned long long)growths, expected_growth, ok_growth ? "ok" : "WRONG");
    printf("pages free at warm-up %zu, at end %zu: drift %ld (allowed %ld) %s\n", pages_warm, pages_end, drift,
           allowed, ok_memory ? "ok" : "LEAKING");
    printf("ring high water %d, ring growths %d, scrap waiting %llu\n", t.ring_high_water, t.ring_growths,
           (unsigned long long)t.scrap_waiting);
    printf("drain after the pump stopped: %.1f ms\n", (double)(t_settled - t_pump_end) / 1e6);
    printf("%s\n", pass ? "PASS" : "FAIL");

    char key[96];
#define M(name, value, unit, anchor, text) do {                           \
        snprintf(key, sizeof key, "endurance.%dcore.%s", cores, name);     \
        metric_record(key, value, unit, anchor, text); } while (0)
    M("runs_per_s", runs_per_s, "runs/s", "endurance-throughput", "box runs completed per second, whole program");
    M("run_cost_ns", cost_ns, "ns", "endurance-run-cost", "core time one run of one box costs, beyond the box's own work");
    M("pass_run_ns", pass_ns, "ns", "endurance-run-cost", "core time per run of a box that does nothing");
    M("round_ns", round_ns, "ns", "endurance-run-cost", "core time for one round of chew's mixing work");
    M("coarseness_rounds", round_ns > 0 ? cost_ns / round_ns : 0, "rounds", "endurance-coarseness",
      "rounds of work a box must do per run to equal the engine's cost of running it");
    M("values_sent", (double)sent, "values", "endurance-arithmetic", "values pumped in during the run");
    M("count_ok", ok_count, "bool", "endurance-arithmetic", "sink count matched the closed-form expectation");
    M("sum_ok", ok_sum, "bool", "endurance-arithmetic", "sink sum matched the closed-form expectation");
    M("spread_least_over_most", most ? (double)least / (double)most : 0, "ratio", "endurance-spread",
      "least-busy core's runs over busiest core's");
    M("port_growths_uneven", (double)growths, "pages", "endurance-growth", "pages the unevenly fed port added");
    M("pages_drift", (double)drift, "pages", "endurance-memory", "free pages lost between warm-up and the end");
    M("ring_high_water", t.ring_high_water, "tasks", "endurance-ring", "most tasks waiting at once");
    M("drain_ms", (double)(t_settled - t_pump_end) / 1e6, "ms", "endurance-drain",
      "time for everything in flight to finish after the pump stopped");
    M("pass", pass, "bool", "endurance-verdict", "every check passed");
#undef M
    metrics_close();

    draw_report(pass, count, expect_count, runs_per_s, per_core, cost_ns, round_ns, growths, drift, restarted, rewired);
    if (png_path) {
        twin_screens_save_png(png_path);
        printf("screens written to %s\n", png_path);
    }
    twin_engine_stop();
    return pass ? 0 : 1;
}
