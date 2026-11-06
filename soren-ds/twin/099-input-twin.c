/*
 * 099-input-twin.c — the laptop twin's buttons (issue 502).
 *
 * General description: see 099-input-twin.h. One word, written by the
 * test and read by whichever core runs read_buttons.
 */
#include <stdatomic.h>
#include <stdint.h>
#include "../src/system/096-input.h"
#include "099-input-twin.h"

static _Atomic uint32_t pressed_now;

/* {{{ twin_input_set_buttons */
void twin_input_set_buttons(uint32_t pressed)
{
    atomic_store(&pressed_now, pressed);
}
/* }}} */

/* {{{ input_buttons_now */
uint32_t input_buttons_now(void)
{
    return atomic_load(&pressed_now);
}
/* }}} */
