/*
 * 092-test-append.c — issue 413.
 *
 * General description: a file larger than one value is built on the card
 * by appending to it, one value at a time. The path layer is checked on
 * cards of one-sector and eight-sector clusters: appends that fit in the
 * last cluster's spare room, ones that cross into new clusters, ones that
 * start exactly at a cluster's end; a file built from many appends of
 * every size up to 4096 bytes reads back byte for byte and holds exactly
 * the clusters its size needs. An append goes through a symlink to its
 * target, is refused on a directory, and on a full card leaves the file
 * and the free space as they were. A card left by an append interrupted
 * after its clusters were linked but before its size was written reads
 * as the old file, and the next append lets the stray clusters go. Two
 * threads appending to one file at once leave every record whole.
 *
 * Then the box: append-path placed in a map and fed through its doors,
 * and a read-slice wired into an append-path copies a 10000-byte file
 * onto the card 4096 bytes at a time, which is the point of the issue.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../../src/system/078-files.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "047-check.h"
#include "080-card-image.h"

#include <pthread.h>
#include <string.h>

#define CORES 2
#define OWNER OWNER_OUTSIDE
#define BOXES "../boxes/082-files.c"

struct path { char chars[256]; };
struct file_bytes { int64_t status; uint64_t file_size; uint32_t length; uint8_t bytes[4096]; };

static uint8_t expected[1 << 18];       /* what the file being built should hold */
static uint8_t got[1 << 18];

/* {{{ pattern */
/* Bytes nobody would write by accident, different at every offset. */
static void pattern(uint8_t *out, uint32_t from, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        uint32_t x = (from + i) * 2654435761u;
        out[i] = (uint8_t)(x >> 24 ^ x >> 11);
    }
}
/* }}} */

/* {{{ free_clusters */
/* The card's free space as a fresh mount counts it. */
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

/* {{{ chain_of */
/* How many clusters the chain of a file in a top-level directory holds,
 * read from a fresh mount; and its entry. */
static uint32_t chain_of(const char *dir, const char *name, struct fat_entry *out)
{
    files_stop();
    struct fat_volume v;
    struct fat_entry d, e;
    uint32_t n = 0;
    if (fat_mount(&v, OWNER) == FAT_OK && fat_dir_find(&v, v.root_cluster, dir, &d) == FAT_OK &&
        fat_dir_find(&v, d.first_cluster, name, &e) == FAT_OK) {
        n = fat_chain_length(&v, e.first_cluster);
        if (out) *out = e;
    }
    fat_unmount(&v);
    files_start(OWNER);
    return n;
}
/* }}} */

/* {{{ same */
/* Does the file hold exactly `n` bytes, and are they `expected`'s? */
static int same(const char *path, uint32_t n)
{
    if (files_size(path) != (int64_t)n) return 0;
    memset(got, 0, n);
    return files_read(path, 0, got, sizeof got) == (int64_t)n && memcmp(got, expected, n) == 0;
}
/* }}} */

