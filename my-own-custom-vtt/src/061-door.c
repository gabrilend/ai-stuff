/*
 * 061-door.c -- binding, accepting, and handing out ports.
 *
 * Interface and reasoning are in 061-door.h.
 *
 * This is the only file in the server that knows what a socket is. Everything
 * above it -- the filter, the gauntlet, the tick -- works on buffers, which is
 * what lets the leak test run exhaustively on every build without a network.
 */

#include "061-door.h"

#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/* {{{ static int make_nonblocking */
static int make_nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL, 0);

    if (flags < 0) {
        return 0;
    }

    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}
/* }}} */

/* {{{ static int listen_on */
static int listen_on(uint16_t port)
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    int reuse = 1;

    if (fd < 0) {
        return -1;
    }

    /*
     * Without this, a port stays unusable for a minute or two after the server
     * stops -- which turns "restart the server" into "wait, then restart the
     * server", and is the single most annoying thing about writing one.
     */
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        close(fd);
        return -1;
    }

    if (listen(fd, 8) < 0) {
        close(fd);
        return -1;
    }

    if (!make_nonblocking(fd)) {
        close(fd);
        return -1;
    }

    return fd;
}
/* }}} */

/* {{{ int door_open */
int door_open(struct door *d, uint16_t port,
              uint16_t range_first, uint16_t range_last,
              const char **why)
{
    memset(d, 0, sizeof(struct door));
    d->socket = -1;

    if (range_last < range_first) {
        *why = "the port range runs backwards";
        return 0;
    }

    d->port = port;
    d->range_first = range_first;
    d->range_last = range_last;

    d->taken_bytes = (uint32_t)(((range_last - range_first) + 1 + 7) / 8);
    d->taken = calloc((size_t)d->taken_bytes, 1);
    if (d->taken == NULL) {
        *why = "could not remember which ports are in use";
        return 0;
    }

    d->socket = listen_on(port);
    if (d->socket < 0) {
        free(d->taken);
        d->taken = NULL;
        /*
         * Named, so a host knows which number to change. "Failed to start" would
         * be true and would tell them nothing.
         */
        *why = "could not bind the door port -- something else is using it, "
               "or it is below 1024 and this process is not privileged";
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ void door_close */
void door_close(struct door *d)
{
    if (d->socket >= 0) {
        close(d->socket);
        d->socket = -1;
    }

    free(d->taken);
    d->taken = NULL;
    d->taken_bytes = 0;
}
/* }}} */

/* {{{ static int claim_port */
static int claim_port(struct door *d, uint16_t *port)
{
    uint32_t span = (uint32_t)(d->range_last - d->range_first) + 1u;
    uint32_t i;

    for (i = 0; i < span; i++) {
        if ((d->taken[i / 8] & (uint8_t)(1u << (i % 8))) == 0) {
            d->taken[i / 8] |= (uint8_t)(1u << (i % 8));
            *port = (uint16_t)(d->range_first + i);
            return 1;
        }
    }

    return 0;
}
/* }}} */

/* {{{ static void release_port */
static void release_port(struct door *d, uint16_t port)
{
    uint32_t i;

    if (port < d->range_first || port > d->range_last) {
        return;
    }

    i = (uint32_t)(port - d->range_first);
    d->taken[i / 8] &= (uint8_t)~(1u << (i % 8));
}
/* }}} */

/* {{{ uint32_t door_ports_in_use */
uint32_t door_ports_in_use(const struct door *d)
{
    uint32_t span = (uint32_t)(d->range_last - d->range_first) + 1u;
    uint32_t total = 0;
    uint32_t i;

    for (i = 0; i < span; i++) {
        if ((d->taken[i / 8] & (uint8_t)(1u << (i % 8))) != 0) {
            total++;
        }
    }

    return total;
}
/* }}} */

/* {{{ const char *join_sentence */
const char *join_sentence(uint8_t outcome)
{
    switch (outcome) {
    case JOIN_ACCEPTED:
        return "welcome";
    case JOIN_NOT_OUR_PROTOCOL:
        return "that is not this protocol -- the first four bytes were wrong";
    case JOIN_WRONG_VERSION:
        return "this client and this server speak different versions";
    case JOIN_NAME_TOO_LONG:
        return "that name is longer than this server will hold";
    case JOIN_RANGE_FULL:
        return "every port in the range is in use -- the host needs to widen it";
    case JOIN_NO_ROOM:
        return "the table is full";
    default:
        return "refused, for a reason nobody wrote down -- which is a bug";
    }
}
/* }}} */

/* {{{ static int read_exactly */
static int read_exactly(int fd, uint8_t *into, uint32_t length)
{
    uint32_t got = 0;
    int attempts = 0;

    /*
     * The join is small and the client has just connected, so a short read means
     * the packet is still in flight rather than that anything is wrong. Bounded
     * attempts, because an attacker who connects and says nothing must not hold
     * the door open.
     */
    while (got < length && attempts < 1000) {
        ssize_t n = recv(fd, into + got, (size_t)(length - got), 0);

        if (n > 0) {
            got += (uint32_t)n;
            continue;
        }

        if (n == 0) {
            return 0;   /* They hung up. */
        }

        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            return 0;
        }

        attempts++;
    }

    return got == length;
}
/* }}} */

/* {{{ static void reply_and_close */
static void reply_and_close(int fd, uint8_t outcome, uint16_t port)
{
    uint8_t reply[8];

    /*
     * A refusal is answered before the socket closes. A silent drop would leave
     * somebody who mistyped a password unable to learn that they mistyped a
     * password.
     */
    reply[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
    reply[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
    reply[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
    reply[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
    reply[4] = outcome;
    reply[5] = 0;
    reply[6] = (uint8_t)(port & 0xFFu);
    reply[7] = (uint8_t)((port >> 8) & 0xFFu);

    send(fd, reply, sizeof(reply), MSG_NOSIGNAL);
    close(fd);
}
/* }}} */

/* {{{ uint32_t door_admit */
uint32_t door_admit(struct door *d, struct viewer_set *set,
                    const struct world *w, wcoord fog_cell)
{
    uint32_t admitted = 0;

    for (;;) {
        struct sockaddr_in from;
        socklen_t from_length = sizeof(from);
        int fd = accept(d->socket, (struct sockaddr *)&from, &from_length);
        uint8_t header[8];
        uint32_t magic;
        uint16_t version;
        uint16_t name_length;
        char name[JOIN_NAME_MAX + 1];
        uint16_t port = 0;
        uint32_t index;

        if (fd < 0) {
            break;   /* Nothing waiting. */
        }

        make_nonblocking(fd);

        if (!read_exactly(fd, header, sizeof(header))) {
            close(fd);
            d->joins_refused++;
            continue;
        }

        magic = (uint32_t)header[0] | ((uint32_t)header[1] << 8)
              | ((uint32_t)header[2] << 16) | ((uint32_t)header[3] << 24);
        version = (uint16_t)((uint32_t)header[4] | ((uint32_t)header[5] << 8));
        name_length = (uint16_t)((uint32_t)header[6] | ((uint32_t)header[7] << 8));

        /*
         * A wrong magic costs one comparison, which is the point of having one:
         * a stray port scanner is turned away before anything else is read.
         */
        if (magic != JOIN_MAGIC) {
            reply_and_close(fd, JOIN_NOT_OUR_PROTOCOL, 0);
            d->joins_refused++;
            continue;
        }

        if (version != JOIN_VERSION) {
            reply_and_close(fd, JOIN_WRONG_VERSION, 0);
            d->joins_refused++;
            continue;
        }

        /*
         * A length past the bound is refused rather than clamped. Clamping would
         * leave the rest of the name in the stream to be read as something else.
         */
        if (name_length > JOIN_NAME_MAX) {
            reply_and_close(fd, JOIN_NAME_TOO_LONG, 0);
            d->joins_refused++;
            continue;
        }

        if (name_length > 0 && !read_exactly(fd, (uint8_t *)name, name_length)) {
            close(fd);
            d->joins_refused++;
            continue;
        }
        name[name_length] = '\0';

        if (!claim_port(d, &port)) {
            reply_and_close(fd, JOIN_RANGE_FULL, 0);
            d->joins_refused++;
            continue;
        }

        index = viewer_add(set, w, fog_cell);
        if (index == 0) {
            release_port(d, port);
            reply_and_close(fd, JOIN_NO_ROOM, 0);
            d->joins_refused++;
            continue;
        }

        {
            struct viewer *v = viewer_at(set, index);

            v->port = port;
            v->address = ntohl(from.sin_addr.s_addr);
            v->socket = listen_on(port);

            if (v->socket < 0) {
                release_port(d, port);
                viewer_departs(set, index);
                viewer_at(set, index)->state = VIEWER_EMPTY;
                reply_and_close(fd, JOIN_RANGE_FULL, 0);
                d->joins_refused++;
                continue;
            }

            /*
             * PERMISSION IS NOT IN THE REQUEST. A client cannot ask to be a GM;
             * the server looks up what they may command and informs them. That is
             * enforced by the request having no field for it rather than by a
             * check that could be forgotten.
             */
        }

        reply_and_close(fd, JOIN_ACCEPTED, port);
        d->joins_accepted++;
        admitted++;
    }

    return admitted;
}
/* }}} */

/* {{{ uint32_t door_connect_waiting */
uint32_t door_connect_waiting(struct door *d, struct viewer_set *set)
{
    uint32_t connected = 0;
    uint32_t i;

    (void)d;

    for (i = 1; i < viewer_count(set); i++) {
        struct viewer *v = viewer_at(set, i);
        struct sockaddr_in from;
        socklen_t from_length = sizeof(from);
        int fd;

        if (v->state != VIEWER_WAITING || v->socket < 0) {
            continue;
        }

        fd = accept(v->socket, (struct sockaddr *)&from, &from_length);
        if (fd < 0) {
            continue;
        }

        /*
         * From the address the join came from, or not at all. The port is the
         * identity, and somebody else connecting to it would be somebody else
         * wearing it.
         */
        if (ntohl(from.sin_addr.s_addr) != v->address) {
            close(fd);
            continue;
        }

        make_nonblocking(fd);

        /* The listening socket has done its job; the connection replaces it. */
        close(v->socket);
        v->socket = fd;
        v->state = VIEWER_CONNECTED;

        connected++;
    }

    return connected;
}
/* }}} */

/* {{{ uint32_t door_drain */
uint32_t door_drain(struct door *d, struct viewer_set *set)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 1; i < viewer_count(set); i++) {
        struct viewer *v = viewer_at(set, i);
        uint8_t chunk[512];
        uint32_t read_this_beat = 0;

        if (v->state != VIEWER_CONNECTED) {
            continue;
        }

        /*
         * Bounded per viewer per beat. Without the bound, one participant
         * flooding their socket starves every other viewer's intake for as long
         * as they keep it up -- not by exploiting anything, just by talking a lot.
         */
        while (read_this_beat < VIEWER_INTAKE_PER_TICK) {
            ssize_t n = recv(v->socket, chunk, sizeof(chunk), 0);
            ssize_t byte;

            if (n == 0) {
                /* A clean hang-up. */
                close(v->socket);
                viewer_departs(set, i);
                release_port(d, v->port);
                break;
            }

            if (n < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;   /* Nothing more right now. */
                }

                close(v->socket);
                viewer_departs(set, i);
                release_port(d, v->port);
                break;
            }

            for (byte = 0; byte < n; byte++) {
                if (v->inbound.count < v->inbound.capacity) {
                    v->inbound.bytes[v->inbound.count] = chunk[byte];
                    v->inbound.count++;
                }
            }

            read_this_beat += (uint32_t)n;
            v->bytes_received += (uint64_t)n;
            total += (uint32_t)n;
        }
    }

    return total;
}
/* }}} */

/* {{{ uint32_t door_flush */
uint32_t door_flush(struct door *d, struct viewer_set *set)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 1; i < viewer_count(set); i++) {
        struct viewer *v = viewer_at(set, i);
        uint32_t written = 0;

        if (v->state != VIEWER_CONNECTED || v->outbound.count == 0) {
            continue;
        }

        while (written < v->outbound.count) {
            ssize_t n = send(v->socket, v->outbound.bytes + written,
                             (size_t)(v->outbound.count - written), MSG_NOSIGNAL);

            if (n <= 0) {
                if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                    /*
                     * Their receive window is full. The rest is dropped rather
                     * than queued, because the next update is the whole picture
                     * anyway -- an update is not a difference, so a missed one
                     * costs a beat of freshness and nothing else.
                     */
                    break;
                }

                close(v->socket);
                viewer_departs(set, i);
                release_port(d, v->port);
                break;
            }

            written += (uint32_t)n;
        }

        total += written;
    }

    return total;
}
/* }}} */

