/*
 * 065-test-httpd.c -- SHA-1 against the published vectors, and a page served.
 *
 * The handshake arithmetic is checked against the values in the specification
 * rather than against itself, because an implementation that agrees with its own
 * bug produces a browser that silently never connects.
 */

#include "020-test-harness.h"
#include "064-httpd.h"

#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <fcntl.h>

#define TEST_HTTP_PORT 47950

/* {{{ static void hex_of */
static void hex_of(const uint8_t digest[20], char out[41])
{
    int i;

    for (i = 0; i < 20; i++) {
        sprintf(out + (i * 2), "%02x", digest[i]);
    }
    out[40] = '\0';
}
/* }}} */

/* {{{ static void test_sha1 */
static void test_sha1(void)
{
    uint8_t digest[20];
    char hex[41];

    TEST_CASE("SHA-1 against the published vectors");

    /*
     * These three are from the specification itself. Checking against published
     * numbers rather than against our own output is the whole point -- an
     * implementation that agrees with its own bug produces a browser that
     * silently never connects, with nothing to look at.
     */
    sha1_digest((const uint8_t *)"abc", 3, digest);
    hex_of(digest, hex);
    CHECK_EQ(strcmp(hex, "a9993e364706816aba3e25717850c26c9cd0d89d"), 0);

    sha1_digest((const uint8_t *)"", 0, digest);
    hex_of(digest, hex);
    CHECK_EQ(strcmp(hex, "da39a3ee5e6b4b0d3255bfef95601890afd80709"), 0);

    sha1_digest((const uint8_t *)
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", 56, digest);
    hex_of(digest, hex);
    CHECK_EQ(strcmp(hex, "84983e441c3bd26ebaae4aa1f95129e5e54670f1"), 0);

    TEST_CASE("and at the length where padding needs a whole extra block");

    /*
     * Fifty-six bytes leaves no room for the length in the same block, so a
     * second one carries it alone. That is the case everybody gets wrong once,
     * and it is why the vector above is exactly this long.
     */
    {
        uint8_t long_input[64];
        memset(long_input, 'a', sizeof(long_input));

        sha1_digest(long_input, 64, digest);
        hex_of(digest, hex);
        CHECK_EQ(strcmp(hex, "0098ba824b5c16427bd7a1122a5a442a25ec644d"), 0);
    }
}
/* }}} */

/* {{{ static void test_base64 */
static void test_base64(void)
{
    char out[64];

    TEST_CASE("base64, including the padded lengths");

    base64_encode((const uint8_t *)"", 0, out, sizeof(out));
    CHECK_EQ(strcmp(out, ""), 0);

    base64_encode((const uint8_t *)"f", 1, out, sizeof(out));
    CHECK_EQ(strcmp(out, "Zg=="), 0);

    base64_encode((const uint8_t *)"fo", 2, out, sizeof(out));
    CHECK_EQ(strcmp(out, "Zm8="), 0);

    base64_encode((const uint8_t *)"foo", 3, out, sizeof(out));
    CHECK_EQ(strcmp(out, "Zm9v"), 0);

    base64_encode((const uint8_t *)"foobar", 6, out, sizeof(out));
    CHECK_EQ(strcmp(out, "Zm9vYmFy"), 0);
}
/* }}} */

/* {{{ static void test_the_handshake_answer */
static void test_the_handshake_answer(void)
{
    /*
     * The worked example from RFC 6455. If this passes, a browser will accept the
     * handshake; if it does not, a browser will refuse it with no useful message
     * anywhere.
     */
    const char *key = "dGhlIHNhbXBsZSBub25jZQ==";
    const char *guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    char combined[128];
    uint8_t digest[20];
    char accept[64];

    TEST_CASE("the websocket handshake answer matches the specification's example");

    sprintf(combined, "%s%s", key, guid);
    sha1_digest((const uint8_t *)combined, (uint32_t)strlen(combined), digest);
    base64_encode(digest, 20, accept, sizeof(accept));

    CHECK_EQ(strcmp(accept, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), 0);
}
/* }}} */

/* {{{ static void test_serving */
static void test_serving(void)
{
    static const char page[] = "<!doctype html><title>hello</title>";
    static const struct served_file files[] = {
        { "/", "text/html; charset=utf-8", page, (uint32_t)(sizeof(page) - 1) }
    };

    struct httpd h;
    const char *why = NULL;

    TEST_CASE("the server starts on loopback");

    CHECK(httpd_start(&h, TEST_HTTP_PORT, files, 1, &why) == 1);

    TEST_CASE("a known path is served");

    {
        int client = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        char reply[1024];
        ssize_t got;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_HTTP_PORT);

        CHECK(connect(client, (struct sockaddr *)&address, sizeof(address)) == 0);
        send(client, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n", 35, MSG_NOSIGNAL);

        httpd_poll(&h, NULL, 0);

        got = recv(client, reply, sizeof(reply) - 1, 0);
        CHECK(got > 0);

        if (got > 0) {
            reply[got] = '\0';
            CHECK(strstr(reply, "200 OK") != NULL);
            CHECK(strstr(reply, "hello") != NULL);
        }

        close(client);
    }

    TEST_CASE("an unknown path is 404, and says nothing about what exists");

    {
        int client = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        char reply[1024];
        ssize_t got;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_HTTP_PORT);

        connect(client, (struct sockaddr *)&address, sizeof(address));
        send(client, "GET /../secret HTTP/1.1\r\n\r\n", 27, MSG_NOSIGNAL);

        httpd_poll(&h, NULL, 0);

        got = recv(client, reply, sizeof(reply) - 1, 0);
        CHECK(got > 0);

        if (got > 0) {
            reply[got] = '\0';
            CHECK(strstr(reply, "404") != NULL);

            /*
             * Files are a compiled-in table keyed by exact path, so ".." is not a
             * question this program can be asked -- there is no directory to
             * escape from.
             */
            CHECK(strstr(reply, "secret") == NULL);
        }

        close(client);
    }

    TEST_CASE("a method other than GET is refused");

    {
        int client = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        char reply[1024];
        ssize_t got;

        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        address.sin_port = htons(TEST_HTTP_PORT);

        connect(client, (struct sockaddr *)&address, sizeof(address));
        send(client, "POST / HTTP/1.1\r\n\r\n", 19, MSG_NOSIGNAL);

        httpd_poll(&h, NULL, 0);

        got = recv(client, reply, sizeof(reply) - 1, 0);
        if (got > 0) {
            reply[got] = '\0';
            CHECK(strstr(reply, "404") != NULL);
        }

        close(client);
    }

    CHECK_EQ(httpd_client_count(&h), 0);

    httpd_stop(&h);
}
/* }}} */

