/*
 * 061-generate.c — the box generator as a laptop tool (issue 304).
 *
 * General description: lists every .c file directly in the box source
 * directory (and every .map file directly in the map directory), reads
 * them, and hands their text to the portable generator
 * (src/engine/060-generator.c). If the generator reports problems, they
 * are all printed and nothing is written — the previous catalogue stays
 * in place and still builds. Otherwise the output is written to a scratch
 * name beside its destination and moved over the old one in a single
 * rename, so nothing can ever compile against a half-written catalogue.
 *
 * This is a build tool and is built by itself, before anything it writes
 * exists, from only this file and the generator.
 *
 * Usage:
 *   061-generate --root DIR --boxes DIR --out FILE --header FILE [--describe]
 *   061-generate --root DIR --maps DIR --out FILE
 *
 * --root is the project directory; addresses are written relative to it
 * ("src/boxes/062-arithmetic.c:add").
 */
#define _GNU_SOURCE
#include "../../src/engine/060-generator.h"

#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* {{{ host_grow */
static void *host_grow(void *ctx, void *old, size_t old_size, size_t size)
{
    (void)ctx;
    (void)old_size;
    void *p = realloc(old, size);
    if (!p) {
        fprintf(stderr, "generate: out of memory\n");
        exit(2);
    }
    return p;
}
/* }}} */

/* {{{ read_whole */
static char *read_whole(const char *path, size_t *length)
{
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "generate: cannot read %s: %s\n", path, strerror(errno));
        exit(2);
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *text = malloc((size_t)n + 1);
    if (fread(text, 1, (size_t)n, f) != (size_t)n) {
        fprintf(stderr, "generate: short read on %s\n", path);
        exit(2);
    }
    text[n] = 0;
    fclose(f);
    *length = (size_t)n;
    return text;
}
/* }}} */

/* {{{ by_name */
static int by_name(const void *a, const void *b)
{
    return strcmp(*(char *const *)a, *(char *const *)b);
}
/* }}} */

/* {{{ list_sources */
/* Every file directly in `dir` ending in `suffix`, sorted — never a tree,
 * so one line's meaning does not depend on a directory listing somebody
 * else controls. */
static int list_sources(const char *root, const char *dir, const char *suffix, struct gen_source **out)
{
    DIR *d = opendir(dir);
    if (!d) {
        fprintf(stderr, "generate: cannot list %s: %s\n", dir, strerror(errno));
        exit(2);
    }
    char *names[1024];
    int n = 0;
    struct dirent *e;
    while ((e = readdir(d)) && n < 1024) {
        size_t len = strlen(e->d_name), sl = strlen(suffix);
        if (len > sl && strcmp(e->d_name + len - sl, suffix) == 0) {
            names[n++] = strdup(e->d_name);
        }
    }
    closedir(d);
    qsort(names, (size_t)n, sizeof names[0], by_name);

    /* The directory's address relative to the project. Two ways to be
     * inside it: as written (a path through the project's tmp/ link stays
     * a project path even though the link points elsewhere), or once both
     * are resolved. */
    char real_root[PATH_MAX], real_dir[PATH_MAX];
    const char *relative_dir = NULL;
    size_t given_len = strlen(root);
    while (given_len > 1 && root[given_len - 1] == '/') given_len--;
    if (strncmp(dir, root, given_len) == 0 && (dir[given_len] == '/' || dir[given_len] == 0)) {
        relative_dir = dir + given_len + (dir[given_len] == '/');
        snprintf(real_dir, sizeof real_dir, "%s", dir);
    } else {
        if (!realpath(root, real_root) || !realpath(dir, real_dir)) {
            fprintf(stderr, "generate: cannot resolve %s or %s\n", root, dir);
            exit(2);
        }
        size_t root_len = strlen(real_root);
        if (strncmp(real_dir, real_root, root_len) != 0) {
            fprintf(stderr, "generate: %s is not inside the project %s\n", dir, root);
            exit(2);
        }
        relative_dir = real_dir + root_len + (real_dir[root_len] == '/');
    }

    struct gen_source *sources = calloc((size_t)(n ? n : 1), sizeof *sources);
    for (int i = 0; i < n; i++) {
        char *absolute = malloc(2 * PATH_MAX);
        char *relative = malloc(2 * PATH_MAX);
        snprintf(absolute, 2 * PATH_MAX, "%s/%s", real_dir, names[i]);
        snprintf(relative, 2 * PATH_MAX, "%s/%s", relative_dir, names[i]);
        sources[i].path = relative;
        sources[i].include_path = absolute;
        sources[i].text = read_whole(absolute, &sources[i].length);
    }
    *out = sources;
    return n;
}
/* }}} */

