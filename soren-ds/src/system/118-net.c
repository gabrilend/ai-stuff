/*
 * 118-net.c — a link-local address, and UDP over it (issue 703).
 *
 * General description: see 118-net.h. One lock covers every link's claim,
 * the ARP cache and the listeners. It is never held while a datagram is
 * handed to a listener, so a listener may send.
 */
#include <stddef.h>
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "118-net.h"

#define ETHERTYPE_IPV4 0x0800
#define ETHERTYPE_ARP  0x0806
#define IP_UDP         17

static const uint8_t everyone[LINK_ADDRESS_BYTES] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
static const uint8_t nobody[LINK_ADDRESS_BYTES]   = { 0, 0, 0, 0, 0, 0 };

struct claim {
    int      state;
    uint8_t  address[LINK_ADDRESS_BYTES];
    uint32_t candidate;             /* the guess, or the address once taken */
    int      sent;                  /* probes or announcements sent of the current kind */
    uint64_t next_ns;               /* when the next one is due */
    int      conflicts;
    uint64_t last_defence_ns;
    int      defended;              /* a defence has been made at last_defence_ns */
    uint64_t random;                /* xorshift state */
    int      guessed;               /* the first guess has been used */
};

struct arp_entry {
    int      in_use;
    int      link;
    uint32_t ip;
    uint8_t  address[LINK_ADDRESS_BYTES];
    uint64_t seen_ns;
};

struct listener {
    int      in_use;
    uint16_t port;
    int32_t  station;
    int      in_port;
    void   (*fn)(const struct net_datagram *d, uint64_t now_ns);
};

static struct claim       claims[LINK_COUNT];
static struct arp_entry   cache[NET_ARP_CACHE];
static struct listener    listeners[NET_LISTENERS];
static struct net_counts  counts;
static spin_lock_t        lock = SPIN_LOCK_INIT;

/* {{{ bytes in network order */
static uint16_t get16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }
static uint32_t get32(const uint8_t *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static void put16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)(v >> 8); p[1] = (uint8_t)v; }
static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }
static int same(const uint8_t *a, const uint8_t *b) { return bytes_equal(a, b, LINK_ADDRESS_BYTES); }
/* }}} */

/* {{{ net_checksum */
/* The Internet checksum: ones' complement of the ones' complement sum of
 * 16-bit words, `start` already summed in (a pseudo-header). */
uint16_t net_checksum(const void *bytes, size_t length, uint32_t start)
{
    const uint8_t *p = bytes;
    uint32_t sum = start;
    while (length > 1) {
        sum += (uint32_t)(p[0] << 8 | p[1]);
        p += 2;
        length -= 2;
    }
    if (length) {
        sum += (uint32_t)(p[0] << 8);
    }
    while (sum >> 16) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    return (uint16_t)~sum;
}
/* }}} */

/* {{{ udp_pseudo */
static uint32_t udp_pseudo(uint32_t from, uint32_t to, uint16_t udp_length)
{
    return (from >> 16) + (from & 0xFFFF) + (to >> 16) + (to & 0xFFFF) + IP_UDP + udp_length;
}
/* }}} */

/* {{{ ethernet_header */
static void ethernet_header(uint8_t *frame, const uint8_t *to, const uint8_t *from, uint16_t type)
{
    bytes_copy(frame, to, LINK_ADDRESS_BYTES);
    bytes_copy(frame + 6, from, LINK_ADDRESS_BYTES);
    put16(frame + 12, type);
}
/* }}} */

/* {{{ net_build_arp */
int net_build_arp(uint8_t *frame, int op, const uint8_t from_address[LINK_ADDRESS_BYTES], uint32_t from_ip,
                  const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t to_ip)
{
    /* A request goes to everyone; its target hardware address is zero. */
    ethernet_header(frame, op == 1 ? everyone : to_address, from_address, ETHERTYPE_ARP);
    uint8_t *a = frame + 14;
    put16(a, 1);                    /* Ethernet */
    put16(a + 2, ETHERTYPE_IPV4);
    a[4] = 6;
    a[5] = 4;
    put16(a + 6, (uint16_t)op);
    bytes_copy(a + 8, from_address, LINK_ADDRESS_BYTES);
    put32(a + 14, from_ip);
    bytes_copy(a + 18, op == 1 ? nobody : to_address, LINK_ADDRESS_BYTES);
    put32(a + 24, to_ip);
    return 14 + 28;
}
/* }}} */

