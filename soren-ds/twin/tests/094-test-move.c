/*
 * 094-test-move.c — issue 414.
 *
 * General description: a file is given another name. Moving onto a new
 * name, into directories not there yet, and onto a file that is there
 * (replacing it, its clusters given back); a link moved as itself and a
 * file moved over a link; a directory neither moved nor replaced; the same
 * file spelt two ways left alone; a long name removed so its pieces do not
 * linger. Then the card is pulled out after every block a move writes, as
 * test 093 does for writes: the destination is the old file or the moved
 * one, never torn, and the two names never share one chain, which would
 * let deleting one free the other's bytes. Last, the box: a file built
 * from three appends under a name of its own is moved over the one a
 * reader uses, and the reader sees the old file or the whole new one.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/031-engine.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../../src/system/078-files.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "047-check.h"
#include "080-card-image.h"

#include <string.h>

#define CORES 2
#define OWNER OWNER_OUTSIDE
#define BOXES "../boxes/082-files.c"

struct path { char chars[256]; };
struct file_bytes { int64_t status; uint64_t file_size; uint32_t length; uint8_t bytes[4096]; };

static char card[600];
static uint8_t *saved;
static uint8_t got[20000];

/* {{{ pattern */
static void pattern(uint8_t *out, uint32_t seed, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        uint32_t x = (seed + i) * 2654435761u;
        out[i] = (uint8_t)(x >> 24 ^ x >> 13);
    }
}
/* }}} */

/* {{{ holds */
/* Does the file at `path` hold exactly these bytes? */
static int holds(const char *path, const uint8_t *bytes, uint32_t n)
{
    if (files_size(path) != (int64_t)n) return 0;
    return files_read(path, 0, got, sizeof got) == (int64_t)n && memcmp(got, bytes, n) == 0;
}
/* }}} */

/* {{{ free_clusters */
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

/* {{{ slots_in_use */
/* How many entries a directory lists, and how many slots on the card it
 * spends on them (live short entries plus long-name pieces not marked
 * deleted), read straight from its clusters. */
static int slots_in_use(const char *dir)
{
    struct fat_entry d;
    if (files_resolve(dir, &d) != FAT_OK) return -1;
    files_stop();
    struct fat_volume v;
    int used = 0;
    if (fat_mount(&v, OWNER) == FAT_OK) {
        uint8_t block[512];
        for (uint32_t c = d.first_cluster; c >= 2 && c < FAT_END; c = fat_next(&v, c)) {
            for (uint32_t s = 0; s < v.sectors_per_cluster; s++) {
                platform_card_read(fat_cluster_block(&v, c) + s, 1, block);
                for (int k = 0; k < 512; k += 32) {
                    if (block[k] == 0) goto done;
                    if (block[k] != 0xE5 && block[k] != '.') used++;
                }
            }
        }
    }
done:
    fat_unmount(&v);
    files_start(OWNER);
    return used;
}
/* }}} */

/* {{{ save / restore */
static void save(void)
{
    FILE *f = fopen(card, "rb");
    if (!f || fread(saved, 1, image_bytes, f) != image_bytes) exit(2);
    fclose(f);
}

static void restore(void)
{
    FILE *f = fopen(card, "r+b");
    if (!f || fwrite(saved, 1, image_bytes, f) != image_bytes) exit(2);
    fclose(f);
}
/* }}} */

/* {{{ stranger */
/* Is there a name in /work that nobody gave a file? A long name whose
 * pieces went before its short entry leaves the file under a short name
 * the card made up. */
static int unexpected_name(const struct fat_entry *e, void *ctx)
{
    if (strcmp(e->name, "built") != 0 && strcmp(e->name, "a name long enough for several long-name pieces.raw") != 0) {
        (*(int *)ctx)++;
    }
    return 0;
}
/* }}} */

