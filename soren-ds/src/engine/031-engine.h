/*
 * 031-engine.h — everything outside the engine may call (phase 2).
 *
 * General description: a program is a set of *stations* — placements of
 * boxes, which are ordinary C functions — with wires from each station's
 * exits to other stations' input ports. There is one rule: a station runs
 * when, and only when, every one of its input ports holds a value. Every
 * run is a task on a ring the cores share, so a program is concurrent
 * from its first line without anybody asking for threads.
 *
 * Three operations build a program — place, configure, wire — and there
 * is no fourth "start": writing the static values that feed the first
 * stations is what sets it going (issue 212).
 *
 * The words, since they are easy to confuse:
 *   box      the code: a C function, its parameter sizes, its name.
 *   station  one placement of a box: its own ports, exits, and error slot.
 *   port     one input of one station: ring (a stream, consumed one value
 *            per run), static (a dial, read by every run), or none (never
 *            holds a value; the station cannot run).
 *   exit     where one station's output goes: a list of {station, port}.
 *   task     one run of one station, carrying copies of its inputs.
 */
#ifndef SOREN_ENGINE_H
#define SOREN_ENGINE_H

#include <stdint.h>
#include <stddef.h>

/* {{{ boxes */
/* One parameter of a box, in the order the C function takes them. The
 * offset is where the parameter's bytes sit in a task's input area; the
 * generator (phase 3) computes it, and a hand-written box states it. */
struct box_param {
    const char *name;
    const char *type;      /* the C type as written, for people and for the width check */
    uint32_t    size;      /* sizeof the type */
    uint32_t    offset;    /* byte offset in the packed input area; 8-byte aligned */
};

/* A box: what a station runs. `call` is a small adapter that unpacks the
 * input area into the real function's arguments and stores its return
 * value — written by hand in phase 2, emitted by the generator from
 * phase 3 on, and the only part of a box the engine ever calls. */
struct box {
    const char             *name;
    const char             *source;       /* the file its function lives in */
    void                  (*call)(const void *in, void *out);
    uint16_t                n_params;
    const struct box_param *params;
    uint32_t                in_bytes;     /* the packed input area's size */
    uint32_t                return_size;  /* 0: returns nothing — a sink */
    const char             *return_type;
};
/* }}} */

/* {{{ words the engine uses */
enum port_tag {
    PORT_RING   = 0,       /* a stream: one value consumed per run; holds up readiness */
    PORT_STATIC = 1,       /* a dial: every run reads the same value; always full */
    PORT_NONE   = 2,       /* no source: can never hold up its end; the station never runs */
    PORT_TAG_COUNT
};

/* How a station picks which exit a returned value leaves by. Phase 2
 * builds only the plain kind; phase 3 (issue 308) fills in the rest as
 * rows of one table, which is why the numbers exist now. A kind is
 * consulted at exactly one moment — choosing an exit on the way out. */
enum station_kind {
    KIND_PLAIN = 0,        /* 1 exit: everything goes out of it */
    KIND_COMPARATOR,       /* 3 exits: below, equal, above a threshold held in an extra static port */
    KIND_ITERATOR,         /* N exits taken in turn; the exit is chosen at claim time and rides in the task */
    KIND_RANDOM,           /* N exits; a random number picks one */
    KIND_WEIGHTED,         /* N exits; a random number against weights held in an extra static port */
    KIND_SPREAD,           /* N exits; whichever destination has fewest values waiting */
    KIND_COUNT
};

/* The comparator and weighted kinds carry one more port than their box
 * has parameters: the threshold, or the weights. It sits after the box's
 * own ports, is only ever static, and is never handed to the box. */
int engine_kind_extra_ports(int kind);

struct destination {
    int32_t station;
    int32_t port;
};

/* Errors every operation answers with. Negative so a station index (zero
 * or more) and an error can share a return value. */
