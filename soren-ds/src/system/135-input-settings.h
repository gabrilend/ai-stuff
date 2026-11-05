/*
 * 135-input-settings.h — turning the input settings in a running
 * input-poll program (issue 507).
 *
 * General description: the appliers in src/maps/input-poll.map
 * (src/boxes/134-input-roles.c) hold handedness and the drawer swap as a
 * fixed value each, right-handed and standard as written in the map. When
 * either setting changes, this turns all three appliers' dials to the new
 * pair, so the very next event carries the new roles and nothing is
 * reloaded. The settings themselves live in /settings/ (408, docs/011);
 * whatever writes them there calls this after, and so does whatever starts
 * input-poll, once, with the values it read at boot.
 *
 * Each applier reads its dial whole (a dial is written under a sequence
 * count, 034-ports.c), so an event sees the old pair or the new one, never
 * one of each. The three appliers are turned one after another, so for the
 * moment between two of them a button event and a stick change may answer
 * to different settings; each is still whole.
 */
#ifndef SOREN_INPUT_SETTINGS_H
#define SOREN_INPUT_SETTINGS_H

#include <stdint.h>

#define INPUT_SETTINGS_MAP "src/maps/input-poll.map"

/* The applier stations the settings are given to, by name. */
#define INPUT_SETTINGS_STATIONS { "roles_down", "roles_up", "roles_sticks" }
#define INPUT_SETTINGS_STATION_COUNT 3

/* The answer for a setting that is neither 0 nor 1: below every engine
 * error, so it is never mistaken for one. */
#define INPUT_SETTINGS_BAD_VALUE (-100)

/* Give `program` (input-poll, loaded on its own or placed: pass the placed
 * one) these settings: `left_handed` 0 or 1, `drawer_swap` 0 or 1. A value
 * other than 0 or 1 is not given to any applier and answers
 * INPUT_SETTINGS_BAD_VALUE, so a wrong value never refuses the stations a
 * person's input passes through. Answers 0, or a negative engine error:
 * no such program, or a station missing (none is turned then), or
 * ENGINE_WRONG_SIZE for a station of that name whose dial is not the
 * settings (the ones before it in INPUT_SETTINGS_STATIONS are turned). */
int input_settings_set(int program, int32_t left_handed, int32_t drawer_swap);

#endif