/* {{{ interrupt_everywhere */
/* Move `from` onto `to` on the saved card, pulled after every block. */
static void interrupt_everywhere(const char *what, const char *from, const char *to,
                                 const uint8_t *moved, uint32_t moved_n, const uint8_t *old, uint32_t old_n)
{
    restore();
    twin_card_open(card);
    files_start(OWNER);
    uint64_t start = twin_card_blocks_written();
    int r = files_move(from, to);
    uint64_t total = twin_card_blocks_written() - start;
    CHECK(r == FAT_OK && holds(to, moved, moved_n) && files_exists(from) == 0,
          "%s: uninterrupted, it writes %llu blocks and the file has its new name only", what, (unsigned long long)total);
    files_stop();

    int olds = 0, news = 0, torn = 0, shared = 0, silent = 0, unusable = 0, strangers = 0;
    for (uint64_t k = 0; k < total; k++) {
        restore();
        twin_card_open(card);
        files_start(OWNER);
        twin_card_pull_after((int64_t)k);
        r = files_move(from, to);
        files_stop();
        twin_card_open(card);
        if (files_start(OWNER) != FAT_OK) {
            unusable++;
            continue;
        }
        int at_new = holds(to, moved, moved_n);
        int at_old = old ? holds(to, old, old_n) : files_exists(to) == 0;
        if (at_new) news++; else if (at_old) olds++; else torn++;
        struct fat_entry a, b;
        if (files_resolve_link(from, &a) == FAT_OK && files_resolve_link(to, &b) == FAT_OK &&
            a.first_cluster != 0 && a.first_cluster == b.first_cluster) shared++;
        if (r == FAT_OK) silent++;
        files_list("/work", unexpected_name, &strangers);
        /* The card still takes a write, and the name moved to holds it. */
        if (files_write(to, "after", 5) != FAT_OK || !holds(to, (const uint8_t *)"after", 5)) unusable++;
        files_stop();
    }
    CHECK(torn == 0, "%s: pulled after each of its %llu blocks, the destination is old (%d) or moved (%d), never torn (%d)",
          what, (unsigned long long)total, olds, news, torn);
    CHECK(shared == 0 && strangers == 0, "%s: the two names never share one chain (%d times), and no file is left under a name nobody gave it (%d)",
          what, shared, strangers);
    CHECK(silent == 0 && unusable == 0, "%s: every interrupted move said so, and the card takes the next write (%d, %d)",
          what, silent, unusable);
}
/* }}} */

static struct engine_error_report last_error;

/* {{{ call */
static int call(const char *function, int n, const void *const *args, const size_t *sizes, void *out, size_t out_size)
{
    char text[512];
    int at = snprintf(text, sizeof text, "station s (" BOXES ":%s)\n", function);
    for (int i = 0; i < n; i++) at += snprintf(text + at, sizeof text - (size_t)at, "  in %d - %d$\n", i, i);
    snprintf(text + at, sizeof text - (size_t)at, "  out 0 - 0$\n");
    static struct map_report report;
    int program = program_load_text("src/maps/move-box.map", text, strlen(text), &report);
    if (program < 0 || program_bring_up(program, &report) != 0) {
        fprintf(stderr, "%s did not load:\n%s", function, report.text);
        return -1;
    }
    for (int i = 0; i < n; i++) program_argument(program, i, args[i], sizes[i]);
    twin_engine_settle(30000);
    int answered = program_result(program, 0, out, out_size);
    engine_read_error(program_station(program, "s"), &last_error, 1);
    program_remove(program);
    return answered;
}
/* }}} */

/* {{{ path_of */
static struct path path_of(const char *s)
{
    struct path p;
    memset(&p, 0, sizeof p);
    snprintf(p.chars, sizeof p.chars, "%s", s);
    return p;
}
/* }}} */

/* {{{ box_move / box_append */
static int64_t box_move(const char *from, const char *to)
{
    struct path a = path_of(from), b = path_of(to);
    const void *args[] = { &a, &b };
    size_t sizes[] = { sizeof a, sizeof b };
    int64_t status = 99;
    call("move_path", 2, args, sizes, &status, sizeof status);
    return status;
}

static int64_t box_append(const char *path, const uint8_t *bytes, uint32_t n)
{
    struct path p = path_of(path);
    struct file_bytes *v = calloc(1, sizeof *v);
    memcpy(v->bytes, bytes, n);
    v->length = n;
    const void *args[] = { &p, v };
    size_t sizes[] = { sizeof p, sizeof *v };
    int64_t status = 99;
    call("append_path", 2, args, sizes, &status, sizeof status);
    free(v);
    return status;
}
/* }}} */

