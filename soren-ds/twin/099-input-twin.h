/*
 * 099-input-twin.h — the laptop twin's buttons (issue 502).
 *
 * General description: the twin has no buttons, so a test holds them
 * down by saying which are down. input_buttons_now (src/system/096-input.h)
 * answers whatever was set last, read whole, so a box on any core sees one
 * consistent snapshot.
 */
#ifndef SOREN_INPUT_TWIN_H
#define SOREN_INPUT_TWIN_H

#include <stdint.h>

/* From now on, these buttons are down (bits as in 096-input.h). */
void twin_input_set_buttons(uint32_t pressed);

#endif
