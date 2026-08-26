/*
 * 064-httpd.c -- enough HTTP to hand over a page, and enough of RFC 6455 to work.
 *
 * Interface and reasoning are in 064-httpd.h.
 *
 * SHA-1 and base64 are here rather than borrowed, for the same reason the world
 * file's hash is: a borrowed one is a dependency to install on every
 * participant's machine, and the bridge is supposed to be one file to copy.
 * Sixty lines of SHA-1 is cheaper than that, and it is a frozen specification so
 * it will never need maintaining.
 */

#include "064-httpd.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/* ------------------------------------------------------------------------- *
 * SHA-1
 *
 * Used for exactly one thing: proving to a browser that we understood its
 * websocket handshake. It is not a security measure here -- the browser's key is
 * not a secret and the answer is not either. It is a handshake, and this is the
 * arithmetic it specifies.
 * ------------------------------------------------------------------------- */

/* {{{ static uint32_t rotate_left */
static uint32_t rotate_left(uint32_t value, uint32_t by)
{
    return (value << by) | (value >> (32 - by));
}
/* }}} */

/* {{{ void sha1_digest */
void sha1_digest(const uint8_t *data, uint32_t length, uint8_t out[20])
{
    uint32_t h[5];
    uint8_t  block[64];
    uint32_t consumed = 0;
    uint64_t bits = (uint64_t)length * 8u;
    uint32_t i;

    h[0] = 0x67452301u;
    h[1] = 0xEFCDAB89u;
    h[2] = 0x98BADCFEu;
    h[3] = 0x10325476u;
    h[4] = 0xC3D2E1F0u;

    for (;;) {
        uint32_t w[80];
        uint32_t a, b, c, d, e;
        uint32_t take;
        int final_block = 0;

        take = length - consumed;
        if (take >= 64) {
            memcpy(block, data + consumed, 64);
            consumed += 64;
        } else {
            /*
             * The tail, padded. A one bit, then zeroes, then the length in bits.
             * If there is not room for the length, a whole extra block is needed
             * -- which is the case everybody gets wrong once.
             */
            memset(block, 0, 64);
            if (take > 0) {
                memcpy(block, data + consumed, take);
            }
            block[take] = 0x80;

            if (take + 1 + 8 <= 64) {
                for (i = 0; i < 8; i++) {
                    block[63 - i] = (uint8_t)((bits >> (i * 8)) & 0xFFu);
                }
                final_block = 1;
            }

            consumed = length + 1;   /* Marks the padding as begun. */
        }

        for (i = 0; i < 16; i++) {
            w[i] = ((uint32_t)block[i * 4] << 24)
                 | ((uint32_t)block[(i * 4) + 1] << 16)
                 | ((uint32_t)block[(i * 4) + 2] << 8)
                 | ((uint32_t)block[(i * 4) + 3]);
        }

        for (i = 16; i < 80; i++) {
            w[i] = rotate_left(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
        }

        a = h[0]; b = h[1]; c = h[2]; d = h[3]; e = h[4];

        for (i = 0; i < 80; i++) {
            uint32_t f;
            uint32_t k;
            uint32_t t;

            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5A827999u;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ED9EBA1u;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8F1BBCDCu;
            } else {
                f = b ^ c ^ d;
                k = 0xCA62C1D6u;
            }

            t = rotate_left(a, 5) + f + e + k + w[i];
            e = d;
            d = c;
            c = rotate_left(b, 30);
            b = a;
            a = t;
        }

        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;

        if (final_block) {
            break;
        }

        if (consumed > length) {
            /*
             * The padding block had no room for the length, so one more block
             * carries it alone.
             */
            memset(block, 0, 64);
            for (i = 0; i < 8; i++) {
                block[63 - i] = (uint8_t)((bits >> (i * 8)) & 0xFFu);
            }

            for (i = 0; i < 16; i++) {
                w[i] = ((uint32_t)block[i * 4] << 24)
                     | ((uint32_t)block[(i * 4) + 1] << 16)
                     | ((uint32_t)block[(i * 4) + 2] << 8)
                     | ((uint32_t)block[(i * 4) + 3]);
            }
            for (i = 16; i < 80; i++) {
                w[i] = rotate_left(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
            }

            a = h[0]; b = h[1]; c = h[2]; d = h[3]; e = h[4];

            for (i = 0; i < 80; i++) {
                uint32_t f;
                uint32_t k;
                uint32_t t;

                if (i < 20)      { f = (b & c) | ((~b) & d);          k = 0x5A827999u; }
                else if (i < 40) { f = b ^ c ^ d;                      k = 0x6ED9EBA1u; }
                else if (i < 60) { f = (b & c) | (b & d) | (c & d);    k = 0x8F1BBCDCu; }
                else             { f = b ^ c ^ d;                      k = 0xCA62C1D6u; }

                t = rotate_left(a, 5) + f + e + k + w[i];
                e = d; d = c; c = rotate_left(b, 30); b = a; a = t;
            }

            h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;
            break;
        }
    }

    for (i = 0; i < 5; i++) {
        out[i * 4]       = (uint8_t)((h[i] >> 24) & 0xFFu);
        out[(i * 4) + 1] = (uint8_t)((h[i] >> 16) & 0xFFu);
        out[(i * 4) + 2] = (uint8_t)((h[i] >> 8) & 0xFFu);
        out[(i * 4) + 3] = (uint8_t)(h[i] & 0xFFu);
    }
}
/* }}} */

/* {{{ uint32_t base64_encode */
uint32_t base64_encode(const uint8_t *data, uint32_t length, char *out, uint32_t out_capacity)
{
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    uint32_t written = 0;
    uint32_t i = 0;

    while (i < length) {
        uint32_t block = 0;
        uint32_t have = 0;
        uint32_t piece;

        for (piece = 0; piece < 3; piece++) {
            block <<= 8;
            if (i < length) {
                block |= data[i];
                i++;
                have++;
            }
        }

        if (written + 4 >= out_capacity) {
            break;
        }

        out[written++] = alphabet[(block >> 18) & 0x3Fu];
        out[written++] = alphabet[(block >> 12) & 0x3Fu];
        out[written++] = (have > 1) ? alphabet[(block >> 6) & 0x3Fu] : '=';
        out[written++] = (have > 2) ? alphabet[block & 0x3Fu] : '=';
    }

    out[written] = '\0';

    return written;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Sockets
 * ------------------------------------------------------------------------- */

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

/* {{{ int httpd_start */
int httpd_start(struct httpd *h, uint16_t port,
                const struct served_file *files, uint32_t file_count,
                const char **why)
{
    struct sockaddr_in address;
    int reuse = 1;
    uint32_t i;

    memset(h, 0, sizeof(struct httpd));
    h->socket = -1;
    h->port = port;
    h->files = files;
    h->file_count = file_count;

    for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
        h->clients[i].socket = -1;
    }

    h->socket = socket(AF_INET, SOCK_STREAM, 0);
    if (h->socket < 0) {
        *why = "could not make a socket";
        return 0;
    }

    setsockopt(h->socket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;

    /*
     * LOOPBACK ONLY, never INADDR_ANY. A bridge listening on a network interface
     * is a web server on somebody's machine that they did not ask for, and the
     * entire security argument for this program existing is that it serves one
     * person: whoever is sitting at it.
     */
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(port);

    if (bind(h->socket, (struct sockaddr *)&address, sizeof(address)) < 0) {
        close(h->socket);
        h->socket = -1;
        *why = "could not bind the local port -- something else is already using it";
        return 0;
    }

    if (listen(h->socket, 4) < 0 || !make_nonblocking(h->socket)) {
        close(h->socket);
        h->socket = -1;
        *why = "could not listen on the local port";
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ void httpd_stop */
void httpd_stop(struct httpd *h)
{
    uint32_t i;

    for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
        if (h->clients[i].socket >= 0) {
            close(h->clients[i].socket);
            h->clients[i].socket = -1;
        }
        free(h->clients[i].incoming);
        h->clients[i].incoming = NULL;
    }

    if (h->socket >= 0) {
        close(h->socket);
        h->socket = -1;
    }
}
/* }}} */

/* {{{ static void send_all */
static void send_all(int fd, const char *bytes, uint32_t length)
{
    uint32_t written = 0;

    while (written < length) {
        ssize_t n = send(fd, bytes + written, (size_t)(length - written), MSG_NOSIGNAL);

        if (n <= 0) {
            if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                continue;
            }
            break;
        }

        written += (uint32_t)n;
    }
}
/* }}} */

/* {{{ static void serve_file */
static void serve_file(struct httpd *h, int fd, const struct served_file *file)
{
    char header[256];
    int header_length;

    header_length = snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %u\r\n"
        "Cache-Control: no-store\r\n"
        "Connection: close\r\n"
        "\r\n",
        file->content_type, (unsigned)file->length);

    send_all(fd, header, (uint32_t)header_length);
    send_all(fd, file->body, file->length);

    h->bytes_served += (uint64_t)header_length + file->length;
}
/* }}} */

/* {{{ static void serve_not_found */
static void serve_not_found(int fd)
{
    /*
     * One line, and no hint about what else might exist. There is no directory
     * to list because there is no directory -- files are a compiled-in table
     * keyed by exact path, so ".." is not a question this program can be asked.
     */
    static const char reply[] =
        "HTTP/1.1 404 Not Found\r\n"
        "Content-Length: 10\r\n"
        "Connection: close\r\n"
        "\r\n"
        "not found\n";

    send_all(fd, reply, (uint32_t)(sizeof(reply) - 1));
}
/* }}} */

/* {{{ static int upgrade_to_websocket */
static int upgrade_to_websocket(struct httpd *h, int fd, const char *request)
{
    static const char guid[] = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    const char *key_line = strstr(request, "Sec-WebSocket-Key:");
    char key[128];
    char combined[256];
    uint8_t digest[20];
    char accept[64];
    char reply[512];
    uint32_t i;
    int reply_length;
    uint32_t slot;

    if (key_line == NULL) {
        return 0;
    }

    key_line += strlen("Sec-WebSocket-Key:");
    while (*key_line == ' ') {
        key_line++;
    }

    for (i = 0; i < sizeof(key) - 1 && key_line[i] != '\r' && key_line[i] != '\n'; i++) {
        key[i] = key_line[i];
    }
    key[i] = '\0';

    /*
     * The handshake: the browser's key, the specification's fixed string, SHA-1,
     * base64. It proves we understood the request rather than proving anything
     * about who is asking -- the key is not a secret and neither is the answer.
     */
    snprintf(combined, sizeof(combined), "%s%s", key, guid);
    sha1_digest((const uint8_t *)combined, (uint32_t)strlen(combined), digest);
    base64_encode(digest, 20, accept, sizeof(accept));

    for (slot = 0; slot < HTTPD_MAX_CLIENTS; slot++) {
        if (h->clients[slot].socket < 0) {
            break;
        }
    }

    if (slot >= HTTPD_MAX_CLIENTS) {
        return 0;
    }

    reply_length = snprintf(reply, sizeof(reply),
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Accept: %s\r\n"
        "\r\n",
        accept);

    send_all(fd, reply, (uint32_t)reply_length);

    h->clients[slot].socket = fd;
    h->clients[slot].connected = 1;
    h->clients[slot].incoming_capacity = 8192;
    h->clients[slot].incoming = calloc(h->clients[slot].incoming_capacity, 1);
    h->clients[slot].incoming_count = 0;

    return 1;
}
/* }}} */

/* {{{ static uint32_t read_frames */
static uint32_t read_frames(struct httpd *h, struct websocket_client *c,
                            uint8_t *into, uint32_t into_capacity)
{
    uint8_t chunk[2048];
    uint32_t delivered = 0;

    for (;;) {
        ssize_t n = recv(c->socket, chunk, sizeof(chunk), 0);
        ssize_t i;

        if (n == 0) {
            close(c->socket);
            c->socket = -1;
            c->connected = 0;
            break;
        }

        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                break;
            }
            close(c->socket);
            c->socket = -1;
            c->connected = 0;
            break;
        }

        for (i = 0; i < n; i++) {
            if (c->incoming_count < c->incoming_capacity) {
                c->incoming[c->incoming_count] = chunk[i];
                c->incoming_count++;
            }
        }
    }

    /*
     * Frames arrive in pieces and two frames arrive in one read. Both are normal,
     * and a decoder that assumes otherwise works in testing and fails in use --
     * so this consumes whole frames out of the accumulated bytes and leaves any
     * partial one where it is.
     */
    for (;;) {
        uint32_t offset = 0;
        uint8_t opcode;
        uint8_t masked;
        uint64_t payload_length;
        uint8_t mask[4];
        uint32_t i;

        if (c->incoming_count < 2) {
            break;
        }

        opcode = c->incoming[0] & 0x0Fu;
        masked = (c->incoming[1] & 0x80u) != 0;
        payload_length = c->incoming[1] & 0x7Fu;
        offset = 2;

        if (payload_length == 126) {
            if (c->incoming_count < offset + 2) break;
            payload_length = ((uint64_t)c->incoming[offset] << 8) | c->incoming[offset + 1];
            offset += 2;
        } else if (payload_length == 127) {
            if (c->incoming_count < offset + 8) break;
            payload_length = 0;
            for (i = 0; i < 8; i++) {
                payload_length = (payload_length << 8) | c->incoming[offset + i];
            }
            offset += 8;
        }

        if (masked) {
            if (c->incoming_count < offset + 4) break;
            memcpy(mask, c->incoming + offset, 4);
            offset += 4;
        }

        if (payload_length > c->incoming_capacity) {
            /* Larger than we will ever hold. Hang up rather than grow forever. */
            close(c->socket);
            c->socket = -1;
            c->connected = 0;
            break;
        }

        if (c->incoming_count < offset + payload_length) {
            break;   /* The rest is still in flight. */
        }

        if (opcode == 0x8) {
            /* A close frame. */
            close(c->socket);
            c->socket = -1;
            c->connected = 0;
            break;
        }

        if (opcode == 0x1 || opcode == 0x2) {
            for (i = 0; i < (uint32_t)payload_length; i++) {
                uint8_t byte = c->incoming[offset + i];

                if (masked) {
                    byte ^= mask[i % 4];
                }

                if (delivered < into_capacity) {
                    into[delivered] = byte;
                    delivered++;
                }
            }
            h->frames_received++;
        }

        /* Consume the frame, keeping whatever came after it. */
        {
            uint32_t consumed = offset + (uint32_t)payload_length;
            uint32_t left = c->incoming_count - consumed;

            memmove(c->incoming, c->incoming + consumed, left);
            c->incoming_count = left;
        }
    }

    return delivered;
}
/* }}} */

