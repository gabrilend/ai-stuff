/*
 * 120-test-link-local.c — issue 703, over the twin's STAND-IN LINK: a
 * link-local address, and UDP over it.
 *
 * General description: the test plays everything on the other end of
 * the stand-in link — other handhelds probing, announcing, answering,
 * sending — by putting the frames they would send on the air, and reads
 * what the device sends back. The clock is the test's own, passed to
 * net_poll, so ten seconds of probing take no time.
 *
 * Checked: no link, no address. A link coming up probes its first guess
 * (always the same for one hardware address) three times, a second or two
 * apart, then announces it twice and has it. A conflict while probing,
 * whether someone has the address or is probing for it too, moves to
 * another guess. Asked who has our address, we answer. Challenged once,
 * we defend; twice inside ten seconds, we give it up. UDP for us arrives
 * at its port's listener whole, and checksums that do not add up,
 * fragments, other people's mail and ports nobody listens on are
 * dropped. What we send reads back with good checksums, goes to everyone
 * or to whoever has the address, and asks first when that is not known.
 * Too many conflicts and guesses come one a minute. And the net map runs
 * the poll on its own timer.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/system/118-net.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../117-link-twin.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

#define CORES 4
#define SECOND 1000000000ull
#define RADIO LINK_RADIO

static const uint8_t ME[6]    = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x01 };
static const uint8_t OTHER[6] = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x02 };
static const uint8_t ALL[6]   = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
static const uint8_t NONE[6]  = { 0, 0, 0, 0, 0, 0 };

/* {{{ what the device sent */
struct sent {
    int      probes, announces, replies, requests, udp;
    uint64_t probe_at[16], announce_at[16];
    uint32_t probed[16];
    struct net_frame last;
    uint8_t  last_bytes[LINK_FRAME_MAX];
    int      last_length;
};

/* Read and sort every frame the device has sent, as at `now`. */
static void collect(struct sent *s, uint64_t now)
{
    uint8_t frame[LINK_FRAME_MAX];
    int n;
    while ((n = twin_link_take(RADIO, frame, sizeof frame)) > 0) {
        struct net_frame f;
        int kind = net_read_frame(frame, (size_t)n, &f);
        memcpy(s->last_bytes, frame, (size_t)n);
        s->last_length = n;
        net_read_frame(s->last_bytes, (size_t)n, &s->last);
        if (kind == 1 && f.arp_op == 1 && f.from_ip == 0) {
            if (s->probes < 16) {
                s->probe_at[s->probes] = now;
                s->probed[s->probes] = f.to_ip;
            }
            s->probes++;
        } else if (kind == 1 && f.arp_op == 1 && f.from_ip == f.to_ip) {
            if (s->announces < 16) s->announce_at[s->announces] = now;
            s->announces++;
        } else if (kind == 1 && f.arp_op == 1) {
            s->requests++;
        } else if (kind == 1 && f.arp_op == 2) {
            s->replies++;
        } else if (kind == 2) {
            s->udp++;
        }
    }
}

/* Poll every 10 ms of the test's clock from `*now` for `ns`. */
static void run(uint64_t *now, uint64_t ns, struct sent *s)
{
    for (uint64_t end = *now + ns; *now < end; *now += 10000000ull) {
        net_poll(*now);
        collect(s, *now);
    }
}
/* }}} */

/* {{{ frames the other end sends */
static void put_arp(int op, const uint8_t *from, uint32_t from_ip, const uint8_t *to, uint32_t to_ip)
{
    uint8_t frame[64];
    twin_link_put(RADIO, frame, (size_t)net_build_arp(frame, op, from, from_ip, to, to_ip));
}

static void put_udp(const uint8_t *to_address, uint32_t from_ip, uint32_t to_ip, uint16_t to_port,
                    const char *text)
{
    uint8_t frame[LINK_FRAME_MAX];
    twin_link_put(RADIO, frame, (size_t)net_build_udp(frame, OTHER, to_address, from_ip, to_ip, 4000, to_port,
                                                     text, strlen(text)));
}
/* }}} */

/* {{{ a box that keeps what it hears */
static struct net_datagram heard;
static int heard_count;
static void listen_call(const void *in, void *out)
{
    (void)out;
    memcpy(&heard, in, sizeof heard);
    __atomic_add_fetch(&heard_count, 1, __ATOMIC_SEQ_CST);
}
static const struct box_param listen_params[] = { { "d", "struct net_datagram", sizeof(struct net_datagram), 0 } };
static const struct box listen_box = { "hear", __FILE__, listen_call, 1, listen_params,
                                       (sizeof(struct net_datagram) + 7) & ~7u, 0, "void" };
