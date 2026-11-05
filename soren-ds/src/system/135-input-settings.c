/*
 * 135-input-settings.c — turning the input settings in a running
 * input-poll program (issue 507).
 *
 * General description: see 135-input-settings.h. Every applier is looked
 * up before any is turned, so a program missing one is left as it was
 * rather than half changed. Delivering into a static port replaces its
 * dial at once; the engine checks the size against the port's own.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/068-programs.h"
#include "135-input-settings.h"

/* {{{ input_settings_set */
int input_settings_set(int program, int32_t left_handed, int32_t drawer_swap)
{
    if ((left_handed != 0 && left_handed != 1) || (drawer_swap != 0 && drawer_swap != 1)) {
        return INPUT_SETTINGS_BAD_VALUE;
    }
    static const char *const names[INPUT_SETTINGS_STATION_COUNT] = INPUT_SETTINGS_STATIONS;
    int32_t stations[INPUT_SETTINGS_STATION_COUNT];
    for (int i = 0; i < INPUT_SETTINGS_STATION_COUNT; i++) {
        stations[i] = program_station(program, names[i]);
        if (stations[i] < 0) {
            return ENGINE_NO_STATION;
        }
    }
    /* struct input_settings (src/boxes/134-input-roles.c): two int32s. */
    int32_t settings[2] = { left_handed, drawer_swap };
    for (int i = 0; i < INPUT_SETTINGS_STATION_COUNT; i++) {
        int err = engine_deliver(stations[i], 1, settings, sizeof settings);
        if (err != 0) {
            return err;
        }
    }
    return 0;
}
/* }}} */
