/*
 * 108-compositor.c — the compositor's frame as a box (issue 603).
 *
 * General description: one box, placed once, in src/maps/compositor.map.
 * It takes the tick and the frame number, composites both screens, and
 * hands the next frame number back round the loop, which is what keeps
 * two frames from running at once.
 */
#include <stdint.h>
#include "../system/107-compositor.h"

/* {{{ composite */
int64_t composite(int64_t tick, int64_t frame)
{
    (void)tick;
    compositor_frame();
    return frame + 1;
}
/* }}} */
