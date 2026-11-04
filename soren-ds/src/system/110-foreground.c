/*
 * 110-foreground.c — which app each screen shows (issue 604).
 *
 * General description: see 110-foreground.h.
 */
#include <stdint.h>
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "104-surfaces.h"
#include "110-foreground.h"

static int32_t foreground[PLATFORM_SCREEN_COUNT] = { SURFACE_APP_NONE, SURFACE_APP_NONE };

/* {{{ screen_set_foreground */
int screen_set_foreground(int screen, int32_t app)
{
    if (screen < 0 || screen >= PLATFORM_SCREEN_COUNT) {
        return SURFACE_OFF_SCREEN;
    }
    int32_t was = atomic_swap(&foreground[screen], app);
    if (was != app) {
        /* After the exchange, never before: a frame between the two then
         * copies the new app's marked surfaces, and the next paints the
         * whole screen. The other order could paint the old app once more
         * and leave it there. */
        struct platform_screen sc = platform_screen(screen);
        surface_expose(screen, 0, 0, sc.width, sc.height);
    }
    return SURFACE_OK;
}
/* }}} */

/* {{{ screen_get_foreground */
int32_t screen_get_foreground(int screen)
{
    if (screen < 0 || screen >= PLATFORM_SCREEN_COUNT) {
        return SURFACE_APP_NONE;
    }
    return atomic_load_acquire(&foreground[screen]);
}
/* }}} */
