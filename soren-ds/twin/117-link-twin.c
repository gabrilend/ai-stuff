/*
 * 117-link-twin.c — the twin's STAND-IN LINK (phase 7).
 *
 * General description: see 117-link-twin.h. Each queue is a ring of whole
 * frames behind one mutex per link; the device's side and the test's side
 * may be on different threads.
 */
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include "117-link-twin.h"

struct ring {
    uint8_t  frames[TWIN_LINK_QUEUE][LINK_FRAME_MAX];
    uint16_t lengths[TWIN_LINK_QUEUE];
    int      head, count;
};

static struct {
    pthread_mutex_t lock;
    int             up;
    uint8_t         address[LINK_ADDRESS_BYTES];
    struct ring     arriving;          /* the test's frames, for the device */
    struct ring     sent;              /* the device's frames, for the test */
    uint64_t        dropped;
} links[LINK_COUNT] = {
    { .lock = PTHREAD_MUTEX_INITIALIZER },
    { .lock = PTHREAD_MUTEX_INITIALIZER },
};

/* {{{ ring_put, ring_take */
static int ring_put(struct ring *r, const void *frame, size_t length)
{
    if (r->count == TWIN_LINK_QUEUE) {
        return 0;
    }
    int at = (r->head + r->count) % TWIN_LINK_QUEUE;
    memcpy(r->frames[at], frame, length);
    r->lengths[at] = (uint16_t)length;
    r->count++;
    return 1;
}

/* Answers the length taken, 0 for none, -1 for one too long (dropped). */
static int ring_take(struct ring *r, void *frame, size_t size)
{
    if (r->count == 0) {
        return 0;
    }
    int length = r->lengths[r->head];
    int fits = (size_t)length <= size;
    if (fits) {
        memcpy(frame, r->frames[r->head], (size_t)length);
    }
    r->head = (r->head + 1) % TWIN_LINK_QUEUE;
    r->count--;
    return fits ? length : -1;
}
/* }}} */

/* {{{ valid */
static int valid(int link)
{
    return link >= 0 && link < LINK_COUNT;
}
/* }}} */

/* {{{ twin_link_set */
void twin_link_set(int link, int up, const uint8_t address[LINK_ADDRESS_BYTES])
{
    if (!valid(link)) {
        return;
    }
    pthread_mutex_lock(&links[link].lock);
    links[link].up = up;
    if (up && address) {
        memcpy(links[link].address, address, LINK_ADDRESS_BYTES);
    }
    links[link].arriving.count = links[link].sent.count = 0;
    links[link].dropped = 0;
    pthread_mutex_unlock(&links[link].lock);
}
/* }}} */

/* {{{ twin_link_put */
int twin_link_put(int link, const void *frame, size_t length)
{
    if (!valid(link)) {
        return LINK_NONE;
    }
    if (length < LINK_FRAME_MIN || length > LINK_FRAME_MAX) {
        return LINK_BAD_SIZE;
    }
    pthread_mutex_lock(&links[link].lock);
    int answer = LINK_NONE;
    if (links[link].up) {
        if (!ring_put(&links[link].arriving, frame, length)) {
            links[link].dropped++;
        }
        answer = 0;
    }
    pthread_mutex_unlock(&links[link].lock);
    return answer;
}
/* }}} */

/* {{{ twin_link_take */
int twin_link_take(int link, void *frame, size_t size)
{
    if (!valid(link)) {
        return 0;
    }
    pthread_mutex_lock(&links[link].lock);
    int length;
    while ((length = ring_take(&links[link].sent, frame, size)) < 0) {
    }
    pthread_mutex_unlock(&links[link].lock);
    return length;
}
/* }}} */

/* {{{ twin_link_dropped */
uint64_t twin_link_dropped(int link)
{
    if (!valid(link)) {
        return 0;
    }
    pthread_mutex_lock(&links[link].lock);
    uint64_t n = links[link].dropped;
    pthread_mutex_unlock(&links[link].lock);
    return n;
}
/* }}} */

/* {{{ link_up */
int link_up(int link)
{
    if (!valid(link)) {
        return 0;
    }
    pthread_mutex_lock(&links[link].lock);
    int up = links[link].up;
    pthread_mutex_unlock(&links[link].lock);
    return up;
}
/* }}} */

/* {{{ link_address */
int link_address(int link, uint8_t address[LINK_ADDRESS_BYTES])
{
    if (!valid(link)) {
        return LINK_NONE;
    }
    pthread_mutex_lock(&links[link].lock);
    int answer = LINK_NONE;
    if (links[link].up) {
        memcpy(address, links[link].address, LINK_ADDRESS_BYTES);
        answer = 0;
    }
    pthread_mutex_unlock(&links[link].lock);
    return answer;
}
/* }}} */

/* {{{ link_send */
int link_send(int link, const void *frame, size_t length)
{
    if (!valid(link)) {
        return LINK_NONE;
    }
    if (length < LINK_FRAME_MIN || length > LINK_FRAME_MAX) {
        return LINK_BAD_SIZE;
    }
    pthread_mutex_lock(&links[link].lock);
    int answer = LINK_NONE;
    if (links[link].up) {
        if (!ring_put(&links[link].sent, frame, length)) {
            links[link].dropped++;
        }
        answer = 0;
    }
    pthread_mutex_unlock(&links[link].lock);
    return answer;
}
/* }}} */

/* {{{ link_receive */
int link_receive(int link, void *frame, size_t size)
{
    if (!valid(link)) {
        return LINK_NONE;
    }
    pthread_mutex_lock(&links[link].lock);
    int answer = LINK_NONE;
    if (links[link].up) {
        while ((answer = ring_take(&links[link].arriving, frame, size)) < 0) {
        }
    }
    pthread_mutex_unlock(&links[link].lock);
    return answer;
}
/* }}} */
