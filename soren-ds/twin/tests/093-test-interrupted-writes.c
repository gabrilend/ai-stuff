/*
 * 093-test-interrupted-writes.c — issues 405, 406, 413.
 *
 * General description: the card is pulled out part-way through a write,
 * at every point a write can be interrupted. Each kind of write is first
 * run once to count the blocks it writes; then, for every count from
 * none of them to all of them, the card is put back as it was, the write
 * is started, the card leaves after that many blocks (a write of several
 * blocks landing only partly), and the card is mounted afresh. Every time,
 * the file must be its old self or its new self and never anything in
 * between; a write that said it succeeded must be its new self; a write
 * that was interrupted must have said so; and the card must still take a
 * write afterwards. The kinds: replacing a file, appending across
 * clusters, appending inside the last cluster's spare room, and making a
 * file in directories that are not there yet.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../../src/system/078-files.h"
#include "../026-platform-twin.h"
#include "047-check.h"
#include "080-card-image.h"

#include <string.h>

#define OWNER OWNER_OUTSIDE

static char card[600];
static uint8_t *saved;                  /* the card as it was before the write */
static uint8_t old_bytes[16384], new_bytes[16384], got[16384];
static uint32_t old_size, new_size;     /* old_size of 0 with old_missing: the file was not there */
static int old_missing;

/* {{{ pattern */
static void pattern(uint8_t *out, uint32_t seed, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        uint32_t x = (seed + i) * 2654435761u;
        out[i] = (uint8_t)(x >> 24 ^ x >> 13);
    }
}
/* }}} */

/* {{{ save / restore */
/* The card image file, kept and put back whole. */
static void save(void)
{
    FILE *f = fopen(card, "rb");
    if (!f || fread(saved, 1, image_bytes, f) != image_bytes) {
        fprintf(stderr, "cannot read %s\n", card);
        exit(2);
    }
    fclose(f);
}

static void restore(void)
{
    FILE *f = fopen(card, "r+b");
    if (!f || fwrite(saved, 1, image_bytes, f) != image_bytes) {
        fprintf(stderr, "cannot write %s\n", card);
        exit(2);
    }
    fclose(f);
}
/* }}} */

/* {{{ what is there */
/* 1 for the old file, 2 for the new, 0 for anything else. */
static int which(const char *path)
{
    int64_t size = files_size(path);
    if (size == FAT_NOT_FOUND) return old_missing ? 1 : 0;
    if (size < 0) return 0;
    int64_t n = files_read(path, 0, got, sizeof got);
    if (n != size) return 0;
    if (!old_missing && (uint32_t)n == old_size && memcmp(got, old_bytes, old_size) == 0) return 1;
    if ((uint32_t)n == new_size && memcmp(got, new_bytes, new_size) == 0) return 2;
    return 0;
}
/* }}} */

/* {{{ chain_exact */
/* Does the file's chain hold exactly the clusters its size needs? Only
 * asked after a write that went through. */
static int chain_exact(const char *path)
{
    struct fat_entry e;
    if (files_resolve(path, &e) != FAT_OK) return 0;
    files_stop();
    struct fat_volume v;
    int ok = fat_mount(&v, OWNER) == FAT_OK &&
             fat_chain_length(&v, e.first_cluster) == (e.size + v.cluster_bytes - 1) / v.cluster_bytes;
    fat_unmount(&v);
    files_start(OWNER);
    return ok;
}
/* }}} */

typedef int (*write_fn)(void);
static const char *target;
static const uint8_t *adding;
static uint32_t adding_length;

static int do_write(void) { return files_write(target, adding, adding_length); }
static int do_append(void) { return files_append(target, adding, adding_length); }

/* {{{ interrupt_everywhere */
/* Run `fn` on the saved card with the card pulled after 0, 1, ... blocks,
 * up to as many as it writes when nothing stops it. */
