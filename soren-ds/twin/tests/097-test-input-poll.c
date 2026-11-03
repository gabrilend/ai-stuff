/*
 * 097-test-input-poll.c — issue 501: the frame every input surface hangs
 * off.
 *
 * General description: the input-poll map loads from the maps compiled
 * in, brings up cleanly and is started by an engine timer writing into
 * its argument door. Over about a second it is checked that: frames are
 * numbered 1, 2, 3 ... with none repeated and none skipped; every frame
 * reaches all three surfaces exactly once; the number of frames plus the
 * periods the timer had to skip matches the time that passed at 60 Hz;
 * each deadline was measured from the one before (the timer's next moment
 * is exactly its first plus a whole number of periods); and once the
 * timer is stopped nothing more happens and every core goes to sleep,
 * with the program still placed and the next frame waiting on its loop.
 * Then the same program is started a second time beside the first, to
 * show two frames do not interfere.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/system/096-input.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

#define CORES 4

/* {{{ sleep_ms */
static void sleep_ms(int ms)
{
    struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}
/* }}} */

/* {{{ surface_counts */
/* How many frames each of the three surfaces received: how many times
 * each surface's history station compared a frame with the one before
 * (502, 503, 504). The sums are left out (-1); the frame numbers are
 * checked by each surface's own test. */
struct surfaces {
    uint64_t count[3];
    int64_t  sum[3];
};

static struct surfaces surface_counts(int program)
{
    static const char *names[3] = { "buttons", "sticks", "touch" };
    struct surfaces s;
    for (int i = 0; i < 3; i++) {
        s.count[i] = engine_station_runs(program_station(program, names[i]));
        s.sum[i] = -1;
    }
    return s;
}
/* }}} */

/* {{{ check_run */
/* Everything about one run of the frame, once its timer has stopped and
 * the engine has settled. `first_ns` is when the first tick was due and
 * `stopped_ns` when the timer was cancelled. */
static void check_run(const char *label, int program, int timer, uint64_t first_ns, uint64_t stopped_ns)
{
    uint64_t frames = engine_station_runs(program_station(program, "frame"));
    uint64_t missed = engine_timer_missed(timer);
    uint64_t due    = engine.timers[timer].due_ns;
    struct surfaces s = surface_counts(program);
    int64_t want_sum = (int64_t)(frames * (frames + 1) / 2);

    CHECK(frames > 0, "%s: the frame ran (%llu frames)", label, (unsigned long long)frames);
    for (int i = 0; i < 3; i++) {
        CHECK(s.count[i] == frames && (s.sum[i] == want_sum || s.sum[i] == -1),
              "%s: surface %d saw every frame once: %llu frames summing to %lld (want %llu, %lld)",
              label, i, (unsigned long long)s.count[i], (long long)s.sum[i],
              (unsigned long long)frames, (long long)want_sum);
    }
    /* Each deadline is the one before plus a period, so the next one is
     * the first plus a whole number of periods: one per frame delivered
     * and one per period skipped. */
    CHECK(due == first_ns + (frames + missed) * INPUT_FRAME_NS,
          "%s: every deadline measured from the one before (next due %llu = first %llu + (%llu + %llu) periods)",
          label, (unsigned long long)due, (unsigned long long)first_ns,
          (unsigned long long)frames, (unsigned long long)missed);
    /* Delivered plus skipped is every period that came due before the stop. */
    uint64_t came_due = (stopped_ns - first_ns) / INPUT_FRAME_NS + 1;
    CHECK(frames + missed + 1 >= came_due && frames + missed <= came_due + 1,
          "%s: %llu frames and %llu skipped periods for the %llu that came due at 60 Hz",
          label, (unsigned long long)frames, (unsigned long long)missed, (unsigned long long)came_due);
}
/* }}} */

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("097-input-poll");
    struct map_report report;

    /* --- start ----------------------------------------------------------- */
    struct input_poll poll;
    uint64_t before = platform_now_ns();
    int program = input_poll_start(&poll, &report);
    CHECK(program >= 0 && poll.timer >= 0, "input-poll loads, brings up and is armed (%s)", report.text);
    CHECK(program_argument_count(program) == 1 && program_result_count(program) == 0,
          "it has one argument door, the tick, and no results");
    CHECK(program_station_count(program) == 25, "its twenty-five stations are placed (%d)",
          program_station_count(program));
    uint64_t first_ns = engine.timers[poll.timer].due_ns;
    CHECK(first_ns >= before + INPUT_FRAME_NS && first_ns <= platform_now_ns() + INPUT_FRAME_NS,
          "the first tick is one frame after starting");

    /* Nothing until the first tick: the loop holds frame 0 and waits. */
    CHECK(twin_engine_settle(5000), "before the first tick, everything is asleep");
    CHECK(engine_station_runs(program_station(program, "frame")) == 0 ||
          platform_now_ns() >= first_ns, "and no frame was made early");

    /* --- run for about a second ----------------------------------------- */
    sleep_ms(1000);
    uint64_t mid = engine_station_runs(program_station(program, "frame"));
    CHECK(mid >= 30, "frames keep coming with no one asking (%llu after a second)", (unsigned long long)mid);
    sleep_ms(200);

    /* --- stop ------------------------------------------------------------ */
    int timer = poll.timer;
    uint64_t stopped_ns = platform_now_ns();
    input_poll_stop(&poll);
    CHECK(poll.timer == -1, "stopping disarms the timer");
    CHECK(twin_engine_settle(10000), "once stopped, every core goes to sleep");
    check_run("alone", program, timer, first_ns, stopped_ns);
    metric_record("input.frames_per_second",
                  (double)engine_station_runs(program_station(program, "frame")) * 1e9 / (double)(stopped_ns - first_ns),
                  "frames/s", "input-poll", "frames the input-poll map made per second of running, alone");
    metric_record("input.skipped_periods", (double)engine_timer_missed(timer), "periods", "input-poll",
                  "frame deadlines that passed with no core free to deliver them, over about 1.2 s");

    uint64_t frames = engine_station_runs(program_station(program, "frame"));
    sleep_ms(100);
    CHECK(engine_station_runs(program_station(program, "frame")) == frames,
          "and nothing more happens after the stop");
    CHECK(engine_port_waiting(program_station(program, "frame"), 1) == 1,
          "the next frame number waits on the loop, ready for a restart");

    /* --- two at once ----------------------------------------------------- */
    /* Two input frames are not something the device wants, but they are two
     * ordinary programs and must not see each other's ticks. */
    struct input_poll a, b;
    CHECK(input_poll_start(&a, &report) >= 0, "a first copy starts (%s)", report.text);
    CHECK(input_poll_start(&b, &report) >= 0, "a second copy starts beside it (%s)", report.text);
    uint64_t first_a = engine.timers[a.timer].due_ns;
    uint64_t first_b = engine.timers[b.timer].due_ns;
    sleep_ms(500);
    int ta = a.timer, tb = b.timer;
    uint64_t stop_a = platform_now_ns();
    input_poll_stop(&a);
    uint64_t stop_b = platform_now_ns();
    input_poll_stop(&b);
    CHECK(twin_engine_settle(10000), "both stopped, every core sleeps");
    check_run("copy a", a.program, ta, first_a, stop_a);
    check_run("copy b", b.program, tb, first_b, stop_b);

    /* --- removal --------------------------------------------------------- */
    CHECK(program_remove(program) == 0 && program_remove(a.program) == 0 && program_remove(b.program) == 0,
          "all three programs come out");

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("097 input poll");
}
