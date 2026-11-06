/*
 * 077-fat.c — FAT32, read and written (issues 402, 403, 404).
 *
 * General description: mounting reads the partition table and the
 * partition's boot block, works out where the allocation table and the
 * data area start, and reads the whole allocation table into memory in
 * page-sized pieces. A file's contents are a chain of clusters the table
 * links together; reading follows the chain, and writing always builds a
 * *new* chain, so the old contents stay whole until a single directory-
 * entry write switches the name over (the atomic step, in 078-files.c).
 * Directories are chains of 32-byte entries; a long name is spread over
 * extra entries placed just before the entry it names, each carrying 13
 * characters and a checksum of the short name they belong to.
 *
 * Every function here assumes its caller holds the filesystem's lock
 * (078-files.c); the card is one shared thing.
 */
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "../engine/028-page-stripes.h"
#include "077-fat.h"

#define SLOT_BYTES 32
#define BLOCK 512
/* FAT's own limit on one directory: 65536 entries (2 MB). A walk stops
 * there even if a damaged chain loops, rather than walking forever. */
#define DIR_MAX_SLOTS 65536u

/* {{{ fat_error_text */
const char *fat_error_text(int error)
{
    static const char *const text[] = {
        "ok", "no card", "a card transfer failed", "not a FAT32 filesystem (FAT16 and exFAT are refused)",
        "not found", "not a directory", "is a directory", "the directory is not empty", "the card is full",
        "that name cannot be written on a FAT card", "that name already exists", "a symlink chain too long, or a loop",
        "out of memory",
    };
    int i = -error;
    return i >= 0 && i < (int)(sizeof text / sizeof text[0]) ? text[i] : "an unknown filesystem error";
}
/* }}} */

/* {{{ little-endian fields */
static uint16_t le16(const uint8_t *p) { return (uint16_t)(p[0] | p[1] << 8); }
static uint32_t le32(const uint8_t *p) { return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }
static void put16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }
static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24); }
/* }}} */

/* {{{ the table in memory */
/* {{{ entry_at */
static uint32_t *entry_at(const struct fat_volume *v, uint32_t cluster)
{
    return &v->pieces[cluster / FAT_PIECE_ENTRIES][cluster % FAT_PIECE_ENTRIES];
}
/* }}} */

/* {{{ in_volume */
/* Is this a data cluster of this volume? A chain on a damaged card can
 * name a cluster past the end of the table; following it would read
 * memory the table does not own, so every walk asks this first and
 * treats anything else as the end of the chain. */
static int in_volume(const struct fat_volume *v, uint32_t cluster)
{
    return cluster >= 2 && cluster < v->total_clusters + 2;
}
/* }}} */

/* {{{ fat_next */
uint32_t fat_next(const struct fat_volume *v, uint32_t cluster)
{
    if (!in_volume(v, cluster)) {
        return 0x0FFFFFFFu;                    /* outside the table: an end, never a step */
    }
    return *entry_at(v, cluster) & 0x0FFFFFFFu;
}
/* }}} */

/* {{{ set_next */
/* The top four bits of an entry are reserved and kept as found. */
static void set_next(struct fat_volume *v, uint32_t cluster, uint32_t next)
{
    uint32_t *e = entry_at(v, cluster);
    uint32_t was = *e & 0x0FFFFFFFu;
    *e = (*e & 0xF0000000u) | (next & 0x0FFFFFFFu);
    v->dirty[cluster / FAT_PIECE_ENTRIES] = 1;
    /* Keep the free count current: a cluster leaving or joining the pool. */
    if (was == FAT_FREE && next != FAT_FREE) v->free_clusters--;
    if (was != FAT_FREE && next == FAT_FREE) v->free_clusters++;
}
/* }}} */
/* }}} */

/* {{{ fat_cluster_block */
uint64_t fat_cluster_block(const struct fat_volume *v, uint32_t cluster)
{
    return v->data_lba + (uint64_t)(cluster - 2) * v->sectors_per_cluster;
}
/* }}} */

