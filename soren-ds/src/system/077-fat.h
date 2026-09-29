/*
 * 077-fat.h — the SD card's FAT32 filesystem (issues 402, 403, 404).
 *
 * General description: the card is formatted the way every consumer card
 * is, so a person can take it out and read their drawings and programs
 * on a laptop. This layer understands exactly that format and nothing
 * more: the partition table at block zero, the FAT32 boot block at the
 * partition's start, the file allocation table (a list saying, for every
 * cluster of the card, which cluster comes next in its file), and
 * directories (files whose contents are 32-byte entries naming other
 * files, with long names spread over extra entries before each one).
 *
 * The whole allocation table is kept in memory, in page-sized pieces, and
 * written back to both of the card's copies when it changes. FAT16 and
 * exFAT are refused, loudly.
 */
#ifndef SOREN_FAT_H
#define SOREN_FAT_H

#include <stdint.h>
#include <stddef.h>

#define FAT_NAME 256                   /* the longest name a directory entry can carry, plus its end */
#define FAT_END 0x0FFFFFF8u            /* this or above: the last cluster of a chain */
#define FAT_FREE 0u
#define FAT_PIECE_ENTRIES 1024         /* allocation-table entries per in-memory piece (one 4 KB page) */

enum fat_error {
    FAT_OK             = 0,
    FAT_NO_CARD        = -1,
    FAT_IO             = -2,            /* a block transfer failed */
    FAT_NOT_FAT32      = -3,            /* FAT16, exFAT, or not a filesystem at all */
    FAT_NOT_FOUND      = -4,
    FAT_NOT_A_DIRECTORY = -5,
    FAT_IS_A_DIRECTORY = -6,
    FAT_NOT_EMPTY      = -7,
    FAT_NO_SPACE       = -8,
    FAT_BAD_NAME       = -9,
    FAT_EXISTS         = -10,
    FAT_LOOP           = -11,           /* a symlink chain longer than the hop limit */
    FAT_NO_MEMORY      = -12,
};
const char *fat_error_text(int error);

/* What mounting learned about the card. */
struct fat_volume {
    uint64_t   partition_lba;          /* where the partition starts, in blocks */
    uint32_t   sectors_per_cluster;
    uint32_t   cluster_bytes;
    uint32_t   reserved_sectors;
    uint32_t   n_fats;
    uint32_t   fat_sectors;            /* sectors in one copy of the table */
    uint32_t   root_cluster;
    uint32_t   total_clusters;         /* data clusters, numbered from 2 */
    uint64_t   fat_lba;                /* first block of the first table copy */
    uint64_t   data_lba;               /* first block of cluster 2 */
    uint32_t   fsinfo_sector;
    char       label[12];
    uint32_t **pieces;                 /* the table in memory, FAT_PIECE_ENTRIES per piece */
    uint32_t   n_pieces;
    uint8_t   *dirty;                  /* one byte per piece: changed since the last flush */
    uint32_t   next_free_hint;         /* where the last free-cluster search stopped */
    uint32_t   free_clusters;          /* counted at mount, kept current */
    int        owner;                  /* whose memory the table lives in */
};

/* One directory entry, assembled. `location` says where its short entry
 * sits on the card (the block, and the byte within it), and `first_slot`
 * where its first long-name entry sits, so it can be updated or removed
 * in place. */
struct fat_entry {
    char     name[FAT_NAME];
    uint8_t  attributes;               /* 0x10 = directory */
    uint32_t first_cluster;
    uint32_t size;
    uint64_t location_block;
    uint32_t location_offset;
    uint32_t dir_cluster;              /* the directory it is in */
    uint32_t slot;                     /* its short entry's index in that directory */
    uint32_t first_slot;               /* the first of its long-name entries (== slot if none) */
};

#define FAT_ATTR_DIRECTORY 0x10
#define FAT_ATTR_ARCHIVE   0x20
#define FAT_ATTR_LONG_NAME 0x0F

/* {{{ the volume (402) */
int  fat_mount(struct fat_volume *v, int owner);
int  fat_flush(struct fat_volume *v);            /* write changed table pieces to every copy */
uint64_t fat_cluster_block(const struct fat_volume *v, uint32_t cluster);
/* }}} */

/* {{{ the allocation table and chains (404) */
uint32_t fat_next(const struct fat_volume *v, uint32_t cluster);
int  fat_chain_read(struct fat_volume *v, uint32_t first, uint32_t offset, void *buffer, uint32_t length);
/* A new chain holding `length` bytes, written; answers its first cluster
 * (0 for an empty file) or a negative error. The old chain is untouched. */
int64_t fat_chain_new(struct fat_volume *v, const void *buffer, uint32_t length);
int  fat_chain_free(struct fat_volume *v, uint32_t first);
uint32_t fat_chain_length(const struct fat_volume *v, uint32_t first);
/* }}} */

/* {{{ directories (403) */
/* Walk a directory: call `visit` for every live entry, long names
 * assembled; stop early if it answers nonzero. */
int  fat_dir_walk(struct fat_volume *v, uint32_t dir_cluster,
                  int (*visit)(const struct fat_entry *e, void *ctx), void *ctx);
/* Find a name, case-insensitively, as FAT convention has it. */
int  fat_dir_find(struct fat_volume *v, uint32_t dir_cluster, const char *name, struct fat_entry *out);
/* Add an entry (with long-name entries, and a unique short name). */
int  fat_dir_add(struct fat_volume *v, uint32_t dir_cluster, const char *name, uint8_t attributes,
                 uint32_t first_cluster, uint32_t size, struct fat_entry *out);
/* Point an existing entry at a new chain and size: one block write. */
int  fat_dir_update(struct fat_volume *v, const struct fat_entry *e, uint32_t first_cluster, uint32_t size);
/* Remove an entry and its long-name entries. */
int  fat_dir_remove(struct fat_volume *v, const struct fat_entry *e);
/* A new, empty directory ("." and ".." only); answers its cluster. */
int64_t fat_dir_make(struct fat_volume *v, uint32_t parent_cluster);
/* }}} */

#endif