/* {{{ uint32_t httpd_poll */
uint32_t httpd_poll(struct httpd *h, uint8_t *into, uint32_t into_capacity)
{
    uint32_t delivered = 0;
    uint32_t i;

    for (;;) {
        int fd = accept(h->socket, NULL, NULL);
        char request[4096];
        ssize_t got;
        char *path;
        char *space;

        if (fd < 0) {
            break;
        }

        /*
         * Read the request head. Blocking briefly is fine: this is loopback and
         * the browser has already sent everything before we accepted.
         */
        got = recv(fd, request, sizeof(request) - 1, 0);
        if (got <= 0) {
            close(fd);
            continue;
        }
        request[got] = '\0';

        if (strncmp(request, "GET ", 4) != 0) {
            serve_not_found(fd);
            close(fd);
            continue;
        }

        path = request + 4;
        space = strchr(path, ' ');
        if (space == NULL) {
            serve_not_found(fd);
            close(fd);
            continue;
        }
        *space = '\0';

        if (strcmp(path, "/socket") == 0) {
            *space = ' ';
            make_nonblocking(fd);
            if (!upgrade_to_websocket(h, fd, request)) {
                close(fd);
            }
            continue;
        }

        {
            uint32_t file;
            int found = 0;

            for (file = 0; file < h->file_count; file++) {
                if (strcmp(path, h->files[file].path) == 0) {
                    serve_file(h, fd, &h->files[file]);
                    found = 1;
                    break;
                }
            }

            if (!found) {
                serve_not_found(fd);
            }
        }

        close(fd);
    }

    for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
        if (h->clients[i].socket >= 0) {
            delivered += read_frames(h, &h->clients[i],
                                     into + delivered,
                                     (delivered < into_capacity)
                                         ? (into_capacity - delivered) : 0);
        }
    }

    return delivered;
}
/* }}} */

