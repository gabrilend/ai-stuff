/*
 * 126-test-transport.c — issue 709, over the twin's STAND-IN LINK:
 * sending to a peer by name, and hearing who sent what.
 *
 * General description: the device has both links up, radio and cable,
 * each with its own address, and the test plays a peer called beta on
 * both. Checked: a send by name goes by the cable while the cable is
 * alive, by the radio once the cable has gone stale and the radio has
 * not, by a stale link when nothing is alive, and nowhere when both are
 * gone or the name was never heard. Our own link with no address is no
 * route. Messages from beta arrive on a bound port with beta's name,
 * whichever link they came by; one from a device the table does not
 * know is dropped. And the boxes: send_to_peer sends from a map, and the
 * box-side message is the system's, byte for byte.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/system/118-net.h"
#include "../../src/system/121-peers.h"
#include "../../src/system/124-transport.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "../046-metrics.h"
#include "../117-link-twin.h"
#include "047-check.h"

#include <stdio.h>
#include <string.h>

#define CORES 4
#define SECOND 1000000000ull

static const uint8_t ME[6]         = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x01 };
static const uint8_t ME_CABLE[6]   = { 0x02, 0x50, 0x52, 0x00, 0x01, 0x01 };
static const uint8_t BETA[6]       = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x02 };
static const uint8_t BETA_CABLE[6] = { 0x02, 0x50, 0x52, 0x00, 0x01, 0x02 };
static const uint8_t STRANGER[6]   = { 0x02, 0x50, 0x52, 0x00, 0x00, 0x09 };
static const uint8_t ALL[6]        = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
#define BETA_RADIO_IP NET_IP(169, 254, 20, 2)
#define BETA_CABLE_IP NET_IP(169, 254, 30, 3)

/* {{{ the links */
static void drain(int link)
{
    uint8_t frame[LINK_FRAME_MAX];
    while (twin_link_take(link, frame, sizeof frame) > 0) {
    }
}

/* The next UDP datagram the device sent on `link` to `port`, read into
 * `f` (whose bytes point into `frame`): 1, or 0 if none. */
static int sent_to(int link, uint16_t port, uint8_t *frame, struct net_frame *f)
{
    int n;
    while ((n = twin_link_take(link, frame, LINK_FRAME_MAX)) > 0) {
        if (net_read_frame(frame, (size_t)n, f) == 2 && f->to_port == port) return 1;
    }
    return 0;
}

static void run(uint64_t *now, uint64_t ns)
{
    for (uint64_t end = *now + ns; *now < end; *now += 50000000ull) {
        net_poll(*now);
        drain(LINK_RADIO);
        drain(LINK_CABLE);
    }
}

static void beta_here(int link, uint64_t now)
{
    uint8_t message[PEER_ANNOUNCEMENT_BYTES], frame[LINK_FRAME_MAX];
    const uint8_t *address = link == LINK_CABLE ? BETA_CABLE : BETA;
    uint32_t ip = link == LINK_CABLE ? BETA_CABLE_IP : BETA_RADIO_IP;
    peers_build_announcement(message, PEER_HERE, 1, address, ip, "beta");
    twin_link_put(link, frame, (size_t)net_build_udp(frame, address, ALL, ip, NET_BROADCAST, PEER_PORT, PEER_PORT,
                                                    message, sizeof message));
    net_poll(now);
}

static void put_from(int link, const uint8_t *from, uint32_t from_ip, uint32_t to_ip, uint16_t port, const char *text)
{
    uint8_t frame[LINK_FRAME_MAX];
    uint8_t to[6];
    link_address(link, to);
    twin_link_put(link, frame, (size_t)net_build_udp(frame, from, to, from_ip, to_ip, port, port, text, strlen(text)));
}
/* }}} */

/* {{{ a box that keeps what arrives */
static struct transport_message got[8];
static int n_got;
static void keep_call(const void *in, void *out)
{
    (void)out;
    int at = __atomic_fetch_add(&n_got, 1, __ATOMIC_SEQ_CST);
    if (at < 8) memcpy(&got[at], in, sizeof got[at]);
}
static const struct box_param keep_params[] = { { "m", "struct transport_message", sizeof(struct transport_message), 0 } };
static const struct box keep_box = { "keep", __FILE__, keep_call, 1, keep_params,
                                     (sizeof(struct transport_message) + 7) & ~7u, 0, "void" };
