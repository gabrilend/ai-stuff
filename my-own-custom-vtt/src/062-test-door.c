/*
 * 062-test-door.c -- joining, being refused, and the range filling up.
 *
 * Real sockets, on loopback, in one process. The server and the clients take
 * turns rather than running concurrently, which is what a non-blocking accept
 * makes possible and is why every test here is deterministic despite involving
 * a network.
 */

#include "020-test-harness.h"
#include "061-door.h"
#include "037-fixture.h"

#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/*
 * A high, unlikely-to-be-taken door, and a range just above it. Chosen rather
 * than a well-known number so that a developer running the tests while something
 * else is listening does not get a mysterious failure.
 */
#define TEST_DOOR_PORT   47801
#define TEST_RANGE_FIRST 47810
#define TEST_RANGE_LAST  47813

/* {{{ static void test_opening_the_door */
static void test_opening_the_door(void)
{
    struct door d;
    const char *why = NULL;

    TEST_CASE("the door opens and reserves its range");

    CHECK(door_open(&d, TEST_DOOR_PORT, TEST_RANGE_FIRST, TEST_RANGE_LAST, &why) == 1);
    CHECK_EQ(door_ports_in_use(&d), 0);

    door_close(&d);

    TEST_CASE("a backwards range is refused by name");

    /*
     * A sentence, so a host knows which number to change. "Failed to start"
     * would be true and would tell them nothing.
     */
    why = NULL;
    CHECK_EQ(door_open(&d, TEST_DOOR_PORT, 500, 400, &why), 0);
    CHECK(why != NULL);
    CHECK(strstr(why, "backwards") != NULL);

    TEST_CASE("and every join outcome has a sentence");

    {
        uint8_t outcome;
        for (outcome = 0; outcome <= JOIN_NO_ANSWER; outcome++) {
            CHECK(join_sentence(outcome)[0] != '\0');
        }
        /* Including the one nobody wrote, which says so. */
        CHECK(join_sentence(200)[0] != '\0');
    }
}
/* }}} */