/* {{{ the layer, on one card */
static void layer(const char *card, uint32_t spc, const char *report)
{
    const uint32_t cb = spc * 512;
    struct layout l;
    format(&l, spc == 1 ? 40 : 16, spc);
    write_image(card);
    twin_card_open(card);
    CHECK(files_start(OWNER) == FAT_OK, "[%u-byte clusters] a blank card mounts", cb);

    /* {{{ small appends, inside and across clusters */
    uint32_t size = 0;
    uint32_t steps[] = { 100, 1000, cb - 1100 % cb, 1, cb, 7 };
    int all = 1;
    for (size_t i = 0; i < sizeof steps / sizeof steps[0]; i++) {
        pattern(expected + size, size, steps[i]);
        all &= files_append("/logs/a.bin", expected + size, steps[i]) == FAT_OK;
        size += steps[i];
        all &= same("/logs/a.bin", size);
    }
    CHECK(all, "[%u] appends of 100, 1000, up to a cluster's end, 1, a whole cluster and 7 bytes each read back whole", cb);
    struct fat_entry e;
    CHECK(chain_of("logs", "a.bin", &e) == (size + cb - 1) / cb && e.size == size,
          "[%u] and the chain holds exactly the clusters %u bytes need", cb, size);
    /* }}} */

    /* {{{ a big file from many values */
    uint32_t before = free_clusters();
    size = 0;
    uint32_t length = 1;
    all = 1;
    for (int i = 0; size + 4096 <= sizeof expected - 4096 && i < 120; i++) {
        length = (length * 1103515245u + 12345u) % 4096 + 1;
        if (i % 10 == 0) length = 4096;
        pattern(expected + size, size * 7, length);
        all &= files_append("/logs/big.bin", expected + size, length) == FAT_OK;
        size += length;
    }
    CHECK(all && same("/logs/big.bin", size), "[%u] a %u-byte file built from 120 appends of 1 to 4096 bytes reads back byte for byte", cb, size);
    uint32_t clusters = chain_of("logs", "big.bin", NULL);
    CHECK(clusters == (size + cb - 1) / cb && before - free_clusters() == clusters,
          "[%u] it holds %u clusters, every one taken from the free count and none lost", cb, clusters);
    /* }}} */

    /* {{{ nothing, empty files, links, directories */
    CHECK(files_append("/logs/big.bin", "x", 0) == FAT_OK && same("/logs/big.bin", size), "[%u] appending nothing changes nothing", cb);
    CHECK(files_append("/logs/new/empty", "x", 0) == FAT_OK && files_exists("/logs/new/empty") == 1 && files_size("/logs/new/empty") == 0,
          "[%u] appending nothing to a missing file makes it, empty, with its directory", cb);
    CHECK(files_append("/logs/new/empty", "abc", 3) == FAT_OK && files_read("/logs/new/empty", 0, got, 16) == 3 && memcmp(got, "abc", 3) == 0,
          "[%u] and appending to an empty file gives it its first cluster", cb);
    CHECK(files_make_link("/logs/latest", "/logs/new/empty") == FAT_OK && files_append("/logs/latest", "def", 3) == FAT_OK &&
          files_read("/logs/new/empty", 0, got, 16) == 6 && memcmp(got, "abcdef", 6) == 0,
          "[%u] an append through a symlink grows its target", cb);
    struct fat_entry link;
    CHECK(files_resolve_link("/logs/latest", &link) == FAT_OK && files_is_link(&link) == 1,
          "[%u] and leaves the link a link", cb);
    CHECK(files_append("/logs", "x", 1) == FAT_IS_A_DIRECTORY && same("/logs/big.bin", size),
          "[%u] a directory cannot be appended to", cb);
    /* }}} */

    /* {{{ a full card */
    uint32_t free_now = free_clusters();
    static uint8_t filler[1 << 16];
    uint32_t filled = 0;
    while (files_append("/full/filler", filler, sizeof filler) == FAT_OK) filled++;
    uint32_t left = free_clusters();
    int64_t filler_size = files_size("/full/filler");
    int r = files_append("/logs/big.bin", expected, (left + 1) * cb);
    CHECK(filled > 0 && r == FAT_NO_SPACE && same("/logs/big.bin", size) && free_clusters() == left && files_size("/full/filler") == filler_size,
          "[%u] on a full card an append that does not fit says so, and leaves the file and the free space as they were", cb);
    CHECK(files_delete("/full/filler") == FAT_OK && files_delete("/full") == FAT_OK && free_clusters() == free_now,
          "[%u] and deleting the filler and its directory gives everything back", cb);
    /* }}} */

    /* {{{ an append interrupted before its size was written */
    files_stop();
    struct fat_volume v;
    struct fat_entry d, b;
    uint8_t tail[3 * 4096];
    pattern(tail, 999, sizeof tail);
    CHECK(fat_mount(&v, OWNER) == FAT_OK && fat_dir_find(&v, v.root_cluster, "logs", &d) == FAT_OK &&
          fat_dir_find(&v, d.first_cluster, "big.bin", &b) == FAT_OK &&
          fat_chain_append(&v, b.first_cluster, b.size, tail, sizeof tail) == FAT_OK,
          "[%u] new clusters are linked onto the file, and the card is put down before its size is written", cb);
    uint32_t stray = fat_chain_length(&v, b.first_cluster) - (size + cb - 1) / cb;
    fat_unmount(&v);
    files_start(OWNER);
    CHECK(stray > 0 && same("/logs/big.bin", size), "[%u] the file reads as it was, with %u stray clusters after it", cb, stray);
    uint32_t free_stray = free_clusters();
    pattern(expected + size, size * 7, 10);
    CHECK(files_append("/logs/big.bin", expected + size, 10) == FAT_OK && same("/logs/big.bin", size + 10),
          "[%u] the next append reads back whole", cb);
    size += 10;
    CHECK(chain_of("logs", "big.bin", NULL) == (size + cb - 1) / cb && free_clusters() >= free_stray + stray - 1,
          "[%u] and the stray clusters were given back rather than kept", cb);
    /* }}} */

    files_stop();
    int checked = card_fsck(card, report);
    if (checked >= 0) CHECK(checked == 1, "[%u] the laptop's fsck.fat finds nothing wrong with the card", cb);
}
/* }}} */