enum engine_error {
    ENGINE_OK            = 0,
    ENGINE_NO_BOX        = -1,   /* placing nothing, or a box with no call */
    ENGINE_NO_STATION    = -2,   /* the index names no station */
    ENGINE_NO_PORT       = -3,   /* the port index is past the station's last port */
    ENGINE_NO_EXIT       = -4,   /* the exit index is past the station's last exit */
    ENGINE_WRONG_SIZE    = -5,   /* a value's size differs from the port's */
    ENGINE_NO_MEMORY     = -6,
    ENGINE_PLACE_BUSY    = -7,   /* placing into a place removed but not yet reclaimed */
    ENGINE_TOO_BIG       = -8,   /* a box whose task would exceed the largest size the engine allows */
    ENGINE_STOPPED       = -9,   /* the station is parked or being removed */
    ENGINE_FULL          = -10,  /* a fixed table (timers, stations) has no room */
    ENGINE_UNORDERED     = -11,  /* a comparator over a return type that has no ordering */
    ENGINE_BAD_KIND      = -12,  /* an unknown kind, or an exit count the kind cannot have */
    ENGINE_BAD_TAG       = -13,  /* an unknown port tag, or a routing port given a non-static source */
};

const char *engine_error_text(int error);
/* }}} */

/* {{{ bringing the engine up */
/* Set up memory, the task ring and the station table for `cores` cores.
 * Called once, on one core or the twin's main thread, before any core is
 * started. */
void engine_init(int cores);

/* What every core runs, from platform_start_cores: per-core setup, wait
 * at the starting gate, then the run loop forever (on the twin: until
 * engine_shutdown). */
void engine_core_main(int core);

/* Open the starting gate. Nothing runs before this. Programs may be built
 * before it (they begin at the gate) or after it (they begin at once). */
void engine_open_gate(void);

/* Twin only in practice: ask every core to leave its run loop after the
 * task it is running. A device never ends. */
void engine_shutdown(void);

/* Every core asleep, the ring empty, no timer due and nobody building:
 * nothing will happen until something outside acts. On the device this is
 * "the user has not pressed anything yet", never "finished"; the twin's
 * tests use it to know when a program has settled. */
int  engine_is_idle(void);
/* }}} */

/* {{{ building a program (issue 212) */
/* Make a station running `box`. `name` is copied and kept, so an error
 * message and a written-out program can say which station they mean.
 * `n_exits` is how many exits the kind needs (1 for plain). Answers the
 * new station's index, or a negative error. Every port starts as NONE. */
int32_t engine_place(const struct box *box, const char *name, int kind, int n_exits);

/* The same, into one particular place — which must be free and fully
 * reclaimed. Refused loudly otherwise (issue 207, step 8). */
int32_t engine_place_at(int32_t index, const struct box *box, const char *name, int kind, int n_exits);

/* Give a port a source. For PORT_STATIC, `value` is the port's size in
 * bytes and becomes the dial's setting; writing a static runs the
 * readiness check, so this is also how a program is started. */
int engine_configure(int32_t station, int port, int tag, const void *value, size_t size);

/* Replace one exit's destinations with this whole list, at once (issue
 * 207: arrows are drawn in batches so every destination starts from the
 * same instant). An empty list unwires the exit. */
int engine_wire(int32_t station, int exit, const struct destination *to, int count);

/* Push one value into a port from outside any box, exactly as a wire
 * would: into a cell for a ring port, over the dial for a static one. */
int engine_deliver(int32_t station, int port, const void *value, size_t size);

/* Take a station out of existence and give its place back (issue 207). */
int engine_remove(int32_t station);

/* Free whatever retired things no core can still be inside. The engine
 * does this itself on every rewire and removal; this is for a caller that
 * wants a removed place back sooner. */
void engine_sweep(void);

/* Station facts, for tools that write programs back out. */
int32_t            engine_station_count(void);
const struct box  *engine_station_box(int32_t station);
const char        *engine_station_name(int32_t station);
int                engine_station_kind(int32_t station);
int                engine_port_tag(int32_t station, int port);
int                engine_exit_count(int32_t station);
/* Copy up to `max` of an exit's current destinations; answers how many
 * the exit has. */
int                engine_exit_destinations(int32_t station, int exit, struct destination *out, int max);
/* Copy a static port's current setting; answers its size or an error. */
int                engine_static_value(int32_t station, int port, void *out, size_t max);
/* Values waiting in a port right now. */
int                engine_port_waiting(int32_t station, int port);
uint64_t           engine_station_runs(int32_t station);
/* }}} */