/* {{{ net_build_udp */
int net_build_udp(uint8_t *frame, const uint8_t from_address[LINK_ADDRESS_BYTES],
                  const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t from_ip, uint32_t to_ip,
                  uint16_t from_port, uint16_t to_port, const void *bytes, size_t length)
{
    if (length > NET_PAYLOAD_MAX) {
        return NET_TOO_BIG;
    }
    ethernet_header(frame, to_address, from_address, ETHERTYPE_IPV4);
    uint8_t *ip = frame + 14;
    uint16_t total = (uint16_t)(20 + 8 + length);
    ip[0] = 0x45;                   /* version 4, five words of header */
    ip[1] = 0;
    put16(ip + 2, total);
    put16(ip + 4, 0);               /* identification: nothing is ever fragmented */
    put16(ip + 6, 0x4000);          /* don't fragment */
    ip[8] = 1;                      /* time to live: one hop; link-local is never forwarded */
    ip[9] = IP_UDP;
    put16(ip + 10, 0);
    put32(ip + 12, from_ip);
    put32(ip + 16, to_ip);
    put16(ip + 10, net_checksum(ip, 20, 0));
    uint8_t *udp = ip + 20;
    uint16_t udp_length = (uint16_t)(8 + length);
    put16(udp, from_port);
    put16(udp + 2, to_port);
    put16(udp + 4, udp_length);
    put16(udp + 6, 0);
    if (length) {
        bytes_copy(udp + 8, bytes, length);
    }
    uint16_t sum = net_checksum(udp, udp_length, udp_pseudo(from_ip, to_ip, udp_length));
    put16(udp + 6, sum ? sum : 0xFFFF);     /* 0 means "no checksum" in UDP */
    return 14 + total;
}
/* }}} */

/* {{{ net_read_frame */
int net_read_frame(const uint8_t *frame, size_t length, struct net_frame *out)
{
    bytes_zero(out, sizeof *out);
    if (length < 14) {
        return 0;
    }
    bytes_copy(out->to_address, frame, LINK_ADDRESS_BYTES);
    bytes_copy(out->from_address, frame + 6, LINK_ADDRESS_BYTES);
    uint16_t type = get16(frame + 12);
    const uint8_t *p = frame + 14;
    size_t left = length - 14;
    if (type == ETHERTYPE_ARP) {
        if (left < 28 || get16(p) != 1 || get16(p + 2) != ETHERTYPE_IPV4 || p[4] != 6 || p[5] != 4) {
            return 0;
        }
        out->arp_op = get16(p + 6);
        if (out->arp_op != 1 && out->arp_op != 2) {
            return 0;
        }
        bytes_copy(out->arp_from_address, p + 8, LINK_ADDRESS_BYTES);
        out->from_ip = get32(p + 14);
        out->to_ip = get32(p + 24);
        return 1;
    }
    if (type != ETHERTYPE_IPV4 || left < 20 || (p[0] >> 4) != 4) {
        return 0;
    }
    size_t header = (size_t)(p[0] & 0x0F) * 4;
    size_t total = get16(p + 2);
    if (header < 20 || total < header + 8 || total > left || net_checksum(p, header, 0) != 0) {
        return 0;
    }
    if ((get16(p + 6) & 0x3FFF) != 0) {     /* more fragments, or an offset: not one of ours */
        return -1;
    }
    if (p[9] != IP_UDP) {
        return 0;
    }
    out->from_ip = get32(p + 12);
    out->to_ip = get32(p + 16);
    const uint8_t *udp = p + header;
    size_t udp_length = get16(udp + 4);
    if (udp_length < 8 || udp_length > total - header) {
        return 0;
    }
    if (get16(udp + 6) != 0 &&
        net_checksum(udp, udp_length, udp_pseudo(out->from_ip, out->to_ip, (uint16_t)udp_length)) != 0) {
        return 0;
    }
    out->from_port = get16(udp);
    out->to_port = get16(udp + 2);
    out->bytes = udp + 8;
    out->length = udp_length - 8;
    return 2;
}
/* }}} */

