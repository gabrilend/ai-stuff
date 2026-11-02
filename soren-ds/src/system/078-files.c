/*
 * 078-files.c — paths on the card, and the device's own symlinks (issue 405).
 *
 * General description: one mounted card, one lock in front of it, and a
 * resolver. The resolver keeps the path still to walk as text and the
 * directories it has come down through as a stack of clusters; each
 * component is looked up in the directory on top of the stack. When a
 * component is one of the device's symlinks, its target's text is put in
 * front of whatever was left of the path, and the walk carries on from the
 * root (a target starting with '/') or from the link's own directory. That
 * one rule handles a link in the middle of a path, a link to a link, and a
 * relative target with ".." in it alike, and the hop count stops a loop.
 *
 * Writes keep the order that makes them safe to interrupt: the new
 * contents go into clusters no entry names, the table is written so the
 * card knows those clusters are taken, and only then does one block write
 * point the name at them. The old clusters are freed after.
 */
#include "../engine/025-platform.h"
#include "../engine/027-primitives.h"
#include "077-fat.h"
#include "078-files.h"

static struct fat_volume volume;
static int mounted;
static spin_lock_t lock = SPIN_LOCK_INIT;

/* Where a path leads: the directory its last component is in, that
 * component's name, and its entry if it is there. A path that ends at
 * the root, ".", or ".." ends at a directory known only by its cluster;
 * its entry is made up, and it cannot be removed or replaced. */
struct place {
    uint32_t         dir;
    char             leaf[FAT_NAME];
    int              found;
    int              made_up;
    struct fat_entry entry;
};