/* {{{ two at once */
#define RECORD 37
#define RECORDS 60
static int appender_failures;

static void *appender(void *arg)
{
    uint8_t record[RECORD];
    memset(record, (int)(intptr_t)arg, sizeof record);
    for (int i = 0; i < RECORDS; i++) {
        if (files_append("/shared/log", record, RECORD) != FAT_OK) __atomic_add_fetch(&appender_failures, 1, __ATOMIC_RELAXED);
    }
    return NULL;
}
/* }}} */

static struct engine_error_report last_error;

/* {{{ call */
/* Run one box once, its arguments and result doors (as 083 does). */
static int call(const char *function, int n, const void *const *args, const size_t *sizes, void *out, size_t out_size)
{
    char text[512];
    int at = snprintf(text, sizeof text, "station s (" BOXES ":%s)\n", function);
    for (int i = 0; i < n; i++) at += snprintf(text + at, sizeof text - (size_t)at, "  in %d - %d$\n", i, i);
    snprintf(text + at, sizeof text - (size_t)at, "  out 0 - 0$\n");
    static struct map_report report;
    int program = program_load_text("src/maps/append-box.map", text, strlen(text), &report);
    if (program < 0 || program_bring_up(program, &report) != 0) {
        fprintf(stderr, "%s did not load:\n%s", function, report.text);
        return -1;
    }
    for (int i = 0; i < n; i++) program_argument(program, i, args[i], sizes[i]);
    twin_engine_settle(5000);
    int answered = program_result(program, 0, out, out_size);
    engine_read_error(program_station(program, "s"), &last_error, 1);
    program_remove(program);
    return answered;
}
/* }}} */

