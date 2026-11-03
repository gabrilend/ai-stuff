/*
 * 117-link-twin.h — the twin's STAND-IN LINK (phase 7).
 *
 * General description: the laptop twin has no radio and no cable. In
 * their place each link is two queues: frames a test puts on the air,
 * which link_receive (src/system/115-link.h) hands to the device, and
 * frames the device sends, which the test takes to read. A test plays
 * whatever is on the other end — another handheld probing for an address,
 * announcing itself, answering — by building the frames that device would
 * send. A link is down, with no address, until a test brings it up.
 */
#ifndef SOREN_LINK_TWIN_H
#define SOREN_LINK_TWIN_H

#include <stddef.h>
#include <stdint.h>
#include "../src/system/115-link.h"

#define TWIN_LINK_QUEUE 64          /* frames each way; one more is dropped and counted */

/* Bring a link up with this hardware address, or take it down (address
 * ignored). Taking it down empties both queues. */
void twin_link_set(int link, int up, const uint8_t address[LINK_ADDRESS_BYTES]);

/* A frame arrives on the link. Answers 0, LINK_NONE if the link is down
 * or LINK_BAD_SIZE. */
int twin_link_put(int link, const void *frame, size_t length);

/* The oldest frame the device sent and the test has not taken: its
 * length, or 0 if none. */
int twin_link_take(int link, void *frame, size_t size);

/* Frames dropped because a queue was full, each way, since the link last
 * came up. */
uint64_t twin_link_dropped(int link);

#endif
