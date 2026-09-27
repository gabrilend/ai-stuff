/*
 * 038-tallies.h — counters that sink boxes write to, the way a box writes
 * to a screen.
 *
 * General description: a box may not remember anything between calls, so
 * a sink that counts what it received writes its count somewhere outside
 * itself: a table of tallies indexed by the station that wrote them. Tests
 * and demos read the tallies to check a program's arithmetic exactly.
 * Stations numbered 4096 and up share tallies modulo 4096.
 */
#ifndef SOREN_TALLIES_H
#define SOREN_TALLIES_H

#include <stdint.h>

void tally_add(int32_t station, int64_t value);
void tally_refusal(int32_t station, int64_t value);

/* How many values reached a station's tally, and their sum. */
void tally_read(int32_t station, uint64_t *count, int64_t *sum);
/* How many values a station turned away, and their sum. */
void tally_refusals(int32_t station, uint64_t *count, int64_t *sum);
void tally_reset(void);

#endif