/* {{{ the card */
/* {{{ files_start */
int files_start(int owner)
{
    spin_lock(&lock);
    if (mounted) {
        fat_flush(&volume);
        fat_unmount(&volume);
        mounted = 0;
    }
    int r = fat_mount(&volume, owner);
    mounted = r == FAT_OK;
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_stop */
void files_stop(void)
{
    spin_lock(&lock);
    if (mounted) {
        fat_flush(&volume);
        fat_unmount(&volume);
        mounted = 0;
    }
    spin_unlock(&lock);
}
/* }}} */

/* {{{ files_ready */
int files_ready(void)
{
    return mounted;
}
/* }}} */
/* }}} */

/* {{{ resolving */
/* {{{ next_component */
/* Take the next component off the front of `*rest` into `name`. Answers
 * its length, 0 when nothing is left, or FAT_TOO_LONG. */
static int next_component(const char **rest, char *name)
{
    const char *p = *rest;
    while (*p == '/') p++;
    size_t n = 0;
    while (p[n] && p[n] != '/') n++;
    if (n >= FAT_NAME) return FAT_TOO_LONG;
    bytes_copy(name, p, n);
    name[n] = 0;
    *rest = p + n;
    return (int)n;
}
/* }}} */

/* {{{ nothing_after */
static int nothing_after(const char *rest)
{
    while (*rest == '/') rest++;
    return *rest == 0;
}
/* }}} */

/* {{{ is_link */
/* Answers 1 for one of the device's symlinks, 0 for anything else. */
static int is_link(const struct fat_entry *e)
{
    if ((e->attributes & FAT_ATTR_DIRECTORY) || e->size <= FILES_LINK_MAGIC_BYTES || e->first_cluster < 2) {
        return 0;
    }
    uint8_t head[FILES_LINK_MAGIC_BYTES];
    int r = fat_chain_read(&volume, e->first_cluster, 0, head, FILES_LINK_MAGIC_BYTES);
    if (r < 0) return r;
    return bytes_equal(head, FILES_LINK_MAGIC, FILES_LINK_MAGIC_BYTES);
}
/* }}} */

/* {{{ read_link */
/* A link's target, as text, into `target` (FILES_PATH bytes). */
static int read_link(const struct fat_entry *e, char *target)
{
    uint32_t n = e->size - FILES_LINK_MAGIC_BYTES;
    if (n > FILES_PATH - 1) n = FILES_PATH - 1;
    int r = fat_chain_read(&volume, e->first_cluster, FILES_LINK_MAGIC_BYTES, target, n);
    if (r < 0) return r;
    target[n] = 0;
    if (text_length(target) == n && e->size - FILES_LINK_MAGIC_BYTES > FILES_PATH - 1) {
        return FAT_TOO_LONG;                   /* no end inside the longest path there can be */
    }
    return FAT_OK;
}
/* }}} */

/* {{{ made_up */
/* The place for a path that ends at a directory known only by cluster. */
static void made_up(struct place *p, uint32_t cluster)
{
    bytes_zero(p, sizeof *p);
    p->dir = cluster;
    p->found = 1;
    p->made_up = 1;
    p->entry.attributes = FAT_ATTR_DIRECTORY;
    p->entry.first_cluster = cluster;
}
/* }}} */

/* {{{ make_directory_in */
/* A new directory named `name` inside `parent`. The table is written
 * before the name, so the card never has a name for clusters it still
 * thinks are free. */
static int make_directory_in(uint32_t parent, const char *name, struct fat_entry *out)
{
    int64_t c = fat_dir_make(&volume, parent);
    if (c < 0) return (int)c;
    int r = fat_flush(&volume);
    if (r == FAT_OK) r = fat_dir_add(&volume, parent, name, FAT_ATTR_DIRECTORY, (uint32_t)c, 0, out);
    if (r < 0) {
        fat_chain_free(&volume, (uint32_t)c);
        fat_flush(&volume);
    }
    return r;
}
/* }}} */

/* {{{ locate */
/* Walk `path`. Symlinks in the middle are always followed; one at the
 * end only when `follow_last`. Missing directories on the way are made
 * when `make_dirs`, and are FAT_NOT_FOUND otherwise. A missing last
 * component is not an error: the place says where it would be. */
static int locate(const char *path, int follow_last, int make_dirs, struct place *p)
{
    char work[FILES_PATH], spliced[FILES_PATH], target[FILES_PATH], name[FAT_NAME];
    uint32_t stack[FILES_DEPTH];
    int depth = 0, hops = 0;
    if (text_length(path) >= FILES_PATH) return FAT_TOO_LONG;
    /* A path with more components than a path may go deep is refused
     * before anything is looked up, so a write that could never finish
     * does not make the directories it would have needed first. */
    int components = 0;
    for (const char *c = path; *c; c++) {
        if (*c != '/' && (c == path || c[-1] == '/')) components++;
    }
    if (components > FILES_DEPTH) return FAT_TOO_LONG;
    text_format(work, sizeof work, "%s", path);
    const char *rest = work;
    stack[0] = volume.root_cluster;
    for (;;) {
        int n = next_component(&rest, name);
        if (n < 0) return n;
        if (n == 0) {                                        /* the path ended at a directory */
            made_up(p, stack[depth]);
            return FAT_OK;
        }
        if (text_equal(name, ".")) continue;
        if (text_equal(name, "..")) {
            if (depth > 0) depth--;
            continue;
        }
        int last = nothing_after(rest);
        struct fat_entry e;
        int r = fat_dir_find(&volume, stack[depth], name, &e);
        if (r == FAT_NOT_FOUND && last) {
            bytes_zero(p, sizeof *p);
            p->dir = stack[depth];
            text_format(p->leaf, sizeof p->leaf, "%s", name);
            return FAT_OK;
        }
        if (r == FAT_NOT_FOUND && make_dirs) {
            r = make_directory_in(stack[depth], name, &e);
        }
        if (r < 0) return r;
        if (!last || follow_last) {
            int link = is_link(&e);
            if (link < 0) return link;
            if (link) {
                if (++hops > FILES_HOPS) return FAT_LOOP;
                r = read_link(&e, target);
                if (r < 0) return r;
                if (text_length(target) + 1 + text_length(rest) >= FILES_PATH) return FAT_TOO_LONG;
                text_format(spliced, sizeof spliced, "%s/%s", target, rest);
                bytes_copy(work, spliced, text_length(spliced) + 1);
                rest = work;
                if (target[0] == '/') depth = 0;
                continue;                                    /* a relative target goes on from the link's directory */
            }
        }
        if (last) {
            bytes_zero(p, sizeof *p);
            p->dir = stack[depth];
            text_format(p->leaf, sizeof p->leaf, "%s", name);
            p->found = 1;
            p->entry = e;
            return FAT_OK;
        }
        if (!(e.attributes & FAT_ATTR_DIRECTORY)) return FAT_NOT_A_DIRECTORY;
        if (depth + 1 >= FILES_DEPTH) return FAT_TOO_LONG;
        /* A directory entry naming cluster 0 is FAT's way of naming the root. */
        stack[++depth] = e.first_cluster ? e.first_cluster : volume.root_cluster;
    }
}
/* }}} */

/* {{{ directory_cluster */
static uint32_t directory_cluster(const struct fat_entry *e)
{
    return e->first_cluster ? e->first_cluster : volume.root_cluster;
}
/* }}} */
/* }}} */

/* {{{ looking things up */
/* {{{ resolve */
static int resolve(const char *path, int follow_last, struct fat_entry *out)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, follow_last, 0, &p) : FAT_NO_CARD;
    if (r == FAT_OK && !p.found) r = FAT_NOT_FOUND;
    if (r == FAT_OK && out) *out = p.entry;
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_resolve */
int files_resolve(const char *path, struct fat_entry *out)
{
    return resolve(path, 1, out);
}
/* }}} */