/* {{{ write_into_place */
/* Write to "<path>.partial" then rename over `path`: the old file is
 * replaced whole or not at all. */
static void write_into_place(const char *path, const struct gen_text *text)
{
    char scratch[PATH_MAX + 16];
    snprintf(scratch, sizeof scratch, "%s.partial", path);
    FILE *f = fopen(scratch, "wb");
    if (!f || fwrite(text->data, 1, text->length, f) != text->length || fclose(f) != 0) {
        fprintf(stderr, "generate: cannot write %s\n", scratch);
        exit(2);
    }
    if (rename(scratch, path) != 0) {
        fprintf(stderr, "generate: cannot move %s into place: %s\n", scratch, strerror(errno));
        exit(2);
    }
}
/* }}} */

int main(int argc, char **argv)
{
    const char *root = NULL, *boxes = NULL, *maps = NULL, *out = NULL, *header = NULL;
    int describe = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--root") && i + 1 < argc) root = argv[++i];
        else if (!strcmp(argv[i], "--boxes") && i + 1 < argc) boxes = argv[++i];
        else if (!strcmp(argv[i], "--maps") && i + 1 < argc) maps = argv[++i];
        else if (!strcmp(argv[i], "--out") && i + 1 < argc) out = argv[++i];
        else if (!strcmp(argv[i], "--header") && i + 1 < argc) header = argv[++i];
        else if (!strcmp(argv[i], "--describe")) describe = 1;
        else {
            fprintf(stderr, "usage: %s --root DIR (--boxes DIR [--describe] | --maps DIR) --out FILE [--header FILE]\n", argv[0]);
            return 2;
        }
    }
    if (!root || (!boxes && !maps) || (!out && !describe)) {
        fprintf(stderr, "generate: --root, and --boxes or --maps, and --out are required\n");
        return 2;
    }
    struct gen_memory memory = { host_grow, NULL };
    struct gen_text text = { 0 };

    /* Two jobs: maps (embed them as strings) or boxes (read, check, emit). */
    if (maps) {
        struct gen_source *sources;
        int n = list_sources(root, maps, ".map", &sources);
        gen_emit_maps(sources, n, &memory, &text);
        write_into_place(out, &text);
        return 0;
    }
    struct gen_source *sources;
    int n = list_sources(root, boxes, ".c", &sources);
    struct gen_description d = { 0 };
    struct gen_text errors = { 0 };
    int problems = gen_read(sources, n, &memory, &d, &errors);
    if (describe) {
        struct gen_text seen = { 0 };
        gen_describe(sources, &d, &memory, &seen);
        fputs(seen.data ? seen.data : "(nothing)\n", stdout);
    }
    if (problems) {
        fprintf(stderr, "%d problem%s in the box sources; nothing was written, and the last good catalogue is still in place:\n%s",
                problems, problems == 1 ? "" : "s", errors.data);
        return 1;
    }
    if (describe && !out) {
        return 0;
    }
    gen_emit(sources, n, &d, &memory, &text);
    write_into_place(out, &text);
    if (header) {
        struct gen_text h = { 0 };
        gen_emit_header(sources, &d, &memory, &h);
        write_into_place(header, &h);
    }
    return 0;
}
