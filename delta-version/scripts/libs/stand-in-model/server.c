/* server.c - a stand-in for the llama.cpp chat server, for tests.
 *
 * It answers the three requests llama-chat-client.lua makes, on 127.0.0.1
 * only, one at a time:
 *
 *   GET  /v1/models             200, an empty model list (the "is it up?" check)
 *   POST /tokenize              the request body's word count, as tokens
 *   POST /v1/chat/completions   the body is handed to a "brain" program on its
 *                               standard input; whatever JSON it prints is the
 *                               reply
 *
 * The brain decides what the stand-in model says, so this program knows
 * nothing about any tool. No model is downloaded or run. Nothing listens
 * beyond the loopback address.
 *
 * Usage: server PORT BRAIN-COMMAND
 *   e.g. server 0 "luajit brain.lua"   (port 0 picks a free port)
 * It prints the port it listens on as its first line, then serves until it is
 * sent SIGTERM or SIGINT.
 */

#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define MAX_REQUEST (8 * 1024 * 1024)

static volatile sig_atomic_t stopping = 0;

/* {{{ on_signal */
static void on_signal(int sig) {
    (void)sig;
    stopping = 1;
}
/* }}} */

/* {{{ send_reply */
static void send_reply(int fd, int code, const char *body, size_t length) {
    char head[256];
    const char *word = code == 200 ? "OK" : code == 404 ? "Not Found" : "Bad Request";
    int n = snprintf(head, sizeof head,
        "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\n"
        "Content-Length: %zu\r\nConnection: close\r\n\r\n", code, word, length);
    if (write(fd, head, (size_t)n) < 0) return;
    size_t sent = 0;
    while (sent < length) {
        ssize_t w = write(fd, body + sent, length - sent);
        if (w <= 0) return;
        sent += (size_t)w;
    }
}
/* }}} */

/* {{{ read_request
 * Reads the head and, by Content-Length, the whole body. Returns the buffer
 * (NUL-terminated) and sets *body to where the body starts. */
static char *read_request(int fd, char **body, size_t *body_length) {
    size_t size = 65536, used = 0;
    char *buffer = malloc(size + 1);
    char *end = NULL;
    long content_length = 0;
    if (!buffer) return NULL;
    for (;;) {
        if (used == size) {
            if (size >= MAX_REQUEST) { free(buffer); return NULL; }
            size *= 2;
            char *bigger = realloc(buffer, size + 1);
            if (!bigger) { free(buffer); return NULL; }
            buffer = bigger;
        }
        ssize_t r = read(fd, buffer + used, size - used);
        if (r <= 0) break;
        used += (size_t)r;
        buffer[used] = '\0';
        if (!end && (end = strstr(buffer, "\r\n\r\n"))) {
            char *field = strcasestr(buffer, "\r\nContent-Length:");
            if (field && field < end) content_length = strtol(field + 17, NULL, 10);
        }
        if (end && used >= (size_t)(end + 4 - buffer) + (size_t)content_length) break;
    }
    buffer[used] = '\0';
    if (!end) { free(buffer); return NULL; }
    *body = end + 4;
    *body_length = used - (size_t)(*body - buffer);
    return buffer;
}
/* }}} */

/* {{{ ask_brain
 * Runs the brain with the body on its standard input; returns what it prints. */
static char *ask_brain(const char *brain, const char *body, size_t body_length, size_t *out_length) {
    char path[] = "/tmp/stand-in-model-XXXXXX";
    int tmp = mkstemp(path);
    if (tmp < 0) return NULL;
    if (write(tmp, body, body_length) != (ssize_t)body_length) { close(tmp); unlink(path); return NULL; }
    close(tmp);

    size_t command_size = strlen(brain) + strlen(path) + 8;
    char *command = malloc(command_size);
    if (!command) { unlink(path); return NULL; }
    snprintf(command, command_size, "%s < %s", brain, path);
    FILE *pipe = popen(command, "r");
    free(command);
    if (!pipe) { unlink(path); return NULL; }

    size_t size = 65536, used = 0;
    char *out = malloc(size);
    size_t r;
    while (out && (r = fread(out + used, 1, size - used, pipe)) > 0) {
        used += r;
        if (used == size) {
            size *= 2;
            char *bigger = realloc(out, size);
            if (!bigger) { free(out); out = NULL; break; }
            out = bigger;
        }
    }
    pclose(pipe);
    unlink(path);
    *out_length = used;
    return out;
}
/* }}} */

/* {{{ count_words */
static int count_words(const char *text, size_t length) {
    int words = 0, inside = 0;
    for (size_t i = 0; i < length; i++) {
        int space = text[i] == ' ' || text[i] == '\n' || text[i] == '\t' || text[i] == '\r';
        if (!space && !inside) words++;
        inside = !space;
    }
    return words;
}
/* }}} */

/* {{{ serve */
static void serve(int fd, const char *brain) {
    char *body = NULL;
    size_t body_length = 0;
    char *request = read_request(fd, &body, &body_length);
    if (!request) { send_reply(fd, 400, "{}", 2); return; }

    if (strncmp(request, "GET /v1/models ", 15) == 0) {
        const char *reply = "{\"data\":[]}";
        send_reply(fd, 200, reply, strlen(reply));
    } else if (strncmp(request, "POST /tokenize ", 15) == 0) {
        char reply[64];
        int n = snprintf(reply, sizeof reply, "{\"count\":%d}", count_words(body, body_length));
        send_reply(fd, 200, reply, (size_t)n);
    } else if (strncmp(request, "POST /v1/chat/completions ", 26) == 0) {
        size_t out_length = 0;
        char *out = ask_brain(brain, body, body_length, &out_length);
        if (out && out_length > 0) send_reply(fd, 200, out, out_length);
        else send_reply(fd, 400, "{\"error\":\"the stand-in brain gave no reply\"}", 44);
        free(out);
    } else {
        send_reply(fd, 404, "{\"error\":\"not served by the stand-in\"}", 38);
    }
    free(request);
}
/* }}} */

/* {{{ main */
int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s PORT BRAIN-COMMAND\n", argv[0]);
        return 2;
    }
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_handler = on_signal;
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    signal(SIGPIPE, SIG_IGN);

    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int yes = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons((unsigned short)atoi(argv[1]));
    if (bind(listener, (struct sockaddr *)&address, sizeof address) < 0 || listen(listener, 16) < 0) {
        perror("stand-in-model");
        return 1;
    }
    socklen_t length = sizeof address;
    getsockname(listener, (struct sockaddr *)&address, &length);
    printf("%d\n", ntohs(address.sin_port));
    fflush(stdout);

    while (!stopping) {
        int fd = accept(listener, NULL, NULL);
        if (fd < 0) continue;
        serve(fd, argv[2]);
        close(fd);
    }
    close(listener);
    return 0;
}
/* }}} */
