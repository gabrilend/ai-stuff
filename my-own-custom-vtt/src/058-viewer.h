/*
 * 058-viewer.h -- one participant, one port, one socket.
 *
 * THE PORT NUMBER IS THE IDENTITY. Bytes arriving on a port belong to whoever
 * that port was bound for, and the operating system decided that using code
 * which has been correct for thirty years. There is no session-token lookup in
 * the receive path, so there is no bug possible in one.
 *
 * That property is what phase 4's whole security argument leans on, and it is
 * why one port per participant was chosen over one port and many sockets. It is
 * also why a host pays for a forwarded range at their router.
 *
 * WHERE VIEWERS LIVE, AND A CORRECTION TO THE DOCUMENTS
 *
 * docs/004-the-world-and-its-tick.md lists `viewers` among the world's blocks.
 * That is wrong in one respect and right in another, and the split is here:
 *
 *   A viewer's IDENTITY is world state -- a scope names a viewer, and a scope is
 *   part of the world, so the index has to be stable and snapshottable.
 *
 *   A viewer's SOCKET is not. Putting a file descriptor in a snapshot would mean
 *   a rollback restoring a connection, which is nonsense: taking a turn back
 *   does not un-send bytes.
 *
 * So viewers live beside the session rather than inside the world, and the index
 * is what the world will refer to when phase 6 adds scopes.
 *
 * See issues/402-a-session-is-a-socket.md.
 */

#ifndef VTT_VIEWER_H
#define VTT_VIEWER_H

#include <stdint.h>

#include "044-fog.h"
#include "056-protocol.h"

#define VIEWER_EMPTY      0u   /* This slot holds nobody. */
#define VIEWER_WAITING    1u   /* Given a port; has not connected to it yet. */
#define VIEWER_CONNECTED  2u
#define VIEWER_GONE       3u

/*
 * How many bytes one participant may have read from them in a single beat.
 *
 * Without a bound, one participant flooding their socket starves every other
 * viewer's intake for as long as they keep it up -- not by exploiting anything,
 * just by talking a lot.
 */
#define VIEWER_INTAKE_PER_TICK 4096

struct viewer {
    uint8_t  state;

    uint16_t port;       /* Theirs alone. */
    int      socket;     /* -1 when not connected. */
    uint32_t address;    /* Where the join came from. Another address is refused. */

    uint32_t name_offset;  /* Display only. NEVER used to decide permission. */

    struct fog fog;              /* Their memory. One per viewer. */
    struct byte_buffer inbound;
    struct byte_buffer outbound;

    /* What a demo reports. */
    uint64_t bytes_sent;
    uint64_t bytes_received;
    uint32_t refusals;
    uint32_t things_sent;
    uint32_t walls_sent;
};

struct viewer_set {
    struct viewer *viewers;
    uint32_t       count;
    uint32_t       capacity;
};

/*
 * Prepare a set with room for `capacity` participants, index 0 reserved for
 * nobody in keeping with every other block in this project.
 */
int viewer_set_init(struct viewer_set *set, uint32_t capacity);
void viewer_set_release(struct viewer_set *set);

/*
 * Claim a slot for a participant. Returns the index, or 0 if the set is full --
 * which a caller must report by name rather than treat as a viewer it can use.
 */
uint32_t viewer_add(struct viewer_set *set, const struct world *w, wcoord fog_cell);

/* Mark a viewer gone and release what it held that is not memory. */
void viewer_departs(struct viewer_set *set, uint32_t index);

struct viewer       *viewer_at(struct viewer_set *set, uint32_t index);
const struct viewer *viewer_at_const(const struct viewer_set *set, uint32_t index);

uint32_t viewer_count(const struct viewer_set *set);

/* How many are actually connected right now. */
uint32_t viewer_connected_count(const struct viewer_set *set);

#endif