/* {{{ guessing */
static uint64_t next_random(struct claim *c)
{
    uint64_t x = c->random;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    c->random = x ? x : 0x9E3779B97F4A7C15ull;
    return c->random;
}

/* An address in 169.254.1.0 – 169.254.254.255 from any 32 bits. */
static uint32_t in_range(uint32_t bits)
{
    return NET_LINK_LOCAL + 0x100 + bits % (254u * 256u);
}

uint32_t net_first_guess(const uint8_t address[LINK_ADDRESS_BYTES])
{
    uint32_t h = 2166136261u;       /* FNV-1a */
    for (int i = 0; i < LINK_ADDRESS_BYTES; i++) {
        h = (h ^ address[i]) * 16777619u;
    }
    return in_range(h);
}

static uint64_t between(struct claim *c, uint64_t low, uint64_t high)
{
    return low + (high > low ? next_random(c) % (high - low) : 0);
}

/* Start probing a new guess. Called holding the lock. */
static void new_guess(struct claim *c, uint64_t now_ns)
{
    c->candidate = c->guessed ? in_range((uint32_t)next_random(c)) : net_first_guess(c->address);
    c->guessed = 1;
    c->sent = 0;
    c->defended = 0;
    if (c->conflicts >= NET_MAX_CONFLICTS) {
        c->state = NET_CLAIM_WAITING;
        c->next_ns = now_ns + NET_RATE_LIMIT_NS;
    } else {
        c->state = NET_CLAIM_PROBING;
        c->next_ns = now_ns + between(c, 0, NET_PROBE_WAIT_NS);
    }
}
/* }}} */

/* {{{ cache */
/* Remember who has an address. Called holding the lock. */
static void learn(int link, uint32_t ip, const uint8_t *address, uint64_t now_ns)
{
    if (ip == 0 || (ip & NET_LINK_LOCAL_MASK) != NET_LINK_LOCAL || ip == NET_BROADCAST) {
        return;
    }
    int at = -1, oldest = 0;
    for (int i = 0; i < NET_ARP_CACHE; i++) {
        if (cache[i].in_use && cache[i].link == link && cache[i].ip == ip) {
            at = i;
            break;
        }
        if (!cache[i].in_use) {
            if (at < 0) at = i;
        } else if (cache[oldest].in_use && cache[i].seen_ns < cache[oldest].seen_ns) {
            oldest = i;
        }
    }
    if (at < 0) {
        at = oldest;
    }
    cache[at].in_use = 1;
    cache[at].link = link;
    cache[at].ip = ip;
    bytes_copy(cache[at].address, address, LINK_ADDRESS_BYTES);
    cache[at].seen_ns = now_ns;
}

static int lookup(int link, uint32_t ip, uint8_t *address)
{
    for (int i = 0; i < NET_ARP_CACHE; i++) {
        if (cache[i].in_use && cache[i].link == link && cache[i].ip == ip) {
            bytes_copy(address, cache[i].address, LINK_ADDRESS_BYTES);
            return 1;
        }
    }
    return 0;
}

static void forget_link(int link)
{
    for (int i = 0; i < NET_ARP_CACHE; i++) {
        if (cache[i].link == link) cache[i].in_use = 0;
    }
}
/* }}} */

/* {{{ send_frame */
static void send_frame(int link, const uint8_t *frame, int length)
{
    if (length > 0 && link_send(link, frame, (size_t)length) == 0) {
        counts.frames_out++;
    }
}
/* }}} */

