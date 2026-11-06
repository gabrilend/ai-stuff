/*
 * 080-card-image.h — a blank card, laid out the way a laptop lays one out.
 *
 * General description: the filesystem tests need cards the device did not
 * write, so this formatter writes one with its own code: a partition table
 * with one FAT32 partition 1 MB in, the FAT32 boot block (and its backup),
 * the FSInfo block, two copies of the table and an empty root directory in
 * cluster 2 — the layout mkfs.fat gives a small card. The card is built in
 * memory (`image`, reachable block by block through blk()) so a test can
 * add files to it the way a laptop would before writing it out.
 */
#ifndef SOREN_TEST_CARD_IMAGE_H
#define SOREN_TEST_CARD_IMAGE_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BLOCK 512
#define START 2048                       /* the partition starts 1 MB in, as card tools place it */

static uint8_t *image;                   /* the whole card, built in memory then written out */
static size_t   image_bytes;

struct layout {
    uint32_t spc;                        /* sectors per cluster */
    uint32_t reserved;
    uint32_t fat_sectors;
    uint32_t total_sectors;              /* in the partition */
    uint32_t clusters;
    uint64_t fat_lba, data_lba;
};

/* {{{ put16 / put32 / get32 */
static inline void put16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }
static inline void put32(uint8_t *p, uint32_t v) { put16(p, (uint16_t)v); put16(p + 2, (uint16_t)(v >> 16)); }
static inline uint32_t get32(const uint8_t *p) { return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }
/* }}} */

/* {{{ blk */
static inline uint8_t *blk(uint64_t lba) { return image + lba * BLOCK; }
/* }}} */

/* {{{ set_fat */
/* Both copies of the table, as a laptop writes them. */
static inline void set_fat(const struct layout *l, uint32_t c, uint32_t next)
{
    for (int copy = 0; copy < 2; copy++) {
        put32(blk(l->fat_lba + (uint64_t)copy * l->fat_sectors) + c * 4, next);
    }
}
/* }}} */

/* {{{ format */
/* A blank FAT32 card of `mb` megabytes, laid out the way mkfs.fat lays one
 * out: 32 reserved sectors, the FSInfo block at 1, a backup boot block at
 * 6, two copies of the table, the root directory in cluster 2. */
static inline void format(struct layout *l, uint32_t mb, uint32_t spc)
{
    image_bytes = (size_t)mb << 20;
    free(image);
    image = calloc(1, image_bytes);
    l->spc = spc;
    l->reserved = 32;
    l->total_sectors = (uint32_t)(image_bytes / BLOCK) - START;
    /* The table's size depends on the cluster count, which depends on the
     * table's size: settle it the way the specification's formula does,
     * by going round until it stops moving. */
    l->fat_sectors = 1;
    for (int round = 0; round < 8; round++) {
        l->clusters = (l->total_sectors - l->reserved - 2 * l->fat_sectors) / spc;
        l->fat_sectors = ((l->clusters + 2) * 4 + BLOCK - 1) / BLOCK;
    }
    l->clusters = (l->total_sectors - l->reserved - 2 * l->fat_sectors) / spc;
    l->fat_lba = START + l->reserved;
    l->data_lba = l->fat_lba + 2ull * l->fat_sectors;

    uint8_t *mbr = blk(0);
    uint8_t *p = mbr + 446;
    p[4] = 0x0C;                                         /* FAT32, addressed by block number */
    put32(p + 8, START);
    put32(p + 12, l->total_sectors);
    mbr[510] = 0x55; mbr[511] = 0xAA;

    uint8_t *b = blk(START);
    b[0] = 0xEB; b[1] = 0x58; b[2] = 0x90;
    memcpy(b + 3, "mkfs.fat", 8);
    put16(b + 11, BLOCK);
    b[13] = (uint8_t)spc;
    put16(b + 14, (uint16_t)l->reserved);
    b[16] = 2;
    b[21] = 0xF8;
    put16(b + 24, 63); put16(b + 26, 255);
    put32(b + 28, START);
    put32(b + 32, l->total_sectors);
    put32(b + 36, l->fat_sectors);
    put32(b + 44, 2);                                    /* the root directory */
    put16(b + 48, 1);                                    /* FSInfo */
    put16(b + 50, 6);                                    /* the backup boot block */
    b[64] = 0x80; b[66] = 0x29;
    put32(b + 67, 0x50524E53);
    memcpy(b + 71, "SORENTEST  ", 11);
    memcpy(b + 82, "FAT32   ", 8);
    b[510] = 0x55; b[511] = 0xAA;
    memcpy(blk(START + 6), b, BLOCK);

    uint8_t *fsinfo = blk(START + 1);
    put32(fsinfo, 0x41615252u);
    put32(fsinfo + 484, 0x61417272u);
    put32(fsinfo + 488, 0xFFFFFFFFu);                    /* "not known": the layer must count */
    put32(fsinfo + 492, 0xFFFFFFFFu);
    put32(fsinfo + 508, 0xAA550000u);

    set_fat(l, 0, 0x0FFFFFF8u);
    set_fat(l, 1, 0x0FFFFFFFu);
    set_fat(l, 2, 0x0FFFFFFFu);
}
/* }}} */

/* {{{ write_image */
static inline void write_image(const char *path)
{
    FILE *f = fopen(path, "wb");
    if (!f || fwrite(image, 1, image_bytes, f) != image_bytes) {
        fprintf(stderr, "cannot write %s\n", path);
        exit(2);
    }
    fclose(f);
}
/* }}} */

/* {{{ card_fsck */
/* Ask the laptop's own checker about a card image, if it has one, keeping
 * its report at `report`. Answers 1 for a clean card, 0 for a complaint,
 * -1 when there is no checker to ask. The checker is pointed at a copy of
 * the partition alone, which every version of it understands. */
static inline int card_fsck(const char *path, const char *report)
{
    if (system("command -v fsck.fat > /dev/null 2>&1") != 0) return -1;
    char partition[1100], command[4400];
    snprintf(partition, sizeof partition, "%s.partition", path);
    snprintf(command, sizeof command,
             "dd if='%s' of='%s' bs=512 skip=%d status=none && fsck.fat -n '%s' > '%s' 2>&1",
             path, partition, START, partition, report);
    int status = system(command);
    remove(partition);
    return status == 0;
}
/* }}} */

#endif