/* }}} */

/* The box side's outgoing value, as the map's argument carries it. */
struct outgoing_value {
    char    to[32];
    int32_t port;
    int32_t length;
    uint8_t bytes[NET_PAYLOAD_MAX];
};

int main(void)
{
    twin_engine_start(CORES, (size_t)256 << 20);
    engine_open_gate();
    metrics_open("126-transport");
    struct map_report report;
    uint64_t now = 3000 * SECOND;
    uint8_t frame[LINK_FRAME_MAX];
    struct net_frame f;
    peers_init();
    peers_set_name("alpha");

    /* --- before anything -------------------------------------------------- */
    CHECK(transport_send("beta", 5000, "hi", 2) == TRANSPORT_NO_PEER && transport_route("beta") == TRANSPORT_NO_PEER,
          "a peer never heard of cannot be sent to");

    /* --- both links, and beta on both ------------------------------------ */
    twin_link_set(LINK_RADIO, 1, ME);
    twin_link_set(LINK_CABLE, 1, ME_CABLE);
    run(&now, 12 * SECOND);
    uint32_t radio_ip = net_address(LINK_RADIO), cable_ip = net_address(LINK_CABLE);
    CHECK(radio_ip && cable_ip && radio_ip != cable_ip, "each link takes an address of its own");
    beta_here(LINK_RADIO, now);
    beta_here(LINK_CABLE, now);
    uint64_t both_heard = now;

    /* --- choosing the link ----------------------------------------------- */
    drain(LINK_RADIO);
    drain(LINK_CABLE);
    int r = transport_send("beta", 5000, "by cable", 8);
    CHECK(r == LINK_CABLE && sent_to(LINK_CABLE, 5000, frame, &f) && bytes_equal(f.to_address, BETA_CABLE, 6) &&
          f.to_ip == BETA_CABLE_IP && f.from_ip == cable_ip && f.from_port == 5000 && f.length == 8 &&
          memcmp(f.bytes, "by cable", 8) == 0 && !sent_to(LINK_RADIO, 5000, frame, &f),
          "alive on both, it goes by the cable, to beta's cable address, from ours (%d)", r);
    now = both_heard + 15 * SECOND;
    beta_here(LINK_RADIO, now);                        /* the cable is pulled; the radio still hears beta */
    peers_tick(both_heard + PEER_ALIVE_NS + SECOND);
    drain(LINK_RADIO);
    drain(LINK_CABLE);
    r = transport_send("beta", 5000, "by radio", 8);
    CHECK(r == LINK_RADIO && sent_to(LINK_RADIO, 5000, frame, &f) && bytes_equal(f.to_address, BETA, 6) &&
          f.to_ip == BETA_RADIO_IP && f.from_ip == radio_ip && !sent_to(LINK_CABLE, 5000, frame, &f),
          "once the cable has gone stale, the next send goes by radio, unasked (%d)", r);
    peers_tick(now + PEER_ALIVE_NS + SECOND);
    CHECK(transport_route("beta") == LINK_CABLE, "with both stale, the cable is tried first");
    peers_tick(now + PEER_GONE_NS + SECOND);
    CHECK(transport_send("beta", 5000, "x", 1) == TRANSPORT_UNREACHABLE, "with both gone, nothing reaches beta");
    now += PEER_GONE_NS + 2 * SECOND;
    beta_here(LINK_RADIO, now);
    beta_here(LINK_CABLE, now);
    twin_link_set(LINK_CABLE, 0, NULL);
    net_poll(now);
    CHECK(transport_route("beta") == LINK_RADIO, "our own cable down, with no address, is no route even while beta is alive on it");
    static uint8_t big[NET_PAYLOAD_MAX + 1];
    CHECK(transport_send("beta", 5000, big, sizeof big) == NET_TOO_BIG, "too much for one datagram is refused");
    twin_link_set(LINK_CABLE, 1, ME_CABLE);
    run(&now, 12 * SECOND);
    cable_ip = net_address(LINK_CABLE);
    beta_here(LINK_RADIO, now);
    beta_here(LINK_CABLE, now);
    CHECK(cable_ip && transport_route("beta") == LINK_CABLE, "the cable back, and it is the route again");

    /* --- hearing ---------------------------------------------------------- */
    CHECK(catalogue_add("src/boxes/999-transport.c:keep", &keep_box) == 0, "a box that keeps messages joins the catalogue");
    const struct box *rb = catalogue_box("src/boxes/125-transport.c:received");
    CHECK(rb && rb->params[0].size == sizeof(struct transport_message) && rb->return_size == sizeof(struct transport_message),
          "the boxes' message is the system's transport_message, byte for byte");
    const char *map = "station keep (../boxes/999-transport.c:keep)\n  in 0 - 0$\n";
    int p = program_load_text("src/maps/keep.map", map, strlen(map), &report);
    CHECK(p >= 0 && program_bring_up(p, &report) == 0 && transport_listen(6000, program_station(p, "keep"), 0) == NET_OK &&
          transport_listen(6000, 0, 0) == NET_TAKEN, "it is bound to port 6000, which nobody else may have (%s)",
          report.text);
    put_from(LINK_CABLE, BETA_CABLE, BETA_CABLE_IP, cable_ip, 6000, "over the cable");
    net_poll(now);
    twin_engine_settle(5000);
    CHECK(n_got == 1 && strcmp(got[0].from, "beta") == 0 && got[0].port == 6000 && got[0].link == LINK_CABLE &&
          got[0].length == 14 && memcmp(got[0].bytes, "over the cable", 14) == 0,
          "a message from beta by cable arrives with beta's name");
    put_from(LINK_RADIO, BETA, BETA_RADIO_IP, radio_ip, 6000, "over the air");
    net_poll(now);
    twin_engine_settle(5000);
    CHECK(n_got == 2 && strcmp(got[1].from, "beta") == 0 && got[1].link == LINK_RADIO,
          "and by radio with the same name");
    put_from(LINK_RADIO, STRANGER, NET_IP(169, 254, 50, 5), radio_ip, 6000, "who am I");
    net_poll(now);
    twin_engine_settle(5000);
    CHECK(n_got == 2 && transport_dropped_unknown() == 1, "one from a device never heard announcing is dropped");

    /* --- sending from a box ----------------------------------------------- */
    const char *sender = "station send (../boxes/125-transport.c:send_to_peer)\n  in 0 - 0$\n  out 0 - 0$\n";
    int ps = program_load_text("src/maps/sender.map", sender, strlen(sender), &report);
    CHECK(ps >= 0 && program_bring_up(ps, &report) == 0, "a map that sends loads (%s)", report.text);
    static struct outgoing_value out;
    memset(&out, 0, sizeof out);
    strcpy(out.to, "beta");
    out.port = 5001;
    out.length = 7;
    memcpy(out.bytes, "a box's", 7);
    drain(LINK_CABLE);
    program_argument(ps, 0, &out, sizeof out);
    twin_engine_settle(5000);
    int64_t answer = -99;
    CHECK(program_result(ps, 0, &answer, sizeof answer) == 1 && answer == LINK_CABLE &&
          sent_to(LINK_CABLE, 5001, frame, &f) && f.length == 7 && memcmp(f.bytes, "a box's", 7) == 0,
          "send_to_peer sends by name from a map, and says which link (%lld)", (long long)answer);
    strcpy(out.to, "nobody");
    program_argument(ps, 0, &out, sizeof out);
    twin_engine_settle(5000);
    CHECK(program_result(ps, 0, &answer, sizeof answer) == 1 && answer == TRANSPORT_NO_PEER,
          "and says so when there is no such peer (%lld)", (long long)answer);

    twin_link_set(LINK_RADIO, 0, NULL);
    twin_link_set(LINK_CABLE, 0, NULL);
    twin_engine_stop();
    metrics_close();
    CHECK_DONE("126 transport");
}
