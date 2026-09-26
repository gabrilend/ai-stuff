/*
 * 057-screens-twin.h — the twin's screens, written out as pictures.
 *
 * General description: the handheld shows its two screens on glass; the
 * laptop twin writes them to PNG files instead, either one screen at a
 * time or both stacked the way they sit on the device (top above bottom,
 * with a strip of case colour between), so a demo's output can be looked
 * at, put in the documentation, or compared against an earlier run.
 */
#ifndef SOREN_SCREENS_TWIN_H
#define SOREN_SCREENS_TWIN_H

/* Save one screen (0 top, 1 bottom). Answers 0, or nonzero with a message
 * already printed. */
int twin_screen_save_png(int which, const char *path);

/* Save both, stacked as on the device. */
int twin_screens_save_png(const char *path);

#endif