/* {{{ on_arp */
/* An ARP frame arrived. Called holding the lock. */
static void on_arp(int link, const struct net_frame *f, uint64_t now_ns)
{
    struct claim *c = &claims[link];
    counts.arp_in++;
    if (same(f->arp_from_address, c->address)) {
        return;                     /* our own, heard back */
    }
    learn(link, f->from_ip, f->arp_from_address, now_ns);
    if (c->state == NET_CLAIM_PROBING) {
        /* Someone has it, or someone else is probing for it too. */
        if (f->from_ip == c->candidate || (f->from_ip == 0 && f->to_ip == c->candidate && f->arp_op == 1)) {
            c->conflicts++;
            new_guess(c, now_ns);
        }
        return;
    }
    if (c->state != NET_CLAIM_ANNOUNCING && c->state != NET_CLAIM_BOUND) {
        return;
    }
    if (f->from_ip == c->candidate) {
        /* Someone else says they have our address. Defend it once; a
         * second time inside the interval, let it go. */
        if (c->defended && now_ns - c->last_defence_ns < NET_DEFEND_INTERVAL_NS) {
            c->conflicts++;
            new_guess(c, now_ns);
            return;
        }
        uint8_t frame[64];
        send_frame(link, frame, net_build_arp(frame, 1, c->address, c->candidate, nobody, c->candidate));
        c->defended = 1;
        c->last_defence_ns = now_ns;
        return;
    }
    if (f->arp_op == 1 && f->to_ip == c->candidate && f->from_ip != 0) {
        uint8_t frame[64];
        send_frame(link, frame, net_build_arp(frame, 2, c->address, c->candidate, f->arp_from_address, f->from_ip));
    }
}
/* }}} */

/* {{{ advance */
/* Send any probe or announcement that is due. Called holding the lock. */
static void advance(int link, uint64_t now_ns)
{
    struct claim *c = &claims[link];
    uint8_t frame[64];
    if (c->state == NET_CLAIM_WAITING && now_ns >= c->next_ns) {
        c->state = NET_CLAIM_PROBING;
    }
    if (now_ns < c->next_ns) {
        return;
    }
    if (c->state == NET_CLAIM_PROBING) {
        if (c->sent < NET_PROBE_NUM) {
            send_frame(link, frame, net_build_arp(frame, 1, c->address, 0, nobody, c->candidate));
            c->sent++;
            c->next_ns = now_ns + (c->sent < NET_PROBE_NUM ? between(c, NET_PROBE_MIN_NS, NET_PROBE_MAX_NS)
                                                          : NET_ANNOUNCE_WAIT_NS);
            return;
        }
        /* Nobody answered: it is ours. */
        c->state = NET_CLAIM_ANNOUNCING;
        c->sent = 0;
    }
    if (c->state == NET_CLAIM_ANNOUNCING) {
        send_frame(link, frame, net_build_arp(frame, 1, c->address, c->candidate, nobody, c->candidate));
        if (++c->sent >= NET_ANNOUNCE_NUM) {
            c->state = NET_CLAIM_BOUND;
            c->next_ns = UINT64_MAX;
        } else {
            c->next_ns = now_ns + NET_ANNOUNCE_INTERVAL_NS;
        }
    }
}
/* }}} */