/* {{{ uint32_t httpd_broadcast */
uint32_t httpd_broadcast(struct httpd *h, const uint8_t *payload, uint32_t length)
{
    uint8_t header[10];
    uint32_t header_length = 0;
    uint32_t sent = 0;
    uint32_t i;

    /*
     * A binary frame, unmasked -- a server never masks. Not fragmented, because
     * nothing here produces a payload big enough to need it.
     */
    header[0] = 0x82;   /* final fragment, binary. */

    if (length < 126) {
        header[1] = (uint8_t)length;
        header_length = 2;
    } else if (length < 65536) {
        header[1] = 126;
        header[2] = (uint8_t)((length >> 8) & 0xFFu);
        header[3] = (uint8_t)(length & 0xFFu);
        header_length = 4;
    } else {
        header[1] = 127;
        for (i = 0; i < 8; i++) {
            header[2 + i] = (uint8_t)((((uint64_t)length) >> ((7 - i) * 8)) & 0xFFu);
        }
        header_length = 10;
    }

    for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
        if (h->clients[i].socket < 0) {
            continue;
        }

        send_all(h->clients[i].socket, (const char *)header, header_length);
        send_all(h->clients[i].socket, (const char *)payload, length);

        h->frames_sent++;
        sent++;
    }

    return sent;
}
/* }}} */

/* {{{ uint32_t httpd_client_count */
uint32_t httpd_client_count(const struct httpd *h)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 0; i < HTTPD_MAX_CLIENTS; i++) {
        if (h->clients[i].socket >= 0) {
            total++;
        }
    }

    return total;
}
/* }}} */