/* {{{ static void test_joining */
static void test_joining(void)
{
    struct door d;
    struct viewer_set set;
    struct world w;
    const char *why = NULL;
    uint8_t outcome = 0;
    uint16_t port = 0;
    int client;

    TEST_CASE("a participant joins and is given a port of their own");

    fixture_make_two_rooms(&w);
    viewer_set_init(&set, 8);
    CHECK(door_open(&d, TEST_DOOR_PORT, TEST_RANGE_FIRST, TEST_RANGE_LAST, &why) == 1);

    /*
     * The client does the whole handshake before the server is asked to look --
     * the door's reply is written and the socket closed inside door_admit, so
     * the client's first half has to have arrived by then.
     *
     * That works because door_join_as_client connects, sends, and then blocks
     * reading the reply, while door_admit is called between the two.
     */
    {
        /* Connect and send, without waiting for the reply yet. */
        int probe = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        uint8_t header[8];

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_DOOR_PORT);

        CHECK(connect(probe, (struct sockaddr *)&address, sizeof(address)) == 0);

        header[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
        header[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
        header[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
        header[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
        header[4] = JOIN_VERSION;
        header[5] = 0;
        header[6] = 5;
        header[7] = 0;

        send(probe, header, sizeof(header), MSG_NOSIGNAL);
        send(probe, "Aelfw", 5, MSG_NOSIGNAL);

        CHECK_EQ(door_admit(&d, &set, &w, WC_ONE), 1);

        {
            uint8_t reply[8];
            uint32_t got = 0;

            while (got < sizeof(reply)) {
                ssize_t n = recv(probe, reply + got, sizeof(reply) - got, 0);
                if (n <= 0) break;
                got += (uint32_t)n;
            }

            CHECK_EQ(got, 8);
            CHECK_EQ(reply[4], JOIN_ACCEPTED);

            port = (uint16_t)((uint32_t)reply[6] | ((uint32_t)reply[7] << 8));
            CHECK(port >= TEST_RANGE_FIRST);
            CHECK(port <= TEST_RANGE_LAST);
        }

        close(probe);
    }

    CHECK_EQ(door_ports_in_use(&d), 1);
    CHECK_EQ(viewer_count(&set), 2);
    CHECK_EQ(viewer_at(&set, 1)->state, VIEWER_WAITING);
    CHECK_EQ(viewer_at(&set, 1)->port, port);

    TEST_CASE("and the door holds no session -- it is a receptionist, not a room");

    /* Connecting to the private port is what makes them present. */
    {
        struct sockaddr_in address;
        client = socket(AF_INET, SOCK_STREAM, 0);

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(port);

        CHECK(connect(client, (struct sockaddr *)&address, sizeof(address)) == 0);

        CHECK_EQ(door_connect_waiting(&d, &set), 1);
        CHECK_EQ(viewer_at(&set, 1)->state, VIEWER_CONNECTED);
        CHECK_EQ(viewer_connected_count(&set), 1);

        close(client);
    }

    (void)outcome;

    door_close(&d);
    viewer_set_release(&set);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_refusals */
static void test_refusals(void)
{
    struct door d;
    struct viewer_set set;
    struct world w;
    const char *why = NULL;

    TEST_CASE("something that is not this protocol is turned away at once");

    fixture_make_two_rooms(&w);
    viewer_set_init(&set, 8);
    CHECK(door_open(&d, TEST_DOOR_PORT, TEST_RANGE_FIRST, TEST_RANGE_LAST, &why) == 1);

    {
        int probe = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        uint8_t rubbish[8];
        uint8_t reply[8];
        uint32_t got = 0;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_DOOR_PORT);

        connect(probe, (struct sockaddr *)&address, sizeof(address));

        memset(rubbish, 0x5A, sizeof(rubbish));
        send(probe, rubbish, sizeof(rubbish), MSG_NOSIGNAL);

        door_admit(&d, &set, &w, WC_ONE);

        while (got < sizeof(reply)) {
            ssize_t n = recv(probe, reply + got, sizeof(reply) - got, 0);
            if (n <= 0) break;
            got += (uint32_t)n;
        }

        CHECK_EQ(got, 8);
        CHECK_EQ(reply[4], JOIN_NOT_OUR_PROTOCOL);

        /* And it took no port and made no viewer. */
        CHECK_EQ(door_ports_in_use(&d), 0);
        CHECK_EQ(viewer_count(&set), 1);
        CHECK_EQ(d.joins_refused, 1);

        close(probe);
    }

    TEST_CASE("a version skew is refused, and answered rather than dropped");

    {
        int probe = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        uint8_t header[8];
        uint8_t reply[8];
        uint32_t got = 0;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_DOOR_PORT);

        connect(probe, (struct sockaddr *)&address, sizeof(address));

        header[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
        header[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
        header[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
        header[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
        header[4] = 99;   /* from the future */
        header[5] = 0;
        header[6] = 0;
        header[7] = 0;

        send(probe, header, sizeof(header), MSG_NOSIGNAL);

        door_admit(&d, &set, &w, WC_ONE);

        while (got < sizeof(reply)) {
            ssize_t n = recv(probe, reply + got, sizeof(reply) - got, 0);
            if (n <= 0) break;
            got += (uint32_t)n;
        }

        CHECK_EQ(reply[4], JOIN_WRONG_VERSION);
        close(probe);
    }

    TEST_CASE("a name past the bound is refused, not cut short");

    {
        int probe = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        uint8_t header[8];
        uint8_t reply[8];
        uint32_t got = 0;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_DOOR_PORT);

        connect(probe, (struct sockaddr *)&address, sizeof(address));

        header[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
        header[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
        header[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
        header[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
        header[4] = JOIN_VERSION;
        header[5] = 0;
        header[6] = 200;   /* well past JOIN_NAME_MAX */
        header[7] = 0;

        send(probe, header, sizeof(header), MSG_NOSIGNAL);

        door_admit(&d, &set, &w, WC_ONE);

        while (got < sizeof(reply)) {
            ssize_t n = recv(probe, reply + got, sizeof(reply) - got, 0);
            if (n <= 0) break;
            got += (uint32_t)n;
        }

        CHECK_EQ(reply[4], JOIN_NAME_TOO_LONG);
        close(probe);
    }

    door_close(&d);
    viewer_set_release(&set);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_range_fills_up */
static void test_the_range_fills_up(void)
{
    struct door d;
    struct viewer_set set;
    struct world w;
    const char *why = NULL;
    int probes[8];
    int i;
    const int span = TEST_RANGE_LAST - TEST_RANGE_FIRST + 1;

    TEST_CASE("the range filling up is refused by name, not by silence");

    /*
     * This is the design's real cost surfacing. A host who forwarded four ports
     * and invited five people needs to be told which number to change.
     */
    fixture_make_two_rooms(&w);
    viewer_set_init(&set, 16);
    CHECK(door_open(&d, TEST_DOOR_PORT, TEST_RANGE_FIRST, TEST_RANGE_LAST, &why) == 1);

    for (i = 0; i < span + 1; i++) {
        struct sockaddr_in address;
        uint8_t header[8];
        uint8_t reply[8];
        uint32_t got = 0;

        probes[i] = socket(AF_INET, SOCK_STREAM, 0);

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_DOOR_PORT);

        connect(probes[i], (struct sockaddr *)&address, sizeof(address));

        header[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
        header[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
        header[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
        header[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
        header[4] = JOIN_VERSION;
        header[5] = 0;
        header[6] = 0;
        header[7] = 0;

        send(probes[i], header, sizeof(header), MSG_NOSIGNAL);

        door_admit(&d, &set, &w, WC_ONE);

        while (got < sizeof(reply)) {
            ssize_t n = recv(probes[i], reply + got, sizeof(reply) - got, 0);
            if (n <= 0) break;
            got += (uint32_t)n;
        }

        if (i < span) {
            CHECK_EQ(reply[4], JOIN_ACCEPTED);
        } else {
            CHECK_EQ(reply[4], JOIN_RANGE_FULL);
            CHECK(strstr(join_sentence(reply[4]), "widen") != NULL);
        }

        close(probes[i]);
    }

    CHECK_EQ(door_ports_in_use(&d), (uint32_t)span);

    door_close(&d);
    viewer_set_release(&set);
    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_opening_the_door();
    test_joining();
    test_refusals();
    test_the_range_fills_up();

    return vtt_test_finish("062-test-door");
}
/* }}} */