/* {{{ fat_mount */
int fat_mount(struct fat_volume *v, int owner)
{
    uint8_t block[BLOCK];
    bytes_zero(v, sizeof *v);
    v->owner = owner;
    if (platform_card_blocks() == 0) {
        return FAT_NO_CARD;
    }
    if (platform_card_read(0, 1, block)) {
        return FAT_IO;
    }
    if (block[510] != 0x55 || block[511] != 0xAA) {
        say_line("fat: block zero has no partition-table signature");
        return FAT_NOT_FAT32;
    }
    /* The first partition marked FAT32. Others are named and refused. */
    int found = 0;
    for (int i = 0; i < 4 && !found; i++) {
        const uint8_t *e = block + 446 + 16 * i;
        uint8_t type = e[4];
        if (type == 0x0B || type == 0x0C) {
            v->partition_lba = le32(e + 8);
            found = 1;
        } else if (type == 0x04 || type == 0x06 || type == 0x0E) {
            say_line("fat: partition %d is FAT16, which this device refuses — reformat the card as FAT32", i + 1);
        } else if (type == 0x07) {
            say_line("fat: partition %d is exFAT (or NTFS), which this device refuses — reformat the card as FAT32", i + 1);
        }
    }
    /* No partition table at all: a card formatted whole, its boot block
     * at block zero (some laptops format a card that way). Only looked
     * for when no partition entry claimed FAT32, so a partition table
     * always wins. */
    if (!found && (block[0] == 0xEB || block[0] == 0xE9) && le16(block + 11) == BLOCK &&
        le16(block + 22) == 0 && bytes_equal(block + 82, "FAT32   ", 8)) {
        say_line("fat: the card has no partition table; its first block is a FAT32 boot block");
        v->partition_lba = 0;
        found = 1;
    }
    if (!found) {
        say_line("fat: no FAT32 partition on the card");
        return FAT_NOT_FAT32;
    }
    if (platform_card_read(v->partition_lba, 1, block)) {
        return FAT_IO;
    }
    if (bytes_equal(block + 3, "EXFAT   ", 8)) {
        say_line("fat: the partition is exFAT, which this device refuses");
        return FAT_NOT_FAT32;
    }
    if (le16(block + 11) != BLOCK || le16(block + 17) != 0 || le16(block + 22) != 0 || block[510] != 0x55) {
        say_line("fat: the partition's boot block is not FAT32's (sector size %u, root entries %u, 16-bit table size %u)",
                 le16(block + 11), le16(block + 17), le16(block + 22));
        return FAT_NOT_FAT32;
    }
    v->sectors_per_cluster = block[13];
    v->cluster_bytes = v->sectors_per_cluster * BLOCK;
    v->reserved_sectors = le16(block + 14);
    v->n_fats = block[16];
    v->fat_sectors = le32(block + 36);
    v->root_cluster = le32(block + 44);
    v->fsinfo_sector = le16(block + 48);
    uint32_t total_sectors = le16(block + 19) ? le16(block + 19) : le32(block + 32);
    bytes_copy(v->label, block + 71, 11);
    v->label[11] = 0;
    for (int i = 10; i >= 0 && v->label[i] == ' '; i--) v->label[i] = 0;   /* the field is space-padded */
    /* Every number below divides by, or is sized from, these; a boot
     * block that gets them wrong is refused rather than believed. */
    uint64_t overhead = (uint64_t)v->reserved_sectors + (uint64_t)v->n_fats * v->fat_sectors;
    if (v->sectors_per_cluster == 0 || (v->sectors_per_cluster & (v->sectors_per_cluster - 1)) ||
        v->reserved_sectors == 0 || v->n_fats == 0 || v->fat_sectors == 0 || overhead >= total_sectors) {
        say_line("fat: the boot block's layout does not add up (%u sectors per cluster, %u reserved, %u tables of %u sectors, %u in all)",
                 v->sectors_per_cluster, v->reserved_sectors, v->n_fats, v->fat_sectors, total_sectors);
        return FAT_NOT_FAT32;
    }
    v->fat_lba = v->partition_lba + v->reserved_sectors;
    v->data_lba = v->fat_lba + (uint64_t)v->n_fats * v->fat_sectors;
    v->total_clusters = (uint32_t)((total_sectors - overhead) / v->sectors_per_cluster);
    /* The table must have an entry for every cluster (Linux refuses a
     * card whose table is too short, and so does this), and the cluster
     * numbers must stop below the ones FAT32 keeps for bad clusters and
     * chain ends. */
    if ((uint64_t)v->fat_sectors * (BLOCK / 4) < (uint64_t)v->total_clusters + 2 ||
        v->total_clusters == 0 || v->total_clusters > 0x0FFFFFF5u) {
        say_line("fat: %u clusters do not fit a table of %u sectors", v->total_clusters, v->fat_sectors);
        return FAT_NOT_FAT32;
    }
    if (!in_volume(v, v->root_cluster)) {
        say_line("fat: the root directory's cluster %u is not on the volume", v->root_cluster);
        return FAT_NOT_FAT32;
    }

    /* The table, into page-sized pieces. */
    uint32_t entries = v->total_clusters + 2;
    v->n_pieces = (entries + FAT_PIECE_ENTRIES - 1) / FAT_PIECE_ENTRIES;
    uint32_t list_pages = (uint32_t)((v->n_pieces * sizeof(uint32_t *) + PAGE_BYTES - 1) / PAGE_BYTES);
    v->pieces = pages_alloc_run(owner, (int)list_pages);
    if (v->pieces) {
        bytes_zero(v->pieces, v->n_pieces * sizeof(uint32_t *));   /* so a failure below frees only what it took */
    }
    v->dirty = pages_alloc_run(owner, (int)((v->n_pieces + PAGE_BYTES - 1) / PAGE_BYTES));
    if (!v->pieces || !v->dirty) {
        fat_unmount(v);
        return FAT_NO_MEMORY;
    }
    bytes_zero(v->dirty, v->n_pieces);
    for (uint32_t i = 0; i < v->n_pieces; i++) {
        v->pieces[i] = page_alloc(owner);
        if (!v->pieces[i]) {
            fat_unmount(v);
            return FAT_NO_MEMORY;
        }
        /* One piece is 8 sectors of the table; the last may be partial. */
        uint32_t first_sector = i * (FAT_PIECE_ENTRIES * 4 / BLOCK);
        uint32_t count = FAT_PIECE_ENTRIES * 4 / BLOCK;
        if (first_sector + count > v->fat_sectors) count = v->fat_sectors - first_sector;
        bytes_zero(v->pieces[i], PAGE_BYTES);
        if (count && platform_card_read(v->fat_lba + first_sector, count, v->pieces[i])) {
            fat_unmount(v);
            return FAT_IO;
        }
    }
    v->free_clusters = 0;
    for (uint32_t c = 2; c < entries; c++) {
        if (fat_next(v, c) == FAT_FREE) v->free_clusters++;
    }
    v->next_free_hint = 2;
    say_line("fat: FAT32 volume \"%s\", %u-byte clusters, data from block %u, %u of %u clusters free",
             v->label, v->cluster_bytes, (uint32_t)v->data_lba, v->free_clusters, v->total_clusters);
    return FAT_OK;
}
/* }}} */