/* {{{ files_resolve_link */
int files_resolve_link(const char *path, struct fat_entry *out)
{
    return resolve(path, 0, out);
}
/* }}} */

/* {{{ files_exists */
int files_exists(const char *path)
{
    int r = resolve(path, 1, (struct fat_entry *)0);
    if (r == FAT_OK) return 1;
    if (r == FAT_NOT_FOUND || r == FAT_NOT_A_DIRECTORY || r == FAT_LOOP) return 0;
    return r;
}
/* }}} */

/* {{{ files_is_link */
int files_is_link(const struct fat_entry *e)
{
    spin_lock(&lock);
    int r = mounted ? is_link(e) : FAT_NO_CARD;
    spin_unlock(&lock);
    return r;
}
/* }}} */
/* }}} */

/* {{{ whole-file operations */
/* {{{ files_read */
int64_t files_read(const char *path, uint32_t offset, void *buffer, uint32_t capacity)
{
    spin_lock(&lock);
    struct place p;
    int64_t r = mounted ? locate(path, 1, 0, &p) : FAT_NO_CARD;
    if (r == FAT_OK && !p.found) r = FAT_NOT_FOUND;
    if (r == FAT_OK && (p.entry.attributes & FAT_ATTR_DIRECTORY)) r = FAT_IS_A_DIRECTORY;
    if (r == FAT_OK) {
        uint32_t n = offset < p.entry.size ? p.entry.size - offset : 0;
        if (n > capacity) n = capacity;
        r = n ? fat_chain_read(&volume, p.entry.first_cluster, offset, buffer, n) : FAT_OK;
        if (r == FAT_OK) r = n;
    }
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_size */
int64_t files_size(const char *path)
{
    struct fat_entry e;
    int r = files_resolve(path, &e);
    if (r < 0) return r;
    if (e.attributes & FAT_ATTR_DIRECTORY) return FAT_IS_A_DIRECTORY;
    return e.size;
}
/* }}} */

/* {{{ put_new_file */
/* Write `bytes` into a new chain and give it the name a place says:
 * the name is pointed at the chain only after the table records it, and
 * a name that already had contents lets them go only after that. */
static int put_new_file(struct place *p, const void *bytes, uint32_t length)
{
    int64_t chain = fat_chain_new(&volume, bytes, length);
    if (chain < 0) return (int)chain;
    int r = fat_flush(&volume);
    if (r == FAT_OK) {
        r = p->found ? fat_dir_update(&volume, &p->entry, (uint32_t)chain, length)
                     : fat_dir_add(&volume, p->dir, p->leaf, FAT_ATTR_ARCHIVE, (uint32_t)chain, length, (struct fat_entry *)0);
    }
    if (r < 0) {
        fat_chain_free(&volume, (uint32_t)chain);    /* nothing names it; give it back */
        fat_flush(&volume);
        return r;
    }
    if (p->found) fat_chain_free(&volume, p->entry.first_cluster);
    return fat_flush(&volume);
}
/* }}} */

/* {{{ files_write */
int files_write(const char *path, const void *bytes, uint32_t length)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, 1, 1, &p) : FAT_NO_CARD;
    if (r == FAT_OK && p.found && (p.entry.attributes & FAT_ATTR_DIRECTORY)) r = FAT_IS_A_DIRECTORY;
    if (r == FAT_OK) r = put_new_file(&p, bytes, length);
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_append */
/* The new bytes go after the old (fat_chain_append), the table is written,
 * and one block write then gives the entry its new size. A file that is
 * missing or empty is a new chain, exactly as files_write makes one. */