/* {{{ int door_join_as_client */
int door_join_as_client(uint16_t door_port, const char *name,
                        uint8_t *outcome, uint16_t *port)
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    uint8_t header[8];
    uint8_t reply[8];
    uint16_t name_length = (uint16_t)strlen(name);
    uint32_t got = 0;

    *outcome = JOIN_NOT_OUR_PROTOCOL;
    *port = 0;

    if (fd < 0) {
        return -1;
    }

    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(door_port);

    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        close(fd);
        return -1;
    }

    header[0] = (uint8_t)(JOIN_MAGIC & 0xFFu);
    header[1] = (uint8_t)((JOIN_MAGIC >> 8) & 0xFFu);
    header[2] = (uint8_t)((JOIN_MAGIC >> 16) & 0xFFu);
    header[3] = (uint8_t)((JOIN_MAGIC >> 24) & 0xFFu);
    header[4] = (uint8_t)(JOIN_VERSION & 0xFFu);
    header[5] = 0;
    header[6] = (uint8_t)(name_length & 0xFFu);
    header[7] = (uint8_t)((name_length >> 8) & 0xFFu);

    send(fd, header, sizeof(header), MSG_NOSIGNAL);
    if (name_length > 0) {
        send(fd, name, (size_t)name_length, MSG_NOSIGNAL);
    }

    while (got < sizeof(reply)) {
        ssize_t n = recv(fd, reply + got, sizeof(reply) - got, 0);
        if (n <= 0) {
            close(fd);
            return -1;
        }
        got += (uint32_t)n;
    }

    close(fd);

    *outcome = reply[4];
    *port = (uint16_t)((uint32_t)reply[6] | ((uint32_t)reply[7] << 8));

    if (*outcome != JOIN_ACCEPTED) {
        return -1;
    }

    /* Now connect to the port we were given. */
    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    address.sin_port = htons(*port);

    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        close(fd);
        return -1;
    }

    return fd;
}
/* }}} */
