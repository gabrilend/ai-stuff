/*
 * 079-test-fat.c — issues 402, 403, 404.
 *
 * General description: the FAT32 layer is tested against cards it did not
 * write. A small formatter here lays out a card the way a laptop's
 * formatting tool does (a partition table, a FAT32 boot block, the FSInfo
 * block, two copies of the table) and then, as a laptop would, writes a
 * few files into it with its own code: a lower-case 8.3 name, a long name
 * whose contents are scattered over the card out of order, a deleted
 * entry, a volume label and a subdirectory. The layer must read all of
 * that back exactly, from a card with a partition table and from one
 * formatted whole without one; refuse cards that are not FAT32, or whose
 * boot block does not add up, with a line saying why; write files and
 * directories a second mount finds again; keep both copies of the table
 * identical; give every entry of a crowded directory its own short name;
 * and survive a damaged chain without reading outside its table. The same
 * checks run on two layouts, one sector per cluster and eight. When the
 * laptop has fsck.fat, it is asked to check every card the layer wrote;
 * when it has mkfs.fat and sfdisk, the writing checks also run on a card
 * they made.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/system/077-fat.h"
#include "../026-platform-twin.h"
#include "047-check.h"
#include "080-card-image.h"

#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#define OWNER OWNER_OUTSIDE

static char log_path[600];

/* {{{ the laptop's side: a few files on a card 080-card-image.h formatted */
/* {{{ cluster_at */
static uint8_t *cluster_at(const struct layout *l, uint32_t c) { return blk(l->data_lba + (uint64_t)(c - 2) * l->spc); }
/* }}} */

/* {{{ checksum */
static uint8_t checksum(const uint8_t *short11)
{
    uint8_t sum = 0;
    for (int i = 0; i < 11; i++) sum = (uint8_t)((sum >> 1) | (sum << 7)) + short11[i];
    return sum;
}
/* }}} */

/* {{{ laptop_entry */
/* Write one directory entry the way a laptop does, long-name pieces
 * first (last piece first), into `dir` starting at slot `*slot`. A NULL
 * long name writes the short entry alone; `nt` is the lower-case flags. */
static void laptop_entry(uint8_t *dir, int *slot, const char *long_name, const char *short11,
                         uint8_t attributes, uint8_t nt, uint32_t cluster, uint32_t size)
{
    static const int at[13] = { 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30 };
    if (long_name) {
        int length = (int)strlen(long_name);
        int pieces = (length + 12) / 13;
        uint8_t sum = checksum((const uint8_t *)short11);
        for (int k = pieces; k >= 1; k--) {
            uint8_t *e = dir + 32 * (*slot)++;
            memset(e, 0, 32);
            e[0] = (uint8_t)(k | (k == pieces ? 0x40 : 0));
            e[11] = 0x0F;
            e[13] = sum;
            for (int c = 0; c < 13; c++) {
                int i = (k - 1) * 13 + c;
                put16(e + at[c], i < length ? (uint8_t)long_name[i] : i == length ? 0 : 0xFFFF);
            }
        }
    }
    uint8_t *e = dir + 32 * (*slot)++;
    memset(e, 0, 32);
    memcpy(e, short11, 11);
    e[11] = attributes;
    e[12] = nt;
    put16(e + 20, (uint16_t)(cluster >> 16));
    put16(e + 26, (uint16_t)cluster);
    put32(e + 28, size);
}
/* }}} */

/* {{{ pattern */
/* Contents that differ at every byte and between files, so a block read
 * from the wrong place cannot pass. */
static uint8_t pattern(uint32_t seed, uint32_t i)
{
    uint32_t x = (i + 1) * 2654435761u ^ (seed * 40503u);
    return (uint8_t)(x >> 13);
}
/* }}} */

