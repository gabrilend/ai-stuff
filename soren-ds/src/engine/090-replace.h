/*
 * 090-replace.h — replacing a box in a running program (issue 411).
 *
 * General description: a station's box cannot change, because its input
 * ports were sized to that box and may be holding values right now. So a
 * box is replaced the only way the engine allows: a new station running
 * the new box, the arrows moved onto it, and the old station left with
 * no arrows — to be removed when whoever asked is sure, or to take the
 * arrows back. Every step is an operation that already existed: place,
 * configure, wire, mark a door, remove.
 *
 * The arrows move one exit at a time, each exit's whole list at once
 * (207), and out before in, so the new station has somewhere to send its
 * first value before any value can reach it. Values already waiting in the
 * old station's ports stay there; a value already in flight towards it is
 * discarded, as any value with nowhere to go is.
 *
 * The program's name for the station follows the arrows: whichever of the
 * two is wired answers program_station, is written out by program_write,
 * and is where the program's doors lead. The other is reachable only
 * through the replacement.
 */
#ifndef SOREN_REPLACE_H
#define SOREN_REPLACE_H

#include <stdint.h>
#include "068-programs.h"

#define REPLACE_DIFFERENT_SHAPE (-40)   /* the new box's widths or port count differ; the report says how */
#define REPLACE_NO_REPLACEMENT  (-41)   /* no such replacement, or it is finished */

/* Replace the station called `name` in `program` with a new one placing
 * the box at `address` (a catalogue address, as a map resolves it:
 * "/boxes/greet.c:greet"). Each of the new box's ports must take exactly
 * as many bytes as the old one's, and its return must be as wide; if not,
 * nothing changes and `report` names both types and both widths. The new
 * station is given the old one's kind, exits, fixed values and doors.
 * Answers the replacement's number (0 or more) or a negative error. The
 * old station stays placed, unwired, until replacement_finish. */
int replace_station(int program, const char *name, const char *address, struct map_report *report);

/* Move the arrows to whichever of the two stations is unwired: once, a
 * rollback to the old box; again, back to the new. Answers 0 or an error. */
int replacement_swap(int replacement);

/* Remove the unwired station and end the replacement (step 4, which a
 * caller such as the editor defers until a person has decided). */
int replacement_finish(int replacement);

/* The station the arrows are on, and the one they are not, or an error. */
int32_t replacement_live(int replacement);
int32_t replacement_spare(int replacement);

/* A program being removed takes the unwired stations of its unfinished
 * replacements with it (068's program_remove calls this). */
void replacements_end_program(int program);

#endif
