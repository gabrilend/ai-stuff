/*
 * 031-engine-internal.h — the engine's own records, shared between its
 * files and nobody else.
 *
 * General description: this is the shape of everything the engine keeps —
 * a core's context, a station, a port and its cells, an exit's list of
 * destinations, a task — with a sentence on each field saying why it is
 * there. The public header (031-engine.h) is what callers see; this is
 * what the engine's own files (032–040) agree on between themselves.
 */
#ifndef SOREN_ENGINE_INTERNAL_H
#define SOREN_ENGINE_INTERNAL_H

#include "025-platform.h"
#include "027-primitives.h"
#include "028-page-stripes.h"
#include "029-blocks.h"
#include "030-task-ring.h"
#include "031-engine.h"

/* {{{ sizes */
#define STATIONS_PER_SHELF 64          /* a power of two: index → shelf is a shift, slot is a mask */
#define SHELF_SHIFT 6
#define MAX_SHELVES 2048               /* 131,072 places. The shelf-address array is fixed at this size, */
                                       /* so it never moves either; see 033-stations.c */
#define PORT_MAX_PAGES 4096            /* a port that needs more than this many pages of waiting values */
                                       /* (about a million 8-byte values) is a program falling hopelessly */
                                       /* behind; the next value is refused, loudly */
#define PORT_FIRST_SLOTS 8             /* a port's list of page addresses starts this long and doubles */
#define CELL_HEADER 8                  /* the cell's state word, padded so the value is 8-byte aligned */
#define PORT_PAGE_BYTES 4032           /* one page less the block header: one port page is one real page */
#define MIN_CELLS_PER_PAGE 4
#define MAX_VALUE_BYTES 65536          /* the largest single value a port will carry; bigger things travel as a pointer */
#define MAX_TASK_BYTES (256 * 1024)    /* the largest task (all inputs + the return) — refused at placement */
#define MAX_TIMERS 64
#define TIMER_VALUE_BYTES 64
#define OWNER_COUNT (OWNER_OUTSIDE + 1)
/* }}} */

/* {{{ cells (issue 208) */
/* A cell's state is its lock. Every transition is one compare-and-swap,
 * so two cores can never own one cell.
 *
 *   empty ──writer takes it──→ reserved ──copy done──→ ready
 *     ▲                                                  │
 *     └────reader done──── claimed ←──reader takes it────┘
 */
enum cell_state {
    CELL_EMPTY    = 0,
    CELL_RESERVED = 1,
    CELL_READY    = 2,
    CELL_CLAIMED  = 3,
};
/* }}} */

/* {{{ port (issue 208) */
struct port {
    uint8_t   tag;                     /* enum port_tag: which of ring / static / none is in effect */
    uint8_t   extra;                   /* 1: a routing port (threshold, weights), never passed to the box */
    uint16_t  unused;
    int32_t   elem_size;               /* bytes in one value; from the box's parameter type */
    int32_t   stride;                  /* bytes from one cell to the next: header + value, rounded to 8 */
    int32_t   cells_per_page;
    int32_t   page_bytes;              /* bytes in one of this port's pages */
    int32_t   n_pages;                 /* grows only; published with release after the page is built */
    int32_t   bookmark;                /* writers' hint: where to start looking for an empty cell. May be wrong */
    int32_t   read_mark;               /* readers' hint: where to start looking for a ready cell. Two hints, */
                                       /* not one, so writers and readers do not drag one number back and forth */
    uint8_t **pages;                   /* where the cells live: a list of page addresses. The pages are */
                                       /* never copied; when the list itself fills, a list twice as long */
                                       /* is built, published, and the old one retired to the scrapyard */
    int32_t   page_slots;              /* how many addresses the current list has room for */
    uint32_t  static_seq;              /* odd while a static is being written: readers retry */
    uint8_t  *static_value;            /* the dial's setting, elem_size bytes */
    uint64_t  growths;                 /* pages added after the first — a port fed faster than its siblings */
    uint64_t  parked_checksum;         /* issue 213: what the released pages held */
    int32_t   parked_ready;            /* issue 213: how many values were waiting when it parked */
    uint8_t   parked_tag;              /* issue 213: the source to give back on restart */
};
/* }}} */

