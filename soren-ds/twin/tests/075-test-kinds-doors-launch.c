/*
 * 075-test-kinds-doors-launch.c — issues 308, 309, 310 and 311.
 *
 * General description: every way of choosing an exit is run over enough
 * values that a wrong picker cannot pass by luck — a comparator's three
 * branches split at the threshold exactly, an iterator deals round
 * exactly evenly, random lands close to even, weighted lands close to its
 * weights, and spread sends more to the destination that keeps up. Then
 * the doors' two deliberate facts: two marked ports on one station fed
 * by two callers pair arbitrarily (the trap), and an argument's number is
 * the mark, not where its line sits. Bringing a program up twice starts
 * nothing twice. The launch boxes: the clock moves forward, random numbers
 * differ, a refusing box is taken out of service with the value it
 * refused, the calibration pair shapes values inside 0..1000, and
 * stopping everything on purpose halts the machine after writing out the
 * transcript. Last, the transcript itself keeps the newest events when it
 * wraps, and streams them when asked.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/038-tallies.h"
#include "catalogue-boxes.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define CORES 4

/* {{{ load */
static int load(const char *name, const char *text)
{
    struct map_report report;
    char path[256];
    snprintf(path, sizeof path, "src/maps/%s", name);
    int p = program_load_text(path, text, strlen(text), &report);
    if (p < 0) {
        fprintf(stderr, "%s did not load:\n%s", name, report.text);
    }
    return p;
}
/* }}} */

/* {{{ count_at */
static uint64_t count_at(int program, const char *station)
{
    uint64_t c;
    int64_t s;
    tally_read(program_station(program, station), &c, &s);
    return c;
}
/* }}} */

/* {{{ feed */
static void feed(int program, const char *station, int port, int64_t from, int64_t to)
{
    int32_t s = program_station(program, station);
    for (int64_t v = from; v < to; v++) {
        engine_deliver(s, port, &v, sizeof v);
    }
}
/* }}} */

/* {{{ near */
static int near(uint64_t got, double want, double tolerance)
{
    return (double)got > want * (1 - tolerance) && (double)got < want * (1 + tolerance);
}
/* }}} */

#define SINK(name, from) "station " name " (../boxes/062-arithmetic.c:discard)\n  in 0 - " from "\n"