/* {{{ laptop_file */
/* A file's contents laid over the clusters named, in that order. */
static void laptop_file(const struct layout *l, const uint32_t *clusters, int n, uint32_t seed, uint32_t size)
{
    uint32_t cb = l->spc * BLOCK;
    for (int k = 0; k < n; k++) {
        set_fat(l, clusters[k], k + 1 < n ? clusters[k + 1] : 0x0FFFFFFFu);
        for (uint32_t j = 0; j < cb; j++) {
            uint32_t i = (uint32_t)k * cb + j;
            cluster_at(l, clusters[k])[j] = i < size ? pattern(seed, i) : 0;
        }
    }
}
/* }}} */

#define LONG_NAME "A long name, longer than thirteen.txt"
static const uint32_t readme_chain[] = { 3, 4 };
static const uint32_t scattered_chain[] = { 10, 7, 20, 8 };   /* out of order on purpose */
#define USED_BY_LAPTOP 9                                       /* root, 2 + 4 above, notes, todo */

/* {{{ laptop_files */
/* What a laptop leaves on the card before the device ever sees it. */
static void laptop_files(struct layout *l, uint32_t *readme_size, uint32_t *scattered_size)
{
    uint32_t cb = l->spc * BLOCK;
    uint8_t *root = cluster_at(l, 2);
    int slot = 0;
    laptop_entry(root, &slot, NULL, "SORENTEST  ", 0x08, 0, 0, 0);             /* the volume label */
    *readme_size = cb + 188;
    laptop_entry(root, &slot, NULL, "README  TXT", 0x20, 0x18, 3, *readme_size);
    laptop_file(l, readme_chain, 2, 1, *readme_size);
    int gone = slot;
    laptop_entry(root, &slot, "gone for good.txt", "GONEFO~1TXT", 0x20, 0, 0, 0);
    for (int s = gone; s < slot; s++) root[32 * s] = 0xE5;                      /* deleted, as a laptop deletes */
    *scattered_size = 3 * cb + 100;
    laptop_entry(root, &slot, LONG_NAME, "ALONGN~1TXT", 0x20, 0, 10, *scattered_size);
    laptop_file(l, scattered_chain, 4, 2, *scattered_size);
    laptop_entry(root, &slot, NULL, "NOTES      ", 0x10, 0x08, 30, 0);
    set_fat(l, 30, 0x0FFFFFFFu);
    uint8_t *notes = cluster_at(l, 30);
    int ns = 0;
    laptop_entry(notes, &ns, NULL, ".          ", 0x10, 0, 30, 0);
    laptop_entry(notes, &ns, NULL, "..         ", 0x10, 0, 0, 0);
    laptop_entry(notes, &ns, NULL, "TODO    TXT", 0x20, 0x18, 31, 5);
    set_fat(l, 31, 0x0FFFFFFFu);
    memcpy(cluster_at(l, 31), "hello", 5);
}
/* }}} */
/* }}} */

/* {{{ helpers on the device's side */
/* {{{ poke */
/* Change bytes of the card image behind the layer's back. */
static void poke(const char *path, uint64_t at, const void *bytes, size_t n)
{
    int fd = open(path, O_WRONLY);
    if (fd < 0 || pwrite(fd, bytes, n, (off_t)at) != (ssize_t)n) {
        fprintf(stderr, "cannot change %s\n", path);
        exit(2);
    }
    close(fd);
}
/* }}} */

/* {{{ log_says */
/* Did the developer's line, since the log was last emptied, say this? */
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

/* {{{ log_empty */
static void log_empty(void)
{
    twin_platform_set_log(NULL, 0);
    remove(log_path);
    twin_platform_set_log(log_path, 0);
}
/* }}} */

/* {{{ matches */
static int matches(const uint8_t *got, uint32_t seed, uint32_t from, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        if (got[i] != pattern(seed, from + i)) return 0;
    }
    return 1;
}
/* }}} */

struct listing {
    char names[256][FAT_NAME];
    int  n;
};

