/*
 * 121-peers.c — finding other devices, and remembering them (issues 704
 * and 705).
 *
 * General description: see 121-peers.h. One lock over the table, the
 * subscribers and the device's own name; events are gathered under it
 * and delivered after it is let go, so a subscriber may look things up.
 */
#include <stddef.h>
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "121-peers.h"

#define MAX_EVENTS (PEER_MAX * LINK_COUNT)

static const uint8_t magic[4] = { 'S', 'D', 'S', 'P' };

struct subscriber {
    int     in_use;
    int32_t station;
    int     port;
};

static struct peer_entry   table[PEER_MAX];
static int                 n_peers;
static struct subscriber   subscribers[PEER_SUBSCRIBERS];
static struct peers_counts counts;
static char                own_name[PEER_NAME_BYTES];
static int                 own_name_set;
static uint32_t            sequence;
static uint64_t            last_announce_ns;
static int                 announced_once;
static int                 initialised;
static spin_lock_t         lock = SPIN_LOCK_INIT;

/* {{{ bytes */
static uint32_t get32(const uint8_t *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }

static void name_copy(char *to, const char *from)
{
    int i = 0;
    for (; i < PEER_NAME_BYTES - 1 && from[i]; i++) to[i] = from[i];
    for (; i < PEER_NAME_BYTES; i++) to[i] = 0;
}
/* }}} */

/* {{{ peers_build_announcement */
void peers_build_announcement(uint8_t *out, int kind, uint32_t seq,
                              const uint8_t address[LINK_ADDRESS_BYTES], uint32_t ip, const char *name)
{
    bytes_zero(out, PEER_ANNOUNCEMENT_BYTES);
    bytes_copy(out, magic, 4);
    out[4] = PEER_VERSION;
    out[5] = (uint8_t)kind;
    put32(out + 8, seq);
    bytes_copy(out + 12, address, LINK_ADDRESS_BYTES);
    put32(out + 20, ip);
    name_copy((char *)out + 24, name);
}
/* }}} */

/* {{{ state_at */
static int state_at(const struct peer_link *l, uint64_t now_ns)
{
    if (!l->heard || l->left) {
        return PEER_GONE;
    }
    uint64_t age = now_ns > l->last_seen_ns ? now_ns - l->last_seen_ns : 0;
    return age <= PEER_ALIVE_NS ? PEER_ALIVE : age <= PEER_GONE_NS ? PEER_STALE : PEER_GONE;
}

static int best_of(const struct peer_entry *e)
{
    int best = PEER_GONE;
    for (int l = 0; l < LINK_COUNT; l++) {
        if (e->link[l].state > best) best = e->link[l].state;
    }
    return best;
}
/* }}} */

/* {{{ events */
static void event(struct peers_event *events, int *n, int kind, int link, int from, int to, const char *name)
{
    if (*n >= MAX_EVENTS) {
        return;
    }
    struct peers_event *e = &events[(*n)++];
    e->kind = kind;
    e->link = link;
    e->from = from;
    e->to = to;
    name_copy(e->name, name);
}

/* Hand events to every subscriber. Called without the lock. */
static void deliver(const struct peers_event *events, int n)
{
    struct subscriber subs[PEER_SUBSCRIBERS];
    spin_lock(&lock);
    bytes_copy(subs, subscribers, sizeof subs);
    spin_unlock(&lock);
    for (int i = 0; i < n; i++) {
        for (int s = 0; s < PEER_SUBSCRIBERS; s++) {
            if (subs[s].in_use) {
                engine_deliver(subs[s].station, subs[s].port, &events[i], sizeof events[i]);
            }
        }
    }
}
/* }}} */

/* {{{ own name and address */
/* Called holding the lock. */
static void name_now(char out[PEER_NAME_BYTES])
{
    if (own_name_set) {
        name_copy(out, own_name);
        return;
    }
    uint8_t address[LINK_ADDRESS_BYTES];
    if (link_address(LINK_RADIO, address) != 0 && link_address(LINK_CABLE, address) != 0) {
        name_copy(out, "soren");
        return;
    }
    uint32_t h = 2166136261u;
    for (int i = 0; i < LINK_ADDRESS_BYTES; i++) h = (h ^ address[i]) * 16777619u;
    text_format(out, PEER_NAME_BYTES, "soren-%04x", (unsigned)(h & 0xFFFF));
}

