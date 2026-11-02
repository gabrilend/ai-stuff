/*
 * 083-test-file-boxes.c — issues 406, 407.
 *
 * General description: the six filesystem boxes, run the way a program
 * runs them: each is placed as a station in a small map whose arguments
 * and result are doors, fed through the doors, and read back once the
 * engine settles. A file is written and read; a read wired straight into
 * a write copies a file, and a copy whose source is missing leaves the
 * destination alone; a file larger than one value is read in slices; a
 * directory's names come back in the layout 407 pins, with the ones that
 * did not fit counted; deleting, asking and linking answer as the path
 * layer does. A path built from text by two small boxes reaches a file.
 * What could never be a path is refused, with the reason as the detail;
 * what merely is not there rides in the value. And with the card taken
 * out, every box says so in its value rather than failing.
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

#include <string.h>

#define CORES 2
#define BOXES "../boxes/082-files.c"

/* The boxes' value types, written again here with the same layout; the
 * first checks below hold them to the catalogue's own sizes. */
struct path { char chars[256]; };
struct file_bytes { int64_t status; uint64_t file_size; uint32_t length; uint8_t bytes[4096]; };
struct name_list { int64_t status; uint32_t count; uint32_t left_out; uint32_t used; uint8_t names[4096]; };

/* {{{ path_of */
static struct path path_of(const char *s)
{
    struct path p;
    memset(&p, 0, sizeof p);
    snprintf(p.chars, sizeof p.chars, "%s", s);
    return p;
}
/* }}} */

/* {{{ bytes_of */
static struct file_bytes bytes_of(const void *data, uint32_t n)
{
    static struct file_bytes b;
    memset(&b, 0, sizeof b);
    memcpy(b.bytes, data, n);
    b.length = n;
    return b;
}
/* }}} */

static struct engine_error_report last_error;

/* {{{ call */
/* Run one box once: a map of one station whose ports 0..n-1 are
 * arguments and whose exit is the result. Answers 1 if a result came
 * out, 0 if none did (the box refused: last_error says why). */
static int call(const char *function, int n, const void *const *args, const size_t *sizes, void *out, size_t out_size)
{
    char text[512];
    int at = snprintf(text, sizeof text, "station s (" BOXES ":%s)\n", function);
    for (int i = 0; i < n; i++) at += snprintf(text + at, sizeof text - (size_t)at, "  in %d - %d$\n", i, i);
    snprintf(text + at, sizeof text - (size_t)at, "  out 0 - 0$\n");
    static struct map_report report;
    int program = program_load_text("src/maps/file-box.map", text, strlen(text), &report);
    if (program < 0 || program_bring_up(program, &report) != 0) {
        fprintf(stderr, "%s did not load:\n%s", function, report.text);
        return -1;
    }
    for (int i = 0; i < n; i++) program_argument(program, i, args[i], sizes[i]);
    twin_engine_settle(5000);
    int got = program_result(program, 0, out, out_size);
    engine_read_error(program_station(program, "s"), &last_error, 1);
    program_remove(program);
    return got;
}
/* }}} */

/* {{{ one-argument and two-argument shorthands */
static int call1(const char *function, const void *a, size_t sa, void *out, size_t so)
{
    const void *args[] = { a };
    size_t sizes[] = { sa };
    return call(function, 1, args, sizes, out, so);
}

static int call2(const char *function, const void *a, size_t sa, const void *b, size_t sb, void *out, size_t so)
{
    const void *args[] = { a, b };
    size_t sizes[] = { sa, sb };
    return call(function, 2, args, sizes, out, so);
}
/* }}} */

/* {{{ the six boxes, as calls */
static int64_t write_path(const char *path, const void *data, uint32_t n)
{
    struct path p = path_of(path);
    struct file_bytes *b = malloc(sizeof *b);
    *b = bytes_of(data, n);
    int64_t status = 99;
    call2("write_path", &p, sizeof p, b, sizeof *b, &status, sizeof status);
    free(b);
    return status;
}

static struct file_bytes read_back;
static int64_t read_path(const char *path)
{
    struct path p = path_of(path);
    memset(&read_back, 0, sizeof read_back);
    read_back.status = 99;
    call1("read_path", &p, sizeof p, &read_back, sizeof read_back);
    return read_back.status;
}

static int64_t one_path(const char *function, const char *path)
{
    struct path p = path_of(path);
    int64_t answer = 99;
    call1(function, &p, sizeof p, &answer, sizeof answer);
    return answer;
}
/* }}} */

