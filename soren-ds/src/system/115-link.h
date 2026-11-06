/*
 * 115-link.h — the link: frames in and out of the device (phase 7's seam).
 *
 * General description: everything phase 7 builds above the radio and the
 * cable — addresses (703), discovery (704), the peer table (705), the
 * transport (709) — sends and receives Ethernet frames through these four
 * calls, and nothing else. Each side of the platform answers them its own
 * way, as it answers platform_screen or the input reads:
 *
 * - The twin answers with a STAND-IN LINK (twin/117-link-twin.c): frames
 *   a test puts on the air arrive, and frames the device sends are kept
 *   for the test to read. It is not a radio and not a cable; it is a
 *   queue each way, and what is on the other end is whatever the test
 *   plays.
 * - The device answers "no link" (src/device/116-link-device.c) until the
 *   radio is up in ad-hoc mode (701, 702) and the cable is a virtual
 *   Ethernet adapter (706). Everything above runs there unchanged, and
 *   simply never hears anything.
 *
 * Two links: the radio and the cable. A frame is a whole Ethernet II
 * frame, destination address first, without the checksum the hardware
 * adds and removes.
 */
#ifndef SOREN_LINK_H
#define SOREN_LINK_H

#include <stddef.h>
#include <stdint.h>

enum link_which {
    LINK_RADIO = 0,             /* ad-hoc WiFi (701, 702) */
    LINK_CABLE = 1,             /* USB-C as Ethernet (706) */
    LINK_COUNT = 2,
};

#define LINK_ADDRESS_BYTES 6
#define LINK_FRAME_MAX     1514     /* 14 bytes of header and 1500 of payload */
#define LINK_FRAME_MIN     14

/* Answers, beside a length. */
#define LINK_NONE     (-1)          /* no such link, or it is not up */
#define LINK_BAD_SIZE (-2)          /* a frame shorter than a header or longer than LINK_FRAME_MAX */

/* Is the link up now (1), or not (0)? */
int link_up(int link);

/* The device's own hardware address on that link. LINK_NONE if it is not
 * up. */
int link_address(int link, uint8_t address[LINK_ADDRESS_BYTES]);

/* Send one frame. Answers 0, or a negative answer above. The frame is
 * copied before this returns. */
int link_send(int link, const void *frame, size_t length);

/* Take the oldest frame that has arrived and not been taken. Answers its
 * length, 0 if none is waiting, or LINK_NONE. A frame longer than `size`
 * is dropped and the next is tried. */
int link_receive(int link, void *frame, size_t size);

#endif
