/*
 * 123-test-peers.c — issues 704 and 705, over the twin's STAND-IN LINK:
 * announcing, hearing, and the peer table's aging.
 *
 * General description: the test plays other devices on the far end of
 * the stand-in link by putting their announcements on the air, built with
 * the same layout the device uses, and reads the device's own. Its clock
 * is its own. Checked: the device's name until one is set; an
 * announcement every five seconds on each link with an address, and none
 * before it has one; a peer heard is in the table, alive, and subscribers
 * hear it was found; its own announcements, heard back, and malformed or
 * mismatched ones are not; a peer that moves address is followed; links
 * go stale after twenty seconds and gone after five minutes, each
 * telling subscribers once, and a peer heard again is alive again; one
 * peer on both links is one entry; "I am leaving" is gone at once; the
 * table fills and says so; and the peers map ticks on its own timer.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/system/118-net.h"
#include "../../src/system/121-peers.h"
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

static const uint8_t ME[6]      = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x01 };
static const uint8_t ME_CABLE[6] = { 0x02, 0x50, 0x52, 0x00, 0x01, 0x01 };
static const uint8_t BETA[6]    = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x02 };
static const uint8_t BETA_CABLE[6] = { 0x02, 0x50, 0x52, 0x00, 0x01, 0x02 };
static const uint8_t ALL[6]     = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

/* {{{ the device's own announcements */
struct heard_own {
    int count;
    uint8_t last[PEER_ANNOUNCEMENT_BYTES];
    uint32_t to_ip;
    int port;
};

static void drain(int link, struct heard_own *h)
{
    uint8_t frame[LINK_FRAME_MAX];
    int n;
    while ((n = twin_link_take(link, frame, sizeof frame)) > 0) {
        struct net_frame f;
        if (h && net_read_frame(frame, (size_t)n, &f) == 2 && f.to_port == PEER_PORT &&
            f.length == PEER_ANNOUNCEMENT_BYTES) {
            h->count++;
            memcpy(h->last, f.bytes, PEER_ANNOUNCEMENT_BYTES);
            h->to_ip = f.to_ip;
        }
    }
}

static void run(uint64_t *now, uint64_t ns)
{
    for (uint64_t end = *now + ns; *now < end; *now += 50000000ull) {
        net_poll(*now);
        drain(LINK_RADIO, NULL);
        drain(LINK_CABLE, NULL);
    }
}
/* }}} */

/* {{{ another device's announcement, on the air */
static void say_here(int link, int kind, uint32_t seq, const uint8_t *address, uint32_t ip, const char *name)
{
    uint8_t message[PEER_ANNOUNCEMENT_BYTES];
    uint8_t frame[LINK_FRAME_MAX];
    peers_build_announcement(message, kind, seq, address, ip, name);
    twin_link_put(link, frame, (size_t)net_build_udp(frame, address, ALL, ip, NET_BROADCAST, PEER_PORT, PEER_PORT,
                                                    message, sizeof message));
}

static void put_raw(const uint8_t *address, uint32_t ip, const uint8_t *message, size_t length)
{
    uint8_t frame[LINK_FRAME_MAX];
    twin_link_put(LINK_RADIO, frame, (size_t)net_build_udp(frame, address, ALL, ip, NET_BROADCAST, PEER_PORT,
                                                          PEER_PORT, message, length));
}
/* }}} */

/* {{{ a box that keeps every event */
static struct peers_event events[64];
static int n_events;
static void keep_call(const void *in, void *out)
{
    (void)out;
    int at = __atomic_fetch_add(&n_events, 1, __ATOMIC_SEQ_CST);
    if (at < 64) memcpy(&events[at], in, sizeof events[at]);
}
static const struct box_param keep_params[] = { { "e", "struct peers_event", sizeof(struct peers_event), 0 } };
static const struct box keep_box = { "keep", __FILE__, keep_call, 1, keep_params,
                                     (sizeof(struct peers_event) + 7) & ~7u, 0, "void" };