int main(void)
{
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    char line[600], report[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/094-card.img", dir);
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/094-move-line.log", dir);
    snprintf(report, sizeof report, "%s/tmp/shared-memory/test-logs/094-move.fsck", dir);
    remove(line);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(line, 0);
    engine_open_gate();

    CHECK(files_move("/a", "/b") == FAT_NO_CARD, "with no card mounted, a move says so");
    struct layout l;
    format(&l, 4, 1);
    write_image(card);
    saved = malloc(image_bytes);
    twin_card_open(card);
    CHECK(files_start(OWNER) == FAT_OK, "a blank card mounts");

    /* {{{ the moves */
    static uint8_t one[5000], two[9000];
    pattern(one, 1, sizeof one);
    pattern(two, 2, sizeof two);
    uint32_t blank = free_clusters();
    CHECK(files_write("/work/drawing-in-progress", one, sizeof one) == FAT_OK &&
          files_move("/work/drawing-in-progress", "/drawings/cat") == FAT_OK &&
          holds("/drawings/cat", one, sizeof one) && files_exists("/work/drawing-in-progress") == 0,
          "a file moves to a new name in a directory not there yet, and leaves its old name");
    CHECK(files_write("/work/next", two, sizeof two) == FAT_OK && files_move("/work/next", "/drawings/cat") == FAT_OK &&
          holds("/drawings/cat", two, sizeof two) && files_exists("/work/next") == 0,
          "a file moved onto one that is there replaces it");
    uint32_t used = (sizeof two + 511) / 512;
    CHECK(blank - free_clusters() == used + 2, "and the replaced file's clusters are given back (%u in use: the file and two directories)",
          blank - free_clusters());
    CHECK(files_move("/drawings/cat", "/DRAWINGS/Cat") == FAT_OK && holds("/drawings/cat", two, sizeof two),
          "moving a file onto itself, spelt another way, leaves it as it was");
    CHECK(files_move("/drawings/none", "/drawings/x") == FAT_NOT_FOUND, "a missing file cannot be moved");
    CHECK(files_move("/work", "/elsewhere") == FAT_IS_A_DIRECTORY && files_exists("/elsewhere") == 0,
          "a directory is not moved");
    CHECK(files_move("/drawings/cat", "/work") == FAT_IS_A_DIRECTORY && files_exists("/drawings/cat") == 1,
          "nor replaced by a file, which stays where it was");
    CHECK(files_move("/", "/x") == FAT_BAD_NAME && files_move("/drawings/cat", "/") == FAT_BAD_NAME,
          "the root is neither moved nor replaced");
    CHECK(files_make_link("/latest", "/drawings/cat") == FAT_OK && files_move("/latest", "/work/latest") == FAT_OK &&
          holds("/work/latest", two, sizeof two), "a link is moved as itself, and still leads to its target");
    struct fat_entry link;
    CHECK(files_resolve_link("/work/latest", &link) == FAT_OK && files_is_link(&link) == 1 && holds("/drawings/cat", two, sizeof two),
          "the moved name is the link, not a copy of the file");
    CHECK(files_write("/work/plain", one, sizeof one) == FAT_OK && files_move("/work/plain", "/work/latest") == FAT_OK &&
          holds("/work/latest", one, sizeof one) && holds("/drawings/cat", two, sizeof two),
          "a file moved onto a link replaces the link, not the file the link led to");
    const char *long_name = "/work/a name long enough for several long-name pieces.raw";
    int pieces = (int)(strlen(long_name) - strlen("/work/") + 12) / 13;
    int before = slots_in_use("/work");
    CHECK(files_write(long_name, one, 10) == FAT_OK && slots_in_use("/work") == before + pieces + 1,
          "a long name takes %d slots: its long-name pieces and its short entry", pieces + 1);
    CHECK(files_move(long_name, "/drawings/short") == FAT_OK && slots_in_use("/work") == before,
          "and moving it away marks every one of them free");
    files_stop();
    int checked = card_fsck(card, report);
    if (checked >= 0) CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the card");
    files_start(OWNER);
    /* }}} */

    /* {{{ interrupted */
    format(&l, 4, 1);
    write_image(card);
    twin_card_open(card);
    files_start(OWNER);
    files_write("/drawings/cat", one, sizeof one);
    files_write("/work/built", two, sizeof two);
    files_write("/work/a name long enough for several long-name pieces.raw", two, sizeof two);
    files_stop();
    save();
    interrupt_everywhere("replacing a file", "/work/built", "/drawings/cat", two, sizeof two, one, sizeof one);
    interrupt_everywhere("a long name onto a new name in a new directory", "/work/a name long enough for several long-name pieces.raw",
                         "/new/place/cat", two, sizeof two, NULL, 0);
    restore();
    twin_card_open(card);
    files_start(OWNER);
    /* }}} */

    /* {{{ the box: built under its own name, then appearing all at once */
    static uint8_t big[3 * 4096];
    pattern(big, 3, sizeof big);
    int all = 1;
    for (int i = 0; i < 3; i++) {
        all &= box_append("/drawings/.cat.building", big + i * 4096, 4096) == 0;
        all &= holds("/drawings/cat", one, sizeof one);        /* the reader's name: still the old file */
    }
    CHECK(all, "append-path builds a 12288-byte file under a name of its own while the reader's name keeps the old one");
    CHECK(box_move("/drawings/.cat.building", "/drawings/cat") == 0 && holds("/drawings/cat", big, sizeof big) &&
          files_exists("/drawings/.cat.building") == 0,
          "move-path puts the whole new file under the reader's name at once");
    CHECK(box_move("/drawings/missing", "/drawings/cat") == FAT_NOT_FOUND && last_error.kind == 0 && holds("/drawings/cat", big, sizeof big),
          "moving a missing file is a status in the value, and the destination is untouched");
    char deep[256] = "";
    for (int i = 0; i < 70; i++) strcat(deep, "/d");
    CHECK(box_move("/drawings/cat", deep) == 99 && last_error.kind == 1 && last_error.detail == (uint64_t)-FAT_TOO_LONG &&
          holds("/drawings/cat", big, sizeof big),
          "a destination deeper than any path may go is refused, and nothing moves");
    /* }}} */

    files_stop();
    twin_engine_stop();
    checked = card_fsck(card, report);
    if (checked >= 0) CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the last card");
    remove(card);
    free(saved);
    free(image);
    CHECK_DONE("094 moving files");
}
