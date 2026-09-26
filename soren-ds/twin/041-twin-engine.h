/*
 * 041-twin-engine.h — running the engine inside an ordinary laptop program.
 *
 * General description: on the handheld the cores run the engine forever
 * and nothing is "the main program". On the laptop a test or a demo needs
 * a thread of its own that builds programs, waits for them to settle,
 * reads their results and finally stops everything. These calls start the
 * engine's cores in the background, leaving the calling thread free to act
 * as the "outside" — the same role the boot code plays on the device
 * before the gate opens.
 */
#ifndef SOREN_TWIN_ENGINE_H
#define SOREN_TWIN_ENGINE_H

#include <stddef.h>
#include <stdint.h>

/* Set up the platform (cores, pool bytes) and the engine, and start the
 * cores in the background. They wait at the gate until
 * engine_open_gate(). */
void twin_engine_start(int cores, size_t pool_bytes);

/* Wait until the engine has been idle (every core asleep, the ring empty)
 * for two looks in a row a short moment apart. Answers 1 if it settled,
 * 0 if `timeout_ms` passed first. */
int  twin_engine_settle(int timeout_ms);

/* Ask the cores to leave their loops and wait for them to do so. */
void twin_engine_stop(void);

/* Milliseconds since the twin started, for reports. */
double twin_ms(void);

#endif