/* {{{ append_box */
static int64_t append_box(const char *path, const struct file_bytes *value)
{
    struct path p;
    memset(&p, 0, sizeof p);
    snprintf(p.chars, sizeof p.chars, "%s", path);
    const void *args[] = { &p, value };
    size_t sizes[] = { sizeof p, sizeof *value };
    int64_t status = 99;
    call("append_path", 2, args, sizes, &status, sizeof status);
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
    char card[600], line[600], report[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/092-card.img", dir);
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/092-append-line.log", dir);
    snprintf(report, sizeof report, "%s/tmp/shared-memory/test-logs/092-append.fsck", dir);
    remove(line);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(line, 0);
    engine_open_gate();

    CHECK(files_append("/x", "x", 1) == FAT_NO_CARD, "with no card mounted, an append says so");
    layer(card, 1, report);
    layer(card, 8, report);

    /* {{{ two threads, one file */
    struct layout l;
    format(&l, 40, 1);
    write_image(card);
    twin_card_open(card);
    files_start(OWNER);
    pthread_t threads[2];
    for (int i = 0; i < 2; i++) pthread_create(&threads[i], NULL, appender, (void *)(intptr_t)('A' + i));
    for (int i = 0; i < 2; i++) pthread_join(threads[i], NULL);
    static uint8_t log[2 * RECORDS * RECORD];
    int whole = files_read("/shared/log", 0, log, sizeof log) == (int64_t)sizeof log;
    int counts[2] = { 0, 0 };
    for (int i = 0; whole && i < 2 * RECORDS; i++) {
        uint8_t c = log[i * RECORD];
        for (int k = 1; k < RECORD; k++) whole &= log[i * RECORD + k] == c;
        if (c == 'A' || c == 'B') counts[c - 'A']++; else whole = 0;
    }
    CHECK(appender_failures == 0 && whole && counts[0] == RECORDS && counts[1] == RECORDS,
          "two threads appending 37-byte records to one file at once: all %d there, none torn or interleaved", 2 * RECORDS);
    /* }}} */

    /* {{{ the box */
    const struct catalogue_type *tb = catalogue_type_named("struct file_bytes");
    CHECK(tb && tb->size == sizeof(struct file_bytes), "the catalogue knows the value append-path takes, at the size this test writes it");
    struct file_bytes *value = calloc(1, sizeof *value);
    pattern(expected, 0, 3 * 4096);
    int all = 1;
    for (int i = 0; i < 3; i++) {
        memcpy(value->bytes, expected + i * 4096, 4096);
        value->length = 4096;
        all &= append_box("/drawings/cat.raw", value) == 0;
    }
    CHECK(all && same("/drawings/cat.raw", 3 * 4096), "append-path builds a 12288-byte file from three full values");
    value->status = FAT_NOT_FOUND;
    value->length = 10;
    CHECK(append_box("/drawings/cat.raw", value) == FAT_NOT_FOUND && same("/drawings/cat.raw", 3 * 4096),
          "a failed read is not appended: its status is passed on and the file is as it was");
    value->status = 0;
    value->length = 5000;
    CHECK(append_box("/drawings/cat.raw", value) == 99 && last_error.kind == 1 && last_error.detail == (uint64_t)-FAT_TOO_LONG &&
          same("/drawings/cat.raw", 3 * 4096),
          "a value claiming more bytes than it can hold is refused, and nothing is appended");
    value->length = 1;
    CHECK(append_box("/drawings", value) == FAT_IS_A_DIRECTORY && last_error.kind == 0, "a directory is a status in the value, not a refusal");

    static uint8_t big[10000];
    pattern(big, 77, sizeof big);
    CHECK(files_write("/drawings/large.raw", big, sizeof big) == FAT_OK, "a 10000-byte file is on the card");
    const char *copy =
        "station from (" BOXES ":read_slice)\n  in 0 - 0$\n  in 1 - 1$\n  in 2 - 2$\n  out 0 - to.1\n"
        "station to (" BOXES ":append_path)\n  in 0 - 3$\n  in 1 - from.0\n  out 0 - 0$\n";
    static struct map_report map_report;
    int program = program_load_text("src/maps/copy-in-slices.map", copy, strlen(copy), &map_report);
    CHECK(program >= 0 && program_bring_up(program, &map_report) == 0, "a read-slice wired into an append-path loads (%s)", map_report.text);
    struct path src, dst;
    memset(&src, 0, sizeof src);
    memset(&dst, 0, sizeof dst);
    strcpy(src.chars, "/drawings/large.raw");
    strcpy(dst.chars, "/backup/large.raw");
    all = 1;
    for (uint64_t offset = 0; offset < sizeof big; offset += 4096) {
        uint64_t length = 4096;
        program_argument(program, 0, &src, sizeof src);
        program_argument(program, 1, &offset, sizeof offset);
        program_argument(program, 2, &length, sizeof length);
        program_argument(program, 3, &dst, sizeof dst);
        twin_engine_settle(5000);
        int64_t status = 99;
        all &= program_result(program, 0, &status, sizeof status) == 1 && status == 0;
    }
    memcpy(expected, big, sizeof big);
    CHECK(all && same("/backup/large.raw", sizeof big), "and copies the file 4096 bytes at a time: three appends, the copy byte for byte");
    program_remove(program);
    free(value);
    /* }}} */

    files_stop();
    twin_engine_stop();
    int checked = card_fsck(card, report);
    if (checked >= 0) CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the last card");
    remove(card);
    free(image);
    CHECK_DONE("092 appending to files");
}
