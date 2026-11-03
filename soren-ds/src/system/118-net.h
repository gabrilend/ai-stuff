/*
 * 118-net.h — a link-local address, and UDP over it (issue 703).
 *
 * General description: the smallest IPv4 stack that phase 7 needs, over
 * each link of 115-link.h: ARP, IPv4 without options or fragments, and
 * UDP. No TCP: rmail (710) brings its own acknowledgements.
 *
 * Each link claims its own address in 169.254.1.0 – 169.254.254.255 the
 * way RFC 3927 says: the first guess is made from the link's hardware
 * address, so a device asks for the same one after every boot; later
 * guesses are random. A guess is probed three times with ARP, a second
 * or two apart, and taken if nobody claims it, then announced twice. An
 * address already taken is defended once; a second challenge within ten
 * seconds gives it up for a new guess. The mask is /16.
 *
 * All of it happens in net_poll, which reads every frame waiting on each
 * link, answers what needs answering, delivers UDP to whoever listens on
 * its port, and sends any probe or announcement that is due. The net map
 * (src/maps/net.map) calls it on its own timer, every NET_POLL_NS; a test
 * may call it directly with a clock of its own.
 *
 * The state here — each link's address, the ARP cache, the listeners — is
 * the system's, like the surface table: a thing in the world that boxes
 * send through and hear from, not a box remembering.
 */
#ifndef SOREN_NET_H
#define SOREN_NET_H

#include <stddef.h>
#include <stdint.h>
#include "../engine/068-programs.h"
#include "115-link.h"

#define NET_MAP           "src/maps/net.map"
#define NET_POLL_NS       10000000ull          /* 10 ms: a hundred looks a second at each link */

#define NET_IP(a, b, c, d) (((uint32_t)(a) << 24) | ((uint32_t)(b) << 16) | ((uint32_t)(c) << 8) | (uint32_t)(d))
#define NET_LINK_LOCAL     NET_IP(169, 254, 0, 0)
#define NET_LINK_LOCAL_MASK NET_IP(255, 255, 0, 0)
#define NET_BROADCAST      NET_IP(169, 254, 255, 255)
#define NET_PAYLOAD_MAX    1472                 /* a 1500-byte IP packet less 28 bytes of headers */
#define NET_LISTENERS      16
#define NET_ARP_CACHE      32

/* RFC 3927's timings, in nanoseconds. */
#define NET_PROBE_WAIT_NS        1000000000ull  /* before the first probe: up to this */
#define NET_PROBE_NUM            3
#define NET_PROBE_MIN_NS         1000000000ull  /* between probes: from this */
#define NET_PROBE_MAX_NS         2000000000ull  /* to this */
#define NET_ANNOUNCE_WAIT_NS     2000000000ull  /* after the last probe */
#define NET_ANNOUNCE_NUM         2
#define NET_ANNOUNCE_INTERVAL_NS 2000000000ull
#define NET_MAX_CONFLICTS        10             /* then one guess a minute */
#define NET_RATE_LIMIT_NS        60000000000ull
#define NET_DEFEND_INTERVAL_NS   10000000000ull

/* Answers. */
#define NET_OK          0
#define NET_NO_LINK    (-1)     /* the link is not up */
#define NET_NO_ADDRESS (-2)     /* it has not claimed an address yet */
#define NET_TOO_BIG    (-3)     /* more than NET_PAYLOAD_MAX bytes */
#define NET_RESOLVING  (-4)     /* whose address that is was asked; send again shortly */
#define NET_FULL       (-5)     /* every listener is taken */
#define NET_TAKEN      (-6)     /* that port already has a listener */

/* Where a link's address stands. */
enum net_claim {
    NET_CLAIM_NO_LINK    = 0,   /* the link is not up */
    NET_CLAIM_PROBING    = 1,   /* asking whether a guess is free */
    NET_CLAIM_ANNOUNCING = 2,   /* taken, and saying so */
    NET_CLAIM_BOUND      = 3,   /* taken and said */
    NET_CLAIM_WAITING    = 4,   /* too many conflicts: one guess a minute */
};

/* What a listener's port receives: one UDP datagram. A box that listens
 * takes a value type of exactly this layout (709 defines it). */
