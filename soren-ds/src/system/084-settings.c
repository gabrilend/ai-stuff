/*
 * 084-settings.c — the device's four remembered settings (issue 408).
 *
 * General description: one table names each setting's file, its default
 * and what values it may take; everything else is the same four steps
 * for all of them. Values are kept in memory as short text, exactly the
 * bytes the file holds (one byte for handedness and the drawer swap, the
 * app's name for the two screens), so loading, saving and a person
 * editing the card on a laptop all deal in the same thing.
 *
 * Two locks: one keeps the values in memory whole for the quick reads
 * the input router and the compositor make, and is only ever held for a
 * copy; the other puts saves in a line, and is held across the card write
 * so the file and the memory end up agreeing even when two saves of one
 * setting race. A read never waits behind a card write.
 */
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "077-fat.h"
#include "078-files.h"
#include "084-settings.h"

enum { HANDEDNESS, DRAWER_SWAP, LAST_TOP, LAST_BOTTOM, SETTINGS_COUNT };
enum { ONE_OF, APP_NAME };

struct setting {
    const char *path;
    const char *fallback;
    int         kind;
    const char *choices;                /* for ONE_OF: the characters allowed */
};

static const struct setting table[SETTINGS_COUNT] = {
    [HANDEDNESS]  = { "/settings/handedness",             "r",         ONE_OF,   "rl" },
    [DRAWER_SWAP] = { "/settings/drawer-swap",            "0",         ONE_OF,   "01" },
    [LAST_TOP]    = { "/settings/last-foreground-top",    "messenger", APP_NAME, (const char *)0 },
    [LAST_BOTTOM] = { "/settings/last-foreground-bottom", "editor",    APP_NAME, (const char *)0 },
};

static char values[SETTINGS_COUNT][SETTINGS_APP_NAME] = {
    [HANDEDNESS] = "r", [DRAWER_SWAP] = "0", [LAST_TOP] = "messenger", [LAST_BOTTOM] = "editor",
};
static spin_lock_t value_lock = SPIN_LOCK_INIT;
static spin_lock_t save_lock = SPIN_LOCK_INIT;

/* {{{ valid */
/* Is this text one of the setting's values? */
static int valid(int which, const char *text)
{
    const struct setting *s = &table[which];
    size_t n = text_length(text);
    if (s->kind == ONE_OF) {
        if (n != 1) return 0;
        for (const char *c = s->choices; *c; c++) if (*c == text[0]) return 1;
        return 0;
    }
    if (n == 0 || n >= SETTINGS_APP_NAME) return 0;
    for (size_t i = 0; i < n; i++) {
        char c = text[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-')) return 0;
    }
    return 1;
}
/* }}} */

/* {{{ trim */
/* Whitespace off both ends, in place: a laptop's editor ends a file with
 * a newline, and a person may type a space. */
static void trim(char *text)
{
    size_t n = text_length(text);
    while (n && (text[n - 1] == ' ' || text[n - 1] == '\t' || text[n - 1] == '\r' || text[n - 1] == '\n')) text[--n] = 0;
    size_t start = 0;
    while (text[start] == ' ' || text[start] == '\t' || text[start] == '\r' || text[start] == '\n') start++;
    for (size_t i = 0; start && i + start <= n; i++) text[i] = text[i + start];   /* forward, so the overlap is safe */
}
/* }}} */

/* {{{ remember */
static void remember(int which, const char *text)
{
    spin_lock(&value_lock);
    text_format(values[which], SETTINGS_APP_NAME, "%s", text);
    spin_unlock(&value_lock);
}
/* }}} */

/* {{{ recall */
static void recall(int which, char *out, size_t size)
{
    spin_lock(&value_lock);
    text_format(out, size, "%s", values[which]);
    spin_unlock(&value_lock);
}
/* }}} */

/* {{{ save */
static int save(int which, const char *text)
{
    if (!valid(which, text)) return SETTINGS_BAD_VALUE;
    spin_lock(&save_lock);
    remember(which, text);
    int r = files_write(table[which].path, text, (uint32_t)text_length(text));
    spin_unlock(&save_lock);
    return r;
}
/* }}} */

/* {{{ settings_load */
int settings_load(void)
{
    int result = FAT_OK;
    for (int which = 0; which < SETTINGS_COUNT; which++) {
        const struct setting *s = &table[which];
        char text[64];
        int64_t n = files_read(s->path, 0, text, sizeof text - 1);
        if (n == FAT_NO_CARD) {
            remember(which, s->fallback);
            result = FAT_NO_CARD;
            continue;
        }
        text[n < 0 ? 0 : n] = 0;
        int whole = n >= 0 && n < (int64_t)sizeof text - 1;    /* a longer file is no value of ours */
        trim(text);
        if (whole && valid(which, text)) {
            remember(which, text);
            continue;
        }
        if (n == FAT_NOT_FOUND) {
            say_line("settings: %s is not on the card; using \"%s\"", s->path, s->fallback);
        } else if (n < 0) {
            say_line("settings: %s could not be read (%s); using \"%s\"", s->path, fat_error_text((int)n), s->fallback);
        } else {
            say_line("settings: %s does not hold a value it can take; using \"%s\"", s->path, s->fallback);
        }
        spin_lock(&save_lock);
        remember(which, s->fallback);
        int r = files_write(s->path, s->fallback, (uint32_t)text_length(s->fallback));
        spin_unlock(&save_lock);
        if (r < 0 && result == FAT_OK) result = r;
    }
    return result;
}
/* }}} */

/* {{{ handedness */
char settings_get_handedness(void)
{
    char v[2];
    recall(HANDEDNESS, v, sizeof v);
    return v[0];
}

int settings_save_handedness(char hand)
{
    char v[2] = { hand, 0 };
    return save(HANDEDNESS, v);
}
/* }}} */

/* {{{ drawer swap */
int settings_get_drawer_swap(void)
{
    char v[2];
    recall(DRAWER_SWAP, v, sizeof v);
    return v[0] == '1';
}

int settings_save_drawer_swap(int swapped)
{
    if (swapped != 0 && swapped != 1) return SETTINGS_BAD_VALUE;
    return save(DRAWER_SWAP, swapped ? "1" : "0");
}
/* }}} */

/* {{{ the last foreground of each screen */
void settings_get_last_foreground_top(char *out, size_t size)
{
    recall(LAST_TOP, out, size);
}

void settings_get_last_foreground_bottom(char *out, size_t size)
{
    recall(LAST_BOTTOM, out, size);
}

int settings_save_last_foreground_top(const char *app)
{
    return save(LAST_TOP, app);
}

int settings_save_last_foreground_bottom(const char *app)
{
    return save(LAST_BOTTOM, app);
}
/* }}} */