/* {{{ fat_unmount */
void fat_unmount(struct fat_volume *v)
{
    if (v->pieces) {
        for (uint32_t i = 0; i < v->n_pieces; i++) {
            if (v->pieces[i]) page_free(v->owner, v->pieces[i]);
        }
        pages_free_run(v->owner, v->pieces, (int)((v->n_pieces * sizeof(uint32_t *) + PAGE_BYTES - 1) / PAGE_BYTES));
    }
    if (v->dirty) {
        pages_free_run(v->owner, v->dirty, (int)((v->n_pieces + PAGE_BYTES - 1) / PAGE_BYTES));
    }
    bytes_zero(v, sizeof *v);
}
/* }}} */

/* {{{ fat_flush */
int fat_flush(struct fat_volume *v)
{
    for (uint32_t i = 0; i < v->n_pieces; i++) {
        if (!v->dirty[i]) continue;
        uint32_t first_sector = i * (FAT_PIECE_ENTRIES * 4 / BLOCK);
        uint32_t count = FAT_PIECE_ENTRIES * 4 / BLOCK;
        if (first_sector + count > v->fat_sectors) count = v->fat_sectors - first_sector;
        /* Every copy of the table gets the same bytes. */
        for (uint32_t copy = 0; copy < v->n_fats; copy++) {
            if (platform_card_write(v->fat_lba + (uint64_t)copy * v->fat_sectors + first_sector, count, v->pieces[i])) {
                return FAT_IO;
            }
        }
        v->dirty[i] = 0;
    }
    /* The FSInfo block's free count and next-free hint, kept current so a
     * laptop's tools do not have to count again. */
    uint8_t block[BLOCK];
    if (v->fsinfo_sector && !platform_card_read(v->partition_lba + v->fsinfo_sector, 1, block) &&
        le32(block) == 0x41615252u && le32(block + 484) == 0x61417272u) {
        put32(block + 488, v->free_clusters);
        put32(block + 492, v->next_free_hint);
        if (platform_card_write(v->partition_lba + v->fsinfo_sector, 1, block)) {
            return FAT_IO;
        }
    }
    return FAT_OK;
}
/* }}} */

/* {{{ chains */
/* {{{ fat_chain_length */
uint32_t fat_chain_length(const struct fat_volume *v, uint32_t first)
{
    uint32_t n = 0;
    for (uint32_t c = first; in_volume(v, c) && n <= v->total_clusters; c = fat_next(v, c)) n++;
    return n;
}
/* }}} */