/* {{{ static void test_it_binds_loopback_only */
static void test_it_binds_loopback_only(void)
{
    static const char page[] = "x";
    static const struct served_file files[] = {
        { "/", "text/plain", page, 1 }
    };

    struct httpd h;
    const char *why = NULL;

    TEST_CASE("the listening socket is bound to loopback, not to every interface");

    /*
     * A bridge listening on a network interface is a web server on somebody's
     * machine that they did not ask for, and the whole security argument for
     * this program is that it serves one person: whoever is sitting at it.
     *
     * Asked of the socket directly rather than inferred from what else can bind
     * the port. An earlier version of this test tried the inference and had the
     * reasoning backwards -- binding every interface while loopback is taken
     * fails, because "every" includes loopback -- which made a passing test
     * impossible and a failing one uninformative.
     */
    CHECK(httpd_start(&h, TEST_HTTP_PORT + 1, files, 1, &why) == 1);

    {
        struct sockaddr_in bound;
        socklen_t length = sizeof(bound);

        CHECK(getsockname(h.socket, (struct sockaddr *)&bound, &length) == 0);

        CHECK_EQ(ntohl(bound.sin_addr.s_addr), INADDR_LOOPBACK);
        CHECK(ntohl(bound.sin_addr.s_addr) != INADDR_ANY);
        CHECK_EQ(ntohs(bound.sin_port), TEST_HTTP_PORT + 1);
    }

    httpd_stop(&h);
}
/* }}} */

/* {{{ static double wall_now */
static double wall_now(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + ((double)now.tv_nsec / 1000000000.0);
}
/* }}} */

/* {{{ static void test_a_browser_that_stops_reading */
static void test_a_browser_that_stops_reading(void)
{
    struct httpd h;
    int pair[2];
    uint8_t payload[8192];
    double started;
    double took;
    int round;

    TEST_CASE("sending to somebody who is not reading gives up rather than spinning");

    /*
     * THIS IS A REGRESSION TEST FOR A REAL FREEZE.
     *
     * Websocket sockets here are non-blocking, so a full receive buffer returns
     * EAGAIN. An earlier version of send_all retried immediately, with no bound
     * and no sleep -- a hot loop that pegs a processor for as long as the far
     * end stays behind. A browser tab left open in the background does exactly
     * that, and the symptom is a machine that stops responding.
     *
     * The fix is a bounded wait in slices, then dropping the rest -- which is
     * safe because an update is the whole picture rather than a difference, so a
     * missed one costs a beat of freshness and nothing else.
     *
     * The test: a socket pair whose far end never reads, filled until it will
     * take no more, and a broadcast that must RETURN rather than run forever.
     */
    memset(&h, 0, sizeof(h));
    h.socket = -1;

    {
        uint32_t i;
        for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
            h.clients[i].socket = -1;
        }
    }

    CHECK_EQ(socketpair(AF_UNIX, SOCK_STREAM, 0, pair), 0);

    /* The far end is never read from, exactly like a browser that has stalled. */
    fcntl(pair[0], F_SETFL, fcntl(pair[0], F_GETFL, 0) | O_NONBLOCK);

    h.clients[0].socket = pair[0];
    h.clients[0].connected = 1;

    memset(payload, 0x41, sizeof(payload));

    started = wall_now();

    /*
     * Enough rounds to fill any reasonable socket buffer several times over. If
     * the bug were present, the first one to find the buffer full would never
     * return and this test would hang the build rather than fail it -- which is
     * why the bound below is generous but real.
     */
    for (round = 0; round < 200; round++) {
        httpd_broadcast(&h, payload, sizeof(payload));
    }

    took = wall_now() - started;

    /*
     * Two hundred rounds, each waiting at most about ten milliseconds when the
     * far end is full, is two seconds of worst case. Anything near that means it
     * is waiting patiently; anything far beyond it means it is not giving up.
     */
    CHECK(took < 10.0);

    TEST_CASE("and the far end still got some of it before we gave up");

    {
        uint8_t drained[4096];
        ssize_t got = recv(pair[1], drained, sizeof(drained), MSG_DONTWAIT);

        /* Something arrived -- it did not simply refuse to send at all. */
        CHECK(got > 0);
    }

    close(pair[0]);
    close(pair[1]);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_sha1();
    test_base64();
    test_the_handshake_answer();
    test_serving();
    test_it_binds_loopback_only();
    test_a_browser_that_stops_reading();

    return vtt_test_finish("065-test-httpd");
}
/* }}} */
