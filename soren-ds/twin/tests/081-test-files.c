/*
 * 081-test-files.c — issue 405.
 *
 * General description: paths and the device's symlinks, on a blank card
 * a laptop formatted (080-card-image.h). Paths are written every way a
 * person might write one and must all reach the same file; writing makes
 * the directories on the way; a replaced file leaves no clusters behind;
 * reading takes slices; listing, deleting and making directories refuse
 * what they should. Then links: to a file that does not exist yet, to a
 * directory in the middle of a path, relative ones with ".." in them,
 * links to links, and loops, which must end in an error and never a hang.
 * Deleting a link removes the link and not what it names. A second mount
 * finds everything again, and the card a laptop sees holds a link as an
 * ordinary small file starting with the magic bytes. Last, four threads
 * write and read their own files at once through the one lock.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../../src/system/078-files.h"
#include "../026-platform-twin.h"
#include "047-check.h"
#include "080-card-image.h"

#include <pthread.h>
#include <string.h>

#define OWNER OWNER_OUTSIDE

/* {{{ read_text */
/* A whole small file as a string, or "" with the error kept. */
static int read_error;
static const char *read_text(const char *path)
{
    static char buffer[4096];
    int64_t n = files_read(path, 0, buffer, sizeof buffer - 1);
    read_error = n < 0 ? (int)n : 0;
    buffer[n < 0 ? 0 : n] = 0;
    return buffer;
}
/* }}} */

/* {{{ free_clusters */
/* The card's free space as a fresh mount counts it, the path layer
 * stopped meanwhile so the two never hold the card at once. */
static uint32_t free_clusters(void)
{
    files_stop();
    struct fat_volume v;
    uint32_t n = fat_mount(&v, OWNER) == FAT_OK ? v.free_clusters : 0;
    fat_unmount(&v);
    files_start(OWNER);
    return n;
}
/* }}} */

struct names {
    char list[64][FAT_NAME];
    uint32_t size[64];
    int  n;
};

/* {{{ collect */
static int collect(const struct fat_entry *e, void *ctx)
{
    struct names *l = ctx;
    if (l->n < 64) {
        snprintf(l->list[l->n], FAT_NAME, "%s", e->name);
        l->size[l->n++] = e->size;
    }
    return 0;
}
/* }}} */

/* {{{ has */
static int has(const struct names *l, const char *name)
{
    for (int i = 0; i < l->n; i++) if (strcmp(l->list[i], name) == 0) return 1;
    return 0;
}
/* }}} */