/* {{{ fat_chain_read */
int fat_chain_read(struct fat_volume *v, uint32_t first, uint32_t offset, void *buffer, uint32_t length)
{
    uint8_t *out = buffer;
    uint32_t c = first;
    uint32_t skip = offset / v->cluster_bytes;
    uint32_t within = offset % v->cluster_bytes;
    for (uint32_t i = 0; i < skip; i++) {
        if (!in_volume(v, c)) return FAT_IO;
        c = fat_next(v, c);
    }
    uint8_t block[BLOCK];
    while (length) {
        if (!in_volume(v, c)) return FAT_IO;
        /* Within one cluster, a block at a time. */
        uint32_t sector = within / BLOCK;
        uint32_t in_block = within % BLOCK;
        for (; sector < v->sectors_per_cluster && length; sector++) {
            if (platform_card_read(fat_cluster_block(v, c) + sector, 1, block)) return FAT_IO;
            uint32_t n = BLOCK - in_block;
            if (n > length) n = length;
            bytes_copy(out, block + in_block, n);
            out += n;
            length -= n;
            in_block = 0;
        }
        within = 0;
        c = fat_next(v, c);
    }
    return FAT_OK;
}
/* }}} */

/* {{{ take_free_cluster */
static uint32_t take_free_cluster(struct fat_volume *v)
{
    uint32_t n = v->total_clusters;
    for (uint32_t k = 0; k < n; k++) {
        uint32_t c = 2 + (v->next_free_hint - 2 + k) % n;
        if (fat_next(v, c) == FAT_FREE) {
            v->next_free_hint = c + 1 < n + 2 ? c + 1 : 2;
            return c;
        }
    }
    return 0;
}
/* }}} */

/* {{{ fat_chain_free */
int fat_chain_free(struct fat_volume *v, uint32_t first)
{
    uint32_t c = first;
    uint32_t guard = 0;
    while (in_volume(v, c) && guard++ <= v->total_clusters) {
        uint32_t next = fat_next(v, c);
        set_next(v, c, FAT_FREE);
        c = next;
    }
    return FAT_OK;
}
/* }}} */

/* {{{ fat_chain_new */
int64_t fat_chain_new(struct fat_volume *v, const void *buffer, uint32_t length)
{
    if (length == 0) return 0;
    uint32_t needed = (length + v->cluster_bytes - 1) / v->cluster_bytes;
    if (needed > v->free_clusters) return FAT_NO_SPACE;
    const uint8_t *in = buffer;
    uint32_t first = 0, previous = 0;
    uint8_t block[BLOCK];
    for (uint32_t i = 0; i < needed; i++) {
        uint32_t c = take_free_cluster(v);
        if (!c) {
            fat_chain_free(v, first);
            return FAT_NO_SPACE;
        }
        set_next(v, c, 0x0FFFFFFFu);                  /* the end, until another follows */
        if (previous) set_next(v, previous, c); else first = c;
        previous = c;
        /* Write this cluster's blocks; the last is padded with zeroes. */
        for (uint32_t s = 0; s < v->sectors_per_cluster; s++) {
            uint32_t at = i * v->cluster_bytes + s * BLOCK;
            uint32_t n = at < length ? length - at : 0;
            if (n > BLOCK) n = BLOCK;
            bytes_zero(block, BLOCK);
            if (n) bytes_copy(block, in + at, n);
            if (platform_card_write(fat_cluster_block(v, c) + s, 1, block)) {
                fat_chain_free(v, first);
                return FAT_IO;
            }
        }
    }
    return first;
}
/* }}} */
/* }}} */

/* {{{ directories */
/* {{{ slot_block */
/* Where a directory's slot N lives: the block, and the byte within it.
 * Answers 0 past the end of the chain. */
static int slot_block(struct fat_volume *v, uint32_t dir_cluster, uint32_t slot, uint64_t *block, uint32_t *offset)
{
    uint32_t per_cluster = v->cluster_bytes / SLOT_BYTES;
    uint32_t c = dir_cluster;
    if (!in_volume(v, c)) return 0;
    for (uint32_t i = 0; i < slot / per_cluster; i++) {
        c = fat_next(v, c);
        if (!in_volume(v, c)) return 0;
    }
    uint32_t byte = (slot % per_cluster) * SLOT_BYTES;
    *block = fat_cluster_block(v, c) + byte / BLOCK;
    *offset = byte % BLOCK;
    return 1;
}
/* }}} */