static void interrupt_everywhere(const char *what, write_fn fn)
{
    restore();
    twin_card_open(card);
    files_start(OWNER);
    uint64_t start = twin_card_blocks_written();
    int r = fn();
    uint64_t total = twin_card_blocks_written() - start;
    int whole = which(target);
    files_stop();
    CHECK(r == FAT_OK && whole == 2 && total > 2, "%s: uninterrupted, it writes %llu blocks and the file is the new one",
          what, (unsigned long long)total);

    int olds = 0, news = 0, torn = 0, silent = 0, lied = 0, unusable = 0, stray = 0;
    for (uint64_t k = 0; k < total; k++) {
        restore();
        twin_card_open(card);
        files_start(OWNER);
        twin_card_pull_after((int64_t)k);
        r = fn();
        files_stop();
        twin_card_open(card);               /* the card back in its slot */
        if (files_start(OWNER) != FAT_OK) {
            unusable++;
            continue;
        }
        int w = which(target);
        if (w == 1) olds++; else if (w == 2) news++; else torn++;
        if (r == FAT_OK) silent++;          /* interrupted, yet it said it worked */
        if (r == FAT_OK && w != 2) lied++;
        /* The card still takes a write, and the next append to the file
         * leaves a chain that is exactly its size. */
        static uint8_t more[700];
        pattern(more, (uint32_t)k, sizeof more);
        if (files_append(target, more, sizeof more) != FAT_OK) unusable++;
        else if (!chain_exact(target)) stray++;
        files_stop();
    }
    CHECK(torn == 0, "%s: pulled after each of its %llu blocks, the file is old (%d times) or new (%d), never torn (%d)",
          what, (unsigned long long)total, olds, news, torn);
    CHECK(silent == 0 && lied == 0, "%s: every interrupted write said it failed (%d said it worked)", what, silent);
    CHECK(unusable == 0 && stray == 0, "%s: and every time the card mounts and takes the next append, the chain exact (%d, %d)",
          what, unusable, stray);
}
/* }}} */

int main(void)
{
    twin_platform_init(2, (size_t)128 << 20);
    stripes_init(2, 4);
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    char line[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/093-card.img", dir);
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/093-interrupted-line.log", dir);
    remove(line);
    twin_platform_set_log(line, 0);

    /* {{{ the pull itself */
    struct layout l;
    format(&l, 4, 1);
    write_image(card);
    saved = malloc(image_bytes);
    twin_card_open(card);
    uint8_t block[512], back[512];
    memset(block, 0x5A, sizeof block);
    uint64_t before = twin_card_blocks_written();
    CHECK(platform_card_write(100, 1, block) == 0 && twin_card_blocks_written() == before + 1, "a block written is counted");
    uint8_t three[3 * 512];
    memset(three, 0xA5, sizeof three);
    twin_card_pull_after(2);
    CHECK(platform_card_write(200, 3, three) != 0, "a three-block write with room for two left fails");
    CHECK(platform_card_read(100, 1, back) != 0 && platform_card_write(100, 1, block) != 0,
          "and with the card gone, every read and write after it fails");
    twin_card_pull_after(-1);
    int landed = platform_card_read(200, 1, back) == 0 && back[0] == 0xA5 && platform_card_read(201, 1, back) == 0 && back[0] == 0xA5 &&
                 platform_card_read(202, 1, back) == 0 && back[0] == 0;
    CHECK(landed, "put back, the card holds the two blocks that landed and not the third");
    /* }}} */

    /* {{{ the card the writes start from */
    format(&l, 4, 1);
    write_image(card);
    twin_card_open(card);
    CHECK(files_start(OWNER) == FAT_OK, "a blank card mounts");
    old_size = 5000;
    pattern(old_bytes, 1, old_size);
    CHECK(files_write("/docs/a", old_bytes, old_size) == FAT_OK && files_write("/docs/other", "x", 1) == FAT_OK,
          "a 5000-byte file is on it, beside another");
    files_stop();
    save();
    /* }}} */

    target = "/docs/a";
    new_size = 9000;
    pattern(new_bytes, 2, new_size);
    adding = new_bytes;
    adding_length = new_size;
    interrupt_everywhere("replacing 5000 bytes with 9000", do_write);

    static uint8_t tail[3000];
    pattern(tail, 3, sizeof tail);
    memcpy(new_bytes, old_bytes, old_size);
    memcpy(new_bytes + old_size, tail, sizeof tail);
    new_size = old_size + sizeof tail;
    adding = tail;
    adding_length = sizeof tail;
    interrupt_everywhere("appending 3000 bytes across clusters", do_append);

    adding_length = 100;                    /* 5000 is 392 bytes into a cluster: 120 to spare */
    new_size = old_size + 100;
    interrupt_everywhere("appending 100 bytes inside the last cluster", do_append);

    target = "/new/deeper/b";
    old_missing = 1;
    new_size = 700;
    pattern(new_bytes, 4, new_size);
    adding = new_bytes;
    adding_length = new_size;
    interrupt_everywhere("making a file in two directories not there yet", do_write);

    remove(card);
    free(saved);
    free(image);
    CHECK_DONE("093 writes interrupted");
}
