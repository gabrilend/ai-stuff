/*
 * 116-link-device.c — the handheld's link (phase 7, declared in
 * src/system/115-link.h).
 *
 * NO LINK YET, deliberately. The radio needs its controller brought up and
 * joined to an ad-hoc network (701, 702), and the cable needs to present
 * itself as a USB Ethernet adapter (706, on 109's controller). Until
 * then every link answers that it is not up, so the network stack above
 * runs on the device exactly as it will, and never hears anything.
 */
#include <stddef.h>
#include <stdint.h>
#include "../system/115-link.h"

/* {{{ link_up */
int link_up(int link)
{
    (void)link;
    return 0;
}
/* }}} */

/* {{{ link_address */
int link_address(int link, uint8_t address[LINK_ADDRESS_BYTES])
{
    (void)link;
    (void)address;
    return LINK_NONE;
}
/* }}} */

/* {{{ link_send */
int link_send(int link, const void *frame, size_t length)
{
    (void)link;
    (void)frame;
    (void)length;
    return LINK_NONE;
}
/* }}} */

/* {{{ link_receive */
int link_receive(int link, void *frame, size_t size)
{
    (void)link;
    (void)frame;
    (void)size;
    return LINK_NONE;
}
/* }}} */