/* {{{ read_slot / write_slot */
static int read_slot(struct fat_volume *v, uint32_t dir_cluster, uint32_t slot, uint8_t *out)
{
    uint64_t block;
    uint32_t offset;
    uint8_t buf[BLOCK];
    if (!slot_block(v, dir_cluster, slot, &block, &offset)) return 0;
    if (platform_card_read(block, 1, buf)) return FAT_IO;
    bytes_copy(out, buf + offset, SLOT_BYTES);
    return 1;
}

static int write_slot(struct fat_volume *v, uint32_t dir_cluster, uint32_t slot, const uint8_t *in)
{
    uint64_t block;
    uint32_t offset;
    uint8_t buf[BLOCK];
    if (!slot_block(v, dir_cluster, slot, &block, &offset)) return FAT_IO;
    if (platform_card_read(block, 1, buf)) return FAT_IO;
    bytes_copy(buf + offset, in, SLOT_BYTES);
    return platform_card_write(block, 1, buf) ? FAT_IO : FAT_OK;
}
/* }}} */

/* {{{ short_checksum */
static uint8_t short_checksum(const uint8_t *name11)
{
    uint8_t sum = 0;
    for (int i = 0; i < 11; i++) sum = (uint8_t)(((sum & 1) << 7) + (sum >> 1) + name11[i]);
    return sum;
}
/* }}} */

/* {{{ lower */
static char lower(char c)
{
    return c >= 'A' && c <= 'Z' ? (char)(c - 'A' + 'a') : c;
}
/* }}} */

/* {{{ names_equal */
static int names_equal(const char *a, const char *b)
{
    while (*a && lower(*a) == lower(*b)) { a++; b++; }
    return lower(*a) == lower(*b);
}
/* }}} */

/* {{{ short_to_name */
/* "NAME    EXT" → "name.ext", honouring the lower-case flags a laptop
 * writes for names that fit 8.3 in lower case. */
static void short_to_name(const uint8_t *e, char *out)
{
    int n = 0;
    int base_lower = e[12] & 0x08, ext_lower = e[12] & 0x10;
    for (int i = 0; i < 8 && e[i] != ' '; i++) out[n++] = base_lower ? lower((char)e[i]) : (char)e[i];
    if (e[8] != ' ') {
        out[n++] = '.';
        for (int i = 8; i < 11 && e[i] != ' '; i++) out[n++] = ext_lower ? lower((char)e[i]) : (char)e[i];
    }
    out[n] = 0;
    if ((uint8_t)out[0] == 0x05) out[0] = (char)0xE5;
}
/* }}} */

/* {{{ fat_dir_walk */
int fat_dir_walk(struct fat_volume *v, uint32_t dir_cluster,
                 int (*visit)(const struct fat_entry *e, void *ctx), void *ctx)
{
    uint8_t e[SLOT_BYTES];
    char long_name[FAT_NAME];
    int have_long = 0;
    uint8_t long_sum = 0;
    uint32_t long_first = 0;
    bytes_zero(long_name, sizeof long_name);
    for (uint32_t slot = 0; slot < DIR_MAX_SLOTS; slot++) {
        int r = read_slot(v, dir_cluster, slot, e);
        if (r < 0) return r;
        if (r == 0 || e[0] == 0x00) return FAT_OK;    /* past the chain, or the end marker */
        if (e[0] == 0xE5) { have_long = 0; continue; }  /* deleted */
        if ((e[11] & 0x3F) == FAT_ATTR_LONG_NAME) {
            /* A long-name piece: 13 two-byte characters at three places.
             * Only the low byte is kept; other characters become '?'. */
            int order = e[0] & 0x1F;
            if (e[0] & 0x40) {
                bytes_zero(long_name, sizeof long_name);
                have_long = 1;
                long_sum = e[13];
                long_first = slot;
            }
            static const uint8_t at[13] = { 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30 };
            for (int k = 0; k < 13; k++) {
                int i = (order - 1) * 13 + k;
                if (i < 0 || i >= FAT_NAME - 1) continue;
                uint16_t ch = le16(e + at[k]);
                if (ch == 0 || ch == 0xFFFF) continue;
                long_name[i] = ch < 128 ? (char)ch : '?';
            }
            continue;
        }
        if (e[11] & 0x08) { have_long = 0; continue; }  /* the volume label */
        struct fat_entry out;
        bytes_zero(&out, sizeof out);
        if (have_long && short_checksum(e) == long_sum) {
            text_format(out.name, sizeof out.name, "%s", long_name);
            out.first_slot = long_first;
        } else {
            short_to_name(e, out.name);
            out.first_slot = slot;
        }
        have_long = 0;
        if (text_equal(out.name, ".") || text_equal(out.name, "..")) continue;
        out.attributes = e[11];
        out.first_cluster = (uint32_t)le16(e + 20) << 16 | le16(e + 26);
        out.size = le32(e + 28);
        out.dir_cluster = dir_cluster;
        out.slot = slot;
        slot_block(v, dir_cluster, slot, &out.location_block, &out.location_offset);
        if (visit(&out, ctx)) return FAT_OK;
    }
    return FAT_OK;
}
/* }}} */

