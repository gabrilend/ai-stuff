/*
 * 133-radial-menu.c — giving the radial menu a table of the user's own
 * (issue 506).
 *
 * General description: see 133-radial-menu.h. Delivering into a static
 * port replaces its setting at once; the engine checks the size against
 * the port's own, which the catalogue took from the box.
 */
#include <stdint.h>
#include "../engine/031-engine.h"
#include "../engine/068-programs.h"
#include "133-radial-menu.h"

/* {{{ radial_menu_set_table */
int radial_menu_set_table(int program, const void *table, size_t size)
{
    int32_t chord = program_station(program, RADIAL_MENU_STATION);
    if (chord < 0) {
        return ENGINE_NO_STATION;
    }
    return engine_deliver(chord, 1, table, size);
}
/* }}} */
