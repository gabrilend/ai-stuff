/*
 * 124-transport.h — sending to a peer by name, whatever reaches it
 * (issue 709).
 *
 * General description: above this, nothing names the radio, the cable or
 * an address. An app sends bytes to a peer's port by the peer's friendly
 * name (705's table), and hears what arrives on its own ports with the
 * sender's name beside it. Underneath, each send picks the best link that
 * reaches the peer now: the cable before the radio, alive before stale.
 * When the cable is pulled and its link ages out, the next send goes by
 * radio, and the app is not told.
 *
 * Over the STAND-IN LINK on the twin (115-link.h), and nothing on the
 * device until the radio (701, 702) and the cable (706) are up.
 */
#ifndef SOREN_TRANSPORT_H
#define SOREN_TRANSPORT_H

#include <stddef.h>
#include <stdint.h>
#include "118-net.h"
#include "121-peers.h"

#define TRANSPORT_PORTS 8

/* Answers, beside a link number (0 radio, 1 cable). NET_TOO_BIG and
 * NET_FULL from 118 also come back as they are. */
#define TRANSPORT_NO_PEER     (-20)   /* no peer of that name was ever heard */
#define TRANSPORT_UNREACHABLE (-21)   /* it was, but no link reaches it now */

/* What a listening station's port receives: one message from a peer. A
 * box that listens takes a value type of exactly this layout:
 * `struct message` in src/boxes/125-transport.c. */
struct transport_message {
    char     from[PEER_NAME_BYTES];
    int32_t  port;
    int32_t  link;                  /* which link it came by; apps need not look */
    int32_t  length;
    int32_t  unused;
    uint8_t  bytes[NET_PAYLOAD_MAX];
};

/* Send `length` bytes to `peer`'s `port`, from the same port of ours.
 * Answers the link it went by, or a negative answer. Nothing is queued or
 * acknowledged here: rmail (710) does that above. */
int transport_send(const char *peer, uint16_t port, const void *bytes, size_t length);

/* Which link a send to `peer` would go by now, without sending: a link
 * number, TRANSPORT_NO_PEER or TRANSPORT_UNREACHABLE. */
int transport_route(const char *peer);

/* Deliver every message from a known peer arriving on `port`, on any
 * link, into a station's port, as a struct transport_message. One
 * station per port. A datagram from a device the peer table does not
 * know is dropped and counted: it has no name to give. */
int transport_listen(uint16_t port, int32_t station, int in_port);
int transport_unlisten(uint16_t port);

uint64_t transport_dropped_unknown(void);

#endif