void peers_set_name(const char *name)
{
    spin_lock(&lock);
    name_copy(own_name, name);
    own_name_set = own_name[0] != 0;
    spin_unlock(&lock);
}

void peers_name(char out[PEER_NAME_BYTES])
{
    spin_lock(&lock);
    name_now(out);
    spin_unlock(&lock);
}
/* }}} */

/* {{{ heard */
/* An announcement arrived (through 118's listener). */
static void heard(const struct net_datagram *d, uint64_t now_ns)
{
    struct peers_event events[2];
    int n = 0;
    const uint8_t *p = d->bytes;
    uint8_t own[LINK_ADDRESS_BYTES];
    int have_own = link_address(d->link, own) == 0;

    spin_lock(&lock);
    int good = d->length >= PEER_ANNOUNCEMENT_BYTES && bytes_equal(p, magic, 4) && p[4] == PEER_VERSION &&
               (p[5] == PEER_HERE || p[5] == PEER_LEAVING) && d->link < LINK_COUNT;
    const char *name = (const char *)p + 24;
    int terminated = 0;
    for (int i = 0; good && i < PEER_NAME_BYTES; i++) {
        if (name[i] == 0) {
            terminated = i > 0;
            break;
        }
    }
    /* What it says must be what it is: the hardware address and IP it
     * names are the ones it came from. */
    good = good && terminated && bytes_equal(p + 12, d->from_address, LINK_ADDRESS_BYTES) && get32(p + 20) == d->from_ip;
    if (!good) {
        counts.dropped++;
        spin_unlock(&lock);
        return;
    }
    if (have_own && bytes_equal(d->from_address, own, LINK_ADDRESS_BYTES)) {
        counts.ours++;
        spin_unlock(&lock);
        return;
    }
    counts.heard++;
    struct peer_entry *e = 0;
    for (int i = 0; i < n_peers; i++) {
        if (text_equal(table[i].name, name)) {
            e = &table[i];
            break;
        }
    }
    int fresh = 0;
    if (!e) {
        if (n_peers == PEER_MAX) {
            counts.full++;
            spin_unlock(&lock);
            return;
        }
        e = &table[n_peers++];
        bytes_zero(e, sizeof *e);
        name_copy(e->name, name);
        fresh = 1;
    }
    struct peer_link *l = &e->link[d->link];
    uint32_t seq = get32(p + 8);
    if (l->heard && !bytes_equal(l->address, d->from_address, LINK_ADDRESS_BYTES)) {
        counts.name_moved++;            /* another device with this name, or this one replaced */
    } else if (l->heard && seq > l->sequence + 1) {
        l->missed += seq - l->sequence - 1;
    }
    int was = l->state;
    l->heard = 1;
    bytes_copy(l->address, d->from_address, LINK_ADDRESS_BYTES);
    l->ip = d->from_ip;
    l->sequence = seq;
    l->last_seen_ns = now_ns;
    l->left = p[5] == PEER_LEAVING;
    l->state = l->left ? PEER_GONE : PEER_ALIVE;
    e->state = best_of(e);
    if (fresh) {
        if (l->state == PEER_ALIVE) {
            event(events, &n, PEER_DISCOVERED, d->link, PEER_GONE, PEER_ALIVE, e->name);
        }
    } else if (l->state != was) {
        event(events, &n, PEER_CHANGED, d->link, was, l->state, e->name);
    }
    spin_unlock(&lock);
    deliver(events, n);
}
/* }}} */

/* {{{ peers_init */
void peers_init(void)
{
    spin_lock(&lock);
    int first = !initialised;
    initialised = 1;
    spin_unlock(&lock);
    if (first) {
        net_listen_fn(PEER_PORT, heard);
    }
}
/* }}} */

/* {{{ announce */
/* Answers on how many links it was said. */
static int announce(int kind)
{
    int said = 0;
    uint8_t message[PEER_ANNOUNCEMENT_BYTES];
    char name[PEER_NAME_BYTES];
    spin_lock(&lock);
    name_now(name);
    uint32_t seq = ++sequence;
    spin_unlock(&lock);
    for (int link = 0; link < LINK_COUNT; link++) {
        uint8_t address[LINK_ADDRESS_BYTES];
        uint32_t ip = net_address(link);
        if (ip == 0 || link_address(link, address) != 0) {
            continue;
        }
        peers_build_announcement(message, kind, seq, address, ip, name);
        if (net_udp_send(link, NET_BROADCAST, PEER_PORT, PEER_PORT, message, sizeof message) == NET_OK) {
            spin_lock(&lock);
            counts.announced++;
            spin_unlock(&lock);
            said++;
        }
    }
    return said;
}

