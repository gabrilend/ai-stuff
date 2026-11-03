/*
 * 099-input-twin.h — the laptop twin's buttons, sticks and touch panels
 * (issues 502, 503, 504).
 *
 * General description: the twin has none of them, so a test holds them
 * down, pushes them and touches them by saying so. The reads declared in
 * src/system/096-input.h answer whatever was set last, each surface read
 * whole under one lock, so a box on any core sees one consistent
 * snapshot of it.
 */
#ifndef SOREN_INPUT_TWIN_H
#define SOREN_INPUT_TWIN_H

#include <stdint.h>

/* From now on, these buttons are down (bits as in 096-input.h). */
void twin_input_set_buttons(uint32_t pressed);

/* From now on, the sticks stand here (-2048..2047, y up). */
void twin_input_set_sticks(int32_t left_x, int32_t left_y, int32_t right_x, int32_t right_y);

/* From now on, `screen` (0 bottom, 1 top) is touched at x, y with this
 * pressure, or is not touched (down 0). */
void twin_input_set_touch(int screen, int32_t down, int32_t x, int32_t y, int32_t pressure);

#endif