/* {{{ list_visit */
static int list_visit(const struct fat_entry *e, void *ctx)
{
    struct listing *l = ctx;
    if (l->n < 256) snprintf(l->names[l->n++], FAT_NAME, "%s", e->name);
    return 0;
}
/* }}} */

/* {{{ listed */
static int listed(const struct listing *l, const char *name)
{
    for (int i = 0; i < l->n; i++) if (strcmp(l->names[i], name) == 0) return 1;
    return 0;
}
/* }}} */

struct shorts {
    uint8_t names[256][11];
    int     n;
};

/* {{{ short_visit */
/* The short name each entry really carries on the card, read raw. */
static int short_visit(const struct fat_entry *e, void *ctx)
{
    struct shorts *s = ctx;
    uint8_t b[BLOCK];
    if (s->n < 256 && platform_card_read(e->location_block, 1, b) == 0) {
        memcpy(s->names[s->n++], b + e->location_offset, 11);
    }
    return 0;
}
/* }}} */

/* {{{ fsck_ok */
static int fsck_ok(const char *path)
{
    char report[700];
    snprintf(report, sizeof report, "%s.fsck", log_path);
    return card_fsck(path, report);
}
/* }}} */
/* }}} */

/* {{{ reading what a laptop wrote (402, 403, 404) */
static void reading_a_laptop_card(const char *path, uint32_t spc)
{
    struct layout l;
    uint32_t readme_size, scattered_size;
    format(&l, spc == 1 ? 40 : 16, spc);
    laptop_files(&l, &readme_size, &scattered_size);
    write_image(path);
    twin_card_open(path);
    uint32_t cb = spc * BLOCK;

    struct fat_volume v;
    log_empty();
    CHECK(fat_mount(&v, OWNER) == FAT_OK, "a laptop's FAT32 card mounts (%u sectors per cluster)", spc);
    CHECK(v.partition_lba == START && v.sectors_per_cluster == spc && v.cluster_bytes == cb,
          "the partition starts where the table says and its clusters are the size the boot block says");
    CHECK(v.reserved_sectors == 32 && v.n_fats == 2 && v.fat_sectors == l.fat_sectors && v.root_cluster == 2,
          "the boot block's fields are read as written");
    CHECK(v.fat_lba == l.fat_lba && v.data_lba == l.data_lba && fat_cluster_block(&v, 2) == l.data_lba,
          "the table and the data area are where the layout puts them, and cluster 2 is the first data block");
    CHECK(v.total_clusters == l.clusters, "every data cluster is counted (%u, expected %u)", v.total_clusters, l.clusters);
    CHECK(v.free_clusters == l.clusters - USED_BY_LAPTOP, "the free count is counted, not taken from FSInfo's \"unknown\" (%u)", v.free_clusters);
    CHECK(strcmp(v.label, "SORENTEST") == 0, "the label is read without its padding (\"%s\")", v.label);
    CHECK(log_says("FAT32 volume") && log_says("clusters free"), "mounting says what it found on the developer's line");

    /* The root: the label and the deleted entry are not files; the rest are. */
    struct listing root = { .n = 0 };
    CHECK(fat_dir_walk(&v, v.root_cluster, list_visit, &root) == FAT_OK, "the root directory walks");
    CHECK(root.n == 3 && listed(&root, "readme.txt") && listed(&root, LONG_NAME) && listed(&root, "notes"),
          "the walk finds the three live entries, lower-case flags honoured and the long name assembled (%d found)", root.n);
    CHECK(!listed(&root, "SORENTEST") && !listed(&root, "gone for good.txt"), "the volume label and a deleted entry are not listed");

    struct fat_entry e;
    CHECK(fat_dir_find(&v, v.root_cluster, "README.TXT", &e) == FAT_OK && e.size == readme_size && e.first_cluster == 3,
          "finding is case-insensitive, as FAT convention has it");
    CHECK(fat_dir_find(&v, v.root_cluster, "a LONG name, LONGER than thirteen.TXT", &e) == FAT_OK && e.first_cluster == 10,
          "a long name is found in any case");
    CHECK(e.first_slot + 3 == e.slot, "a long name's three pieces sit just before its short entry");
    CHECK(fat_dir_find(&v, v.root_cluster, "gone for good.txt", &e) == FAT_NOT_FOUND, "a deleted name is not found");

    /* A file scattered over the card, read whole and at awkward offsets. */
    fat_dir_find(&v, v.root_cluster, LONG_NAME, &e);
    CHECK(fat_chain_length(&v, e.first_cluster) == 4, "the scattered file's chain has four clusters");
    uint8_t *got = malloc(scattered_size);
    CHECK(fat_chain_read(&v, e.first_cluster, 0, got, scattered_size) == FAT_OK && matches(got, 2, 0, scattered_size),
          "a file whose clusters are out of order on the card reads back exactly");
    uint32_t awkward[][2] = { { cb - 3, 7 }, { cb + BLOCK - 1, 2 }, { 2 * cb + 17, cb }, { scattered_size - 1, 1 }, { 5, 0 } };
    int all = 1;
    for (size_t k = 0; k < sizeof awkward / sizeof awkward[0]; k++) {
        memset(got, 0, scattered_size);
        if (fat_chain_read(&v, e.first_cluster, awkward[k][0], got, awkward[k][1]) != FAT_OK ||
            !matches(got, 2, awkward[k][0], awkward[k][1])) all = 0;
    }
    CHECK(all, "reads that start and stop across block and cluster boundaries return the right bytes");
    CHECK(fat_chain_read(&v, e.first_cluster, 4 * cb - 10, got, 20) == FAT_IO, "a read past the chain's end is an error, not other bytes");
    free(got);

    /* A subdirectory: "." and ".." are not listed, its file is there. */
    CHECK(fat_dir_find(&v, v.root_cluster, "Notes", &e) == FAT_OK && (e.attributes & FAT_ATTR_DIRECTORY),
          "the subdirectory is found and says it is one");
    struct listing notes = { .n = 0 };
    fat_dir_walk(&v, e.first_cluster, list_visit, &notes);
    CHECK(notes.n == 1 && listed(&notes, "todo.txt"), "a subdirectory lists its file and not \".\" or \"..\"");
    char hello[6] = { 0 };
    CHECK(fat_dir_find(&v, e.first_cluster, "todo.txt", &e) == FAT_OK &&
          fat_chain_read(&v, e.first_cluster, 0, hello, 5) == FAT_OK && strcmp(hello, "hello") == 0,
          "a file in a subdirectory reads back");
    fat_unmount(&v);

    /* The same card with no partition table: the partition alone, its
     * boot block at block zero. */
    char whole[700];
    snprintf(whole, sizeof whole, "%s.whole", path);
    FILE *f = fopen(whole, "wb");
    CHECK(f && fwrite(blk(START), 1, image_bytes - (size_t)START * BLOCK, f) == image_bytes - (size_t)START * BLOCK,
          "a card with no partition table is written");
    if (f) fclose(f);
    twin_card_open(whole);
    CHECK(fat_mount(&v, OWNER) == FAT_OK && v.partition_lba == 0 && v.data_lba == l.data_lba - START,
          "a card formatted whole, with no partition table, mounts from block zero");
    CHECK(fat_dir_find(&v, v.root_cluster, "notes", &e) == FAT_OK && fat_dir_find(&v, e.first_cluster, "todo.txt", &e) == FAT_OK &&
          fat_chain_read(&v, e.first_cluster, 0, hello, 5) == FAT_OK && strcmp(hello, "hello") == 0,
          "and its files read back");
    fat_unmount(&v);
    remove(whole);
}
/* }}} */