/* Wait for the boxes, then: how many events since `from`, and the last. */
static int events_since(int from)
{
    twin_engine_settle(5000);
    return __atomic_load_n(&n_events, __ATOMIC_SEQ_CST) - from;
}
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
    metrics_open("123-peers");
    struct map_report report;
    uint64_t now = 2000 * SECOND;
    struct heard_own own = { 0 };
    struct peer_entry e;
    char name[PEER_NAME_BYTES];
    peers_init();

    /* --- the subscriber -------------------------------------------------- */
    CHECK(catalogue_add("src/boxes/999-peers.c:keep", &keep_box) == 0, "a box that keeps peer events joins the catalogue");
    const struct box *say = catalogue_box("src/boxes/122-peers.c:say_peer");
    CHECK(say && say->n_params == 1 && say->params[0].size == sizeof(struct peers_event),
          "the boxes' peer_event is the system's peers_event, byte for byte (%u)", say ? say->params[0].size : 0);
    const char *map = "station keep (../boxes/999-peers.c:keep)\n  in 0 - 0$\n";
    int p = program_load_text("src/maps/keep.map", map, strlen(map), &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0 && peers_subscribe(program_station(p, "keep"), 0) == NET_OK,
          "it is placed and subscribed (%s)", report.text);

    /* --- announcing ------------------------------------------------------- */
    peers_name(name);
    CHECK(strcmp(name, "soren") == 0, "with no link, the device is called soren (%s)", name);
    twin_link_set(LINK_RADIO, 1, ME);
    peers_name(name);
    CHECK(strncmp(name, "soren-", 6) == 0 && strlen(name) == 10, "with a radio, soren- and four hex digits (%s)", name);
    peers_set_name("alpha");
    peers_name(name);
    CHECK(strcmp(name, "alpha") == 0, "until a name is set");
    peers_tick(now);
    drain(LINK_RADIO, &own);
    CHECK(own.count == 0, "before the link has an address, nothing is announced");
    run(&now, 12 * SECOND);
    uint32_t mine = net_address(LINK_RADIO);
    CHECK(mine != 0, "the radio takes an address");
    now += 5 * SECOND;
    peers_tick(now);
    drain(LINK_RADIO, &own);
    CHECK(own.count == 1 && own.to_ip == NET_BROADCAST && memcmp(own.last, "SDSP", 4) == 0 && own.last[4] == 1 &&
          own.last[5] == PEER_HERE && memcmp(own.last + 12, ME, 6) == 0 &&
          own.last[20] == 169 && own.last[21] == 254 && strcmp((char *)own.last + 24, "alpha") == 0,
          "then it says who it is, to everyone, in the layout of notes/networking/000");
    uint32_t seq1 = (uint32_t)own.last[8] << 24 | (uint32_t)own.last[9] << 16 | (uint32_t)own.last[10] << 8 | own.last[11];
    peers_tick(now + 1 * SECOND);
    peers_tick(now + 4 * SECOND);
    drain(LINK_RADIO, &own);
    CHECK(own.count == 1, "not again for five seconds");
    peers_tick(now + 5 * SECOND);
    drain(LINK_RADIO, &own);
    uint32_t seq2 = (uint32_t)own.last[8] << 24 | (uint32_t)own.last[9] << 16 | (uint32_t)own.last[10] << 8 | own.last[11];
    CHECK(own.count == 2 && seq2 == seq1 + 1, "then again, one further on in the sequence (%u, %u)", seq1, seq2);
    now += 5 * SECOND;

    /* --- hearing ---------------------------------------------------------- */
    uint32_t beta_ip = NET_IP(169, 254, 20, 2);
    int mark = events_since(0);
    say_here(LINK_RADIO, PEER_HERE, 1, BETA, beta_ip, "beta");
    net_poll(now);
    CHECK(peers_lookup("beta", &e) && e.state == PEER_ALIVE && e.link[LINK_RADIO].state == PEER_ALIVE &&
          e.link[LINK_RADIO].ip == beta_ip && memcmp(e.link[LINK_RADIO].address, BETA, 6) == 0 &&
          !e.link[LINK_CABLE].heard && peers_alive_count() == 1,
          "a peer heard is in the table, alive on the radio, with where it was heard from");
    CHECK(events_since(mark) == 1 && events[mark].kind == PEER_DISCOVERED && strcmp(events[mark].name, "beta") == 0 &&
          events[mark].link == LINK_RADIO, "and the subscriber hears it was found");
    struct peers_counts before = peers_counts();
    put_raw(ME, mine, own.last, PEER_ANNOUNCEMENT_BYTES);        /* our own, heard back */
    uint8_t bad[PEER_ANNOUNCEMENT_BYTES];
    peers_build_announcement(bad, PEER_HERE, 1, BETA, beta_ip, "gamma");
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES - 1);   /* short */
    bad[4] = 2;
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES);       /* a version we do not know */
    peers_build_announcement(bad, PEER_HERE, 1, BETA, beta_ip, "gamma");
    bad[0] = 'X';
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES);       /* not ours at all */
    peers_build_announcement(bad, PEER_HERE, 1, BETA, beta_ip, "gamma");
    memset(bad + 24, 'g', 32);
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES);       /* a name with no end */
    peers_build_announcement(bad, PEER_HERE, 1, BETA_CABLE, beta_ip, "gamma");
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES);       /* naming another hardware address */
    peers_build_announcement(bad, PEER_HERE, 1, BETA, beta_ip + 1, "gamma");
    put_raw(BETA, beta_ip, bad, PEER_ANNOUNCEMENT_BYTES);       /* naming another IP */
    net_poll(now);
    struct peers_counts after = peers_counts();
    CHECK(after.ours - before.ours == 1 && after.dropped - before.dropped == 6 && !peers_lookup("gamma", &e) &&
          events_since(mark) == 1,
          "its own announcement is ignored and six bad ones are dropped (%llu, %llu)",
          (unsigned long long)(after.ours - before.ours), (unsigned long long)(after.dropped - before.dropped));
    now += 3 * SECOND;
    say_here(LINK_RADIO, PEER_HERE, 4, BETA, beta_ip + 7, "beta");
    net_poll(now);
    CHECK(peers_lookup("beta", &e) && e.link[LINK_RADIO].ip == beta_ip + 7 && e.link[LINK_RADIO].missed == 2 &&
          events_since(mark) == 1, "a peer that moves is followed, missed announcements counted, nothing announced");

    /* --- aging ------------------------------------------------------------ */
    uint64_t heard_at = now;
    peers_tick(heard_at + PEER_ALIVE_NS);
    CHECK(peers_lookup("beta", &e) && e.state == PEER_ALIVE, "at twenty seconds it is still alive");
    mark = events_since(0);
    peers_tick(heard_at + PEER_ALIVE_NS + SECOND);
    CHECK(peers_lookup("beta", &e) && e.state == PEER_STALE && peers_alive_count() == 0 && events_since(mark) == 1 &&
          events[mark].kind == PEER_CHANGED && events[mark].from == PEER_ALIVE && events[mark].to == PEER_STALE,
          "past it, stale, and the subscriber hears so once");
    peers_tick(heard_at + 60 * SECOND);
    CHECK(events_since(mark) == 1, "nothing more while it stays stale");
    peers_tick(heard_at + PEER_GONE_NS + SECOND);
    CHECK(peers_lookup("beta", &e) && e.state == PEER_GONE && events_since(mark) == 2 && events[mark + 1].to == PEER_GONE,
          "past five minutes, gone, but still in the table");
    now = heard_at + PEER_GONE_NS + 2 * SECOND;
    drain(LINK_RADIO, NULL);
    say_here(LINK_RADIO, PEER_HERE, 5, BETA, beta_ip, "beta");
    net_poll(now);
    CHECK(peers_lookup("beta", &e) && e.state == PEER_ALIVE && events_since(mark) == 3 &&
          events[mark + 2].kind == PEER_CHANGED && events[mark + 2].from == PEER_GONE,
          "heard again, alive again: a change, not a new peer");

    /* --- both links ------------------------------------------------------- */
    twin_link_set(LINK_CABLE, 1, ME_CABLE);
    run(&now, 12 * SECOND);
    CHECK(net_address(LINK_CABLE) != 0, "the cable takes an address of its own");
    say_here(LINK_RADIO, PEER_HERE, 6, BETA, beta_ip, "beta");
    say_here(LINK_CABLE, PEER_HERE, 6, BETA_CABLE, NET_IP(169, 254, 30, 3), "beta");
    net_poll(now);
    int count = peers_list(NULL, 0);
    CHECK(peers_lookup("beta", &e) && e.link[LINK_RADIO].state == PEER_ALIVE && e.link[LINK_CABLE].state == PEER_ALIVE &&
          memcmp(e.link[LINK_CABLE].address, BETA_CABLE, 6) == 0 && count == 1,
          "one peer on both links is one entry with both filled in");
    own.count = 0;
    peers_tick(now + PEER_ANNOUNCE_NS);
    drain(LINK_RADIO, &own);
    drain(LINK_CABLE, &own);
    CHECK(own.count == 2, "and the device announces itself on both");
    mark = events_since(0);
    say_here(LINK_CABLE, PEER_LEAVING, 7, BETA_CABLE, NET_IP(169, 254, 30, 3), "beta");
    net_poll(now);
    CHECK(peers_lookup("beta", &e) && e.link[LINK_CABLE].state == PEER_GONE && e.link[LINK_RADIO].state == PEER_ALIVE &&
          e.state == PEER_ALIVE && events_since(mark) == 1 && events[mark].link == LINK_CABLE &&
          events[mark].to == PEER_GONE,
          "saying it is leaving on the cable is gone there at once, still alive by radio (cable %d, radio %d, %d events)",
          e.link[LINK_CABLE].state, e.link[LINK_RADIO].state, events_since(mark));
    peers_tick(now + SECOND);
    CHECK(events_since(mark) == 1 && peers_lookup("beta", &e) && e.link[LINK_CABLE].state == PEER_GONE,
          "and stays gone there");

    /* --- a full table ----------------------------------------------------- */
    before = peers_counts();
    for (int i = 0; i < PEER_MAX + 2; i++) {
        uint8_t address[6] = { 0x02, 0x60, 0, 0, 0, (uint8_t)i };
        char other[16];
        snprintf(other, sizeof other, "dev-%d", i);
        say_here(LINK_RADIO, PEER_HERE, 1, address, NET_IP(169, 254, 40, i + 1), other);
    }
    net_poll(now);
    after = peers_counts();
    CHECK(peers_list(NULL, 0) == PEER_MAX && after.full - before.full == 3,
          "the table holds %d peers and counts the ones it cannot (%llu)", PEER_MAX,
          (unsigned long long)(after.full - before.full));
    twin_engine_settle(5000);

    /* --- the map ---------------------------------------------------------- */
    peers_unsubscribe(program_station(p, "keep"), 0);
    own.count = 0;
    struct net_runner net;
    struct peers_runner peers;
    twin_link_set(LINK_CABLE, 0, NULL);
    twin_link_set(LINK_RADIO, 0, NULL);
    net_poll(0);
    twin_link_set(LINK_RADIO, 1, ME);
    CHECK(net_start(&net, &report) >= 0 && peers_start(&peers, &report) >= 0, "the net and peers maps start (%s)",
          report.text);
    int waited = 0;
    while (own.count == 0 && waited < 15000) {
        sleep_ms(100);
        waited += 100;
        drain(LINK_RADIO, &own);
    }
    peers_stop(&peers);
    net_stop(&net);
    twin_engine_settle(10000);
    drain(LINK_RADIO, &own);
    CHECK(own.count >= 1 && engine_station_runs(program_station(peers.program, "tick")) >= 2,
          "on their own timers the link takes an address and the device announces itself (%d, %llu ticks)",
          own.count, (unsigned long long)engine_station_runs(program_station(peers.program, "tick")));
    twin_link_set(LINK_RADIO, 0, NULL);

    twin_engine_stop();
    metrics_close();
    CHECK_DONE("123 peers");
}