/* }}} */

static void sleep_ms(int ms)
{
    struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("120-link-local");
    struct map_report report;
    uint64_t now = 1000 * SECOND;
    struct sent s;

    /* --- no link ---------------------------------------------------------- */
    net_poll(now);
    CHECK(net_claim(RADIO) == NET_CLAIM_NO_LINK && net_address(RADIO) == 0 &&
          net_udp_send(RADIO, NET_BROADCAST, 1, 2, "x", 1) == NET_NO_LINK,
          "with no link there is no address, and nothing can be sent");

    /* --- claiming --------------------------------------------------------- */
    uint32_t first = net_first_guess(ME);
    CHECK(first == net_first_guess(ME) && first != net_first_guess(OTHER) &&
          first >= NET_IP(169, 254, 1, 0) && first <= NET_IP(169, 254, 254, 255),
          "the first guess comes from the hardware address, the same every time, in 169.254.1.0 – 254.255");
    twin_link_set(RADIO, 1, ME);
    memset(&s, 0, sizeof s);
    run(&now, 10 * SECOND, &s);
    CHECK(s.probes == 3 && s.probed[0] == first && s.probed[1] == first && s.probed[2] == first,
          "the link comes up and the first guess is probed three times (%d)", s.probes);
    uint64_t gap1 = s.probe_at[1] - s.probe_at[0], gap2 = s.probe_at[2] - s.probe_at[1];
    CHECK(gap1 >= NET_PROBE_MIN_NS && gap1 <= NET_PROBE_MAX_NS && gap2 >= NET_PROBE_MIN_NS && gap2 <= NET_PROBE_MAX_NS,
          "a second or two apart (%llu ms, %llu ms)", (unsigned long long)(gap1 / 1000000),
          (unsigned long long)(gap2 / 1000000));
    CHECK(s.announces == 2 && s.announce_at[0] - s.probe_at[2] >= NET_ANNOUNCE_WAIT_NS &&
          s.announce_at[1] - s.announce_at[0] >= NET_ANNOUNCE_INTERVAL_NS,
          "then, nobody answering, it is announced twice, two seconds apart (%d)", s.announces);
    CHECK(net_claim(RADIO) == NET_CLAIM_BOUND && net_address(RADIO) == first && net_conflicts(RADIO) == 0,
          "and it is ours");

    /* --- conflicts while probing ----------------------------------------- */
    twin_link_set(RADIO, 0, NULL);
    net_poll(now);
    CHECK(net_claim(RADIO) == NET_CLAIM_NO_LINK && net_address(RADIO) == 0, "the link goes down and the address with it");
    twin_link_set(RADIO, 1, ME);
    memset(&s, 0, sizeof s);
    run(&now, 2 * SECOND + 100000000ull, &s);
    CHECK(s.probes >= 1 && s.probed[0] == first, "back up, it probes the same first guess");
    put_arp(2, OTHER, first, ME, 0);       /* someone has it */
    memset(&s, 0, sizeof s);
    run(&now, 3 * SECOND, &s);
    uint32_t second = net_candidate(RADIO);
    CHECK(net_conflicts(RADIO) == 1 && second != first && s.probes >= 1 && s.probed[0] == second,
          "someone answering for it moves the probes to another guess");
    put_arp(1, OTHER, 0, NONE, second);    /* someone else is probing for the same one */
    run(&now, 100000000ull, &s);
    CHECK(net_conflicts(RADIO) == 2 && net_candidate(RADIO) != second,
          "so does someone else probing for the same guess");
    memset(&s, 0, sizeof s);
    run(&now, 10 * SECOND, &s);
    uint32_t mine = net_address(RADIO);
    CHECK(net_claim(RADIO) == NET_CLAIM_BOUND && mine != 0 && mine != first && mine != second,
          "and the third guess is taken");

    /* --- answering and defending ----------------------------------------- */
    uint32_t theirs = NET_IP(169, 254, 9, 9);
    memset(&s, 0, sizeof s);
    put_arp(1, OTHER, theirs, NONE, mine);
    run(&now, 100000000ull, &s);
    CHECK(s.replies == 1 && bytes_equal(s.last.to_address, OTHER, 6) && s.last.from_ip == mine &&
          s.last.to_ip == theirs && bytes_equal(s.last.arp_from_address, ME, 6),
          "asked who has our address, we answer the asker");
    memset(&s, 0, sizeof s);
    put_arp(1, OTHER, mine, NONE, mine);   /* someone announces our address */
    run(&now, 100000000ull, &s);
    CHECK(s.announces == 1 && net_address(RADIO) == mine, "challenged once, we defend it and keep it");
    run(&now, 5 * SECOND, &s);
    put_arp(1, OTHER, mine, NONE, mine);
    run(&now, 100000000ull, &s);
    CHECK(net_claim(RADIO) == NET_CLAIM_PROBING && net_address(RADIO) == 0 && net_candidate(RADIO) != mine,
          "challenged again inside ten seconds, we give it up and guess again");
    run(&now, 10 * SECOND, &s);
    mine = net_address(RADIO);
    CHECK(mine != 0, "and take the new one");

    /* --- hearing ---------------------------------------------------------- */
    CHECK(catalogue_add("src/boxes/999-net.c:hear", &listen_box) == 0, "a box that hears datagrams joins the catalogue");
    const char *map = "station hear (../boxes/999-net.c:hear)\n  in 0 - 0$\n";
    int p = program_load_text("src/maps/hear.map", map, strlen(map), &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0, "a map of it loads (%s)", report.text);
    CHECK(net_listen(7000, program_station(p, "hear"), 0) == NET_OK && net_listen(7000, 0, 0) == NET_TAKEN,
          "it listens on port 7000, and nobody else may");
    struct net_counts before = net_counts();
    put_udp(ME, theirs, mine, 7000, "hello, you");
    net_poll(now);
    twin_engine_settle(5000);
    CHECK(heard_count == 1 && heard.length == 10 && memcmp(heard.bytes, "hello, you", 10) == 0 && heard.broadcast == 0,
          "a datagram to our address reaches the listener");
    put_udp(ALL, theirs, NET_BROADCAST, 7000, "hello, everyone");
    net_poll(now);
    twin_engine_settle(5000);
    CHECK(heard_count == 2 && heard.from_ip == theirs && heard.from_port == 4000 && heard.to_port == 7000 &&
          heard.length == 15 && memcmp(heard.bytes, "hello, everyone", 15) == 0 && heard.broadcast == 1 &&
          bytes_equal(heard.from_address, OTHER, 6) && heard.link == RADIO,
          "so does one to everyone, whole, with who sent it (%d)", heard_count);

    uint8_t frame[LINK_FRAME_MAX];
    int n = net_build_udp(frame, OTHER, ME, theirs, mine, 4000, 7000, "bad", 3);
    frame[14 + 20 + 8] ^= 1;               /* the payload no longer matches the UDP checksum */
    twin_link_put(RADIO, frame, (size_t)n);
    n = net_build_udp(frame, OTHER, ME, theirs, mine, 4000, 7000, "bad", 3);
    frame[14 + 8] ^= 1;                    /* nor the header its own */
    twin_link_put(RADIO, frame, (size_t)n);
    n = net_build_udp(frame, OTHER, ME, theirs, mine, 4000, 7000, "frag", 4);
    frame[14 + 6] = 0x20;                  /* "more fragments" */
    frame[14 + 10] = frame[14 + 11] = 0;
    {
        uint16_t sum = net_checksum(frame + 14, 20, 0);
        frame[14 + 10] = (uint8_t)(sum >> 8);
        frame[14 + 11] = (uint8_t)sum;
    }
    twin_link_put(RADIO, frame, (size_t)n);
    put_udp(ME, theirs, NET_IP(169, 254, 3, 3), 7000, "for someone else");
    put_udp(OTHER, theirs, mine, 7000, "to another card");
    put_udp(ME, theirs, mine, 7001, "nobody listens");
    net_poll(now);
    twin_engine_settle(5000);
    struct net_counts after = net_counts();
    CHECK(heard_count == 2 && after.dropped_bad - before.dropped_bad == 2 &&
          after.dropped_not_ours - before.dropped_not_ours == 3 &&
          after.dropped_no_listener - before.dropped_no_listener == 1,
          "bad checksums, a fragment, other addresses and an unheard port are all dropped (%llu bad, %llu not ours, %llu unheard)",
          (unsigned long long)(after.dropped_bad - before.dropped_bad),
          (unsigned long long)(after.dropped_not_ours - before.dropped_not_ours),
          (unsigned long long)(after.dropped_no_listener - before.dropped_no_listener));

    /* --- sending ---------------------------------------------------------- */
    memset(&s, 0, sizeof s);
    CHECK(net_udp_send(RADIO, NET_BROADCAST, 7000, 7001, "to all", 6) == NET_OK, "a datagram to everyone goes");
    collect(&s, now);
    CHECK(s.udp == 1 && bytes_equal(s.last.to_address, ALL, 6) && s.last.from_ip == mine &&
          s.last.to_ip == NET_BROADCAST && s.last.from_port == 7000 && s.last.to_port == 7001 && s.last.length == 6 &&
          memcmp(s.last.bytes, "to all", 6) == 0, "and reads back whole, checksums and all, from our address");
    CHECK(s.last_bytes[14 + 8] == 1, "with a time to live of one hop");
    memset(&s, 0, sizeof s);
    CHECK(net_udp_send(RADIO, theirs, 7000, 4000, "back", 4) == NET_OK, "a datagram to someone heard from goes");
    collect(&s, now);
    CHECK(s.udp == 1 && bytes_equal(s.last.to_address, OTHER, 6) && s.last.to_ip == theirs,
          "straight to the hardware address they sent from");
    uint32_t stranger = NET_IP(169, 254, 77, 77);
    memset(&s, 0, sizeof s);
    CHECK(net_udp_send(RADIO, stranger, 7000, 4000, "hi", 2) == NET_RESOLVING, "to an address never heard from, it asks first");
    collect(&s, now);
    CHECK(s.requests == 1 && s.udp == 0 && s.last.to_ip == stranger && s.last.from_ip == mine,
          "who has it, from our address");
    static const uint8_t STRANGER[6] = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x77 };
    put_arp(2, STRANGER, stranger, ME, mine);
    net_poll(now);
    memset(&s, 0, sizeof s);
    CHECK(net_udp_send(RADIO, stranger, 7000, 4000, "hi", 2) == NET_OK, "once answered, it goes");
    collect(&s, now);
    CHECK(s.udp == 1 && bytes_equal(s.last.to_address, STRANGER, 6), "to the address that answered");
    static uint8_t big[NET_PAYLOAD_MAX + 1];
    CHECK(net_udp_send(RADIO, NET_BROADCAST, 1, 2, big, sizeof big) == NET_TOO_BIG &&
          net_udp_send(RADIO, NET_BROADCAST, 1, 2, big, NET_PAYLOAD_MAX) == NET_OK,
          "%d bytes fit in one datagram, and no more", NET_PAYLOAD_MAX);
    collect(&s, now);

    /* --- too many conflicts ---------------------------------------------- */
    twin_link_set(RADIO, 0, NULL);
    net_poll(now);
    twin_link_set(RADIO, 1, ME);
    for (int i = 0; i < NET_MAX_CONFLICTS; i++) {
        net_poll(now);
        put_arp(2, OTHER, net_candidate(RADIO), ME, 0);
        net_poll(now);
    }
    collect(&s, now);
    CHECK(net_conflicts(RADIO) == NET_MAX_CONFLICTS && net_claim(RADIO) == NET_CLAIM_WAITING,
          "after %d conflicts the next guess waits", NET_MAX_CONFLICTS);
    memset(&s, 0, sizeof s);
    run(&now, 50 * SECOND, &s);
    CHECK(s.probes == 0 && net_claim(RADIO) == NET_CLAIM_WAITING, "nothing is probed for most of a minute");
    run(&now, 20 * SECOND, &s);
    CHECK(s.probes == 3 && net_claim(RADIO) == NET_CLAIM_BOUND, "then the guess is probed and taken");
    twin_link_set(RADIO, 0, NULL);
    net_poll(now);

    /* --- the map, on its own timer --------------------------------------- */
    struct net_runner runner;
    int np = net_start(&runner, &report);
    CHECK(np >= 0 && runner.timer >= 0, "the net map loads and is armed (%s)", report.text);
    twin_link_set(RADIO, 1, ME);
    sleep_ms(300);
    collect(&s, 0);
    int32_t poll = program_station(np, "poll");
    CHECK(engine_station_runs(poll) >= 15 && net_claim(RADIO) == NET_CLAIM_PROBING,
          "it polls on its own (%llu polls) and the link starts probing",
          (unsigned long long)engine_station_runs(poll));
    net_stop(&runner);
    CHECK(twin_engine_settle(10000) && engine_port_waiting(poll, 1) == 1,
          "stopped, the next poll number waits on its loop");
    twin_link_set(RADIO, 0, NULL);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("120 link-local");
}
