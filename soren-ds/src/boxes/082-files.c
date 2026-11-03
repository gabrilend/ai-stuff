/*
 * 082-files.c — the eight filesystem boxes, and the values they pass
 * (issues 406, 407, 413, 414).
 *
 * General description: everything an app ever does to the card goes
 * through one of these: read-path, write-path, list-directory,
 * delete-path, path-exists and make-symlink (docs/011-filesystem.md);
 * append-path, which builds a file larger than one value (413); and
 * move-path, which lets such a file appear all at once (414). Each
 * is a thin wrapper over the path layer (src/system/078-files.c), which
 * holds the card's one lock, follows the device's symlinks, and keeps a
 * write whole if it is interrupted.
 *
 * A box may not pass a pointer, so a path travels as `struct path` (256
 * characters, ended by a zero), a file's contents as `struct file_bytes`
 * (up to FILE_CHUNK bytes, with the outcome and the file's whole size
 * beside them), and a directory's names as `struct name_list`. Two small
 * boxes make a path out of text, so a program can build one from pieces.
 *
 * What goes wrong is split the way 407 asks. A result the caller may
 * reasonably want to handle — no such file, a directory that is not
 * empty, no card in the slot — rides in the value: a status of 0 for
 * success or one of fat_error's negative codes. A path that cannot be a
 * path at all — no end inside its 256 characters, longer or deeper than
 * any path may be, a name FAT cannot hold, the root asked to be deleted —
 * is a refusal (issue 214), and the refusal's detail is the error's code
 * without its sign.
 *
 * These boxes wait for the card, which is the one exception the launch
 * system makes to "a box never blocks": the card is the only place the
 * bytes are, and a box is where docs/011 puts reading them.
 */
#include <stdint.h>
#include "../engine/027-primitives.h"
#include "../engine/031-engine.h"
#include "../system/077-fat.h"
#include "../system/078-files.h"

#define FILE_PATH_CHARS 256
#define FILE_CHUNK 4096                /* the most bytes one value carries: one page of a file */
#define NAME_LIST_BYTES 4096

struct path {
    char chars[FILE_PATH_CHARS];
};

/* A file's contents, or as much of them as one value holds. `status` is 0
 * or a negative fat_error code; `file_size` is the whole file's size, so a
 * reader can tell whether there is more to ask for with read_slice. */
struct file_bytes {
    int64_t  status;
    uint64_t file_size;
    uint32_t length;
    uint8_t  bytes[FILE_CHUNK];
};

/* A directory's names, pinned so a consumer can take them apart (407):
 * `count` names, packed one after another in the first `used` bytes of
 * `names`, each as one byte giving its length, then its characters, then
 * a zero. Names that did not fit are counted in `left_out` rather than
 * lost silently. */
struct name_list {
    int64_t  status;
    uint32_t count;
    uint32_t left_out;
    uint32_t used;
    uint8_t  names[NAME_LIST_BYTES];
};

/* {{{ refused */
/* Is this an error that means the path could never have been a path? If
 * so, refuse the value (the engine throws the box's answer away). */
static int refused(int64_t error)
{
    if (error == FAT_TOO_LONG || error == FAT_BAD_NAME) {
        engine_refuse((uint64_t)-error);
        return 1;
    }
    return 0;
}
/* }}} */

/* {{{ ended */
/* A path with no zero inside its 256 characters is refused. */
static int ended(const struct path *p)
{
    for (int i = 0; i < FILE_PATH_CHARS; i++) {
        if (p->chars[i] == 0) return 1;
    }
    engine_refuse((uint64_t)-FAT_TOO_LONG);
    return 0;
}
/* }}} */

/* {{{ text_path */
/* A path from text: the same characters, in the larger value. */
struct path text_path(struct text t)
{
    struct path p;
    bytes_zero(&p, sizeof p);
    int n = 0;
    while (n < (int)sizeof t.chars - 1 && t.chars[n]) {
        p.chars[n] = t.chars[n];
        n++;
    }
    return p;
}
/* }}} */

/* {{{ path_join */
/* A directory's path and a name in it: "dir" and "name" give "dir/name".
 * One that would not fit is refused. */
struct path path_join(struct path dir, struct text name)
{
    if (!ended(&dir)) return dir;
    int n = (int)text_length(dir.chars);
    if (n > 0 && dir.chars[n - 1] != '/') {
        if (n + 1 >= FILE_PATH_CHARS) {
            engine_refuse((uint64_t)-FAT_TOO_LONG);
            return dir;
        }
        dir.chars[n++] = '/';
    }
    for (int i = 0; i < (int)sizeof name.chars && name.chars[i]; i++) {
        if (n + 1 >= FILE_PATH_CHARS) {
            engine_refuse((uint64_t)-FAT_TOO_LONG);
            return dir;
        }
        dir.chars[n++] = name.chars[i];
    }
    dir.chars[n] = 0;
    return dir;
}
/* }}} */

/* {{{ read_slice */
/* Up to `length` bytes (at most FILE_CHUNK) of a file, from `offset`.
 * A slice starting at or past the end holds no bytes and is not an error. */