/* {{{ refusing what is not FAT32 (402) */
static void refusing(const char *path)
{
    struct layout l;
    format(&l, 40, 1);
    write_image(path);
    twin_card_open(path);
    struct fat_volume v;
    uint8_t b[BLOCK];
    memcpy(b, blk(START), BLOCK);

    uint8_t type = 0x06;
    poke(path, 446 + 4, &type, 1);
    log_empty();
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32 && log_says("FAT16"), "a FAT16 partition is refused, and the line says FAT16");
    type = 0x07;
    poke(path, 446 + 4, &type, 1);
    log_empty();
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32 && log_says("exFAT"), "an exFAT partition is refused, and the line says exFAT");
    type = 0x0C;
    poke(path, 446 + 4, &type, 1);

    uint8_t bad[BLOCK];
    memcpy(bad, b, BLOCK);
    memcpy(bad + 3, "EXFAT   ", 8);
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "an exFAT boot block behind a FAT32 partition type is refused");
    memcpy(bad, b, BLOCK);
    put16(bad + 22, 200);                                   /* a 16-bit table size: FAT16's boot block */
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "a FAT16 boot block is refused");
    memcpy(bad, b, BLOCK);
    bad[13] = 0;                                            /* no sectors per cluster: would divide by zero */
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    log_empty();
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32 && log_says("does not add up"), "a boot block with zero sectors per cluster is refused, not divided by");
    memcpy(bad, b, BLOCK);
    bad[13] = 3;
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "a cluster size that is not a power of two is refused");
    memcpy(bad, b, BLOCK);
    put32(bad + 36, 4);                                     /* a table far too short for the clusters */
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "a table too short to describe every cluster is refused");
    memcpy(bad, b, BLOCK);
    put32(bad + 44, 0x0FFFFF00u);
    poke(path, (uint64_t)START * BLOCK, bad, BLOCK);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "a root directory outside the volume is refused");
    poke(path, (uint64_t)START * BLOCK, b, BLOCK);

    uint8_t no_signature[2] = { 0, 0 };
    poke(path, 510, no_signature, 2);
    CHECK(fat_mount(&v, OWNER) == FAT_NOT_FAT32, "a card with no partition-table signature is refused");
    uint8_t signature[2] = { 0x55, 0xAA };
    poke(path, 510, signature, 2);
    CHECK(fat_mount(&v, OWNER) == FAT_OK, "and once the card is put right it mounts");
    fat_unmount(&v);
}
/* }}} */

