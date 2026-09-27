/*
 * 074-test-generator.c — issues 301, 302, 303 and 304.
 *
 * General description: the generator is fed box sources as text and must
 * find exactly the boxes, helpers, orderings and value types in them —
 * several declarations in one file, a struct returned by value, a sink, a
 * declaration spread over lines, a brace inside a string and inside a
 * comment. Each rule a box source keeps is broken once, and every break
 * is reported, all together, naming file and line. The command-line tool
 * is run over a directory holding a broken box source and must write
 * nothing, leaving the previous catalogue exactly as it was. Then the
 * real catalogue: a generated box answers the same as the arithmetic it
 * wraps; identically laid-out structs under different names wire together
 * and carry their bytes unchanged; same-width structs with the fields the
 * other way round wire together too — and arrive scrambled, on purpose.
 */
#define _GNU_SOURCE
#include "../../src/engine/060-generator.h"
#include "../../src/engine/068-programs.h"
#include "../../src/engine/070-catalogue.h"
#include "../../src/engine/038-tallies.h"
#include "catalogue-boxes.h"
#include "../041-twin-engine.h"
#include "047-check.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

/* {{{ host_grow */
static void *host_grow(void *ctx, void *old, size_t old_size, size_t size)
{
    (void)ctx; (void)old_size;
    return realloc(old, size);
}
/* }}} */

/* {{{ read_sources */
static int read_sources(const char *path, const char *text, struct gen_description *d, struct gen_text *errors)
{
    static struct gen_memory memory = { host_grow, NULL };
    struct gen_source s = { path, path, text, strlen(text) };
    memset(d, 0, sizeof *d);
    memset(errors, 0, sizeof *errors);
    return gen_read(&s, 1, &memory, d, errors);
}
/* }}} */

/* {{{ find_box */
static const struct gen_box *find_box(const struct gen_description *d, const char *name)
{
    for (int i = 0; i < d->n_boxes; i++) if (!strcmp(d->boxes[i].name, name)) return &d->boxes[i];
    return NULL;
}
/* }}} */

/* {{{ run */
static int run(const char *command)
{
    int status = system(command);
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}
/* }}} */