/* {{{ net_poll */
void net_poll(uint64_t now_ns)
{
    uint8_t frame[LINK_FRAME_MAX];
    for (int link = 0; link < LINK_COUNT; link++) {
        struct claim *c = &claims[link];
        if (!link_up(link)) {
            spin_lock(&lock);
            if (c->state != NET_CLAIM_NO_LINK) {
                c->state = NET_CLAIM_NO_LINK;
                c->candidate = 0;
                forget_link(link);
            }
            spin_unlock(&lock);
            continue;
        }
        spin_lock(&lock);
        if (c->state == NET_CLAIM_NO_LINK) {
            uint8_t address[LINK_ADDRESS_BYTES];
            if (link_address(link, address) == 0) {
                /* A new link, or a different one: start again from its
                 * first guess. */
                bytes_copy(c->address, address, LINK_ADDRESS_BYTES);
                uint64_t seed = platform_entropy();
                for (int i = 0; i < LINK_ADDRESS_BYTES; i++) seed = seed * 1099511628211ull + address[i];
                c->random = seed ? seed : 1;
                c->guessed = 0;
                c->conflicts = 0;
                new_guess(c, now_ns);
            }
        }
        spin_unlock(&lock);

        int length;
        while ((length = link_receive(link, frame, sizeof frame)) > 0) {
            struct net_frame f;
            spin_lock(&lock);
            counts.frames_in++;
            int kind = net_read_frame(frame, (size_t)length, &f);
            if (!same(f.to_address, c->address) && !same(f.to_address, everyone)) {
                counts.dropped_not_ours++;
                spin_unlock(&lock);
                continue;
            }
            if (kind == 1) {
                on_arp(link, &f, now_ns);
                spin_unlock(&lock);
                continue;
            }
            if (kind != 2) {
                if (kind < 0) counts.dropped_not_ours++;
                else counts.dropped_bad++;
                spin_unlock(&lock);
                continue;
            }
            int bound = c->state == NET_CLAIM_ANNOUNCING || c->state == NET_CLAIM_BOUND;
            int broadcast = f.to_ip == NET_BROADCAST || f.to_ip == 0xFFFFFFFFu;
            if (!broadcast && !(bound && f.to_ip == c->candidate)) {
                counts.dropped_not_ours++;
                spin_unlock(&lock);
                continue;
            }
            learn(link, f.from_ip, f.from_address, now_ns);
            struct listener l = { 0, 0, -1, 0, 0 };
            for (int i = 0; i < NET_LISTENERS; i++) {
                if (listeners[i].in_use && listeners[i].port == f.to_port) {
                    l = listeners[i];
                    break;
                }
            }
            if (!l.in_use) {
                counts.dropped_no_listener++;
                spin_unlock(&lock);
                continue;
            }
            counts.udp_delivered++;
            spin_unlock(&lock);

            struct net_datagram d;
            bytes_zero(&d, sizeof d - NET_PAYLOAD_MAX);
            d.from_ip = f.from_ip;
            d.from_port = f.from_port;
            d.to_port = f.to_port;
            bytes_copy(d.from_address, f.from_address, LINK_ADDRESS_BYTES);
            d.link = (uint8_t)link;
            d.broadcast = (uint8_t)broadcast;
            d.length = (uint16_t)f.length;
            bytes_copy(d.bytes, f.bytes, f.length);
            bytes_zero(d.bytes + f.length, NET_PAYLOAD_MAX - f.length);
            if (l.fn) {
                l.fn(&d, now_ns);
            } else {
                engine_deliver(l.station, l.in_port, &d, sizeof d);
            }
        }

        spin_lock(&lock);
        advance(link, now_ns);
        spin_unlock(&lock);
    }
}
/* }}} */

/* {{{ addresses */
int net_claim(int link)
{
    if (link < 0 || link >= LINK_COUNT) return NET_CLAIM_NO_LINK;
    spin_lock(&lock);
    int state = claims[link].state;
    spin_unlock(&lock);
    return state;
}

uint32_t net_address(int link)
{
    if (link < 0 || link >= LINK_COUNT) return 0;
    spin_lock(&lock);
    uint32_t ip = claims[link].state == NET_CLAIM_ANNOUNCING || claims[link].state == NET_CLAIM_BOUND
                      ? claims[link].candidate : 0;
    spin_unlock(&lock);
    return ip;
}

uint32_t net_candidate(int link)
{
    if (link < 0 || link >= LINK_COUNT) return 0;
    spin_lock(&lock);
    uint32_t ip = claims[link].state == NET_CLAIM_NO_LINK ? 0 : claims[link].candidate;
    spin_unlock(&lock);
    return ip;
}

int net_conflicts(int link)
{
    if (link < 0 || link >= LINK_COUNT) return 0;
    spin_lock(&lock);
    int n = claims[link].conflicts;
    spin_unlock(&lock);
    return n;
}
/* }}} */

/* {{{ net_udp_send_to */
int net_udp_send_to(int link, const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t to_ip,
                    uint16_t from_port, uint16_t to_port, const void *bytes, size_t length)
{
    uint8_t frame[LINK_FRAME_MAX];
    if (link < 0 || link >= LINK_COUNT || !link_up(link)) {
        return NET_NO_LINK;
    }
    if (length > NET_PAYLOAD_MAX) {
        return NET_TOO_BIG;
    }
    spin_lock(&lock);
    struct claim *c = &claims[link];
    int bound = c->state == NET_CLAIM_ANNOUNCING || c->state == NET_CLAIM_BOUND;
    uint32_t from_ip = c->candidate;
    uint8_t from_address[LINK_ADDRESS_BYTES];
    bytes_copy(from_address, c->address, LINK_ADDRESS_BYTES);
    spin_unlock(&lock);
    if (!bound) {
        return NET_NO_ADDRESS;
    }
    int n = net_build_udp(frame, from_address, to_address, from_ip, to_ip, from_port, to_port, bytes, length);
    if (n < 0) {
        return n;
    }
    if (link_send(link, frame, (size_t)n) != 0) {
        return NET_NO_LINK;
    }
    spin_lock(&lock);
    counts.frames_out++;
    spin_unlock(&lock);
    return NET_OK;
}
/* }}} */

