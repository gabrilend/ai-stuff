/*
 * 084-settings.h — the device's four remembered settings (issue 408).
 *
 * General description: the few things the device remembers across a
 * power-off, each one small file under /settings/ on the card, so a
 * person can read or fix them on a laptop: which hand holds the stylus,
 * which app each screen was showing, and whether the drawer buttons are
 * swapped. They are read once at boot into memory; the input router and
 * the compositor ask the memory, and whichever app owns a setting saves a
 * new value through here, which writes the file and the memory together.
 *
 * A setting that is missing, or holds something that is not one of its
 * values, is given its default and the default is written back, with a
 * line on the developer's channel saying so. Whitespace around a value is
 * ignored, so a file a laptop's editor saved with a newline still reads.
 */
#ifndef SOREN_SETTINGS_H
#define SOREN_SETTINGS_H

#include <stddef.h>
#include <stdint.h>

#define SETTINGS_APP_NAME 32            /* the longest app name, plus its end */
#define SETTINGS_BAD_VALUE (-20)        /* not one of the setting's values */

/* Read every setting from the card, giving defaults to any that are
 * missing or unreadable and writing those defaults back. Needs the card
 * mounted (files_start). Answers FAT_OK, or the first error met while
 * writing a default (the settings are still usable: memory holds them).
 * With no card, every setting is its default and FAT_NO_CARD is answered. */
int settings_load(void);

/* {{{ handedness: 'r' or 'l', default 'r' */
char settings_get_handedness(void);
int  settings_save_handedness(char hand);
/* }}} */

/* {{{ drawer swap: 0 or 1, default 0 (the standard mapping) */
int  settings_get_drawer_swap(void);
int  settings_save_drawer_swap(int swapped);
/* }}} */

/* {{{ the app each screen last showed: defaults "messenger" (top) and
 * "editor" (bottom). A name is 1 to 31 letters, digits or '-'. */
void settings_get_last_foreground_top(char *out, size_t size);
void settings_get_last_foreground_bottom(char *out, size_t size);
int  settings_save_last_foreground_top(const char *app);
int  settings_save_last_foreground_bottom(const char *app);
/* }}} */

/* A save always changes the value in memory, so the device behaves as the
 * person chose for the rest of this session; what it answers says whether
 * the card has it too (FAT_OK) or not (an error, such as FAT_NO_CARD).
 * A value that is not one of the setting's is SETTINGS_BAD_VALUE and
 * changes nothing. */

#endif
