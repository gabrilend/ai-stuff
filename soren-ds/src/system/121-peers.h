/*
 * 121-peers.h — finding other devices, and remembering them (issues 704
 * and 705).
 *
 * General description: every few seconds the device says "I am here, my
 * name is X" to everyone on each link that has an address (118), and it
 * listens for everyone else saying the same. What it hears goes into the
 * peer table: one entry per friendly name, holding, for each link
 * separately, the hardware address and IP the peer was heard from and
 * when. A peer reachable over both the radio and the cable is one entry
 * with both links filled in.
 *
 * Each link of each entry ages on its own: alive while heard within
 * PEER_ALIVE_NS, stale until PEER_GONE_NS, then gone. A peer's own state
 * is the best of its links'. Entries are never removed while the device
 * runs; a gone peer is still in the table, only not reachable. A device
 * that says it is leaving is gone on that link at once.
 *
 * Whoever wants to know subscribes a station's port, and receives a
 * struct peers_event for every peer first heard and every change of a
 * link's state. Nothing is announced for a peer heard again while alive.
 *
 * The announcement's layout is notes/networking/000-discovery-format.md.
 * The device's name will come from /settings/name (408, waiting in #48);
 * until then it is "soren-" and four hex digits of the radio's hardware
 * address, and peers_set_name changes it.
 */
#ifndef SOREN_PEERS_H
#define SOREN_PEERS_H

#include <stddef.h>
#include <stdint.h>
#include "../engine/068-programs.h"
#include "115-link.h"
#include "118-net.h"

#define PEERS_MAP          "src/maps/peers.map"
#define PEER_PORT          47100                 /* where announcements are sent and heard */
#define PEER_VERSION       1
#define PEER_NAME_BYTES    32                    /* 31 bytes of name and a zero */
#define PEER_MAX           32
#define PEER_SUBSCRIBERS   8
#define PEER_ANNOUNCEMENT_BYTES 56

#define PEER_TICK_NS       1000000000ull         /* aging is looked at once a second */
#define PEER_ANNOUNCE_NS   5000000000ull         /* and the device announces itself every five */
#define PEER_ALIVE_NS      20000000000ull        /* heard within: alive */
#define PEER_GONE_NS       300000000000ull       /* heard within: stale; beyond it, gone */

enum peer_state {
    PEER_GONE  = 0,             /* never heard, past the gone window, or said it was leaving */
    PEER_STALE = 1,             /* heard, but not lately: try, it may not work */
    PEER_ALIVE = 2,
};

enum peer_kind {
    PEER_HERE    = 1,           /* an announcement */
    PEER_LEAVING = 2,           /* the last one, before the radio goes off */
};

/* {{{ the table */
struct peer_link {
    int      heard;                                /* ever, on this link */
    int      state;                                /* an enum peer_state */
    uint8_t  address[LINK_ADDRESS_BYTES];
    uint32_t ip;
    uint64_t last_seen_ns;
    uint32_t sequence;                             /* the last one heard */
    uint32_t missed;                               /* announcements skipped in the sequence */
    int      left;                                 /* its last word was that it was leaving */
};

struct peer_entry {
    char             name[PEER_NAME_BYTES];
    int              state;                        /* the best of its links' */
    struct peer_link link[LINK_COUNT];
};

/* The entry for a name: 1 and a copy in `out`, or 0. */
int peers_lookup(const char *name, struct peer_entry *out);
/* How many peers are alive on any link. */
int peers_alive_count(void);
/* Every entry, up to `max`; answers how many there are. */
int peers_list(struct peer_entry *out, int max);
/* }}} */

/* {{{ events */
enum peer_event_kind {
    PEER_DISCOVERED = 1,        /* a name heard for the first time */
    PEER_CHANGED    = 2,        /* one link of a peer changed state */
};

/* What a subscriber's port receives. A box that subscribes takes a value
 * type of exactly this layout: `struct peer_event` in
 * src/boxes/122-peers.c. */
struct peers_event {
    int32_t kind;               /* an enum peer_event_kind */
    int32_t link;
    int32_t from;               /* states, for PEER_CHANGED */
    int32_t to;
    char    name[PEER_NAME_BYTES];
};

int peers_subscribe(int32_t station, int port);
int peers_unsubscribe(int32_t station, int port);
/* }}} */

/* {{{ running */
/* Start listening for announcements (on PEER_PORT, through 118). Once. */
void peers_init(void);

/* Announce on every link with an address if PEER_ANNOUNCE_NS have passed,
 * and age every entry, as at `now_ns`. */
void peers_tick(uint64_t now_ns);

/* Say "I am leaving" on every link with an address. */
void peers_leave(void);

void        peers_set_name(const char *name);
void        peers_name(char out[PEER_NAME_BYTES]);

struct peers_runner {
    int program;
    int timer;
};
/* Load the peers map and arm its once-a-second tick; stop disarms it. */
int  peers_start(struct peers_runner *r, struct map_report *report);
void peers_stop(struct peers_runner *r);
/* }}} */

/* {{{ the announcement, for tests and for whoever plays another device */
/* Build an announcement into `out` (PEER_ANNOUNCEMENT_BYTES). */
void peers_build_announcement(uint8_t *out, int kind, uint32_t sequence,
                              const uint8_t address[LINK_ADDRESS_BYTES], uint32_t ip, const char *name);

struct peers_counts {
    uint64_t announced, heard, dropped, ours, full, name_moved;
};
struct peers_counts peers_counts(void);
/* }}} */

#endif
