/*
 * 085-test-settings.c — issue 408.
 *
 * General description: the four remembered settings. Before any card,
 * every setting answers its default. A first boot on a blank card writes
 * all four defaults, each as the small file docs/011 names. A saved value
 * survives a reboot (the card stopped and mounted again, the settings
 * loaded afresh). A value a setting cannot take is refused and changes
 * nothing. A file a person edited on a laptop is read with its newline;
 * one holding nonsense, or far too much, is put back to its default and
 * the developer's line says so. With the card out, a save still changes
 * the device's behaviour for this session and says the card did not get
 * it. And two threads saving the same setting at once leave the card and
 * the memory agreeing.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../../src/system/078-files.h"
#include "../../src/system/084-settings.h"
#include "../026-platform-twin.h"
#include "047-check.h"
#include "080-card-image.h"

#include <pthread.h>
#include <string.h>

#define OWNER OWNER_OUTSIDE

static char log_path[600];

/* {{{ on_card */
/* A setting's file, exactly as the card holds it. */
static const char *on_card(const char *path)
{
    static char text[128];
    int64_t n = files_read(path, 0, text, sizeof text - 1);
    text[n < 0 ? 0 : n] = 0;
    return text;
}
/* }}} */

/* {{{ log_says */
static int log_says(const char *text)
{
    FILE *f = fopen(log_path, "r");
    if (!f) return 0;
    static char buffer[1 << 16];
    size_t n = fread(buffer, 1, sizeof buffer - 1, f);
    fclose(f);
    buffer[n] = 0;
    return strstr(buffer, text) != NULL;
}
/* }}} */

/* {{{ reboot */
/* The card stopped and mounted again, and the settings read afresh. */
static int reboot(void)
{
    files_stop();
    files_start(OWNER);
    return settings_load();
}
/* }}} */

/* {{{ saver */
static void *saver(void *arg)
{
    char hand = (char)(intptr_t)arg;
    for (int i = 0; i < 40; i++) settings_save_handedness(hand);
    return NULL;
}
/* }}} */

