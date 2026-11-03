/*
 * 125-transport.c — peers by name, as boxes see them (issue 709).
 *
 * General description: an app sends with `send_to_peer`, naming the peer,
 * the port and the bytes, and hears with a station of `received` placed in
 * its map and bound to a port (transport_listen, by whoever starts the
 * app). Neither names a link or an address. Over the STAND-IN LINK on the
 * twin; nothing goes anywhere on the device until the radio and cable are
 * up.
 */
#include <stdint.h>
#include "../system/124-transport.h"

/* Bytes for a peer: who, which port, and up to 1472 bytes. */
struct outgoing {
    char     to[32];
    int32_t  port;
    int32_t  length;
    uint8_t  bytes[1472];
};

/* Bytes from a peer: the same layout as struct transport_message in
 * 124-transport.h. */
struct message {
    char     from[32];
    int32_t  port;
    int32_t  link;
    int32_t  length;
    int32_t  unused;
    uint8_t  bytes[1472];
};

/* {{{ send_to_peer */
/* Answers the link it went by (0 radio, 1 cable), or a negative answer:
 * -20 no such peer, -21 nothing reaches it now, -3 too big. */
int64_t send_to_peer(struct outgoing o)
{
    o.to[31] = 0;
    if (o.length < 0 || o.length > 1472) {
        return -3;
    }
    return transport_send(o.to, (uint16_t)o.port, o.bytes, (size_t)o.length);
}
/* }}} */

/* {{{ received */
/* Where a bound port's messages arrive, passed on unchanged to whatever
 * the app wires after it. */
struct message received(struct message m)
{
    return m;
}
/* }}} */
