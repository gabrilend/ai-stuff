/*
 * 098-input-device.c — the handheld's answer to "which buttons are down?"
 * (issue 502, declared in src/system/096-input.h).
 *
 * UNVERIFIED ON HARDWARE, and not yet a read at all. The buttons are GPIO
 * inputs, but which pin of which bank is which button is issue 101's
 * finding and is not in hand. Until it is, this answers "nothing pressed"
 * every frame, so the input-poll map runs on the device exactly as it
 * will once the pins are known, only quietly.
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