int main(void)
{
    twin_platform_init(4, (size_t)128 << 20);
    stripes_init(4, 4);
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    char card[600], report[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/085-card.img", dir);
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/085-settings-line.log", dir);
    snprintf(report, sizeof report, "%s/tmp/shared-memory/test-logs/085-settings.fsck", dir);
    remove(log_path);
    twin_platform_set_log(log_path, 0);

    char app[SETTINGS_APP_NAME];
    /* {{{ before any card */
    settings_get_last_foreground_top(app, sizeof app);
    CHECK(settings_get_handedness() == 'r' && settings_get_drawer_swap() == 0 && strcmp(app, "messenger") == 0,
          "before anything is read, every setting answers its default");
    CHECK(settings_load() == FAT_NO_CARD && settings_get_handedness() == 'r', "loading with no card says so and keeps the defaults");
    /* }}} */

    /* {{{ first boot */
    struct layout l;
    format(&l, 40, 1);
    write_image(card);
    twin_card_open(card);
    files_start(OWNER);
    CHECK(settings_load() == FAT_OK, "a first boot on a blank card loads");
    CHECK(strcmp(on_card("/settings/handedness"), "r") == 0 && strcmp(on_card("/settings/drawer-swap"), "0") == 0 &&
          strcmp(on_card("/settings/last-foreground-top"), "messenger") == 0 &&
          strcmp(on_card("/settings/last-foreground-bottom"), "editor") == 0,
          "and writes all four defaults, each as its own small file");
    CHECK(files_size("/settings/handedness") == 1 && files_size("/settings/drawer-swap") == 1,
          "handedness and the drawer swap are one byte each, as docs/011 says");
    CHECK(log_says("is not on the card"), "the developer's line says why a default was written");
    /* }}} */

    /* {{{ saving, and a reboot */
    CHECK(settings_save_handedness('l') == FAT_OK && settings_get_handedness() == 'l' && strcmp(on_card("/settings/handedness"), "l") == 0,
          "a saved handedness is in memory and on the card");
    CHECK(settings_save_drawer_swap(1) == FAT_OK && settings_save_last_foreground_top("paint") == FAT_OK &&
          settings_save_last_foreground_bottom("modeller") == FAT_OK, "the other three are saved");
    CHECK(reboot() == FAT_OK, "the device reboots");
    char bottom[SETTINGS_APP_NAME];
    settings_get_last_foreground_top(app, sizeof app);
    settings_get_last_foreground_bottom(bottom, sizeof bottom);
    CHECK(settings_get_handedness() == 'l' && settings_get_drawer_swap() == 1 && strcmp(app, "paint") == 0 && strcmp(bottom, "modeller") == 0,
          "and every saved setting is as it was left");
    /* }}} */

    /* {{{ values a setting cannot take */
    CHECK(settings_save_handedness('x') == SETTINGS_BAD_VALUE && settings_get_handedness() == 'l' &&
          strcmp(on_card("/settings/handedness"), "l") == 0,
          "a handedness that is neither r nor l is refused and changes nothing");
    CHECK(settings_save_drawer_swap(2) == SETTINGS_BAD_VALUE && settings_get_drawer_swap() == 1, "a drawer swap of 2 is refused");
    CHECK(settings_save_last_foreground_top("") == SETTINGS_BAD_VALUE &&
          settings_save_last_foreground_top("an app name far longer than thirty-one") == SETTINGS_BAD_VALUE &&
          settings_save_last_foreground_top("../escape") == SETTINGS_BAD_VALUE,
          "an empty app name, one too long, and one with a path in it are refused");
    settings_get_last_foreground_top(app, sizeof app);
    CHECK(strcmp(app, "paint") == 0, "and the top screen's app is still the one saved");
    /* }}} */

    /* {{{ what a person did on a laptop */
    files_write("/settings/handedness", "r\n", 2);
    files_write("/settings/last-foreground-top", "  editor \r\n", 11);
    files_write("/settings/drawer-swap", "maybe", 5);
    char too_much[200];
    memset(too_much, 'a', sizeof too_much);
    files_write("/settings/last-foreground-bottom", too_much, sizeof too_much);
    remove(log_path);
    twin_platform_set_log(log_path, 0);
    CHECK(reboot() == FAT_OK, "the device reboots after the card was edited on a laptop");
    settings_get_last_foreground_top(app, sizeof app);
    settings_get_last_foreground_bottom(bottom, sizeof bottom);
    CHECK(settings_get_handedness() == 'r' && strcmp(app, "editor") == 0, "values with a newline and spaces around them read as typed");
    CHECK(settings_get_drawer_swap() == 0 && strcmp(on_card("/settings/drawer-swap"), "0") == 0,
          "a drawer swap of \"maybe\" is put back to its default, on the card too");
    CHECK(strcmp(bottom, "editor") == 0 && strcmp(on_card("/settings/last-foreground-bottom"), "editor") == 0,
          "a file of 200 letters is no app name, and is put back to its default");
    CHECK(log_says("does not hold a value it can take"), "the developer's line says which settings were put back");
    files_delete("/settings/handedness");
    files_delete("/settings/drawer-swap");
    files_delete("/settings/last-foreground-top");
    files_delete("/settings/last-foreground-bottom");
    files_delete("/settings");
    files_write("/settings", "not a directory", 15);
    CHECK(reboot() == FAT_NOT_A_DIRECTORY && settings_get_handedness() == 'r',
          "with /settings a file, loading says it could not write and the defaults still hold");
    files_delete("/settings");
    /* }}} */

    /* {{{ the card out */
    files_stop();
    CHECK(settings_save_handedness('l') == FAT_NO_CARD && settings_get_handedness() == 'l',
          "with the card out, a save still changes the device for this session and says the card did not get it");
    files_start(OWNER);
    /* }}} */

    /* {{{ two at once */
    settings_load();
    pthread_t a, b;
    pthread_create(&a, NULL, saver, (void *)(intptr_t)'l');
    pthread_create(&b, NULL, saver, (void *)(intptr_t)'r');
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    CHECK(on_card("/settings/handedness")[0] == settings_get_handedness(),
          "two threads saving at once leave the card and memory agreeing ('%c')", settings_get_handedness());
    /* }}} */

    files_stop();
    int checked = card_fsck(card, report);
    if (checked >= 0) CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the card");
    remove(card);
    free(image);
    CHECK_DONE("085 settings");
}