struct finding {
    const char       *name;
    struct fat_entry *out;
    int               found;
};

/* {{{ find_visit */
static int find_visit(const struct fat_entry *e, void *ctx)
{
    struct finding *f = ctx;
    if (names_equal(e->name, f->name)) {
        *f->out = *e;
        f->found = 1;
        return 1;
    }
    return 0;
}
/* }}} */

/* {{{ fat_dir_find */
int fat_dir_find(struct fat_volume *v, uint32_t dir_cluster, const char *name, struct fat_entry *out)
{
    struct finding f = { name, out, 0 };
    int r = fat_dir_walk(v, dir_cluster, find_visit, &f);
    if (r < 0) return r;
    return f.found ? FAT_OK : FAT_NOT_FOUND;
}
/* }}} */

/* {{{ valid_name */
static int valid_name(const char *name)
{
    size_t n = text_length(name);
    if (n == 0 || n >= FAT_NAME || text_equal(name, ".") || text_equal(name, "..")) return 0;
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)name[i];
        if (c < 32 || c == '/' || c == '\\' || c == ':' || c == '*' || c == '?' || c == '"' ||
            c == '<' || c == '>' || c == '|' || c >= 127) return 0;
    }
    return 1;
}
/* }}} */

/* Short-name tails are looked for a window at a time: one pass over the
 * directory marks which numbers in the window are taken, and the first
 * free one is used. A window of 4096 costs 512 bytes of stack; a
 * directory needs a second pass only once it holds 4095 names that
 * shorten alike (a folder of messages named message-0001.txt onward
 * is exactly that). */
#define TAIL_WINDOW 4096u
#define TAIL_LIMIT  1000000u           /* "~999999" is the longest tail that fits */

/* {{{ tail_of */
/* If a short entry reads PREFIX~DIGITS.EXT, where PREFIX is exactly what
 * make_short_name keeps of `base` beside that many digits and EXT is
 * `ext3`, answer its number; anything else answers 0. Only names of that
 * shape can equal a name make_short_name would write, so marking these
 * is the whole of the uniqueness check. */
static uint32_t tail_of(const uint8_t *e, const char *base, int nb, const uint8_t *ext3)
{
    if (!bytes_equal(e + 8, ext3, 3)) return 0;
    int tilde = -1;
    for (int i = 0; i < 8 && tilde < 0; i++) if (e[i] == '~') tilde = i;
    if (tilde < 1 || tilde + 1 >= 8 || e[tilde + 1] < '1' || e[tilde + 1] > '9') return 0;
    uint32_t n = 0;
    int i = tilde + 1;
    for (; i < 8 && e[i] >= '0' && e[i] <= '9'; i++) n = n * 10 + (uint32_t)(e[i] - '0');
    for (int k = i; k < 8; k++) if (e[k] != ' ') return 0;
    int digits = i - tilde;                     /* the '~' and its number */
    int keep = 8 - digits < nb ? 8 - digits : nb;
    if (tilde != keep || !bytes_equal(e, base, (size_t)keep)) return 0;
    return n;
}
/* }}} */

/* {{{ make_short_name */
/* A short name no other entry here has: up to six characters of the long
 * name's base, "~N", and up to three of its extension, upper-cased. The
 * long name is what everybody reads; this is only what FAT requires.
 * Every short name in the directory is looked at, however many there
 * are: two entries sharing one short name is a damaged directory as far
 * as a laptop's checker is concerned. */