void peers_leave(void)
{
    (void)announce(PEER_LEAVING);
}
/* }}} */

/* {{{ peers_tick */
void peers_tick(uint64_t now_ns)
{
    struct peers_event events[MAX_EVENTS];
    int n = 0;
    spin_lock(&lock);
    /* Due five seconds after the last one that reached any link: a link
     * that has only just taken its address is announced on at once. */
    int due = !announced_once || now_ns - last_announce_ns >= PEER_ANNOUNCE_NS;
    for (int i = 0; i < n_peers; i++) {
        struct peer_entry *e = &table[i];
        for (int l = 0; l < LINK_COUNT; l++) {
            int was = e->link[l].state;
            int now = state_at(&e->link[l], now_ns);
            if (now != was) {
                e->link[l].state = now;
                event(events, &n, PEER_CHANGED, l, was, now, e->name);
            }
        }
        e->state = best_of(e);
    }
    spin_unlock(&lock);
    if (due && announce(PEER_HERE) > 0) {
        spin_lock(&lock);
        announced_once = 1;
        last_announce_ns = now_ns;
        spin_unlock(&lock);
    }
    deliver(events, n);
}
/* }}} */

/* {{{ the table */
int peers_lookup(const char *name, struct peer_entry *out)
{
    int found = 0;
    spin_lock(&lock);
    for (int i = 0; i < n_peers; i++) {
        if (text_equal(table[i].name, name)) {
            *out = table[i];
            found = 1;
            break;
        }
    }
    spin_unlock(&lock);
    return found;
}

int peers_alive_count(void)
{
    int alive = 0;
    spin_lock(&lock);
    for (int i = 0; i < n_peers; i++) {
        alive += table[i].state == PEER_ALIVE;
    }
    spin_unlock(&lock);
    return alive;
}

int peers_list(struct peer_entry *out, int max)
{
    spin_lock(&lock);
    int n = n_peers;
    for (int i = 0; i < n && i < max; i++) out[i] = table[i];
    spin_unlock(&lock);
    return n;
}
/* }}} */

/* {{{ subscribers */
int peers_subscribe(int32_t station, int port)
{
    int answer = NET_FULL;
    spin_lock(&lock);
    for (int i = 0; i < PEER_SUBSCRIBERS; i++) {
        if (!subscribers[i].in_use) {
            subscribers[i].in_use = 1;
            subscribers[i].station = station;
            subscribers[i].port = port;
            answer = NET_OK;
            break;
        }
    }
    spin_unlock(&lock);
    return answer;
}

int peers_unsubscribe(int32_t station, int port)
{
    spin_lock(&lock);
    for (int i = 0; i < PEER_SUBSCRIBERS; i++) {
        if (subscribers[i].in_use && subscribers[i].station == station && subscribers[i].port == port) {
            subscribers[i].in_use = 0;
        }
    }
    spin_unlock(&lock);
    return NET_OK;
}
/* }}} */

/* {{{ peers_counts */
struct peers_counts peers_counts(void)
{
    spin_lock(&lock);
    struct peers_counts c = counts;
    spin_unlock(&lock);
    return c;
}
/* }}} */

/* {{{ peers_start, peers_stop */
int peers_start(struct peers_runner *r, struct map_report *report)
{
    r->program = -1;
    r->timer = -1;
    peers_init();
    int program = program_load(PEERS_MAP, report);
    if (program < 0) {
        return -1;
    }
    if (program_bring_up(program, report) != 0) {
        program_remove(program);
        return -1;
    }
    int64_t tick = 1;
    int timer = engine_timer(program_station(program, "tick"), 0, &tick, sizeof tick,
                             platform_now_ns(), PEER_TICK_NS);
    if (timer < 0) {
        text_format(report->text, sizeof report->text, "%s: the tick's timer could not be armed (%d)\n",
                    PEERS_MAP, timer);
        report->problems = 1;
        program_remove(program);
        return -1;
    }
    r->program = program;
    r->timer = timer;
    return program;
}

void peers_stop(struct peers_runner *r)
{
    if (r->timer >= 0) {
        engine_timer_cancel(r->timer);
        r->timer = -1;
    }
}
/* }}} */
