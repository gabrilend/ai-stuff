/*
 * 068-programs.h — loading a map into a running program, and everything a
 * program is once it is running (issues 306, 307, 309).
 *
 * General description: the loader is a caller, not a mechanism. It reads a
 * map (066), checks everything that can be checked — every box exists,
 * every port and exit number is real, both ends of every wire agree, every
 * wire joins two things of the same width, every fixed value reads — and
 * collects every problem before reporting any. Only if there are none does
 * it build, through the engine's own place, wire and configure, in that
 * order: create everything, connect everything, then write the fixed
 * values, and writing those is what starts it (there is no other start).
 *
 * A file with problems places nothing at all. (Proposed answer to issue
 * 307's open question, UNVERIFIED: a partial program is a program nobody
 * asked for, and the list of problems is what the person needs.)
 *
 * A program is the record of which stations one load placed: their names
 * (scoped to the program, so two programs may each have a station called
 * `speak`), their doors (the ports marked as its arguments and the exits
 * marked as its results), and the programs placed inside it. That one
 * record answers three places that asked "which stations belong
 * together?" — parking (213), name scoping (306) and composition (309).
 *
 * A map is a box: a station line whose address is a .map file places that
 * program inside this one, and this one wires to its doors by number
 * exactly as it would wire to a box's ports.
 */
#ifndef SOREN_PROGRAMS_H
#define SOREN_PROGRAMS_H

#include <stdint.h>
#include <stddef.h>
#include "066-map-read.h"

#define PROGRAM_MAX 64
#define PROGRAM_DOORS 16

/* A report: problems (refusals) or findings (the unfinished-work list),
 * each one a line, collected in file order. */
struct map_report {
    char text[16384];
    int  problems;
};

/* Where map files come from. The device's default reads the maps compiled
 * into the image (issue 305: before phase 4 there is no filesystem); the
 * twin also reads them from disk. Answers the text, or NULL. */
typedef const char *(*map_reader_fn)(const char *path, size_t *length, void *ctx);
void program_set_reader(map_reader_fn reader, void *ctx);

/* Load the map at `path` (project-relative: "src/maps/greeting.map").
 * Answers the new program's number, or -1 with the problems in `report`. */
int program_load(const char *path, struct map_report *report);
int program_load_text(const char *path, const char *text, size_t length, struct map_report *report);

/* Say the program is finished: check what can only be checked about a
 * whole program (its argument and result numbering: no gaps, no repeats),
 * and look once at every station that has not been looked at. Repeatable:
 * a station added since the last call is looked at by this one, and none
 * is started twice. Answers the number of problems. */
int program_bring_up(int program, struct map_report *report);

/* Asked for, never volunteered (issue 307): stations with queued inputs
 * nothing feeds, and ports with no source. Findings, not refusals. */
int program_unfinished(int program, struct map_report *report);

/* The outside's two doors. An argument is delivered into the port marked
 * with that number that no wire feeds; a result is taken from the exit
 * marked with that number (1 taken, 0 none waiting, negative an error). */
int program_argument(int program, int door, const void *value, size_t size);
int program_result(int program, int door, void *out, size_t size);
int program_argument_count(int program);
int program_result_count(int program);

/* Stations by the names the map gave them. */
int32_t program_station(int program, const char *name);
int     program_station_count(int program);
int32_t program_station_at(int program, int i);
const char *program_path(int program);
const char *program_name(int program);

/* Programs placed inside this one. */
int program_child_count(int program);
int program_child(int program, int i);

/* Take every station of the program (and its children) out of existence. */
int program_remove(int program);

/* Write the running program back out as a map (069). Answers the length,
 * or -1 if it did not fit. The text reads back into the same program. */
int program_write(int program, char *out, size_t size);

/* Internal to 068/069: the program record. */
struct program_door {
    int32_t station;                 /* -1: no such door */
    int     number;                  /* the port (argument) or exit (result) */
};

struct program_record {
    int                 in_use;
    int                 parent;      /* -1 for a top-level program */
    char                name[MAP_NAME];     /* the station line that placed it, in its parent; "" at top level */
    char                path[MAP_ADDRESS];
    char                home[MAP_ADDRESS];
    int32_t            *stations;
    char              (*names)[MAP_NAME];
    char              (*addresses)[MAP_ADDRESS];
    uint8_t            *looked_at;   /* bring-up has checked this station */
    int                 n_stations;
    int                 capacity;
    int                 children[PROGRAM_MAX];
    int                 n_children;
    struct program_door args[PROGRAM_DOORS];
    struct program_door results[PROGRAM_DOORS];
    int                 owner;       /* whose blocks the arrays came from */
};

struct program_record *program_record(int program);

#endif
