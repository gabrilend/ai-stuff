/*
 * 124-transport.c — sending to a peer by name, whatever reaches it
 * (issue 709).
 *
 * General description: see 124-transport.h. A send reads the peer's entry
 * once and walks its links best first. Arriving datagrams come from 118
 * through one C listener for every port taken here, which names the
 * sender from the peer table and passes the message on.
 */
#include <stddef.h>
#include <stdint.h>
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "124-transport.h"

struct binding {
    int      in_use;
    uint16_t port;
    int32_t  station;
    int      in_port;
};

static struct binding bindings[TRANSPORT_PORTS];
static uint64_t       dropped_unknown;
static spin_lock_t    lock = SPIN_LOCK_INIT;

/* {{{ route */
/* The best link to `e` now: the cable before the radio, alive before
 * stale; a link of ours with no address does not count. -1 if none. */
static int route(const struct peer_entry *e)
{
    static const int order[2] = { LINK_CABLE, LINK_RADIO };
    for (int want = PEER_ALIVE; want >= PEER_STALE; want--) {
        for (int i = 0; i < 2; i++) {
            int l = order[i];
            if (e->link[l].state == want && net_address(l) != 0) {
                return l;
            }
        }
    }
    return -1;
}

int transport_route(const char *peer)
{
    struct peer_entry e;
    if (!peers_lookup(peer, &e)) {
        return TRANSPORT_NO_PEER;
    }
    int l = route(&e);
    return l < 0 ? TRANSPORT_UNREACHABLE : l;
}
/* }}} */

/* {{{ transport_send */
int transport_send(const char *peer, uint16_t port, const void *bytes, size_t length)
{
    struct peer_entry e;
    if (length > NET_PAYLOAD_MAX) {
        return NET_TOO_BIG;
    }
    if (!peers_lookup(peer, &e)) {
        return TRANSPORT_NO_PEER;
    }
    int l = route(&e);
    if (l < 0) {
        return TRANSPORT_UNREACHABLE;
    }
    int r = net_udp_send_to(l, e.link[l].address, e.link[l].ip, port, port, bytes, length);
    return r == NET_OK ? l : r;
}
/* }}} */

/* {{{ arrived */
static void arrived(const struct net_datagram *d, uint64_t now_ns)
{
    (void)now_ns;
    struct binding b = { 0, 0, -1, 0 };
    spin_lock(&lock);
    for (int i = 0; i < TRANSPORT_PORTS; i++) {
        if (bindings[i].in_use && bindings[i].port == d->to_port) {
            b = bindings[i];
            break;
        }
    }
    spin_unlock(&lock);
    if (!b.in_use) {
        return;
    }
    /* Who sent it: the peer heard on this link from this hardware
     * address. */
    struct peer_entry list[PEER_MAX];
    int n = peers_list(list, PEER_MAX);
    const char *from = 0;
    for (int i = 0; i < n && i < PEER_MAX && !from; i++) {
        const struct peer_link *l = &list[i].link[d->link];
        if (l->heard && bytes_equal(l->address, d->from_address, LINK_ADDRESS_BYTES)) {
            from = list[i].name;
        }
    }
    if (!from) {
        spin_lock(&lock);
        dropped_unknown++;
        spin_unlock(&lock);
        return;
    }
    struct transport_message m;
    bytes_zero(&m, sizeof m - NET_PAYLOAD_MAX);
    for (int i = 0; i < PEER_NAME_BYTES - 1 && from[i]; i++) m.from[i] = from[i];
    m.port = d->to_port;
    m.link = d->link;
    m.length = d->length;
    bytes_copy(m.bytes, d->bytes, NET_PAYLOAD_MAX);
    engine_deliver(b.station, b.in_port, &m, sizeof m);
}
/* }}} */

/* {{{ transport_listen */
int transport_listen(uint16_t port, int32_t station, int in_port)
{
    int answer = NET_FULL;
    spin_lock(&lock);
    for (int i = 0; i < TRANSPORT_PORTS; i++) {
        if (bindings[i].in_use && bindings[i].port == port) {
            spin_unlock(&lock);
            return NET_TAKEN;
        }
    }
    int at = -1;
    for (int i = 0; i < TRANSPORT_PORTS && at < 0; i++) {
        if (!bindings[i].in_use) at = i;
    }
    spin_unlock(&lock);
    if (at < 0) {
        return NET_FULL;
    }
    answer = net_listen_fn(port, arrived);
    if (answer != NET_OK) {
        return answer;
    }
    spin_lock(&lock);
    bindings[at].in_use = 1;
    bindings[at].port = port;
    bindings[at].station = station;
    bindings[at].in_port = in_port;
    spin_unlock(&lock);
    return NET_OK;
}

int transport_unlisten(uint16_t port)
{
    spin_lock(&lock);
    for (int i = 0; i < TRANSPORT_PORTS; i++) {
        if (bindings[i].in_use && bindings[i].port == port) bindings[i].in_use = 0;
    }
    spin_unlock(&lock);
    return net_unlisten(port);
}

uint64_t transport_dropped_unknown(void)
{
    spin_lock(&lock);
    uint64_t n = dropped_unknown;
    spin_unlock(&lock);
    return n;
}
/* }}} */
