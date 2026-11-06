/*
 * 078-files.h — paths on the card, and the device's own symlinks (issue 405).
 *
 * General description: the layer every filesystem box calls. It owns the
 * one mounted card and the one lock in front of it, turns a path like
 * "/programs/hello/meta.json" into a directory entry, follows the device's
 * symlinks on the way, and does each whole-file operation the boxes of
 * 406 and 407 need under that lock: read, replace, list, delete, ask
 * whether something exists, make a link, make a directory.
 *
 * Paths are '/'-separated and always start from the card's root, whether
 * or not they begin with '/'. Empty components and "." are skipped; ".."
 * steps back up the way the path came down (never above the root). Names
 * are compared without regard to case, as FAT convention has it.
 *
 * A symlink is an ordinary file whose contents are the eight bytes
 * "SOSYMLNK" and then the target path, ending in a zero byte
 * (docs/011-filesystem.md). A laptop sees a small file; the device follows
 * it, at any component of a path. A target starting with '/' starts from
 * the root; any other target is relative to the directory the link is in.
 * More than FILES_HOPS links in one resolution is FAT_LOOP.
 *
 * Every function answers FAT_OK (0), a count, or one of fat_error's
 * negative codes; fat_error_text says what each means.
 */
#ifndef SOREN_FILES_H
#define SOREN_FILES_H

#include <stdint.h>
#include <stddef.h>
#include "077-fat.h"

#define FILES_PATH 1024                 /* the longest path, links spliced in, plus its end */
#define FILES_DEPTH 64                  /* the deepest directory a path may reach */
#define FILES_HOPS 32                   /* symlinks followed in one resolution */
#define FILES_LINK_MAGIC "SOSYMLNK"
#define FILES_LINK_MAGIC_BYTES 8

/* {{{ the card */
/* Mount the card, into memory `owner` holds. Answers FAT_OK, FAT_NO_CARD,
 * or why the card was refused. Calling it again remounts (the card may
 * have been changed). */
int  files_start(int owner);
/* Write back anything not yet written and give the table back. */
void files_stop(void);
/* Is a card mounted? */
int  files_ready(void);
/* }}} */

/* {{{ looking things up */
/* The entry a path names, every symlink on the way followed, the last
 * one included. The root answers an entry with no name, the directory
 * attribute and the root's cluster. */
int  files_resolve(const char *path, struct fat_entry *out);
/* The same, but a symlink at the last component is answered as itself. */
int  files_resolve_link(const char *path, struct fat_entry *out);
/* 1 if the path names something (following every link), 0 if it does not
 * (a link to nothing, or links that loop, also answer 0), negative only
 * for a path that cannot be a path or a card that cannot be read. */
int  files_exists(const char *path);
/* Is this entry one of the device's symlinks? Reads its first bytes. */
int  files_is_link(const struct fat_entry *e);
/* }}} */

/* {{{ whole-file operations */
/* Up to `capacity` bytes of a file from `offset`; answers how many were
 * read (0 at or past the end). A directory is FAT_IS_A_DIRECTORY. */
int64_t files_read(const char *path, uint32_t offset, void *buffer, uint32_t capacity);
/* A file's size in bytes, links followed. */
int64_t files_size(const char *path);
/* Replace a file's contents, making it if it is not there, and making any
 * directories on the way that are not there either. Through a symlink, the
 * target is written. Atomic in the sense docs/011 asks for: a reader, or a
 * card pulled out part-way, finds the old contents or the new, never part
 * of each (the new contents are written to clusters nobody names, and one
 * block write then switches the name over). */
int  files_write(const char *path, const void *bytes, uint32_t length);
/* Add bytes to the end of a file, making it (and directories on the way)
 * if it is not there; through a symlink, the target grows (issue 413).
 * Each append is whole or not at all: a reader, or a card pulled out
 * part-way, finds the file as it was before the call or with every new
 * byte after it. A file built from many appends is not one write: what is
 * on the card between them is the appends so far. */
int  files_append(const char *path, const void *bytes, uint32_t length);
/* Call `visit` for every entry of a directory (links followed to reach it;
 * entries that are links are listed as themselves). */
int  files_list(const char *path, int (*visit)(const struct fat_entry *e, void *ctx), void *ctx);
/* Remove a file or an empty directory. A symlink at the last component is
 * removed itself, never its target. A directory with anything in it is
 * FAT_NOT_EMPTY; the root cannot be removed. */
int  files_delete(const char *path);
/* A symlink at `link` naming `target`. The target need not exist yet.
 * Directories on the way to the link are made if missing. */
int  files_make_link(const char *link, const char *target);
/* A directory, and any missing on the way. One that is already there is
 * not an error. */
int  files_make_directory(const char *path);
/* }}} */

#endif
