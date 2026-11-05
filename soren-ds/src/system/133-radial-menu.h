/*
 * 133-radial-menu.h — giving the radial menu a table of the user's own
 * (issue 506).
 *
 * General description: src/maps/radial-menu-chord.map types from the table
 * written in it. A person who remaps the characters keeps their table in
 * /settings/ (phase 8's editor reads it); this is how it reaches the
 * running chord: it replaces the `chord` station's table where it stands,
 * the way a dial is turned, so the very next frame types from it and
 * nothing is reloaded. A box cannot do this — a fixed value is not a port
 * any wire feeds — so it is a call, made by whatever places the program.
 */
#ifndef SOREN_RADIAL_MENU_H
#define SOREN_RADIAL_MENU_H

#include <stddef.h>

#define RADIAL_MENU_MAP     "src/maps/radial-menu-chord.map"
#define RADIAL_MENU_STATION "chord"

/* Use `table` (a struct radial_table, src/boxes/131-radial-menu.c, of
 * `size` bytes) in `program`, a radial-menu-chord program loaded on its
 * own or placed inside another (pass the placed one: program_child). A
 * table the chord finds wrong refuses it on the next frame, as the
 * default would. Answers 0, or a negative engine error: no such program
 * or station, or a size that is not the table's. */
int radial_menu_set_table(int program, const void *table, size_t size);

#endif
