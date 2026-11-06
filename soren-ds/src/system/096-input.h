/*
 * 096-input.h — starting and stopping the input frame (issue 501).
 *
 * General description: the input-poll map (src/maps/input-poll.map) is
 * an ordinary program; what makes it run 60 times a second is an engine
 * timer writing into its argument door. These two calls are the whole of
 * the outside's part: load and bring up the map, arm the timer; and, for
 * the laptop twin's tests, disarm it again. On the device the first call
 * belongs at the end of boot, once the engine's cores are running.
 */
#ifndef SOREN_INPUT_H
#define SOREN_INPUT_H

#include <stdint.h>
#include "../engine/068-programs.h"

#define INPUT_POLL_MAP "src/maps/input-poll.map"

/* One frame. A second is not a whole number of nanoseconds over 60, so
 * this rounds 16 666 666.67 up: the frame drifts 20 ns a second (1.7 ms
 * a day) behind the true 60 Hz. Nothing on this device keeps wall time by
 * counting frames, so that is accepted rather than made exact. */
#define INPUT_FRAME_NS 16666667ull

struct input_poll {
    int program;                 /* the input-poll program, or -1 */
    int timer;                   /* the engine timer driving it, or -1 */
};

/* Load and bring up the input-poll map and start its frame, the first
 * tick one frame from now. Answers the program number, or -1 with the
 * reason in `report` (nothing is left placed or armed). */
int input_poll_start(struct input_poll *poll, struct map_report *report);

/* Stop the frame. The program stays placed, idle, with the next frame
 * number waiting on its loop; program_remove takes it away. */
void input_poll_stop(struct input_poll *poll);

#endif