/* {{{ time (issue 206) */
/* Deliver `value` into a port at `first_ns` on the platform clock, and
 * then every `period_ns` after (0: once). This is how "something is
 * scheduled to arrive" is known when every core is idle — the 60 Hz input
 * frame of phase 5 is one of these. Answers a timer number or an error. */
int engine_timer(int32_t station, int port, const void *value, size_t size,
                 uint64_t first_ns, uint64_t period_ns);
int engine_timer_cancel(int timer);
uint64_t engine_timer_missed(int timer);   /* periods skipped because nobody fired it in time */
/* }}} */

/* {{{ what a box may call while it runs */
/* "Not this value." The box's return is thrown away, the refusal is
 * recorded in the station's error slot, and the station takes itself out
 * of service by setting its inputs to none (issue 214). */
void engine_refuse(uint64_t detail);

/* Which station is running on this core right now, or -1. */
int32_t engine_current_station(void);
/* }}} */

/* {{{ asked to stop, and parking (issue 213) */
/* Programs here end because they were asked to — never because work ran
 * out. Stopping a program is three steps, because a box must never wait
 * and the caller is often a box (the compositor, when an app leaves the
 * screen):
 *
 *   begin    every input of every listed station is set to no source, so
 *            nothing new can start; values already moving keep moving.
 *   step     asked again later (the next frame, say) until it answers
 *            PARK_PARKED: in-flight runs have finished, every core has
 *            been seen between tasks, and the stations' waiting values
 *            have been checksummed and their pages given back to the
 *            allocator — released, but remembered.
 *   restart  take the pages back if nobody was handed them meanwhile and
 *            the checksum still matches (resumed, values intact), or
 *            start the stations empty and say so out loud (rebuilt).
 *
 * Which stations make up "a program" is the caller's list: there is no
 * program object in the engine (issue 213's first open question). */
enum park_state {
    PARK_DRAINING = 1,     /* runs of these stations are still in flight */
    PARK_QUIETING = 2,     /* waiting for every core to be seen between tasks */
    PARK_PARKED   = 3,     /* pages released; costs no core and no cycle */
};
enum restart_result {
    RESTART_RESUMED = 1,
    RESTART_REBUILT = 2,
};
int engine_park_begin(const int32_t *stations, int count);
int engine_park_step(int handle);
int engine_restart(int handle, int *values_lost);
/* }}} */

/* {{{ errors (issue 214) */
/* A station's one error slot, as read. The same error a million times is
 * one slot with a count of a million. */
struct engine_error_report {
    int      kind;         /* 0 none, 1 refused, 2 bad wiring, 3 wrong size, 4 no memory, 5 trapped */
    uint64_t count;        /* how many since the slot was last cleared */
    uint64_t detail;       /* whatever the kind needs: a bad index, a size, an address */
    uint64_t first_ns;     /* when the first of them happened, on the platform clock */
};
/* Copy a station's slot; with `clear`, reading also resets it, so the
 * reader owns the number from then on. */
int         engine_read_error(int32_t station, struct engine_error_report *out, int clear);
const char *engine_error_kind_text(int kind);
/* Values that arrived at a station while it was parked or being removed. */
uint64_t    engine_station_discarded(int32_t station);
/* }}} */

/* {{{ counters (for the endurance demo and the metrics pages) */
struct engine_core_stats {
    uint64_t ran;              /* tasks this core completed */
    uint64_t sleeps;           /* times it parked for lack of work */
    uint64_t deliveries;       /* values it wrote into ports */
    uint64_t checks;           /* readiness checks it ran */
    uint64_t checks_merged;    /* checks it handed to a core already checking that station */
    uint64_t tasks_built;      /* tasks it built and pushed */
    uint64_t discarded;        /* values it had nowhere to put */
    uint64_t timer_fires;      /* timers it fired */
};
void engine_core_stats(int core, struct engine_core_stats *out);

struct engine_totals {
    int      cores;
    int32_t  stations;         /* places in the table, including free ones */
    int32_t  live_stations;
    int      ring_count, ring_capacity, ring_high_water, ring_growths;
    uint64_t ring_pushed;
    uint64_t port_growths;     /* pages added to ports, all stations */
    uint64_t scrap_waiting;    /* retired things not yet freed */
    uint64_t scrap_freed;
    size_t   pages_total, pages_free;
};
void engine_totals(struct engine_totals *out);
/* }}} */

#endif
