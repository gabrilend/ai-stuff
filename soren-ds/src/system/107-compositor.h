/*
 * 107-compositor.h — copying surfaces onto the screens, once a frame
 * (issue 603).
 *
 * General description: once every display refresh, the compositor walks
 * each screen's surfaces (601) back to front and copies forward the ones
 * that changed (602), row by row, with no blending, scaling or filtering.
 * Wherever a surface has left — released, moved or shrunk — it first
 * paints the background colour, which belongs to the system, and then
 * copies again every surface that overlaps what it painted. A surface
 * that overlaps one copied this frame, in front of it, is copied again as
 * well, so a surface behind never shows through one in front.
 *
 * Only the foreground app's surfaces and the system's are copied to a
 * screen (604, 110-foreground.h).
 *
 * The frame is driven the way the input frame is (501): an engine timer
 * writes a tick into the compositor map's argument door once every
 * 1/60 s, and the frame number rides a loop, so there is only ever one
 * frame in progress. Other boxes run on the other cores meanwhile.
 *
 * On the twin the screens are memory a test reads back; on the device
 * they are the framebuffers of 111a–111d, still to come, and nothing
 * starts the compositor there yet.
 */
#ifndef SOREN_COMPOSITOR_H
#define SOREN_COMPOSITOR_H

#include <stdint.h>
#include "../engine/068-programs.h"
#include "058-draw.h"

#define COMPOSITOR_MAP "src/maps/compositor.map"

/* One display refresh at 60 Hz: the same cadence as the input frame, on a
 * timer of its own so the two run on different cores at once. */
#define COMPOSITOR_FRAME_NS 16666667ull

/* What shows where no surface is: the system's, not any app's. A colour
 * for now; a constant so it can become wallpaper later. */
#define COMPOSITOR_BACKGROUND COLOUR_PAPER

struct compositor {
    int program;                 /* the compositor program, or -1 */
    int timer;                   /* the engine timer driving it, or -1 */
};

/* Load the compositor map, bring it up and arm its timer. Answers the
 * program's number, or -1 with the problem in `report`. */
int compositor_start(struct compositor *c, struct map_report *report);

/* Disarm the timer. The program stays placed, its next frame number
 * waiting on the loop; nothing more is composited until it is armed. */
void compositor_stop(struct compositor *c);

/* What one frame did, for tests and metrics. */
struct compositor_frame {
    int copied;                  /* surfaces copied, both screens */
    int painted;                 /* background rectangles painted */
};

/* One frame of one screen, or of both. The map's box calls
 * compositor_frame; a test outside the engine may too, when nothing else
 * is compositing and nothing releases surfaces at the same time. */
struct compositor_frame compositor_screen(int screen);
struct compositor_frame compositor_frame(void);

#endif