struct net_datagram {
    uint32_t from_ip;
    uint16_t from_port;
    uint16_t to_port;
    uint8_t  from_address[LINK_ADDRESS_BYTES];
    uint8_t  link;
    uint8_t  broadcast;         /* 1 if it was sent to everyone */
    uint16_t length;
    uint16_t unused;
    uint8_t  bytes[NET_PAYLOAD_MAX];
};

/* {{{ running */
/* Read every link, answer, deliver, and send whatever is due by `now_ns`. */
void net_poll(uint64_t now_ns);

struct net_runner {
    int program;                /* the net program, or -1 */
    int timer;                  /* its engine timer, or -1 */
};

/* Load and bring up the net map and arm its timer; answers the program
 * number, or -1 with the problem in `report`. Stop disarms the timer. */
int  net_start(struct net_runner *r, struct map_report *report);
void net_stop(struct net_runner *r);
/* }}} */

/* {{{ addresses */
int      net_claim(int link);           /* an enum net_claim */
uint32_t net_address(int link);         /* the address taken, or 0 */
uint32_t net_candidate(int link);       /* the guess being probed, or 0 */
int      net_conflicts(int link);       /* conflicts since the link came up */

/* The first guess for a hardware address: the same every time. */
uint32_t net_first_guess(const uint8_t address[LINK_ADDRESS_BYTES]);
/* }}} */

/* {{{ UDP */
/* Send `length` bytes from our `from_port` to `to_ip`:`to_port`.
 * NET_BROADCAST goes to everyone on the link. A unicast address whose
 * hardware address is not yet known is asked for, and NET_RESOLVING
 * answered. */
int net_udp_send(int link, uint32_t to_ip, uint16_t from_port, uint16_t to_port,
                 const void *bytes, size_t length);

/* The same, to a hardware address already known (the peer table's). */
int net_udp_send_to(int link, const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t to_ip,
                    uint16_t from_port, uint16_t to_port, const void *bytes, size_t length);

/* Deliver every datagram for `port` into a station's port, as a struct
 * net_datagram; or to a function, for the system's own listeners
 * (discovery, 704). One listener per port. */
int net_listen(uint16_t port, int32_t station, int in_port);
int net_listen_fn(uint16_t port, void (*fn)(const struct net_datagram *d, uint64_t now_ns));
int net_unlisten(uint16_t port);
/* }}} */

/* {{{ counting */
struct net_counts {
    uint64_t frames_in, frames_out;
    uint64_t arp_in, udp_delivered;
    uint64_t dropped_bad;           /* malformed, or a checksum that does not add up */
    uint64_t dropped_not_ours;      /* for another address, or a fragment */
    uint64_t dropped_no_listener;
};
struct net_counts net_counts(void);
/* }}} */

/* {{{ building and reading frames, for the layers above and for tests */
uint16_t net_checksum(const void *bytes, size_t length, uint32_t start);

/* An ARP frame: op 1 request, 2 reply. Answers its length (42). */
int net_build_arp(uint8_t *frame, int op, const uint8_t from_address[LINK_ADDRESS_BYTES], uint32_t from_ip,
                  const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t to_ip);

/* A UDP datagram in an IPv4 packet in an Ethernet frame, checksums and
 * all. Answers its length, or NET_TOO_BIG. */
int net_build_udp(uint8_t *frame, const uint8_t from_address[LINK_ADDRESS_BYTES],
                  const uint8_t to_address[LINK_ADDRESS_BYTES], uint32_t from_ip, uint32_t to_ip,
                  uint16_t from_port, uint16_t to_port, const void *bytes, size_t length);

/* Read a frame back: what it is (0 neither, 1 ARP, 2 UDP), and its parts.
 * Checksums are checked; a frame that fails reads as 0. */
struct net_frame {
    uint8_t  to_address[LINK_ADDRESS_BYTES], from_address[LINK_ADDRESS_BYTES];
    int      arp_op;
    uint8_t  arp_from_address[LINK_ADDRESS_BYTES];
    uint32_t from_ip, to_ip;
    uint16_t from_port, to_port;
    const uint8_t *bytes;
    size_t   length;
};
int net_read_frame(const uint8_t *frame, size_t length, struct net_frame *out);
/* }}} */

#endif