/* {{{ writing (403, 404), on any blank card */
static void writing(const char *path, const char *what)
{
    twin_card_open(path);
    struct fat_volume v;
    CHECK(fat_mount(&v, OWNER) == FAT_OK, "%s: the blank card mounts", what);
    uint32_t cb = v.cluster_bytes;
    uint32_t free_at_start = v.free_clusters;
    uint32_t total_clusters = v.total_clusters;

    /* A new chain, three and a half clusters long. */
    uint32_t size = 3 * cb + cb / 2;
    uint8_t *data = malloc(size), *back = malloc(4 * cb);
    for (uint32_t i = 0; i < size; i++) data[i] = pattern(7, i);
    int64_t first = fat_chain_new(&v, data, size);
    CHECK(first >= 2 && fat_chain_length(&v, (uint32_t)first) == 4 && v.free_clusters == free_at_start - 4,
          "%s: a new chain takes exactly the clusters it needs", what);
    CHECK(fat_chain_read(&v, (uint32_t)first, 0, back, size) == FAT_OK && memcmp(back, data, size) == 0,
          "%s: a new chain reads back exactly", what);
    CHECK(fat_chain_read(&v, (uint32_t)first, 0, back, 4 * cb) == FAT_OK && back[size] == 0 && back[4 * cb - 1] == 0,
          "%s: the last cluster's unused end is zeroes, not whatever was on the card", what);
    CHECK(fat_chain_new(&v, data, 0) == 0, "%s: an empty file has no chain", what);
    CHECK(fat_chain_new(&v, data, (v.free_clusters + 1) * cb) == FAT_NO_SPACE && v.free_clusters == free_at_start - 4,
          "%s: a chain larger than the free space is refused and takes nothing", what);

    struct fat_entry e;
    CHECK(fat_dir_add(&v, v.root_cluster, "drawing of a cat.raw", FAT_ATTR_ARCHIVE, (uint32_t)first, size, &e) == FAT_OK,
          "%s: a long name is added to the root", what);
    CHECK(fat_dir_add(&v, v.root_cluster, "Drawing Of A Cat.RAW", FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_EXISTS,
          "%s: the same name in another case already exists", what);
    CHECK(fat_dir_add(&v, v.root_cluster, "a/b", FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_BAD_NAME &&
          fat_dir_add(&v, v.root_cluster, "..", FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_BAD_NAME &&
          fat_dir_add(&v, v.root_cluster, "", FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_BAD_NAME,
          "%s: names FAT cannot hold are refused", what);

    /* A directory, and enough names in it to need a second cluster. */
    int64_t dir = fat_dir_make(&v, v.root_cluster);
    CHECK(dir >= 2 && fat_dir_add(&v, v.root_cluster, "messages", FAT_ATTR_DIRECTORY, (uint32_t)dir, 0, NULL) == FAT_OK,
          "%s: a directory is made and named", what);
    uint8_t raw[BLOCK];
    platform_card_read(fat_cluster_block(&v, (uint32_t)dir), 1, raw);
    CHECK(raw[0] == '.' && raw[1] == ' ' && raw[32] == '.' && raw[33] == '.' && (raw[11] & FAT_ATTR_DIRECTORY) &&
          (raw[26] | raw[27] << 8 | raw[20] << 16 | raw[21] << 24) == dir && (raw[32 + 26] | raw[32 + 27] << 8) == 0,
          "%s: a new directory's \".\" names itself and its \"..\" names the root as 0", what);
    int names = 3 * (int)(cb / 32) + 5;
    if (names > 200) names = 200;
    int added = 0;
    for (int i = 0; i < names; i++) {
        char name[64];
        snprintf(name, sizeof name, "message-%04d.txt", i);
        if (fat_dir_add(&v, (uint32_t)dir, name, FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_OK) added++;
    }
    CHECK(added == names, "%s: %d names that shorten alike are all added (%d)", what, names, added);
    CHECK(fat_chain_length(&v, (uint32_t)dir) > 1, "%s: the directory grew past its first cluster", what);
    struct shorts s = { .n = 0 };
    fat_dir_walk(&v, (uint32_t)dir, short_visit, &s);
    int distinct = s.n == names;
    for (int i = 0; i < s.n && distinct; i++) {
        for (int j = i + 1; j < s.n && distinct; j++) distinct = memcmp(s.names[i], s.names[j], 11) != 0;
    }
    CHECK(distinct, "%s: every one of them has its own short name on the card (%d read)", what, s.n);
    struct listing l = { .n = 0 };
    fat_dir_walk(&v, (uint32_t)dir, list_visit, &l);
    CHECK(l.n == names && listed(&l, "message-0000.txt") && listed(&l, "message-0070.txt") == (names > 70),
          "%s: and every long name reads back (%d)", what, l.n);

    /* Removing one takes its long-name pieces too, and nothing else. */
    CHECK(fat_dir_find(&v, (uint32_t)dir, "message-0003.txt", &e) == FAT_OK && fat_dir_remove(&v, &e) == FAT_OK &&
          fat_dir_find(&v, (uint32_t)dir, "message-0003.txt", &e) == FAT_NOT_FOUND &&
          fat_dir_find(&v, (uint32_t)dir, "message-0002.txt", &e) == FAT_OK && fat_dir_find(&v, (uint32_t)dir, "message-0004.txt", &e) == FAT_OK,
          "%s: a removed name is gone and its neighbours are not", what);
    CHECK(fat_dir_add(&v, (uint32_t)dir, "a replacement with a much longer name than before.txt", FAT_ATTR_ARCHIVE, 0, 0, NULL) == FAT_OK &&
          fat_dir_find(&v, (uint32_t)dir, "a replacement with a much longer name than before.txt", &e) == FAT_OK,
          "%s: a name too long for the freed slots is put elsewhere and found", what);

    /* Pointing an entry at a new chain: one block write. */
    fat_dir_find(&v, v.root_cluster, "drawing of a cat.raw", &e);
    int64_t second = fat_chain_new(&v, data, 100);
    CHECK(second >= 2 && fat_dir_update(&v, &e, (uint32_t)second, 100) == FAT_OK &&
          fat_dir_find(&v, v.root_cluster, "drawing of a cat.raw", &e) == FAT_OK && e.first_cluster == (uint32_t)second && e.size == 100,
          "%s: an entry updated in place names its new chain and size", what);
    uint32_t before = v.free_clusters;
    fat_chain_free(&v, (uint32_t)first);
    CHECK(v.free_clusters == before + 4, "%s: freeing the old chain gives back its four clusters", what);

    /* Everything written survives a second mount, and both tables agree. */
    uint32_t free_now = v.free_clusters;
    CHECK(fat_flush(&v) == FAT_OK, "%s: the table is written back", what);
    uint64_t fat_lba = v.fat_lba, fat_sectors = v.fat_sectors, fsinfo = v.partition_lba + v.fsinfo_sector;
    fat_unmount(&v);
    int same = 1;
    uint8_t one[BLOCK], two[BLOCK];
    for (uint64_t k = 0; k < fat_sectors && same; k++) {
        platform_card_read(fat_lba + k, 1, one);
        platform_card_read(fat_lba + fat_sectors + k, 1, two);
        same = memcmp(one, two, BLOCK) == 0;
    }
    CHECK(same, "%s: both copies of the table are identical on the card", what);
    platform_card_read(fsinfo, 1, one);
    CHECK(get32(one + 488) == free_now, "%s: FSInfo's free count is the layer's own", what);
    CHECK(fat_mount(&v, OWNER) == FAT_OK && v.free_clusters == free_now, "%s: a second mount counts the same free space", what);
    CHECK(fat_dir_find(&v, v.root_cluster, "messages", &e) == FAT_OK && fat_dir_find(&v, e.first_cluster, "message-0001.txt", &e) == FAT_OK,
          "%s: a second mount finds the directory and a name in it", what);
    CHECK(fat_dir_find(&v, v.root_cluster, "drawing of a cat.raw", &e) == FAT_OK &&
          fat_chain_read(&v, e.first_cluster, 0, back, 100) == FAT_OK && memcmp(back, data, 100) == 0,
          "%s: and the file's new contents", what);
    fat_unmount(&v);
    free(data);
    free(back);

    /* Only a card with FAT32's minimum of 65525 clusters is put to the
     * checker; a smaller one is FAT32 to this layer and to Linux, but the
     * checker warns about its size whatever was written. */
    int checked = total_clusters >= 65525 ? fsck_ok(path) : -1;
    if (checked >= 0) {
        CHECK(checked == 1, "%s: the laptop's fsck.fat finds nothing wrong with what was written (its report: %s.fsck)", what, log_path);
    }
}
/* }}} */

/* {{{ a damaged chain (404) */
static void damaged(const char *path)
{
    struct layout l;
    format(&l, 40, 1);
    write_image(path);
    twin_card_open(path);
    struct fat_volume v;
    fat_mount(&v, OWNER);
    uint8_t data[BLOCK * 2] = { 1 };
    uint32_t a = (uint32_t)fat_chain_new(&v, data, sizeof data);
    uint32_t b = fat_next(&v, a);
    /* The second cluster now names one far past the end of the volume. */
    v.pieces[b / FAT_PIECE_ENTRIES][b % FAT_PIECE_ENTRIES] = 0x0FFFF000u;
    uint8_t got[BLOCK * 3];
    CHECK(fat_next(&v, 0x0FFFF000u) >= FAT_END, "asking for the cluster after one outside the volume answers an end");
    CHECK(fat_chain_length(&v, a) == 2, "a chain that runs off the volume is counted to its last real cluster");
    CHECK(fat_chain_read(&v, a, 0, got, sizeof got) == FAT_IO, "reading into it is an error, not memory outside the table");
    /* And now it loops back on itself. */
    v.pieces[b / FAT_PIECE_ENTRIES][b % FAT_PIECE_ENTRIES] = a;
    CHECK(fat_chain_length(&v, a) == v.total_clusters + 1, "a looping chain's length stops at the volume's size");
    uint32_t free_before = v.free_clusters;
    fat_chain_free(&v, a);
    CHECK(v.free_clusters == free_before + 2, "a looping chain is freed once, and the free walk stops");
    /* A directory whose chain loops is walked to FAT's limit, not forever. */
    int64_t dir = fat_dir_make(&v, v.root_cluster);
    v.pieces[dir / FAT_PIECE_ENTRIES][dir % FAT_PIECE_ENTRIES] = (uint32_t)dir;
    uint8_t full[BLOCK];
    memset(full, 0, BLOCK);
    for (int k = 0; k < BLOCK / 32; k++) memcpy(full + 32 * k, "X       TXT", 11), full[32 * k + 11] = FAT_ATTR_ARCHIVE;
    platform_card_write(fat_cluster_block(&v, (uint32_t)dir), 1, full);
    struct listing seen = { .n = 0 };
    CHECK(fat_dir_walk(&v, (uint32_t)dir, list_visit, &seen) == FAT_OK, "a directory whose chain loops is walked and the walk ends");
    CHECK(fat_dir_add(&v, (uint32_t)dir, "one more.txt", FAT_ATTR_ARCHIVE, 0, 0, NULL) < 0,
          "and adding to it is refused rather than spinning");
    fat_unmount(&v);
}
/* }}} */

int main(void)
{
    twin_platform_init(1, (size_t)128 << 20);
    stripes_init(1, 4);
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    char card[600], made[600];
    snprintf(log_path, sizeof log_path, "%s/tmp/shared-memory/test-logs/079-fat-line.log", dir);
    snprintf(card, sizeof card, "%s/tmp/shared-memory/079-card.img", dir);
    snprintf(made, sizeof made, "%s/tmp/shared-memory/079-made-card.img", dir);
    twin_platform_set_log(log_path, 0);

    struct fat_volume v;
    CHECK(fat_mount(&v, OWNER) == FAT_NO_CARD, "with no card in the slot, mounting says so");

    for (uint32_t spc = 1; spc <= 8; spc *= 8) {
        char what[32];
        snprintf(what, sizeof what, "%u sector%s per cluster", spc, spc == 1 ? "" : "s");
        reading_a_laptop_card(card, spc);
        struct layout l;
        format(&l, spc == 1 ? 40 : 16, spc);
        write_image(card);
        writing(card, what);
    }
    refusing(card);
    damaged(card);

    /* A card the laptop's own tools made, when it has them. */
    if (system("command -v mkfs.fat > /dev/null 2>&1 && command -v sfdisk > /dev/null 2>&1") == 0) {
        char command[1400];
        snprintf(command, sizeof command, "'%s/scripts/make-card-image' '%s' '%s' 48 > /dev/null", dir, dir, made);
        if (system(command) == 0) writing(made, "a card mkfs.fat made");
        else CHECK(0, "scripts/make-card-image could not make a card");
        remove(made);
    } else {
        printf("no mkfs.fat and sfdisk here: the check on a card they make is skipped\n");
    }
    remove(card);
    free(image);
    CHECK_DONE("079 FAT32 on the card");
}
