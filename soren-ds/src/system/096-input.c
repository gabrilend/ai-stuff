/*
 * 096-input.c — starting and stopping the input frame (issue 501).
 *
 * General description: see 096-input.h. The tick is a fixed value (1);
 * its arrival is what matters, and the frame number is counted by the map.
 * The buttons' names live here so the boxes and the tools that print
 * events agree on them; how the buttons are read is each side's own
 * (src/device/098-input-device.c, twin/099-input-twin.c).
 */
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "096-input.h"

/* {{{ button_name */
const char *button_name(int button)
{
    static const char *const names[BUTTON_COUNT] = {
        "dpad-up", "dpad-down", "dpad-left", "dpad-right",
        "abxy-a", "abxy-b", "abxy-x", "abxy-y",
        "l1", "r1", "l2", "r2",
        "start1", "select1", "select2", "start2",
        "stick-left", "stick-right",
    };
    if (button < 0 || button >= BUTTON_COUNT) {
        return "?";
    }
    return names[button];
}
/* }}} */

/* {{{ direction_name */
const char *direction_name(int direction)
{
    static const char *const names[DIRECTION_COUNT] = {
        "none", "n", "ne", "e", "se", "s", "sw", "w", "nw",
    };
    if (direction < 0 || direction >= DIRECTION_COUNT) {
        return "?";
    }
    return names[direction];
}
/* }}} */

/* {{{ input_poll_start */
int input_poll_start(struct input_poll *poll, struct map_report *report)
{
    poll->program = -1;
    poll->timer = -1;
    int program = program_load(INPUT_POLL_MAP, report);
    if (program < 0) {
        return -1;
    }
    if (program_bring_up(program, report) != 0) {
        program_remove(program);
        return -1;
    }
    int64_t tick = 1;
    int timer = program_argument_every(program, 0, &tick, sizeof tick,
                                       platform_now_ns() + INPUT_FRAME_NS, INPUT_FRAME_NS);
    if (timer < 0) {
        text_format(report->text, sizeof report->text,
                    "%s: the frame's timer could not be armed (%d)\n", INPUT_POLL_MAP, timer);
        report->problems = 1;
        program_remove(program);
        return -1;
    }
    poll->program = program;
    poll->timer = timer;
    return program;
}
/* }}} */

/* {{{ input_poll_stop */
void input_poll_stop(struct input_poll *poll)
{
    if (poll->timer >= 0) {
        engine_timer_cancel(poll->timer);
        poll->timer = -1;
    }
}
/* }}} */