int main(void)
{
    /* --- reading ---------------------------------------------------------- */
    struct gen_description d;
    struct gen_text errors;
    const char *good =
        "#include <stdint.h>\n"
        "/* a comment with a brace { that must not count */\n"
        "struct colour { uint8_t r; uint8_t g; uint8_t b; char name[12]; };\n"
        "int colour__compare(struct colour a, struct colour b) { return a.r - b.r; }\n"
        "static int helper(int x) { return x * 2; }\n"
        "int64_t first(int64_t a) { return a; }\n"
        "struct colour\n"
        "  mix(struct colour a,\n"
        "      struct colour b)\n"
        "{ const char *s = \"a brace } in a string\"; (void)s; return a; }\n"
        "void sink(int32_t v) { (void)v; }\n"
        "uint8_t red(struct colour c) { return c.r; }\n";
    int problems = read_sources("src/boxes/test.c", good, &d, &errors);
    CHECK(problems == 0, "a well-formed source reads cleanly (%s)", errors.data ? errors.data : "");
    CHECK(d.n_boxes == 4, "four boxes found (%d)", d.n_boxes);
    CHECK(d.n_helpers == 1 && !strcmp(d.helpers[0].name, "helper"), "one helper, private to its file");
    CHECK(d.n_structs == 1 && !strcmp(d.structs[0].name, "colour") && d.structs[0].n_fields == 4,
          "one value type with four fields");
    CHECK(d.structs[0].compare && !strcmp(d.structs[0].compare, "colour__compare"), "and its ordering, found by name");
    const struct gen_box *mix = find_box(&d, "mix");
    CHECK(mix && mix->n_params == 2 && !strcmp(mix->returns, "struct colour") && mix->line == 8,
          "a declaration spread over three lines, returning a struct, read with its line");
    const struct gen_box *sink = find_box(&d, "sink");
    CHECK(sink && !strcmp(sink->returns, "void"), "a box returning nothing is a sink");

    const char *bad =
        "#include <stdint.h>\n"
        "char *name(int64_t v) { (void)v; return 0; }\n"       /* 2: returns a string */
        "int64_t *where(int64_t v) { (void)v; return 0; }\n"   /* 3: returns a pointer */
        "int64_t through(int64_t *p) { return *p; }\n"          /* 4: pointer parameter */
        "int64_t anonymous(int64_t) { return 0; }\n"            /* 5: unnamed */
        "int64_t nothing(void) { return 0; }\n"                 /* 6: no inputs */
        "int64_t real(double d) { return (int64_t)d; }\n"       /* 7: floating point */
        "int64_t mystery(struct unknown u) { (void)u; return 0; }\n"; /* 8: undefined type */
    problems = read_sources("src/boxes/bad.c", bad, &d, &errors);
    CHECK(problems == 7, "every broken rule is reported, all together (%d):\n%s", problems, errors.data);
    const char *expect[] = {
        "bad.c:2: box name: a box may not return a string",
        "bad.c:3: box where: a box may not return a pointer",
        "bad.c:4: box through: a value type is a struct, not a bare pointer",
        "bad.c:5: box anonymous: every parameter must be named",
        "bad.c:6: box nothing: a box with no inputs can never be made to run",
        "bad.c:7: box real: floating point cannot be carried",
        "bad.c:8: box mystery: parameter u has type struct unknown",
    };
    for (size_t i = 0; i < sizeof expect / sizeof expect[0]; i++) {
        CHECK(errors.data && strstr(errors.data, expect[i]), "the report says: %s", expect[i]);
    }

    /* --- the tool writes nothing when anything is wrong ------------------- */
    const char *dir = getenv("SOREN_DIR");
    char work[1024], cmd[8192], generator[1024];
    snprintf(work, sizeof work, "%s/tmp/shared-memory/generator-test", dir);
    snprintf(generator, sizeof generator, "%s/tmp/build/tools/generate", dir);
    snprintf(cmd, sizeof cmd, "rm -rf '%s' && mkdir -p '%s/boxes'", work, work);
    run(cmd);
    snprintf(cmd, sizeof cmd, "printf '#include <stdint.h>\\nint64_t twice(int64_t v) { return v * 2; }\\n' > '%s/boxes/1-ok.c'", work);
    run(cmd);
    snprintf(cmd, sizeof cmd, "'%s' --root '%s' --boxes '%s/boxes' --out '%s/catalogue.c' --header '%s/catalogue.h' 2>/dev/null",
             generator, dir, work, work, work);
    CHECK(run(cmd) == 0, "the tool writes a catalogue for a good directory");
    char before[1 << 16], after[1 << 16];
    snprintf(cmd, sizeof cmd, "%s/catalogue.c", work);
    FILE *f = fopen(cmd, "r");
    size_t nb = f ? fread(before, 1, sizeof before - 1, f) : 0;
    if (f) fclose(f);
    before[nb] = 0;
    CHECK(nb > 0 && strstr(before, "tmp/shared-memory/generator-test/boxes/1-ok.c:twice"), "keyed by the box's address");
    snprintf(cmd, sizeof cmd, "printf '#include <stdint.h>\\nint64_t broken(int64_t) { return 0; }\\n' > '%s/boxes/2-broken.c'", work);
    run(cmd);
    snprintf(cmd, sizeof cmd, "'%s' --root '%s' --boxes '%s/boxes' --out '%s/catalogue.c' --header '%s/catalogue.h' 2>/dev/null",
             generator, dir, work, work, work);
    CHECK(run(cmd) == 1, "a broken box source fails the generator");
    snprintf(cmd, sizeof cmd, "%s/catalogue.c", work);
    f = fopen(cmd, "r");
    size_t na = f ? fread(after, 1, sizeof after - 1, f) : 0;
    if (f) fclose(f);
    after[na] = 0;
    CHECK(na == nb && !memcmp(before, after, na), "and the previous catalogue is left exactly as it was");
    snprintf(cmd, sizeof cmd, "%s/catalogue.c.partial", work);
    struct stat st;
    CHECK(stat(cmd, &st) != 0, "with no half-written file left beside it");

    /* --- the real catalogue ----------------------------------------------- */
    twin_engine_start(2, (size_t)256 << 20);
    engine_open_gate();
    const struct box *add = catalogue_box("src/boxes/062-arithmetic.c:add");
    CHECK(add == &box__arithmetic__add, "the catalogue finds a box by its address");
    int64_t in[2] = { 40, 2 }, out = 0;
    add->call(in, &out);
    CHECK(out == 42, "and its generated adapter answers as the function does (%lld)", (long long)out);
    CHECK(add->params[1].offset == 8 && add->in_bytes == 16 && add->return_size == 8,
          "with every size and offset the compiler worked out");
    const struct catalogue_type *text = catalogue_type_named("struct text");
    CHECK(text && text->size == 64 && text->n_fields == 1 && text->order, "struct text has a field table and an ordering");

    struct map_report report;
    const char *widths =
        "s = ../boxes/073-shapes.c\n"
        "station maker (s:make_point)\n"
        "  in 0 = 7\n"
        "  out 0 - as_pair.0\n"
        "  out 0 - as_flipped.0\n"
        "station as_pair (s:pair_sum)\n"
        "  in 0 - maker.0\n"
        "  out 0 - pair_sink.0\n"
        "station as_flipped (s:flipped_x)\n"
        "  in 0 - maker.0\n"
        "  out 0 - flipped_sink.0\n"
        "station pair_sink (../boxes/062-arithmetic.c:discard)\n"
        "  in 0 - as_pair.0\n"
        "station flipped_sink (../boxes/062-arithmetic.c:discard)\n"
        "  in 0 - as_flipped.0\n";
    int prog = program_load_text("src/maps/widths-test.map", widths, strlen(widths), &report);
    CHECK(prog >= 0, "a point wires into a pair and into a flipped: same width, no adapter (%s)", report.text);
    twin_engine_settle(2000);
    uint64_t count;
    int64_t sum;
    tally_read(program_station(prog, "pair_sink"), &count, &sum);
    CHECK(count == 1 && sum == 7 * 1000 + 70, "the pair received the point's bytes unchanged (%lld)", (long long)sum);
    tally_read(program_station(prog, "flipped_sink"), &count, &sum);
    CHECK(count == 1 && sum == 70, "the flipped received them scrambled — its x is the point's y (%lld), by decision", (long long)sum);
    twin_engine_stop();
    CHECK_DONE("074 generator");
}