/* {{{ exit and destinations (issue 207) */
/* An exit's destinations are one immutable list; the exit holds its
 * address. Rewiring builds a whole new list and swaps the address in one
 * atomic store. A walker reads the address once and walks whatever it
 * got, which nobody will ever modify. */
struct dest_list {
    int32_t count;
    int32_t unused;
    struct destination to[];
};

struct exit {
    struct dest_list *list;            /* NULL: wired to nothing — values leaving here are discarded */
};
/* }}} */

/* {{{ error slot (issue 214) */
enum error_kind {
    ERROR_NONE = 0,
    ERROR_REFUSED,                     /* the box decided it could not proceed */
    ERROR_BAD_WIRING,                  /* a wire named a station or port that does not exist */
    ERROR_WRONG_SIZE,                  /* a value's bytes did not match its port's type */
    ERROR_NO_MEMORY,                   /* an allocation could not be satisfied */
    ERROR_TRAPPED,                     /* the box faulted (debug builds survive this) */
    ERROR_KIND_COUNT
};

/* One fixed slot per station. The same error a million times is one slot
 * with a count of a million. */
struct error_slot {
    uint32_t kind;
    uint32_t unused;
    uint64_t count;                    /* since the slot was last read or reset */
    uint64_t detail;                   /* whatever the kind needs: an index, a size, an address */
    uint64_t first_ns;                 /* when the first of these happened */
};
/* }}} */

/* {{{ station (issue 207) */
enum station_state {
    STATION_FREE      = 0,             /* the place is empty and reclaimed: it may be placed into */
    STATION_LIVE      = 1,
    STATION_REMOVING  = 2,             /* removed; nothing new starts from it; waiting for the sweep */
    STATION_PARKED    = 3,             /* issue 213: its port pages are released; deliveries are discarded */
};

struct station {
    spin_lock_t        lock;           /* growth, rewiring, static writes, changing a source. Never on the delivery path */
    const struct box  *box;            /* what it runs. NULL only for a free place */
    uint8_t            kind;           /* enum station_kind: consulted only when choosing an exit */
    uint8_t            state;          /* enum station_state */
    uint16_t           n_ports;        /* box parameters, plus one for kinds that carry a routing port */
    uint16_t           n_exits;
    uint16_t           n_box_ports;    /* the first n_box_ports ports are the box's parameters */
    struct port       *ports;          /* array of n_ports */
    struct exit       *exits;          /* array of n_exits */
    uint32_t           cursor;         /* iterator and spread tie-break: which exit is next */
    int32_t            pending;        /* readiness checks asked for while one is already running (see 034) */
    int32_t            in_flight;      /* tasks built from this station and not yet finished */
    int32_t            open_ports;     /* ports whose tag is ring or none: 0 means the station is always ready */
    char              *name;           /* copied at placement, kept for messages and for writing programs out */
    struct error_slot  error;
    uint64_t           runs;           /* completed runs */
    uint64_t           discarded;      /* values that arrived while it was removing or parked */
    uint32_t           program;        /* which program placed it (phase 3's loader); 0 = none */
    int32_t            order;          /* comparator: how its return type orders (303); set by phase 3 */
};
/* }}} */

/* {{{ task (issue 210) */
/* One run of one station. One allocation, exactly sized: header, then the
 * input area (the box's packed parameters, copied at claim time), then the
 * return value. The values are copies, so once built a task depends on
 * nothing another core can change. */
struct task {
    const struct box *box;
    int32_t  station;
    int32_t  exit;                     /* chosen at claim time for iterators; -1 = choose on the way out */
    uint32_t in_bytes;
    uint32_t out_bytes;
    uint8_t *out;                      /* points into this same allocation */
    uint64_t pad;                      /* keeps `in` on a 16-byte boundary */
    uint8_t  in[];
};
/* }}} */

/* {{{ a core's context (issue 205) */
/* One per core plus one for the outside owner, each on its own cache
 * lines so bumping one core's counters never takes a line from another. */
