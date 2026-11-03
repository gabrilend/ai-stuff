/*
 * 122-peers.c — peers as boxes see them (issues 704, 705).
 *
 * General description: the peers map's tick, and the value a subscriber
 * receives. A box that wants to hear of peers takes a `struct peer_event`
 * and has its station subscribed (peers_subscribe, 121); `say_peer` is
 * one such box, which says each event on the developer's line.
 */
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../system/121-peers.h"

/* A peer first heard (kind 1), or one link of it changing state (kind 2):
 * the same layout as struct peers_event in 121-peers.h. States are 0 gone,
 * 1 stale, 2 alive. */
struct peer_event {
    int32_t kind;
    int32_t link;
    int32_t from;
    int32_t to;
    char    name[32];
};

/* {{{ peers_frame */
/* Once a second: age the table, and announce every fifth time. The
 * number rides a loop so only one tick runs at once. */
int64_t peers_frame(int64_t tick, int64_t frame)
{
    (void)tick;
    peers_tick(platform_now_ns());
    return frame + 1;
}
/* }}} */

/* {{{ say_peer */
void say_peer(struct peer_event e)
{
    static const char *states[3] = { "gone", "stale", "alive" };
    static const char *links[2] = { "radio", "cable" };
    e.name[31] = 0;
    const char *link = e.link >= 0 && e.link < 2 ? links[e.link] : "?";
    if (e.kind == PEER_DISCOVERED) {
        say_line("peer %s found on the %s", e.name, link);
    } else {
        say_line("peer %s on the %s: %s to %s", e.name, link,
                 e.from >= 0 && e.from < 3 ? states[e.from] : "?", e.to >= 0 && e.to < 3 ? states[e.to] : "?");
    }
}
/* }}} */
