/*
 * 098-input-device.c — the handheld's answers to "which buttons are
 * down?", "where are the sticks?" and "is a panel touched?" (issues 502,
 * 503 and 504, declared in src/system/096-input.h).
 *
 * UNVERIFIED ON HARDWARE, and not yet a read at all. The buttons are GPIO
 * inputs, the sticks an ADC's channels, the panels two I2C controllers;
 * which pin, channel and controller is which is issue 101's finding and
 * is not in hand. Until it is, this answers "nothing pressed", "both
 * sticks centred" and "neither panel touched" every frame, so the
 * input-poll map runs on the device exactly as it will once they are
 * known, only quietly.
 *
 * General description: once 101 names the pins, this becomes one read of
 * each GPIO bank's data register that has a button on it (all of them in
 * one go, so every button is sampled at the same instant), each button's
 * pin moved to its bit in notes/diagnostics/001-button-bit-order.md, and
 * the pins that read low when pressed inverted.
 */
#include <stdint.h>
#include "../system/096-input.h"

/* {{{ input_buttons_now */
uint32_t input_buttons_now(void)
{
    return 0;
}
/* }}} */

/* {{{ input_sticks_now */
/* Once 101 names the converter: one conversion of the four channels,
 * each with its resting middle taken off (002-stick-calibration.md). */
void input_sticks_now(int32_t axes[STICK_AXES])
{
    for (int i = 0; i < STICK_AXES; i++) {
        axes[i] = 0;
    }
}
/* }}} */

/* {{{ input_touch_now */
/* Once 101 names the controllers: one short I2C read per panel, bounded
 * by the frame's budget; a controller that misses it reads as untouched
 * and leaves one line in the transcript ring. */
void input_touch_now(int screen, int32_t out[TOUCH_FIELDS])
{
    (void)screen;
    for (int i = 0; i < TOUCH_FIELDS; i++) {
        out[i] = 0;
    }
}
/* }}} */