struct core_ctx {
    int32_t   number;                  /* which core, or OWNER_OUTSIDE */
    int32_t   inside;                  /* which station this core is running now; -1 between tasks */
    uint64_t  epoch;                   /* odd while inside a task or an engine call; even otherwise (207) */
    int32_t   depth;                   /* engine calls nested inside each other on this core */
    int32_t   in_task;                 /* 1 while running a task's box and delivering its value */
    int32_t   asleep;                  /* 1 while parked (206) */
    int32_t   refused;                 /* set by engine_refuse during a box call */
    uint64_t  refused_detail;
    uint64_t  random;                  /* this core's own random stream (xorshift), seeded once from the platform */
    struct engine_core_stats stats;
} LINE_ALIGNED;
/* }}} */

/* {{{ the engine's one global record */
struct timer {
    int32_t  active;
    int32_t  station;
    int32_t  port;
    int32_t  size;
    uint64_t due_ns;
    uint64_t period_ns;
    uint64_t missed;
    uint8_t  value[TIMER_VALUE_BYTES];
};

struct engine {
    int              cores;
    int              gate_open;
    int              shutting_down;
    int32_t          asleep_count;     /* cores parked right now */
    struct task_ring ring;
    spin_lock_t      table_lock;       /* placement and the free-place list; rare */
    int32_t          count;            /* places ever made; grows only, published after the place is built */
    struct station  *shelves[MAX_SHELVES];
    int32_t         *free_places;      /* reclaimed places, reused before the table grows */
    int32_t          n_free_places;
    int32_t          free_capacity;
    spin_lock_t      outside_lock;     /* callers that are not a core take turns as the outside owner */
    spin_lock_t      timer_lock;
    uint64_t         next_deadline;    /* earliest active timer, or all ones */
    struct timer     timers[MAX_TIMERS];
    uint64_t         port_growths;
    struct core_ctx  ctx[OWNER_COUNT];
};

extern struct engine engine;
/* }}} */

/* {{{ engine-internal calls, by the file that defines them */
/* 032-workers.c */
struct core_ctx *engine_enter(void);
void             engine_leave(struct core_ctx *c);
struct core_ctx *engine_here(void);
void             engine_fire_due_timers(struct core_ctx *c);
void             engine_wake_sleepers(void);

/* 033-stations.c */
struct station  *station_at(int32_t index);
struct station  *station_live(int32_t index);        /* NULL unless placed and live */
void             scrap_retire(struct core_ctx *c, void (*release)(struct core_ctx *c, void *thing, int64_t arg),
                              void *thing, int64_t arg);
void             scrap_sweep(struct core_ctx *c);
uint64_t         scrap_waiting(void);
uint64_t         scrap_freed(void);
void             scrap_release_block(struct core_ctx *c, void *thing, int64_t arg);

/* 034-ports.c */
int              port_init(struct core_ctx *c, struct port *p, int32_t elem_size);
void             port_release(struct core_ctx *c, struct port *p);
int              port_write_cell(struct core_ctx *c, struct station *s, struct port *p, const void *value);
void             port_write_static(struct station *s, struct port *p, const void *value);
void             port_read_static(const struct port *p, void *out);
int              port_waiting(const struct port *p);
void             station_check(struct core_ctx *c, int32_t index);
void             station_recount_open(struct station *s);

/* 035-tasks.c */
struct task     *task_build(struct core_ctx *c, struct station *s, int32_t index, void **claimed_cells);
void             task_free(struct core_ctx *c, struct task *t);
size_t           task_bytes(const struct box *box);

/* 036-delivery.c */
void             deliver_task(struct core_ctx *c, struct task *t);
int              deliver_value(struct core_ctx *c, int32_t station, int32_t port, const void *value, size_t size);
int32_t          choose_exit(struct core_ctx *c, struct station *s, struct task *t);
int32_t          choose_exit_at_claim(struct station *s);

/* 036-delivery.c: how a comparator's return type orders (issue 303) */
enum ordering {
    ORDER_NONE = 0,                    /* the type has no ordering: a comparator over it is refused */
    ORDER_SIGNED,                      /* two's-complement integer of the box's return width */
    ORDER_UNSIGNED,                    /* unsigned integer of the box's return width */
    ORDER_COUNT
};
uint64_t         core_random(struct core_ctx *c);

/* 040-errors.c */
void             error_record(struct station *s, int32_t index, int kind, uint64_t detail);
void             error_take_out_of_service(struct core_ctx *c, struct station *s, int32_t index);
/* }}} */

#endif