static int make_short_name(struct fat_volume *v, uint32_t dir_cluster, const char *name, uint8_t *out)
{
    const char *dot = (const char *)0;
    for (const char *p = name; *p; p++) if (*p == '.') dot = p;
    if (dot == name) dot = (const char *)0;
    char base[7] = { 0 };
    uint8_t ext[3] = { ' ', ' ', ' ' };
    int nb = 0, ne = 0;
    for (const char *p = name; *p && (!dot || p < dot) && nb < 6; p++) {
        char c = *p;
        if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
        if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-') base[nb++] = c;
    }
    if (!nb) base[nb++] = 'F';
    for (const char *p = dot ? dot + 1 : ""; *p && ne < 3; p++) {
        char c = *p;
        if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
        if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ext[ne++] = (uint8_t)c;
    }
    for (uint32_t window = 0; window < TAIL_LIMIT; window += TAIL_WINDOW) {
        uint8_t taken[TAIL_WINDOW / 8];
        bytes_zero(taken, sizeof taken);
        uint8_t e[SLOT_BYTES];
        for (uint32_t slot = 0; slot < DIR_MAX_SLOTS; slot++) {
            int r = read_slot(v, dir_cluster, slot, e);
            if (r < 0) return r;
            if (r == 0 || e[0] == 0) break;
            if (e[0] == 0xE5 || (e[11] & 0x3F) == FAT_ATTR_LONG_NAME) continue;
            uint32_t t = tail_of(e, base, nb, ext);
            if (t >= window && t < window + TAIL_WINDOW) taken[(t - window) / 8] |= (uint8_t)(1u << ((t - window) % 8));
        }
        for (uint32_t t = window ? window : 1; t < window + TAIL_WINDOW && t < TAIL_LIMIT; t++) {
            if (taken[(t - window) / 8] & (1u << ((t - window) % 8))) continue;
            char digits[8];
            int nd = text_format(digits, sizeof digits, "~%u", t);
            int keep = 8 - nd < nb ? 8 - nd : nb;
            for (int i = 0; i < 11; i++) out[i] = ' ';
            for (int i = 0; i < keep; i++) out[i] = (uint8_t)base[i];
            for (int i = 0; i < nd; i++) out[keep + i] = (uint8_t)digits[i];
            bytes_copy(out + 8, ext, 3);
            return FAT_OK;
        }
    }
    return FAT_EXISTS;
}
/* }}} */

/* {{{ extend_directory */
/* Add one zeroed cluster to a directory's chain. */
static int extend_directory(struct fat_volume *v, uint32_t dir_cluster)
{
    uint32_t last = dir_cluster;
    uint32_t guard = 0;
    while (in_volume(v, fat_next(v, last))) {
        last = fat_next(v, last);
        if (++guard > v->total_clusters) return FAT_IO;   /* the chain loops back on itself */
    }
    uint32_t c = take_free_cluster(v);
    if (!c) return FAT_NO_SPACE;
    set_next(v, c, 0x0FFFFFFFu);
    set_next(v, last, c);
    uint8_t zero[BLOCK];
    bytes_zero(zero, BLOCK);
    for (uint32_t s = 0; s < v->sectors_per_cluster; s++) {
        if (platform_card_write(fat_cluster_block(v, c) + s, 1, zero)) return FAT_IO;
    }
    return FAT_OK;
}
/* }}} */