struct file_bytes read_slice(struct path path, uint64_t offset, uint64_t length)
{
    struct file_bytes out;
    bytes_zero(&out, sizeof out);
    if (!ended(&path)) return out;
    int64_t size = files_size(path.chars);
    if (size < 0) {
        out.status = size;
        refused(size);
        return out;
    }
    out.file_size = (uint64_t)size;
    if (length > FILE_CHUNK) length = FILE_CHUNK;
    if (offset >= (uint64_t)size || length == 0) return out;
    int64_t n = files_read(path.chars, (uint32_t)offset, out.bytes, (uint32_t)length);
    if (n < 0) {
        out.status = n;
        return out;
    }
    out.length = (uint32_t)n;
    return out;
}
/* }}} */

/* {{{ read_path */
/* A file's contents from the start: all of them, if the file is no larger
 * than FILE_CHUNK; otherwise the first FILE_CHUNK bytes, with file_size
 * saying how many more read_slice can fetch. */
struct file_bytes read_path(struct path path)
{
    return read_slice(path, 0, FILE_CHUNK);
}
/* }}} */

/* {{{ write_path */
/* Replace a file's contents with the value's bytes, making the file and
 * any directories on its way. Through a symlink, the target is written.
 * A value that is itself a failed read (status below 0) is not written:
 * its status is passed on, so a copy whose source is missing never
 * replaces the destination with nothing. Answers 0 or a negative code. */
int64_t write_path(struct path path, struct file_bytes value)
{
    if (!ended(&path)) return FAT_TOO_LONG;
    if (value.status < 0) return value.status;
    if (value.length > FILE_CHUNK) {
        engine_refuse((uint64_t)-FAT_TOO_LONG);
        return FAT_TOO_LONG;
    }
    int r = files_write(path.chars, value.bytes, value.length);
    refused(r);
    return r;
}
/* }}} */

/* {{{ append_path */
/* Add the value's bytes to the end of a file, making the file and any
 * directories on its way (issue 413). This is how a file larger than one
 * value is written: one append per FILE_CHUNK bytes. Each append is whole
 * or not at all; the file between appends is the appends so far. A failed
 * read is not appended and its status is passed on, as write_path does,
 * so a copy loop whose source runs out stops growing the destination.
 * Answers 0 or a negative code. */
int64_t append_path(struct path path, struct file_bytes value)
{
    if (!ended(&path)) return FAT_TOO_LONG;
    if (value.status < 0) return value.status;
    if (value.length > FILE_CHUNK) {
        engine_refuse((uint64_t)-FAT_TOO_LONG);
        return FAT_TOO_LONG;
    }
    int r = files_append(path.chars, value.bytes, value.length);
    refused(r);
    return r;
}
/* }}} */

/* {{{ move_path */
/* Give a file another name, replacing any file that had it (issue 414).
 * Build a large file under a name of its own with append_path, then move
 * it over the name readers use: they see the old file or the whole new
 * one, never the appends so far. Links at either end are moved or
 * replaced as themselves; a directory is a status, not moved. Answers 0
 * or a negative code. */
int64_t move_path(struct path from, struct path to)
{
    if (!ended(&from) || !ended(&to)) return FAT_TOO_LONG;
    int r = files_move(from.chars, to.chars);
    refused(r);
    return r;
}
/* }}} */

/* {{{ add_name */
static int add_name(const struct fat_entry *e, void *ctx)
{
    struct name_list *list = ctx;
    uint32_t n = (uint32_t)text_length(e->name);
    if (n > 255 || list->used + 1 + n + 1 > NAME_LIST_BYTES) {
        list->left_out++;
        return 0;
    }
    list->names[list->used] = (uint8_t)n;
    bytes_copy(list->names + list->used + 1, e->name, n + 1);
    list->used += 1 + n + 1;
    list->count++;
    return 0;
}
/* }}} */

/* {{{ list_directory */
/* The names in a directory, links listed as themselves. A path that is
 * not a directory is an error in the status, never an empty list. */
struct name_list list_directory(struct path path)
{
    struct name_list out;
    bytes_zero(&out, sizeof out);
    if (!ended(&path)) return out;
    int r = files_list(path.chars, add_name, &out);
    if (r < 0) {
        bytes_zero(&out, sizeof out);
        out.status = r;
        refused(r);
    }
    return out;
}
/* }}} */

/* {{{ delete_path */
/* Remove a file or an empty directory. A symlink is removed itself, never
 * what it names. Answers 0 or a negative code. */
int64_t delete_path(struct path path)
{
    if (!ended(&path)) return FAT_TOO_LONG;
    int r = files_delete(path.chars);
    refused(r);
    return r;
}
/* }}} */

/* {{{ path_exists */
/* 1 if the path names something, links followed; 0 if not, including a
 * link to nothing, links that loop, and no card in the slot. */
int64_t path_exists(struct path path)
{
    if (!ended(&path)) return 0;
    int r = files_exists(path.chars);
    if (r < 0) {
        refused(r);
        return 0;
    }
    return r;
}
/* }}} */

/* {{{ make_symlink */
/* A link at `link` naming `target`, which need not exist yet. A target
 * starting with '/' starts from the root; any other is relative to the
 * link's own directory. Answers 0 or a negative code. */
int64_t make_symlink(struct path link, struct path target)
{
    if (!ended(&link) || !ended(&target)) return FAT_TOO_LONG;
    int r = files_make_link(link.chars, target.chars);
    refused(r);
    return r;
}
/* }}} */