/* {{{ writer */
/* One of four threads, each writing and reading back its own file. */
static int writer_failures;
static void *writer(void *arg)
{
    int who = (int)(intptr_t)arg;
    char path[64], text[64];
    for (int round = 0; round < 25; round++) {
        snprintf(path, sizeof path, "/busy/writer-%d.txt", who);
        snprintf(text, sizeof text, "writer %d, round %d", who, round);
        char back[64] = { 0 };
        if (files_write(path, text, (uint32_t)strlen(text)) != FAT_OK ||
            files_read(path, 0, back, sizeof back - 1) != (int64_t)strlen(text) || strcmp(back, text) != 0) {
            __atomic_fetch_add(&writer_failures, 1, __ATOMIC_RELAXED);
        }
    }
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
    char card[600], line[600], report[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/081-card.img", dir);
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/081-files-line.log", dir);
    snprintf(report, sizeof report, "%s/tmp/shared-memory/test-logs/081-files.fsck", dir);
    remove(line);
    twin_platform_set_log(line, 0);

    CHECK(!files_ready() && files_exists("/anything") == FAT_NO_CARD && files_read("/x", 0, line, 1) == FAT_NO_CARD,
          "before a card is mounted, every call says there is no card");
    struct layout l;
    format(&l, 40, 1);
    write_image(card);
    twin_card_open(card);
    CHECK(files_start(OWNER) == FAT_OK && files_ready(), "a blank card mounts");

    /* {{{ paths */
    CHECK(files_write("/settings/handedness", "r", 1) == FAT_OK, "writing a file makes its directory");
    CHECK(files_exists("/settings") == 1 && files_exists("/settings/handedness") == 1 && files_size("/settings/handedness") == 1,
          "the directory and the file are both there, and the file is one byte");
    const char *ways[] = { "settings/handedness", "//settings///handedness/", "/settings/./handedness",
                           "/settings/../settings/handedness", "/../../settings/handedness", "/SETTINGS/Handedness" };
    int all = 1;
    for (size_t i = 0; i < sizeof ways / sizeof ways[0]; i++) all &= strcmp(read_text(ways[i]), "r") == 0;
    CHECK(all, "every way of writing the path reaches the same file (no leading slash, doubled slashes, \".\", \"..\", above the root, any case)");
    CHECK(files_write("/settings/handedness", "l", 1) == FAT_OK && strcmp(read_text("/settings/handedness"), "l") == 0,
          "writing again replaces the contents");
    uint32_t before = free_clusters();
    for (int i = 0; i < 20; i++) files_write("/settings/handedness", i % 2 ? "r" : "l", 1);
    CHECK(free_clusters() == before, "twenty replacements leave the card's free space exactly as it was");
    CHECK(files_write("/settings/empty", "", 0) == FAT_OK && files_exists("/settings/empty") == 1 &&
          files_size("/settings/empty") == 0 && files_read("/settings/empty", 0, line, 10) == 0,
          "an empty file is a file, of no bytes");

    uint8_t big[3000], slice[600];
    for (int i = 0; i < 3000; i++) big[i] = (uint8_t)(i * 7 + 3);
    CHECK(files_write("/drawings/strip.raw", big, sizeof big) == FAT_OK, "a file several clusters long is written");
    CHECK(files_read("/drawings/strip.raw", 1000, slice, sizeof slice) == 600 && memcmp(slice, big + 1000, 600) == 0,
          "a slice from the middle reads back");
    CHECK(files_read("/drawings/strip.raw", 2900, slice, sizeof slice) == 100 && memcmp(slice, big + 2900, 100) == 0,
          "a slice running past the end is cut at the end");
    CHECK(files_read("/drawings/strip.raw", 3000, slice, sizeof slice) == 0, "a read at the end answers nothing");

    CHECK(files_read("/settings", 0, line, 10) == FAT_IS_A_DIRECTORY && files_size("/") == FAT_IS_A_DIRECTORY,
          "reading a directory, the root included, is refused");
    CHECK(files_read("/settings/missing", 0, line, 10) == FAT_NOT_FOUND && files_exists("/settings/missing") == 0,
          "a missing file is not found and does not exist");
    CHECK(files_read("/nowhere/at/all", 0, line, 10) == FAT_NOT_FOUND, "a missing directory on the way is not found, and nothing is made");
    CHECK(files_exists("/nowhere") == 0, "reading made no directory");
    CHECK(files_write("/settings", "x", 1) == FAT_IS_A_DIRECTORY, "a directory cannot be written over");
    CHECK(files_write("/settings/handedness/inside", "x", 1) == FAT_NOT_A_DIRECTORY && files_exists("/settings/handedness/inside") == 0,
          "a file cannot be a directory on the way");
    char very_long[1200];
    memset(very_long, 'a', sizeof very_long - 1);
    very_long[sizeof very_long - 1] = 0;
    CHECK(files_write(very_long, "x", 1) == FAT_TOO_LONG, "a path longer than any path may be is refused");
    char long_name[400] = "/";
    memset(long_name + 1, 'b', 300);
    CHECK(files_write(long_name, "x", 1) == FAT_TOO_LONG, "a name longer than FAT can hold is refused");
    char deep[FILES_PATH];
    int at = 0;
    for (int i = 0; i < FILES_DEPTH + 2; i++) at += snprintf(deep + at, sizeof deep - (size_t)at, "/d");
    CHECK(files_make_directory(deep) == FAT_TOO_LONG, "a path deeper than %d directories is refused", FILES_DEPTH);
    /* }}} */

    /* {{{ listing, making and deleting */
    struct names names = { .n = 0 };
    CHECK(files_list("/settings", collect, &names) == FAT_OK && names.n == 2 && has(&names, "handedness") && has(&names, "empty"),
          "a directory lists its files");
    names.n = 0;
    CHECK(files_list("/", collect, &names) == FAT_OK && has(&names, "settings") && has(&names, "drawings") && !has(&names, "d"),
          "the root lists its directories, and the refused deep path made none");
    CHECK(files_list("/settings/handedness", collect, &names) == FAT_NOT_A_DIRECTORY && files_list("/gone", collect, &names) == FAT_NOT_FOUND,
          "listing a file, or nothing, is refused");
    CHECK(files_make_directory("/messages/alice") == FAT_OK && files_exists("/messages/alice") == 1,
          "a directory and the one above it are made");
    CHECK(files_make_directory("/messages/alice") == FAT_OK, "making a directory that is there already is not an error");
    CHECK(files_make_directory("/settings/handedness") == FAT_EXISTS, "a directory cannot be made where a file is");
    CHECK(files_delete("/messages") == FAT_NOT_EMPTY, "a directory with something in it is not deleted");
    CHECK(files_delete("/messages/alice") == FAT_OK && files_delete("/messages") == FAT_OK && files_exists("/messages") == 0,
          "emptied directories are deleted, innermost first");
    CHECK(files_delete("/settings/empty") == FAT_OK && files_exists("/settings/empty") == 0 && files_exists("/settings/handedness") == 1,
          "a deleted file is gone and its neighbour is not");
    CHECK(files_delete("/") == FAT_BAD_NAME && files_delete("/settings/..") == FAT_BAD_NAME, "the root cannot be deleted, by any name");
    CHECK(files_delete("/settings/empty") == FAT_NOT_FOUND, "deleting what is not there says so");
    /* }}} */

    /* {{{ symlinks */
    CHECK(files_make_link("/latest", "/drawings/cat.raw") == FAT_OK, "a link to a file that is not there yet is made");
    struct fat_entry e;
    CHECK(files_exists("/latest") == 0 && files_resolve_link("/latest", &e) == FAT_OK && files_is_link(&e) == 1,
          "a link to nothing does not exist, but the link itself does, and is a link");
    CHECK(files_write("/latest", "meow", 4) == FAT_OK && strcmp(read_text("/drawings/cat.raw"), "meow") == 0,
          "writing through a link writes its target");
    CHECK(strcmp(read_text("/latest"), "meow") == 0 && files_exists("/latest") == 1 && files_size("/latest") == 4,
          "reading through it reads the target, and now it exists");
    CHECK(files_resolve_link("/latest", &e) == FAT_OK && e.size == 8 + strlen("/drawings/cat.raw") + 1,
          "the link is still its own small file, untouched by the write");
    CHECK(files_make_link("/drawings/newest", "cat.raw") == FAT_OK && strcmp(read_text("/drawings/newest"), "meow") == 0,
          "a relative target is found beside the link");
    CHECK(files_make_link("/programs/picture", "../drawings/cat.raw") == FAT_OK && strcmp(read_text("/programs/picture"), "meow") == 0,
          "a relative target can climb out of the link's directory");
    CHECK(files_make_link("/programs/settings", "/settings/handedness") == FAT_OK && strcmp(read_text("/programs/settings"), "r") == 0,
          "a target starting with '/' starts from the root, wherever the link is");
    CHECK(files_make_link("/d", "/drawings") == FAT_OK && strcmp(read_text("/d/cat.raw"), "meow") == 0,
          "a link to a directory is followed in the middle of a path");
    CHECK(files_write("/d/dog.raw", "woof", 4) == FAT_OK && strcmp(read_text("/drawings/dog.raw"), "woof") == 0,
          "and a file written through it lands in the real directory");
    names.n = 0;
    CHECK(files_list("/d", collect, &names) == FAT_OK && has(&names, "cat.raw") && has(&names, "dog.raw") && has(&names, "newest"),
          "listing through a link lists the directory it names, links shown as themselves");
    CHECK(files_make_link("/again", "/latest") == FAT_OK && strcmp(read_text("/again"), "meow") == 0, "a link to a link is followed to the end");
    char from[64], to[64];
    for (int i = 1; i <= FILES_HOPS; i++) {
        snprintf(from, sizeof from, "/chain/%d", i);
        if (i < FILES_HOPS) snprintf(to, sizeof to, "%d", i + 1);
        else snprintf(to, sizeof to, "/drawings/cat.raw");
        files_make_link(from, to);
    }
    CHECK(strcmp(read_text("/chain/1"), "meow") == 0, "a chain of %d links is followed", FILES_HOPS);
    files_make_link("/chain/0", "1");
    CHECK(files_read("/chain/0", 0, line, 10) == FAT_LOOP && files_exists("/chain/0") == 0, "one more than %d is too many", FILES_HOPS);
    CHECK(files_make_link("/loop-a", "/loop-b") == FAT_OK && files_make_link("/loop-b", "loop-a") == FAT_OK,
          "two links naming each other are made");
    CHECK(files_read("/loop-a", 0, line, 10) == FAT_LOOP && files_exists("/loop-b") == 0 && files_write("/loop-a/x", "x", 1) == FAT_LOOP,
          "reading, asking about and writing through a loop each end with an error");
    CHECK(files_make_link("/self", "self") == FAT_OK && files_read("/self", 0, line, 10) == FAT_LOOP, "a link to itself is a loop too");
    CHECK(files_make_link("/latest", "/elsewhere") == FAT_EXISTS && files_make_link("/empty-link", "") == FAT_BAD_NAME,
          "a link is not made over a name that is there, nor with no target");
    CHECK(files_delete("/latest") == FAT_OK && files_exists("/latest") == 0 && strcmp(read_text("/drawings/cat.raw"), "meow") == 0,
          "deleting a link removes the link, never its target");
    CHECK(files_delete("/d") == FAT_OK && files_exists("/drawings") == 1, "deleting a link to a directory leaves the directory");
    /* }}} */

    /* {{{ a second mount, and what a laptop sees */
    files_stop();
    CHECK(!files_ready() && files_exists("/settings") == FAT_NO_CARD, "a stopped card answers nothing");
    CHECK(files_start(OWNER) == FAT_OK && strcmp(read_text("/drawings/dog.raw"), "woof") == 0 &&
          strcmp(read_text("/programs/picture"), "meow") == 0 && strcmp(read_text("/settings/handedness"), "r") == 0,
          "a second mount finds files and links again");
    files_stop();
    struct fat_volume v;
    fat_mount(&v, OWNER);
    struct fat_entry programs, picture;
    uint8_t raw[64] = { 0 };
    CHECK(fat_dir_find(&v, v.root_cluster, "programs", &programs) == FAT_OK &&
          fat_dir_find(&v, programs.first_cluster, "picture", &picture) == FAT_OK &&
          fat_chain_read(&v, picture.first_cluster, 0, raw, picture.size) == FAT_OK &&
          memcmp(raw, "SOSYMLNK../drawings/cat.raw", 27) == 0 && raw[27] == 0,
          "on the card a link is an ordinary file: the magic bytes, the target, a zero");
    fat_unmount(&v);
    files_start(OWNER);
    /* }}} */

    /* {{{ four at once */
    pthread_t threads[4];
    for (int i = 0; i < 4; i++) pthread_create(&threads[i], NULL, writer, (void *)(intptr_t)i);
    for (int i = 0; i < 4; i++) pthread_join(threads[i], NULL);
    names.n = 0;
    files_list("/busy", collect, &names);
    CHECK(writer_failures == 0 && names.n == 4, "four threads writing their own files at once all read back what they wrote");
    /* }}} */

    files_stop();
    int checked = card_fsck(card, report);
    if (checked >= 0) {
        CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the card (its report: %s)", report);
    }
    remove(card);
    free(image);
    CHECK_DONE("081 paths and symlinks");
}
