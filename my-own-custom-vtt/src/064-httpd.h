/*
 * 064-httpd.h -- the smallest thing that can hand a browser a page and a socket.
 *
 * This runs inside the BRIDGE, on the participant's own machine, listening on
 * loopback and serving exactly one person: themselves.
 *
 * That is the whole reason it may be this small. It is not a web server and must
 * not grow into one -- an HTTP bug here compromises somebody who already had the
 * files.
 *
 *   Does                              Does not
 *   ----                              --------
 *   GET / and a fixed list of files   Virtual hosts
 *   GET /socket -- websocket upgrade  Directory listing, ever
 *   Anything else -- 404, one line    Uploads, cookies, sessions, compression
 *
 * A FIXED LIST, NOT A DIRECTORY. Serving a path from a request means handling
 * ".." correctly forever; serving from a list means the question never arises.
 *
 * IT BINDS LOOPBACK ONLY. A bridge listening on a network interface is a web
 * server on somebody's machine that they did not ask for.
 *
 * See docs/002-the-three-programs.md and issues/502.
 */

#ifndef VTT_HTTPD_H
#define VTT_HTTPD_H

#include <stdint.h>

/* One file this server will hand over, keyed by exact path. */
struct served_file {
    const char *path;         /* "/", "/view.js" -- matched exactly. */
    const char *content_type;
    const char *body;
    uint32_t    length;
};

/* A browser that has upgraded to a websocket. */
#define HTTPD_MAX_CLIENTS 4

struct websocket_client {
    int      socket;          /* -1 when unused. */
    uint8_t  connected;

    /* Partial frames arrive constantly; this is where an incomplete one waits. */
    uint8_t *incoming;
    uint32_t incoming_count;
    uint32_t incoming_capacity;
};

struct httpd {
    int      socket;
    uint16_t port;

    const struct served_file *files;
    uint32_t                  file_count;

    struct websocket_client clients[HTTPD_MAX_CLIENTS];

    uint64_t bytes_served;
    uint64_t frames_sent;
    uint64_t frames_received;
};

/*
 * Start listening on loopback. Returns 1 on success, 0 with a sentence through
 * `why` -- because somebody whose bridge will not start needs to know whether the
 * port is taken or something else went wrong.
 */
int httpd_start(struct httpd *h, uint16_t port,
                const struct served_file *files, uint32_t file_count,
                const char **why);

void httpd_stop(struct httpd *h);

/*
 * Accept and answer whatever is waiting, without blocking. Serves files, upgrades
 * websockets, and reads frames into `into`.
 * Returns how many bytes of websocket payload arrived.
 */
uint32_t httpd_poll(struct httpd *h, uint8_t *into, uint32_t into_capacity);

/* Send a binary frame to every connected browser. */
uint32_t httpd_broadcast(struct httpd *h, const uint8_t *payload, uint32_t length);

/* How many browsers are attached. */
uint32_t httpd_client_count(const struct httpd *h);

/*
 * The two pieces the websocket handshake needs, exposed because they are worth
 * testing directly rather than only through a socket.
 */
void sha1_digest(const uint8_t *data, uint32_t length, uint8_t out[20]);
uint32_t base64_encode(const uint8_t *data, uint32_t length, char *out, uint32_t out_capacity);

#endif
