/*
 * 119-net.c — the network's poll as a box (issue 703).
 *
 * General description: one box, placed once, in src/maps/net.map. It takes
 * the tick and the poll number, looks at every link once (net_poll: read,
 * answer, deliver, and send what is due), and hands the next number back
 * round the loop, so only one poll is ever running.
 */
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../system/118-net.h"

/* {{{ net_frame */
int64_t net_frame(int64_t tick, int64_t frame)
{
    (void)tick;
    net_poll(platform_now_ns());
    return frame + 1;
}
/* }}} */
