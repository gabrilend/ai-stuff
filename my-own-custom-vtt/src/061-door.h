/*
 * 061-door.h -- one port that is always open, and a range it hands out.
 *
 * There is one number a participant has to be told in advance: the door. They
 * connect to it, say who they are, and are given a port of their own. The door
 * then closes the conversation -- IT IS A RECEPTIONIST, NOT A ROOM.
 *
 * WHAT ONE PORT PER PARTICIPANT BUYS
 *
 * Bytes arriving on a port belong to whoever that port was bound for. The kernel
 * decided that before any of our code ran, so there is no session lookup in the
 * receive path and therefore no bug possible in one. And the per-viewer outbound
 * filter binds to a socket once rather than being passed as a parameter on every
 * message -- which removes the most plausible way a secret could leak, a
 * misthreaded "who is this for".
 *
 * WHAT IT COSTS, AND THE COST IS REAL
 *
 * A host behind a home router forwards a RANGE, not a port. That is a longer
 * conversation with a router's web interface, and faith/boons-expected records
 * the expectation that it will be what stops somebody joining on the first
 * evening a real table tries this.
 *
 * See docs/003-the-door-and-the-private-port.md and issues/401.
 */

#ifndef VTT_DOOR_H
#define VTT_DOOR_H

#include <stdint.h>

#include "058-viewer.h"
#include "027-world.h"

/* A connection that does not begin with this is not our protocol. */
#define JOIN_MAGIC   0x564A4F4Eu   /* "VJON" */
#define JOIN_VERSION 1u

/* The longest name a participant may present. Refused past this, never cut. */
#define JOIN_NAME_MAX 63

/* What the door says back. */
#define JOIN_ACCEPTED           0u
#define JOIN_NOT_OUR_PROTOCOL   1u
#define JOIN_WRONG_VERSION      2u
#define JOIN_NAME_TOO_LONG      3u
#define JOIN_RANGE_FULL         4u
#define JOIN_NO_ROOM            5u
#define JOIN_NO_ANSWER          6u   /* Nothing there, or it never replied. */

struct door {
    int      socket;          /* The always-open port. -1 when closed. */
    uint16_t port;

    uint16_t range_first;
    uint16_t range_last;

    /* One bit per port in the range: taken or free. */
    uint8_t *taken;
    uint32_t taken_bytes;

    /* What a demo reports. */
    uint32_t joins_accepted;
    uint32_t joins_refused;
};

/*
 * Open the door and reserve the range. Returns 1 on success, 0 with the reason
 * written through `why` -- which is a sentence, because a host who cannot start
 * the server needs to know which number to change.
 */
int door_open(struct door *d, uint16_t port,
              uint16_t range_first, uint16_t range_last,
              const char **why);

void door_close(struct door *d);

/*
 * Accept whatever is waiting at the door, without blocking. Each accepted join
 * claims a port, binds a listening socket to it, and puts a viewer in the
 * WAITING state.
 *
 * Returns how many joined.
 */
uint32_t door_admit(struct door *d, struct viewer_set *set,
                    const struct world *w, wcoord fog_cell);

/*
 * Accept the connections that waiting viewers make to their private ports, and
 * check each came from the address the join came from.
 * Returns how many connected.
 */
uint32_t door_connect_waiting(struct door *d, struct viewer_set *set);

/*
 * Read from every connected viewer into their inbound buffer, bounded per viewer
 * per beat. Marks departures.
 * Returns how many bytes were read in total.
 */
uint32_t door_drain(struct door *d, struct viewer_set *set);

/* Write every connected viewer's outbound buffer to their socket. */
uint32_t door_flush(struct door *d, struct viewer_set *set);

/* A join outcome as a sentence. Never a number, and never silence. */
const char *join_sentence(uint8_t outcome);

/* How many ports in the range are in use. */
uint32_t door_ports_in_use(const struct door *d);

/*
 * A test client, so the phase demo can run several participants in one process.
 * A demo that needs three terminals is a demo nobody runs.
 *
 * Returns the connected socket, or -1, with the outcome written through
 * `outcome` and the port through `port`.
 */
int door_join_as_client(uint16_t door_port, const char *name,
                        uint8_t *outcome, uint16_t *port);

#endif