/* {{{ list_has */
/* Walk a name list by its pinned layout; is `name` in it? */
static int list_has(const struct name_list *l, const char *name)
{
    uint32_t at = 0;
    for (uint32_t i = 0; i < l->count; i++) {
        uint8_t n = l->names[at];
        if (l->names[at + 1 + n] != 0) return 0;          /* every name ends in a zero */
        if (n == strlen(name) && memcmp(l->names + at + 1, name, n) == 0) return 1;
        at += 1u + n + 1u;
    }
    return 0;
}
/* }}} */

int main(void)
{
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    char card[600], line[600];
    snprintf(card, sizeof card, "%s/tmp/shared-memory/083-card.img", dir);
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/083-developer-line.log", dir);
    remove(line);
    twin_engine_start(CORES, (size_t)256 << 20);
    twin_platform_set_log(line, 0);
    engine_open_gate();

    const struct catalogue_type *tp = catalogue_type_named("struct path");
    const struct catalogue_type *tb = catalogue_type_named("struct file_bytes");
    const struct catalogue_type *tl = catalogue_type_named("struct name_list");
    CHECK(tp && tb && tl && tp->size == sizeof(struct path) && tb->size == sizeof(struct file_bytes) && tl->size == sizeof(struct name_list),
          "the catalogue knows the three value types, at the sizes this test writes them");

    struct layout l;
    format(&l, 40, 1);
    write_image(card);
    twin_card_open(card);
    CHECK(files_start(OWNER_OUTSIDE) == FAT_OK, "the card mounts");

    /* {{{ write, read, exists */
    CHECK(one_path("path_exists", "/settings/handedness") == 0, "path-exists says no before anything is written");
    CHECK(write_path("/settings/handedness", "r", 1) == 0, "write-path writes a file, making its directory");
    CHECK(one_path("path_exists", "/settings/handedness") == 1 && one_path("path_exists", "/settings") == 1,
          "path-exists says yes to the file and the directory");
    CHECK(read_path("/settings/handedness") == 0 && read_back.length == 1 && read_back.file_size == 1 && read_back.bytes[0] == 'r',
          "read-path reads it back: one byte, 'r'");
    CHECK(read_path("/settings/missing") == FAT_NOT_FOUND && read_back.length == 0 && last_error.kind == 0,
          "a missing file is a status in the value, not a refusal");
    CHECK(read_path("/settings") == FAT_IS_A_DIRECTORY, "reading a directory is a status too");
    /* }}} */

    /* {{{ a read wired into a write is a copy */
    const char *copy =
        "station from (" BOXES ":read_path)\n  in 0 - 0$\n  out 0 - to.1\n"
        "station to (" BOXES ":write_path)\n  in 0 - 1$\n  in 1 - from.0\n  out 0 - 0$\n";
    static struct map_report report;
    int program = program_load_text("src/maps/copy.map", copy, strlen(copy), &report);
    CHECK(program >= 0 && program_bring_up(program, &report) == 0, "a read wired into a write loads: same value type at both ends (%s)", report.text);
    struct path src = path_of("/settings/handedness"), dst = path_of("/backup/handedness");
    program_argument(program, 0, &src, sizeof src);
    program_argument(program, 1, &dst, sizeof dst);
    twin_engine_settle(5000);
    int64_t status = 99;
    CHECK(program_result(program, 0, &status, sizeof status) == 1 && status == 0 && read_path("/backup/handedness") == 0 &&
          read_back.length == 1 && read_back.bytes[0] == 'r',
          "and copies the file");
    src = path_of("/settings/never-written");
    program_argument(program, 0, &src, sizeof src);
    program_argument(program, 1, &dst, sizeof dst);
    twin_engine_settle(5000);
    CHECK(program_result(program, 0, &status, sizeof status) == 1 && status == FAT_NOT_FOUND &&
          read_path("/backup/handedness") == 0 && read_back.length == 1,
          "a copy whose source is missing passes the status on and leaves the destination as it was");
    program_remove(program);
    /* }}} */

    /* {{{ larger than one value */
    static uint8_t big[10000];
    for (int i = 0; i < 10000; i++) big[i] = (uint8_t)(i * 13 + 1);
    CHECK(files_write("/drawings/large.raw", big, sizeof big) == FAT_OK, "a file larger than one value is on the card");
    CHECK(read_path("/drawings/large.raw") == 0 && read_back.length == 4096 && read_back.file_size == 10000 &&
          memcmp(read_back.bytes, big, 4096) == 0,
          "read-path answers its first 4096 bytes, and says the whole file is 10000");
    struct path large = path_of("/drawings/large.raw");
    uint64_t offset = 8192, length = 4096;
    const void *args3[] = { &large, &offset, &length };
    size_t sizes3[] = { sizeof large, sizeof offset, sizeof length };
    memset(&read_back, 0, sizeof read_back);
    CHECK(call("read_slice", 3, args3, sizes3, &read_back, sizeof read_back) == 1 && read_back.status == 0 &&
          read_back.length == 1808 && memcmp(read_back.bytes, big + 8192, 1808) == 0,
          "read-slice fetches the last 1808 bytes from offset 8192");
    offset = 20000;
    CHECK(call("read_slice", 3, args3, sizes3, &read_back, sizeof read_back) == 1 && read_back.status == 0 && read_back.length == 0,
          "a slice past the end is empty, not an error");
    CHECK(write_path("/drawings/full.raw", big, 4096) == 0 && read_path("/drawings/full.raw") == 0 && read_back.length == 4096 &&
          memcmp(read_back.bytes, big, 4096) == 0,
          "a full value of 4096 bytes is written and read whole");
    /* }}} */

    /* {{{ list-directory */
    struct path settings = path_of("/settings");
    struct name_list *list = malloc(sizeof *list);
    CHECK(call1("list_directory", &settings, sizeof settings, list, sizeof *list) == 1 && list->status == 0 &&
          list->count == 1 && list->left_out == 0 && list_has(list, "handedness") && list->used == 1 + 10 + 1,
          "list-directory answers the names in 407's layout: a length, the characters, a zero");
    struct path missing = path_of("/nowhere"), file = path_of("/settings/handedness");
    CHECK(call1("list_directory", &missing, sizeof missing, list, sizeof *list) == 1 && list->status == FAT_NOT_FOUND && list->count == 0,
          "a directory that is not there is an error in the value, never an empty list");
    CHECK(call1("list_directory", &file, sizeof file, list, sizeof *list) == 1 && list->status == FAT_NOT_A_DIRECTORY,
          "and so is a file");
    char name[128];
    for (int i = 0; i < 120; i++) {
        snprintf(name, sizeof name, "/many/a rather long name for a message, number %03d.txt", i);
        files_write(name, "x", 1);
    }
    struct path many = path_of("/many");
    CHECK(call1("list_directory", &many, sizeof many, list, sizeof *list) == 1 && list->status == 0 &&
          list->count + list->left_out == 120 && list->left_out > 0 && list->used <= 4096 &&
          list_has(list, "a rather long name for a message, number 000.txt"),
          "a directory too full for one value lists what fits and counts the rest (%u listed, %u left out)", list->count, list->left_out);
    free(list);
    /* }}} */

    /* {{{ delete-path and make-symlink */
    struct path link = path_of("/latest"), target = path_of("/settings/handedness");
    int64_t made = 99;
    CHECK(call2("make_symlink", &link, sizeof link, &target, sizeof target, &made, sizeof made) == 1 && made == 0,
          "make-symlink makes a link");
    CHECK(read_path("/latest") == 0 && read_back.length == 1 && read_back.bytes[0] == 'r', "read-path follows it");
    CHECK(call2("make_symlink", &link, sizeof link, &target, sizeof target, &made, sizeof made) == 1 && made == FAT_EXISTS,
          "a second link over the first says it exists");
    CHECK(one_path("delete_path", "/latest") == 0 && one_path("path_exists", "/latest") == 0 && one_path("path_exists", "/settings/handedness") == 1,
          "delete-path removes the link and not its target");
    CHECK(one_path("delete_path", "/settings") == FAT_NOT_EMPTY && one_path("delete_path", "/settings/nothing") == FAT_NOT_FOUND,
          "a full directory and a missing file are statuses, not refusals");
    CHECK(one_path("delete_path", "/backup/handedness") == 0 && one_path("delete_path", "/backup") == 0 && one_path("path_exists", "/backup") == 0,
          "a file, then its emptied directory, are deleted");
    /* }}} */

    /* {{{ a path built from text */
    const char *built =
        "station where (" BOXES ":text_path)\n  in 0 = \"/settings\"\n  out 0 - full.0\n"
        "station full (" BOXES ":path_join)\n  in 0 - where.0\n  in 1 = \"handedness\"\n  out 0 - reader.0\n"
        "station reader (" BOXES ":read_path)\n  in 0 - full.0\n  out 0 - 0$\n";
    program = program_load_text("src/maps/built.map", built, strlen(built), &report);
    CHECK(program >= 0 && program_bring_up(program, &report) == 0, "a map that builds a path from text loads (%s)", report.text);
    twin_engine_settle(5000);
    memset(&read_back, 0, sizeof read_back);
    CHECK(program_result(program, 0, &read_back, sizeof read_back) == 1 && read_back.status == 0 && read_back.bytes[0] == 'r',
          "text-path and path-join make \"/settings\" and \"handedness\" into a path that reads the file");
    program_remove(program);
    const char *literal = "station r (" BOXES ":read_path)\n  in 0 = \"/SETTINGS/handedness\"\n  out 0 - 0$\n";
    program = program_load_text("src/maps/literal.map", literal, strlen(literal), &report);
    program_bring_up(program, &report);
    twin_engine_settle(5000);
    memset(&read_back, 0, sizeof read_back);
    CHECK(program_result(program, 0, &read_back, sizeof read_back) == 1 && read_back.status == 0 && read_back.bytes[0] == 'r',
          "a path written in a map as a quoted string works as well");
    program_remove(program);
    /* }}} */

    /* {{{ refusals */
    struct path unended;
    memset(unended.chars, 'a', sizeof unended.chars);
    struct file_bytes *out = malloc(sizeof *out);
    CHECK(call1("read_path", &unended, sizeof unended, out, sizeof *out) == 0 && last_error.kind == 1 &&
          last_error.detail == (uint64_t)-FAT_TOO_LONG,
          "a path with no end is refused, the detail naming why (kind %d, detail %llu)", last_error.kind, (unsigned long long)last_error.detail);
    CHECK(one_path("delete_path", "/") == 99 && last_error.kind == 1 && last_error.detail == (uint64_t)-FAT_BAD_NAME,
          "asking to delete the root is refused");
    char long_name[300] = "/drawings/";
    memset(long_name + 10, 'n', 200);
    CHECK(one_path("path_exists", long_name) == 0 && last_error.kind == 0,
          "a long but legal path that is not there is simply not there (kind %d)", last_error.kind);
    char deep[256] = "";
    for (int i = 0; i < 70; i++) strcat(deep, "/d");
    CHECK(one_path("path_exists", deep) == 99 && last_error.kind == 1 && last_error.detail == (uint64_t)-FAT_TOO_LONG,
          "a path deeper than any path may go is refused");
    struct path p = path_of("/x");
    struct file_bytes *huge = malloc(sizeof *huge);
    *huge = bytes_of("x", 1);
    huge->length = 5000;
    int64_t written = 99;
    CHECK(call2("write_path", &p, sizeof p, huge, sizeof *huge, &written, sizeof written) == 0 && last_error.kind == 1 &&
          one_path("path_exists", "/x") == 0,
          "a value claiming more bytes than it can hold is refused, and nothing is written");
    struct path almost;
    memset(&almost, 0, sizeof almost);
    memset(almost.chars, 'b', 250);
    char longer[64] = "a name of more than five letters";
    struct path joined;
    CHECK(call2("path_join", &almost, sizeof almost, longer, 64, &joined, sizeof joined) == 0 && last_error.kind == 1,
          "a join that would not fit in a path is refused");
    free(huge);
    /* }}} */

    /* {{{ no card */
    files_stop();
    CHECK(read_path("/settings/handedness") == FAT_NO_CARD && one_path("path_exists", "/settings/handedness") == 0 &&
          write_path("/settings/handedness", "l", 1) == FAT_NO_CARD,
          "with the card out, every box says so in its value");
    CHECK(files_start(OWNER_OUTSIDE) == FAT_OK && read_path("/settings/handedness") == 0 && read_back.bytes[0] == 'r',
          "and with it back, nothing was lost");
    /* }}} */

    free(out);
    files_stop();
    twin_engine_stop();
    snprintf(line, sizeof line, "%s/tmp/shared-memory/test-logs/083-files.fsck", dir);
    int checked = card_fsck(card, line);
    if (checked >= 0) CHECK(checked == 1, "the laptop's fsck.fat finds nothing wrong with the card");
    remove(card);
    free(image);
    CHECK_DONE("083 filesystem boxes");
}
