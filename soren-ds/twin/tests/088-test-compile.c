/*
 * 088-test-compile.c — issue 409.
 *
 * General description: a box's C source handed to the running engine
 * becomes boxes a station can place. The text box source the image was
 * built from, compiled again under a card path, runs and delivers values
 * byte for byte as the image's own boxes do, through the same doors and
 * with its fixed values read by the same catalogue. A program placing it
 * is written back out naming the card path, and reads back in. Its source
 * is kept from the moment it exists and is found from a box's address.
 *
 * Then the two deliberate facts the issue pins: a box whose input is a
 * different width from what feeds it is refused, naming both types and
 * both widths, by the same check a built-in box gets; and two boxes whose
 * struct has one name and two layouts at one width are accepted, and the
 * fields arrive scrambled — the accepted cost of comparing by width.
 *
 * And what must leave nothing behind: a source the compiler refuses (its
 * own words come back, naming the file and line), one the generator
 * cannot read, one with no box, a path no address can name, an address
 * the image already holds. A late box sharing a function's name with the
 * image's runs its own code. Compiling a file again makes a newer unit
 * that answers the address from then on while the station placed on the
 * older one keeps running it. Four threads compiling at once all land.
 */
#define _GNU_SOURCE
#include "../../src/engine/031-engine-internal.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/087-compile.h"
#include "../026-platform-twin.h"
#include "../041-twin-engine.h"
#include "047-check.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct text {
    char chars[64];
};

static struct map_report report;

/* {{{ read_file */
static char *read_file(const char *path, size_t *length)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *text = malloc((size_t)n + 1);
    *length = fread(text, 1, (size_t)n, f);
    text[*length] = 0;
    fclose(f);
    return text;
}
/* }}} */

/* {{{ compile */
static struct compile_report words;

static int compile(const char *path, const char *source)
{
    return compile_box_source(path, source, strlen(source), &words);
}
/* }}} */

/* {{{ load */
static int load(const char *path, const char *text)
{
    int p = program_load_text(path, text, strlen(text), &report);
    if (p >= 0 && program_bring_up(p, &report) != 0) return -1;
    return p;
}
/* }}} */

/* {{{ one */
/* One value through a one-argument program and out of its result door. */
static int one(int program, const void *in, size_t in_size, void *out, size_t out_size)
{
    program_argument(program, 0, in, in_size);
    twin_engine_settle(2000);
    return program_result(program, 0, out, out_size);
}
/* }}} */

/* {{{ two */
static int two(int program, const void *a, const void *b, size_t in_size, void *out, size_t out_size)
{
    program_argument(program, 0, a, in_size);
    program_argument(program, 1, b, in_size);
    twin_engine_settle(2000);
    return program_result(program, 0, out, out_size);
}
/* }}} */

/* {{{ a_text */
/* A text whose bytes after its end are not zero, so "byte for byte"
 * covers the whole value and not only the characters before the zero. */
static struct text a_text(int i, int length)
{
    struct text t;
    memset(t.chars, 0x40 + (i % 50), sizeof t.chars);
    for (int k = 0; k < length && k < 63; k++) t.chars[k] = (char)('a' + (i * 7 + k * 3) % 26);
    t.chars[length < 63 ? length : 63] = 0;
    return t;
}
/* }}} */

/* {{{ compiler */
static void *compiler(void *arg)
{
    int n = (int)(intptr_t)arg;
    char path[64], source[256];
    snprintf(path, sizeof path, "/boxes/thread-%d.c", n);
    snprintf(source, sizeof source,
             "#include <stdint.h>\nint64_t plus_%d(int64_t v)\n{\n    return v + %d;\n}\n", n, n);
    struct compile_report r;
    return (void *)(intptr_t)compile_box_source(path, source, strlen(source), &r);
}
/* }}} */