/* {{{ fat_dir_add */
int fat_dir_add(struct fat_volume *v, uint32_t dir_cluster, const char *name, uint8_t attributes,
                uint32_t first_cluster, uint32_t size, struct fat_entry *out)
{
    if (!valid_name(name)) return FAT_BAD_NAME;
    struct fat_entry existing;
    if (fat_dir_find(v, dir_cluster, name, &existing) == FAT_OK) return FAT_EXISTS;
    uint8_t short_name[11];
    int r = make_short_name(v, dir_cluster, name, short_name);
    if (r < 0) return r;
    int n_long = (int)((text_length(name) + 12) / 13);
    int needed = n_long + 1;

    /* A run of free slots long enough; the directory grows if there is none. */
    uint8_t e[SLOT_BYTES];
    uint32_t run_start = 0;
    int run = 0;
    uint32_t slot = 0;
    for (;; slot++) {
        if (slot >= DIR_MAX_SLOTS) return FAT_NO_SPACE;   /* FAT's limit on one directory */
        r = read_slot(v, dir_cluster, slot, e);
        if (r < 0) return r;
        if (r == 0) {
            r = extend_directory(v, dir_cluster);
            if (r < 0) return r;
            slot--;
            continue;
        }
        if (e[0] == 0x00 || e[0] == 0xE5) {
            if (run == 0) run_start = slot;
            if (++run == needed) break;
        } else {
            run = 0;
        }
    }
    /* The long-name pieces, last piece first on the card. */
    uint8_t sum = short_checksum(short_name);
    size_t length = text_length(name);
    static const uint8_t at[13] = { 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30 };
    for (int k = 0; k < n_long; k++) {
        int order = n_long - k;
        bytes_zero(e, SLOT_BYTES);
        e[0] = (uint8_t)(order | (k == 0 ? 0x40 : 0));
        e[11] = FAT_ATTR_LONG_NAME;
        e[13] = sum;
        for (int c = 0; c < 13; c++) {
            size_t i = (size_t)(order - 1) * 13 + (size_t)c;
            uint16_t ch = i < length ? (uint8_t)name[i] : (i == length ? 0x0000 : 0xFFFF);
            put16(e + at[c], ch);
        }
        r = write_slot(v, dir_cluster, run_start + (uint32_t)k, e);
        if (r < 0) return r;
    }
    bytes_zero(e, SLOT_BYTES);
    bytes_copy(e, short_name, 11);
    e[11] = attributes;
    put16(e + 20, (uint16_t)(first_cluster >> 16));
    put16(e + 26, (uint16_t)first_cluster);
    put32(e + 28, size);
    /* Dates: the card has no clock to ask (no real-time clock is brought
     * up), so every date is FAT's earliest, 1980-01-01. */
    put16(e + 16, 0x21);
    put16(e + 18, 0x21);
    put16(e + 24, 0x21);
    uint32_t short_slot = run_start + (uint32_t)n_long;
    r = write_slot(v, dir_cluster, short_slot, e);
    if (r < 0) return r;
    if (out) {
        bytes_zero(out, sizeof *out);
        text_format(out->name, sizeof out->name, "%s", name);
        out->attributes = attributes;
        out->first_cluster = first_cluster;
        out->size = size;
        out->dir_cluster = dir_cluster;
        out->slot = short_slot;
        out->first_slot = run_start;
        slot_block(v, dir_cluster, short_slot, &out->location_block, &out->location_offset);
    }
    return FAT_OK;
}
/* }}} */

/* {{{ fat_dir_update */
int fat_dir_update(struct fat_volume *v, const struct fat_entry *e, uint32_t first_cluster, uint32_t size)
{
    uint8_t block[BLOCK];
    (void)v;
    if (platform_card_read(e->location_block, 1, block)) return FAT_IO;
    uint8_t *s = block + e->location_offset;
    put16(s + 20, (uint16_t)(first_cluster >> 16));
    put16(s + 26, (uint16_t)first_cluster);
    put32(s + 28, size);
    return platform_card_write(e->location_block, 1, block) ? FAT_IO : FAT_OK;
}
/* }}} */

/* {{{ fat_dir_remove */
int fat_dir_remove(struct fat_volume *v, const struct fat_entry *e)
{
    uint8_t slot[SLOT_BYTES];
    for (uint32_t s = e->first_slot; s <= e->slot; s++) {
        int r = read_slot(v, e->dir_cluster, s, slot);
        if (r <= 0) return r < 0 ? r : FAT_IO;
        slot[0] = 0xE5;
        r = write_slot(v, e->dir_cluster, s, slot);
        if (r < 0) return r;
    }
    return FAT_OK;
}
/* }}} */

/* {{{ fat_dir_make */
int64_t fat_dir_make(struct fat_volume *v, uint32_t parent_cluster)
{
    uint32_t c = take_free_cluster(v);
    if (!c) return FAT_NO_SPACE;
    set_next(v, c, 0x0FFFFFFFu);
    uint8_t block[BLOCK];
    for (uint32_t s = 0; s < v->sectors_per_cluster; s++) {
        bytes_zero(block, BLOCK);
        if (s == 0) {
            /* "." names this directory, ".." its parent (0 when the
             * parent is the root, by FAT convention). */
            uint32_t parent = parent_cluster == v->root_cluster ? 0 : parent_cluster;
            for (int i = 0; i < 11; i++) { block[i] = ' '; block[32 + i] = ' '; }
            block[0] = '.';
            block[32] = '.'; block[33] = '.';
            block[11] = FAT_ATTR_DIRECTORY;
            block[32 + 11] = FAT_ATTR_DIRECTORY;
            put16(block + 20, (uint16_t)(c >> 16)); put16(block + 26, (uint16_t)c);
            put16(block + 32 + 20, (uint16_t)(parent >> 16)); put16(block + 32 + 26, (uint16_t)parent);
            put16(block + 16, 0x21); put16(block + 24, 0x21); put16(block + 18, 0x21);
            put16(block + 32 + 16, 0x21); put16(block + 32 + 24, 0x21); put16(block + 32 + 18, 0x21);
        }
        if (platform_card_write(fat_cluster_block(v, c) + s, 1, block)) return FAT_IO;
    }
    return c;
}
/* }}} */
/* }}} */