int files_append(const char *path, const void *bytes, uint32_t length)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, 1, 1, &p) : FAT_NO_CARD;
    if (r == FAT_OK && p.found && (p.entry.attributes & FAT_ATTR_DIRECTORY)) r = FAT_IS_A_DIRECTORY;
    if (r == FAT_OK && (!p.found || p.entry.size == 0)) {
        r = put_new_file(&p, bytes, length);
    } else if (r == FAT_OK && length) {
        uint32_t first = p.entry.first_cluster, size = p.entry.size;
        r = fat_chain_append(&volume, first, size, bytes, length);
        if (r == FAT_OK) r = fat_dir_update(&volume, &p.entry, first, size + length);
        if (r < 0) {
            /* The size was never written: the file is its old self, and the
             * clusters added after it are let go again. */
            fat_chain_cut(&volume, first, size);
            fat_flush(&volume);
        }
    }
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_list */
/* `visit` runs with the card's lock held, so it must not call back into
 * this layer; it is for collecting names. */
int files_list(const char *path, int (*visit)(const struct fat_entry *e, void *ctx), void *ctx)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, 1, 0, &p) : FAT_NO_CARD;
    if (r == FAT_OK && !p.found) r = FAT_NOT_FOUND;
    if (r == FAT_OK && !(p.entry.attributes & FAT_ATTR_DIRECTORY)) r = FAT_NOT_A_DIRECTORY;
    if (r == FAT_OK) r = fat_dir_walk(&volume, directory_cluster(&p.entry), visit, ctx);
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ any_entry */
static int any_entry(const struct fat_entry *e, void *ctx)
{
    (void)e;
    *(int *)ctx = 1;
    return 1;
}
/* }}} */

/* {{{ files_delete */
int files_delete(const char *path)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, 0, 0, &p) : FAT_NO_CARD;
    if (r == FAT_OK && !p.found) r = FAT_NOT_FOUND;
    if (r == FAT_OK && p.made_up) r = FAT_BAD_NAME;              /* the root, ".", or ".." */
    if (r == FAT_OK && (p.entry.attributes & FAT_ATTR_DIRECTORY)) {
        int any = 0;
        r = fat_dir_walk(&volume, directory_cluster(&p.entry), any_entry, &any);
        if (r == FAT_OK && any) r = FAT_NOT_EMPTY;
    }
    /* The name goes first, then its clusters: an interruption between the
     * two leaves clusters nothing names, never a name for free clusters. */
    if (r == FAT_OK) r = fat_dir_remove(&volume, &p.entry);
    if (r == FAT_OK) {
        fat_chain_free(&volume, p.entry.first_cluster);
        r = fat_flush(&volume);
    }
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_make_link */
int files_make_link(const char *link, const char *target)
{
    size_t n = text_length(target);
    if (n == 0) return FAT_BAD_NAME;
    if (n >= FILES_PATH) return FAT_TOO_LONG;
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(link, 0, 1, &p) : FAT_NO_CARD;
    if (r == FAT_OK && p.found) r = FAT_EXISTS;
    if (r == FAT_OK) {
        char contents[FILES_LINK_MAGIC_BYTES + FILES_PATH];
        bytes_copy(contents, FILES_LINK_MAGIC, FILES_LINK_MAGIC_BYTES);
        bytes_copy(contents + FILES_LINK_MAGIC_BYTES, target, n + 1);
        r = put_new_file(&p, contents, (uint32_t)(FILES_LINK_MAGIC_BYTES + n + 1));
    }
    spin_unlock(&lock);
    return r;
}
/* }}} */

/* {{{ files_make_directory */
int files_make_directory(const char *path)
{
    spin_lock(&lock);
    struct place p;
    int r = mounted ? locate(path, 1, 1, &p) : FAT_NO_CARD;
    if (r == FAT_OK && p.found && !(p.entry.attributes & FAT_ATTR_DIRECTORY)) r = FAT_EXISTS;
    if (r == FAT_OK && !p.found) r = make_directory_in(p.dir, p.leaf, (struct fat_entry *)0);
    spin_unlock(&lock);
    return r;
}
/* }}} */
/* }}} */