/* {{{ net_udp_send */
int net_udp_send(int link, uint32_t to_ip, uint16_t from_port, uint16_t to_port,
                 const void *bytes, size_t length)
{
    if (link < 0 || link >= LINK_COUNT || !link_up(link)) {
        return NET_NO_LINK;
    }
    uint8_t to_address[LINK_ADDRESS_BYTES];
    if (to_ip == NET_BROADCAST || to_ip == 0xFFFFFFFFu) {
        return net_udp_send_to(link, everyone, to_ip, from_port, to_port, bytes, length);
    }
    spin_lock(&lock);
    int known = lookup(link, to_ip, to_address);
    struct claim *c = &claims[link];
    int bound = c->state == NET_CLAIM_ANNOUNCING || c->state == NET_CLAIM_BOUND;
    uint8_t frame[64];
    int asked = 0;
    if (!known && bound) {
        asked = net_build_arp(frame, 1, c->address, c->candidate, nobody, to_ip);
    }
    spin_unlock(&lock);
    if (known) {
        return net_udp_send_to(link, to_address, to_ip, from_port, to_port, bytes, length);
    }
    if (!bound) {
        return NET_NO_ADDRESS;
    }
    if (length > NET_PAYLOAD_MAX) {
        return NET_TOO_BIG;
    }
    spin_lock(&lock);
    send_frame(link, frame, asked);
    spin_unlock(&lock);
    return NET_RESOLVING;
}
/* }}} */

/* {{{ listeners */
static int listen_as(uint16_t port, int32_t station, int in_port,
                     void (*fn)(const struct net_datagram *d, uint64_t now_ns))
{
    int answer = NET_FULL;
    spin_lock(&lock);
    for (int i = 0; i < NET_LISTENERS; i++) {
        if (listeners[i].in_use && listeners[i].port == port) {
            spin_unlock(&lock);
            return NET_TAKEN;
        }
    }
    for (int i = 0; i < NET_LISTENERS; i++) {
        if (!listeners[i].in_use) {
            listeners[i].in_use = 1;
            listeners[i].port = port;
            listeners[i].station = station;
            listeners[i].in_port = in_port;
            listeners[i].fn = fn;
            answer = NET_OK;
            break;
        }
    }
    spin_unlock(&lock);
    return answer;
}

int net_listen(uint16_t port, int32_t station, int in_port)
{
    return listen_as(port, station, in_port, 0);
}

int net_listen_fn(uint16_t port, void (*fn)(const struct net_datagram *d, uint64_t now_ns))
{
    return listen_as(port, -1, 0, fn);
}

int net_unlisten(uint16_t port)
{
    spin_lock(&lock);
    for (int i = 0; i < NET_LISTENERS; i++) {
        if (listeners[i].in_use && listeners[i].port == port) {
            listeners[i].in_use = 0;
        }
    }
    spin_unlock(&lock);
    return NET_OK;
}
/* }}} */

/* {{{ net_counts */
struct net_counts net_counts(void)
{
    spin_lock(&lock);
    struct net_counts n = counts;
    spin_unlock(&lock);
    return n;
}
/* }}} */

/* {{{ net_start, net_stop */
int net_start(struct net_runner *r, struct map_report *report)
{
    r->program = -1;
    r->timer = -1;
    int program = program_load(NET_MAP, report);
    if (program < 0) {
        return -1;
    }
    if (program_bring_up(program, report) != 0) {
        program_remove(program);
        return -1;
    }
    int64_t tick = 1;
    int timer = engine_timer(program_station(program, "poll"), 0, &tick, sizeof tick,
                             platform_now_ns() + NET_POLL_NS, NET_POLL_NS);
    if (timer < 0) {
        text_format(report->text, sizeof report->text, "%s: the poll's timer could not be armed (%d)\n",
                    NET_MAP, timer);
        report->problems = 1;
        program_remove(program);
        return -1;
    }
    r->program = program;
    r->timer = timer;
    return program;
}

void net_stop(struct net_runner *r)
{
    if (r->timer >= 0) {
        engine_timer_cancel(r->timer);
        r->timer = -1;
    }
}
/* }}} */