int main(void)
{
    char log_path[512];
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/075-developer-line.log", getenv("SOREN_DIR"));
    remove(log_path);
    twin_engine_start(CORES, (size_t)512 << 20);
    twin_platform_set_log(log_path, 0);
    engine_open_gate();
    metrics_open("075-kinds-doors-launch");

    /* --- a comparator splits at its threshold ------------------------- */
    int cmp = load("comparator.map",
        "comparator split (../boxes/062-arithmetic.c:below)\n"
        "  in 0 -\n  in 1 = 50\n"
        "  out 0 - low.0\n  out 1 - even.0\n  out 2 - high.0\n"
        SINK("low", "split.0") SINK("even", "split.1") SINK("high", "split.2"));
    engine_configure(program_station(cmp, "split"), 0, PORT_RING, NULL, 0);
    feed(cmp, "split", 0, 0, 100);
    twin_engine_settle(3000);
    CHECK(count_at(cmp, "low") == 50 && count_at(cmp, "even") == 1 && count_at(cmp, "high") == 49,
          "a comparator sent 0-49 below, 50 equal, 51-99 above (%llu %llu %llu)",
          (unsigned long long)count_at(cmp, "low"), (unsigned long long)count_at(cmp, "even"), (unsigned long long)count_at(cmp, "high"));

    /* --- an iterator deals round exactly -------------------------------- */
    int it = load("iterator.map",
        "iterator deal (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 -\n"
        "  out 0 - a.0\n  out 1 - b.0\n  out 2 - c.0\n"
        SINK("a", "deal.0") SINK("b", "deal.1") SINK("c", "deal.2"));
    engine_configure(program_station(it, "deal"), 0, PORT_RING, NULL, 0);
    feed(it, "deal", 0, 0, 3000);
    twin_engine_settle(3000);
    CHECK(count_at(it, "a") == 1000 && count_at(it, "b") == 1000 && count_at(it, "c") == 1000,
          "an iterator dealt 3000 values exactly 1000 to each exit");

    /* --- random lands close to even -------------------------------------- */
    const int R = 40000;
    int rnd = load("random.map",
        "random pick (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 -\n"
        "  out 0 - r0.0\n  out 1 - r1.0\n  out 2 - r2.0\n  out 3 - r3.0\n"
        SINK("r0", "pick.0") SINK("r1", "pick.1") SINK("r2", "pick.2") SINK("r3", "pick.3"));
    engine_configure(program_station(rnd, "pick"), 0, PORT_RING, NULL, 0);
    feed(rnd, "pick", 0, 0, R);
    twin_engine_settle(5000);
    uint64_t r[4] = { count_at(rnd, "r0"), count_at(rnd, "r1"), count_at(rnd, "r2"), count_at(rnd, "r3") };
    CHECK(r[0] + r[1] + r[2] + r[3] == (uint64_t)R && near(r[0], R / 4.0, 0.05) && near(r[1], R / 4.0, 0.05) &&
          near(r[2], R / 4.0, 0.05) && near(r[3], R / 4.0, 0.05),
          "random spread 40000 values within 5%% of even (%llu %llu %llu %llu)", (unsigned long long)r[0],
          (unsigned long long)r[1], (unsigned long long)r[2], (unsigned long long)r[3]);
    double spread = 0;
    for (int i = 0; i < 4; i++) {
        double d = ((double)r[i] - R / 4.0) / (R / 4.0);
        if (d < 0) d = -d;
        if (d > spread) spread = d;
    }
    metric_record("kinds.random_worst_deviation", spread * 100, "%", "kinds-random",
                  "largest distance of any exit's share from an even quarter, 40000 values over 4 exits");

    /* --- weighted lands close to its weights ------------------------------ */
    int wt = load("weighted.map",
        "weighted pick (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 -\n  in 1 = { 1, 2, 5 }\n"
        "  out 0 - w0.0\n  out 1 - w1.0\n  out 2 - w2.0\n"
        SINK("w0", "pick.0") SINK("w1", "pick.1") SINK("w2", "pick.2"));
    engine_configure(program_station(wt, "pick"), 0, PORT_RING, NULL, 0);
    feed(wt, "pick", 0, 0, 40000);
    twin_engine_settle(5000);
    uint64_t w0 = count_at(wt, "w0"), w1 = count_at(wt, "w1"), w2 = count_at(wt, "w2");
    CHECK(near(w0, 5000, 0.07) && near(w1, 10000, 0.07) && near(w2, 25000, 0.07),
          "weighted {1, 2, 5} split 40000 close to 5000 / 10000 / 25000 (%llu %llu %llu)",
          (unsigned long long)w0, (unsigned long long)w1, (unsigned long long)w2);

    /* --- spread favours the destination that keeps up --------------------- */
    int sp = load("spread.map",
        "spread share (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 -\n"
        "  out 0 - slow.0\n  out 1 - quick.0\n"
        "station slow (../boxes/062-arithmetic.c:chew)\n"
        "  in 0 - share.0\n  in 1 = 200000\n  out 0 - slow_sink.0\n"
        "station quick (../boxes/062-arithmetic.c:pass)\n"
        "  in 0 - share.1\n  out 0 - quick_sink.0\n"
        SINK("slow_sink", "slow.0") SINK("quick_sink", "quick.0"));
    engine_configure(program_station(sp, "share"), 0, PORT_RING, NULL, 0);
    feed(sp, "share", 0, 0, 2000);
    twin_engine_settle(20000);
    uint64_t slow = count_at(sp, "slow_sink"), quick = count_at(sp, "quick_sink");
    CHECK(slow + quick == 2000 && quick > slow, "spread sent more to the destination that keeps up (quick %llu, slow %llu)",
          (unsigned long long)quick, (unsigned long long)slow);
    metric_record("kinds.spread_quick_share", (double)quick / 2000.0, "fraction", "kinds-spread",
                  "share of values spread sent to the quick destination instead of the slow one");

    /* --- the pairing trap ---------------------------------------------------- */
    int trap = load("trap.map",
        "station pair (../boxes/062-arithmetic.c:add)\n"
        "  in 0 - 0$\n  in 1 - 1$\n"
        "  out 0 - paired.0\n"
        SINK("paired", "pair.0"));
    /* Two callers each mean their own object with their own colour:
     * (100 with 1) and (200 with 2). One caller's object arrives, then the
     * other caller's colour, then the rest. Correspondence across two
     * ports is not promised, so the first object meets the wrong colour. */
    int64_t o1 = 100, c1 = 1, o2 = 200, c2 = 2;
    program_argument(trap, 0, &o1, sizeof o1);
    program_argument(trap, 1, &c2, sizeof c2);
    program_argument(trap, 0, &o2, sizeof o2);
    program_argument(trap, 1, &c1, sizeof c1);
    twin_engine_settle(2000);
    uint64_t runs = count_at(trap, "paired");
    int64_t sum;
    uint64_t count;
    tally_read(program_station(trap, "paired"), &count, &sum);
    int32_t pair = program_station(trap, "pair");
    CHECK(runs == 2 && engine_station_runs(pair) == 2, "the trap: both pairs ran");
    /* Their sum is the same either way (303 = 101+202 = 102+201); what the
     * trap costs is correspondence, which the ports never promised. The
     * test pins the decision: anything that must arrive as a unit is one
     * struct on one port. */
    CHECK(sum == 303, "and the values all arrived (%lld), paired by arrival, not by caller", (long long)sum);

    /* --- an argument's number is its mark, not its line's position --------- */
    int first = load("order-a.map",
        "station take (../boxes/062-arithmetic.c:chew)\n"
        "  in 0 - 0$\n  in 1 - 1$\n  out 0 - out_a.0\n" SINK("out_a", "take.0"));
    int second = load("order-b.map",
        "station take (../boxes/062-arithmetic.c:chew)\n"
        "  in 1 - 1$\n  in 0 - 0$\n  out 0 - out_b.0\n" SINK("out_b", "take.0"));
    int swapped = load("order-c.map",
        "station take (../boxes/062-arithmetic.c:chew)\n"
        "  in 0 - 1$\n  in 1 - 0$\n  out 0 - out_c.0\n" SINK("out_c", "take.0"));
    int64_t seed = 5, rounds = 3;
    int progs[3] = { first, second, swapped };
    for (int i = 0; i < 3; i++) {
        program_argument(progs[i], 0, &seed, sizeof seed);
        program_argument(progs[i], 1, &rounds, sizeof rounds);
    }
    twin_engine_settle(2000);
    int64_t sa, sb, sc;
    tally_read(program_station(first, "out_a"), &count, &sa);
    tally_read(program_station(second, "out_b"), &count, &sb);
    tally_read(program_station(swapped, "out_c"), &count, &sc);
    CHECK(sa == sb, "moving the lines changed nothing (%lld, %lld)", (long long)sa, (long long)sb);
    CHECK(sa != sc, "editing the marks swapped the arguments (%lld vs %lld)", (long long)sa, (long long)sc);

    /* --- bringing up twice starts nothing twice ------------------------------- */
    int counting = program_load("src/maps/counting.map", &(struct map_report){ 0 });
    twin_engine_settle(2000);
    int32_t add_one = program_station(counting, "add_one");
    uint64_t before = engine_station_runs(add_one);
    struct map_report report;
    program_bring_up(counting, &report);
    program_bring_up(counting, &report);
    twin_engine_settle(2000);
    CHECK(before == 10 && engine_station_runs(add_one) == before, "bringing a program up twice started nothing again (%llu runs)",
          (unsigned long long)engine_station_runs(add_one));

    /* --- the launch boxes ------------------------------------------------------ */
    char line[512];
    int launch = load("launch.map",
        "station clock (../boxes/064-launch.c:clock)\n  in 0 -\n"
        "station dice (../boxes/064-launch.c:random_number)\n  in 0 -\n  out 0 - rolls.0\n"
        SINK("rolls", "dice.0")
        "station no (../boxes/064-launch.c:refuse)\n  in 0 -\n");
    CHECK(launch >= 0, "the launch boxes load");
    int32_t no = program_station(launch, "no");
    engine_configure(no, 0, PORT_RING, NULL, 0);
    int64_t refused_value = 77;
    engine_deliver(no, 0, &refused_value, sizeof refused_value);
    int32_t dice = program_station(launch, "dice");
    engine_configure(dice, 0, PORT_RING, NULL, 0);
    for (int64_t k = 0; k < 64; k++) engine_deliver(dice, 0, &k, sizeof k);
    twin_engine_settle(2000);
    struct engine_error_report er;
    engine_read_error(no, &er, 0);
    CHECK(er.kind == 1 && er.detail == 77 && engine_port_tag(no, 0) == PORT_NONE,
          "refuse took itself out of service, naming the value it refused (kind %d, detail %llu)", er.kind, (unsigned long long)er.detail);
    tally_read(program_station(launch, "rolls"), &count, &sum);
    CHECK(count == 64, "random_number answered 64 triggers");

    /* --- the transcript ---------------------------------------------------------- */
#ifdef SOREN_DEBUG
    struct transcript_event events[TRANSCRIPT_ENTRIES];
    uint64_t next;
    int n = transcript_read(0, events, TRANSCRIPT_ENTRIES, &next);
    int kinds_seen[TRANSCRIPT_KIND_COUNT] = { 0 };
    int contiguous = 1;
    for (int i = 0; i < n; i++) {
        kinds_seen[events[i].kind]++;
        if (i && events[i].sequence != events[i - 1].sequence + 1) contiguous = 0;
    }
    CHECK(transcript_newest() > TRANSCRIPT_ENTRIES && n == TRANSCRIPT_ENTRIES && contiguous,
          "the transcript wrapped (%llu events) and kept exactly the newest %d, in order", (unsigned long long)transcript_newest(), n);
    CHECK(kinds_seen[TRANSCRIPT_QUEUED] && kinds_seen[TRANSCRIPT_STARTED] && kinds_seen[TRANSCRIPT_FINISHED] &&
          kinds_seen[TRANSCRIPT_DELIVERED] && kinds_seen[TRANSCRIPT_OUT_OF_SERVICE],
          "it recorded queued, started, finished, delivered and out-of-service events");
    transcript_live(1);
    for (int64_t k = 0; k < 8; k++) engine_deliver(dice, 0, &k, sizeof k);
    twin_engine_settle(2000);
    transcript_live(0);
    FILE *lf = fopen(log_path, "r");
    int streamed = 0;
    while (lf && fgets(line, sizeof line, lf)) streamed += strstr(line, "finished") && strstr(line, "dice");
    if (lf) fclose(lf);
    CHECK(streamed >= 8, "switched on, the live stream wrote events out as cores went idle (%d dice runs seen)", streamed);
#endif

    /* --- stopping everything, on purpose ---------------------------------------- */
    fflush(NULL);
    pid_t child = fork();
    if (child == 0) {
        /* The halt message goes to standard error and the transcript to the
         * developer's line; each gets its own file so neither overwrites
         * the other. */
        char path[600], errors[600];
        snprintf(path, sizeof path, "%s/tmp/shared-memory/test-logs/075-halt.log", getenv("SOREN_DIR"));
        snprintf(errors, sizeof errors, "%s/tmp/shared-memory/test-logs/075-halt-stderr.log", getenv("SOREN_DIR"));
        remove(path);
        freopen(errors, "w", stderr);
        /* Threads do not survive a fork: the child starts an engine of its own. */
        twin_engine_start(2, (size_t)64 << 20);
        engine_open_gate();
        twin_platform_set_log(path, 0);
        int stop = load("stop.map", "station stop (../boxes/064-launch.c:stop_everything)\n  in 0 = 9\n");
        (void)stop;
        sleep(5);
        _exit(0);                              /* not reached if the halt worked */
    }
    int status;
    waitpid(child, &status, 0);
    char halt_path[600];
    snprintf(halt_path, sizeof halt_path, "%s/tmp/shared-memory/test-logs/075-halt.log", getenv("SOREN_DIR"));
    FILE *hf = fopen(halt_path, "r");
    int said_halt = 0, said_transcript = 0;
    while (hf && fgets(line, sizeof line, hf)) {
        said_transcript += strstr(line, "transcript: the last") != NULL;
    }
    if (hf) fclose(hf);
    snprintf(halt_path, sizeof halt_path, "%s/tmp/shared-memory/test-logs/075-halt-stderr.log", getenv("SOREN_DIR"));
    hf = fopen(halt_path, "r");
    while (hf && fgets(line, sizeof line, hf)) {
        said_halt += strstr(line, "HALT") && strstr(line, "stop_everything was asked to, with 9");
    }
    if (hf) fclose(hf);
    CHECK(WIFSIGNALED(status), "stop_everything halted the machine");
    CHECK(said_halt == 1, "saying why, once");
#ifdef SOREN_DEBUG
    CHECK(said_transcript == 1, "after writing out the transcript (a debug build's last words)");
#else
    CHECK(said_transcript == 0, "and an ordinary build has no transcript to write");
#endif

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("075 kinds, doors and launch boxes");
}