int main(void)
{
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "SOREN_DIR is not set; run this through scripts/test-twin\n");
        return 2;
    }
    twin_engine_start(4, (size_t)256 << 20);
    engine_open_gate();

    /* {{{ the image's own text boxes, compiled again from the card */
    char path[600];
    snprintf(path, sizeof path, "%s/src/boxes/063-text.c", dir);
    size_t text_length_063 = 0;
    char *text_063 = read_file(path, &text_length_063);
    if (!text_063) text_063 = calloc(1, 1);
    CHECK(text_063 != NULL, "the text box source the image was built from is readable");
    int rows_before = catalogue_count();
    int unit = compile_box_source("/boxes/text.c", text_063, text_length_063, &words);
    CHECK(unit >= 0, "it compiles on the running engine as /boxes/text.c (%s)", words.text);
    const struct box *late = catalogue_box("/boxes/text.c:join");
    const struct box *image = catalogue_box("src/boxes/063-text.c:join");
    CHECK(late && image && late != image, "and /boxes/text.c:join is a box of its own beside the image's");
    int same_shape = late && image && late->n_params == image->n_params && late->in_bytes == image->in_bytes &&
                     late->return_size == image->return_size && strcmp(late->return_type, image->return_type) == 0;
    for (int p = 0; same_shape && p < late->n_params; p++) {
        same_shape = late->params[p].size == image->params[p].size && late->params[p].offset == image->params[p].offset;
    }
    CHECK(same_shape, "with every width the compiler worked out for the image's join");
    CHECK(late && late->return_order && late->return_order != image->return_order,
          "and an ordering of its own, from its own text__compare");
    CHECK(strcmp(late ? late->source : "", "/boxes/text.c") == 0, "its record names the file it came from");
    CHECK(catalogue_count() == rows_before + 5, "the unit added one row per box in the file, its ordering not one (%d)", catalogue_count() - rows_before);
    struct compile_unit_facts facts;
    CHECK(compile_unit_facts(unit, &facts) == 0 && facts.state == UNIT_LOADED && facts.boxes == 5 && facts.when_ns > 0,
          "the unit is recorded: loaded, five boxes, and when");

    const char *shout = "station s (%s:to_upper)\n  in 0 - 0$\n  out 0 - 0$\n";
    const char *joining = "station j (%s:join)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - 0$\n";
    const char *naming = "station n (%s:number_text)\n  in 0 - 0$\n  out 0 - 0$\n";
    char map[512];
    snprintf(map, sizeof map, shout, "../boxes/063-text.c");
    int shout_image = load("src/maps/shout-image.map", map);
    snprintf(map, sizeof map, shout, "/boxes/text.c");
    int shout_late = load("src/maps/shout-late.map", map);
    snprintf(map, sizeof map, joining, "../boxes/063-text.c");
    int join_image = load("src/maps/join-image.map", map);
    snprintf(map, sizeof map, joining, "/boxes/text.c");
    int join_late = load("src/maps/join-late.map", map);
    snprintf(map, sizeof map, naming, "../boxes/063-text.c");
    int name_image = load("src/maps/name-image.map", map);
    snprintf(map, sizeof map, naming, "/boxes/text.c");
    int name_late = load("src/maps/name-late.map", map);
    CHECK(shout_image >= 0 && shout_late >= 0 && join_image >= 0 && join_late >= 0 && name_image >= 0 && name_late >= 0,
          "a map places the late boxes by their card address, beside programs placing the image's (%s)", report.text);

    int differ = 0, ran = 0;
    for (int i = 0; i < 40; i++) {
        struct text a = a_text(i, i % 70), b = a_text(i + 13, (i * 5) % 70);
        struct text x, y;
        memset(&x, 0x11, sizeof x);
        memset(&y, 0x22, sizeof y);
        ran += one(shout_image, &a, sizeof a, &x, sizeof x) == 1 && one(shout_late, &a, sizeof a, &y, sizeof y) == 1;
        differ += memcmp(&x, &y, sizeof x) != 0;
        memset(&x, 0x11, sizeof x);
        memset(&y, 0x22, sizeof y);
        ran += two(join_image, &a, &b, sizeof a, &x, sizeof x) == 1 && two(join_late, &a, &b, sizeof a, &y, sizeof y) == 1;
        differ += memcmp(&x, &y, sizeof x) != 0;
        int64_t v = (int64_t)i * 1234567 - 9000000;
        memset(&x, 0x11, sizeof x);
        memset(&y, 0x22, sizeof y);
        ran += one(name_image, &v, sizeof v, &x, sizeof x) == 1 && one(name_late, &v, sizeof v, &y, sizeof y) == 1;
        differ += memcmp(&x, &y, sizeof x) != 0;
    }
    CHECK(ran == 120 && differ == 0, "120 values through the late boxes match the image's byte for byte (%d ran, %d differed)", ran, differ);

    int greeting = load("src/maps/late-greeting.map",
                        "station g (/boxes/text.c:constant_text)\n  in 0 = \"world\"\n  out 0 - u.0\n"
                        "station u (/boxes/text.c:to_upper)\n  in 0 - g.0\n  out 0 - 0$\n");
    struct text got;
    twin_engine_settle(2000);
    CHECK(greeting >= 0 && program_result(greeting, 0, &got, sizeof got) == 1 && strcmp(got.chars, "WORLD") == 0,
          "a fixed value written in a map reaches a late box (%s)", greeting >= 0 ? got.chars : report.text);

    char written[4096];
    int n = program_write(join_late, written, sizeof written);
    CHECK(n > 0 && strstr(written, "(/boxes/text.c:join)") != NULL, "written back out, the program names the card's file:\n%s", written);
    int again = program_load_text("src/maps/join-again.map", written, (size_t)n, &report);
    CHECK(again >= 0 && engine_station_box(program_station(again, "j")) == late,
          "and what was written reads back in, placing the same late box (%s)", report.text);

    size_t kept_length = 0;
    const char *kept = compile_source("/boxes/text.c:join", &kept_length);
    CHECK(kept && kept_length == text_length_063 && memcmp(kept, text_063, kept_length) == 0,
          "its source was kept as it arrived, and is found from a box's address");
    kept = compile_source("/boxes/text.c", &kept_length);
    CHECK(kept && kept_length == text_length_063, "or from the file's path");
    CHECK(compile_source("/boxes/nothing.c", &kept_length) == NULL, "and a file nothing came from has none");
    /* }}} */

    /* {{{ widths: refused by the same check, naming both types and widths */
    CHECK(compile("/boxes/wide.c",
                  "#include <stdint.h>\nstruct wide { int64_t a; int64_t b; };\n"
                  "int64_t first(struct wide w)\n{\n    return w.a;\n}\n") >= 0, "a box taking a 16-byte struct compiles (%s)", words.text);
    const char *wide_map = "station k (../boxes/062-arithmetic.c:constant)\n  in 0 = 5\n  out 0 - f.0\n"
                           "station f (/boxes/wide.c:first)\n  in 0 - k.0\n";
    int refused = program_load_text("src/maps/wide.map", wide_map, strlen(wide_map), &report);
    CHECK(refused < 0 && strstr(report.text, "returns int64_t (8 bytes), the port takes struct wide (16 bytes)"),
          "an 8-byte value wired into its 16-byte port is refused, naming both types and both widths:\n%s", report.text);
    const char *narrow_map = "station k (../boxes/063-text.c:constant_text)\n  in 0 = \"x\"\n  out 0 - f.0\n"
                             "station f (../boxes/062-arithmetic.c:pass)\n  in 0 - k.0\n";
    int built_in_refusal = program_load_text("src/maps/narrow.map", narrow_map, strlen(narrow_map), &report);
    CHECK(built_in_refusal < 0 && strstr(report.text, "returns struct text (64 bytes), the port takes int64_t (8 bytes)"),
          "which is the same refusal two of the image's boxes get");
    /* }}} */

    /* {{{ layouts: one name, two layouts, one width — accepted, scrambled */
    CHECK(compile("/boxes/pair-a.c",
                  "#include <stdint.h>\nstruct pair { int32_t first; int32_t second; };\n"
                  "struct pair make_pair(int64_t first, int64_t second)\n{\n"
                  "    struct pair p = { (int32_t)first, (int32_t)second };\n    return p;\n}\n") >= 0 &&
          compile("/boxes/pair-b.c",
                  "#include <stdint.h>\nstruct pair { int32_t second; int32_t first; };\n"
                  "int64_t first_of(struct pair p)\n{\n    return p.first;\n}\n") >= 0,
          "two files each defining struct pair, with its fields in opposite orders, both compile (%s)", words.text);
    int scrambled = load("src/maps/pair.map",
                         "station mk (/boxes/pair-a.c:make_pair)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - f.0\n"
                         "station f (/boxes/pair-b.c:first_of)\n  in 0 - mk.0\n  out 0 - 0$\n");
    int64_t first = 1, second = 2, out = 0;
    CHECK(scrambled >= 0, "a wire between them is accepted: both sides are 8 bytes (%s)", report.text);
    CHECK(scrambled >= 0 && two(scrambled, &first, &second, sizeof first, &out, sizeof out) == 1 && out == 2,
          "and the field called first arrives holding the second (%lld) — the accepted cost of comparing widths", (long long)out);
    /* }}} */

    /* {{{ what leaves nothing behind */
    int rows = catalogue_count(), units = compile_unit_count();
    int r = compile("/boxes/broken.c", "#include <stdint.h>\nint64_t broken(int64_t v)\n{\n    return v + ;\n}\n");
    CHECK(r == COMPILE_FAILED && strstr(words.text, "/boxes/broken.c:4") && strstr(words.text, "error"),
          "a source the compiler refuses comes back with the compiler's own words, naming the file and line:\n%s", words.text);
    r = compile("/boxes/pointer.c", "#include <stdint.h>\nint64_t peek(int64_t *p)\n{\n    return *p;\n}\n");
    CHECK(r == COMPILE_UNREADABLE && strstr(words.text, "/boxes/pointer.c:2"),
          "one the generator cannot read comes back with the generator's words:\n%s", words.text);
    r = compile("/boxes/quiet.c", "static int helper(int v)\n{\n    return v;\n}\n");
    CHECK(r == COMPILE_NO_BOXES, "one that defines no box is refused (%s)", words.text);
    CHECK(compile("/boxes/notes.txt", "int64_t f(int64_t v) { return v; }\n") == COMPILE_BAD_PATH &&
          compile("/boxes/a:b.c", "int64_t f(int64_t v) { return v; }\n") == COMPILE_BAD_PATH &&
          compile("", "int64_t f(int64_t v) { return v; }\n") == COMPILE_BAD_PATH,
          "a path no box address can name is refused");
    r = compile("src/boxes/062-arithmetic.c", "#include <stdint.h>\nint64_t add(int64_t a, int64_t b)\n{\n    return a - b;\n}\n");
    CHECK(r == COMPILE_TAKEN && strstr(words.text, "src/boxes/062-arithmetic.c:add"),
          "an address the image already holds is refused, naming it (%s)", words.text);
    CHECK(catalogue_count() == rows && compile_unit_count() == units && !catalogue_box("/boxes/broken.c:broken") &&
          !catalogue_box("/boxes/pointer.c:peek"), "and none of them added a row or a unit");
    /* }}} */

    /* {{{ a name the image also uses, and a file compiled again */
    CHECK(compile("/boxes/times.c", "#include <stdint.h>\nint64_t add(int64_t a, int64_t b)\n{\n    return a * b;\n}\n") >= 0,
          "a late box may share a function's name with one of the image's (%s)", words.text);
    int times = load("src/maps/times.map", "station t (/boxes/times.c:add)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - 0$\n");
    int plus = load("src/maps/plus.map", "station t (../boxes/062-arithmetic.c:add)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - 0$\n");
    int64_t six = 6, seven = 7, product = 0, sum = 0;
    CHECK(two(times, &six, &seven, sizeof six, &product, sizeof product) == 1 && product == 42 &&
          two(plus, &six, &seven, sizeof six, &sum, sizeof sum) == 1 && sum == 13,
          "and each runs its own code: the late add multiplies (%lld), the image's adds (%lld)", (long long)product, (long long)sum);

    const struct box *older = catalogue_box("/boxes/times.c:add");
    int newer_unit = compile("/boxes/times.c", "#include <stdint.h>\nint64_t add(int64_t a, int64_t b)\n{\n    return a * b + 1;\n}\n");
    const struct box *newer = catalogue_box("/boxes/times.c:add");
    CHECK(newer_unit > unit && newer && newer != older, "compiling the file again makes a newer unit, which answers the address");
    int times_again = load("src/maps/times-again.map", "station t (/boxes/times.c:add)\n  in 0 - 0$\n  in 1 - 1$\n  out 0 - 0$\n");
    int64_t old_answer = 0, new_answer = 0;
    CHECK(two(times, &six, &seven, sizeof six, &old_answer, sizeof old_answer) == 1 && old_answer == 42 &&
          two(times_again, &six, &seven, sizeof six, &new_answer, sizeof new_answer) == 1 && new_answer == 43,
          "a station placed on the older keeps running it (%lld); one placed now runs the newer (%lld)",
          (long long)old_answer, (long long)new_answer);
    kept = compile_source("/boxes/times.c:add", &kept_length);
    CHECK(kept && memmem(kept, kept_length, "a * b + 1", 9), "and the source kept for the file is the newer one");
    /* }}} */

    /* {{{ four at once */
    pthread_t threads[4];
    for (int i = 0; i < 4; i++) pthread_create(&threads[i], NULL, compiler, (void *)(intptr_t)i);
    int landed = 0;
    for (int i = 0; i < 4; i++) {
        void *answer;
        pthread_join(threads[i], &answer);
        char address[64];
        snprintf(address, sizeof address, "/boxes/thread-%d.c:plus_%d", i, i);
        landed += (intptr_t)answer >= 0 && catalogue_box(address) != NULL;
    }
    CHECK(landed == 4, "four threads compiling four files at once all land (%d)", landed);
    /* }}} */

    free(text_063);
    twin_engine_stop();
    CHECK_DONE("088 compile");
}
