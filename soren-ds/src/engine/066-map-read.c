/*
 * 066-map-read.c — the map reader (issue 305).
 *
 * General description: the text is taken a logical line at a time — a
 * physical line with its comment removed, extended by the following lines
 * while a brace is open. The first word of each logical line picks one of
 * a handful of readers (a table, not a chain of ifs). Everything read goes
 * into a description; everything malformed goes into the problem list with
 * its line number; nothing stops the read.
 */
#include "027-primitives.h"
#include "029-blocks.h"
#include "031-engine.h"
#include "066-map-read.h"

#define ARENA_CHUNK 16384

/* {{{ the arena */
struct arena_chunk {
    struct arena_chunk *next;
};

/* {{{ map_arena_begin */
void map_arena_begin(struct map_arena *a, int owner)
{
    a->owner = owner;
    a->chunks = (void *)0;
    a->next = (char *)0;
    a->left = 0;
}
/* }}} */

/* {{{ map_arena_take */
void *map_arena_take(struct map_arena *a, size_t bytes)
{
    bytes = round_up_pow2(bytes ? bytes : 1, 8);
    if (bytes > a->left) {
        size_t size = bytes + sizeof(struct arena_chunk) > ARENA_CHUNK ? bytes + sizeof(struct arena_chunk) : ARENA_CHUNK;
        struct arena_chunk *c = block_alloc(a->owner, size);
        if (!c) {
            return (void *)0;
        }
        c->next = a->chunks;
        a->chunks = c;
        a->next = (char *)(c + 1);
        a->left = size - sizeof(struct arena_chunk);
    }
    void *p = a->next;
    a->next += bytes;
    a->left -= bytes;
    bytes_zero(p, bytes);
    return p;
}
/* }}} */

/* {{{ map_arena_end */
void map_arena_end(struct map_arena *a)
{
    struct arena_chunk *c = a->chunks;
    while (c) {
        struct arena_chunk *next = c->next;
        block_free(a->owner, c);
        c = next;
    }
    a->chunks = (void *)0;
    a->left = 0;
}
/* }}} */
/* }}} */

/* {{{ map_problem */
void map_problem(struct map_problems *p, const char *path, int line, const char *fmt, ...)
{
    char message[600];
    char entry[800];
    va_list args;
    va_start(args, fmt);
    text_format_va(message, sizeof message, fmt, args);
    va_end(args);
    int n = text_format(entry, sizeof entry, "  %s line %3d  %s\n", path, line, message);
    if ((size_t)n >= sizeof entry) n = (int)sizeof entry - 1;
    if (p->length + (size_t)n + 1 > p->capacity) {
        size_t cap = p->capacity ? p->capacity * 2 : 2048;
        while (cap < p->length + (size_t)n + 1) cap *= 2;
        char *bigger = map_arena_take(p->arena, cap);
        if (!bigger) {
            return;
        }
        if (p->text) bytes_copy(bigger, p->text, p->length);
        p->text = bigger;
        p->capacity = cap;
    }
    bytes_copy(p->text + p->length, entry, (size_t)n);
    p->length += (size_t)n;
    p->text[p->length] = 0;
    p->count++;
}
/* }}} */

/* {{{ small text tools */
/* {{{ copy_name */
static void copy_name(char *dst, size_t size, const char *s, size_t n)
{
    if (n >= size) n = size - 1;
    bytes_copy(dst, s, n);
    dst[n] = 0;
}
/* }}} */

/* {{{ is_space */
static int is_space(char c)
{
    return c == ' ' || c == '\t' || c == '\r';
}
/* }}} */

/* {{{ is_digit */
static int is_digit(char c)
{
    return c >= '0' && c <= '9';
}
/* }}} */

/* {{{ skip_space */
static const char *skip_space(const char *s)
{
    while (is_space(*s)) s++;
    return s;
}
/* }}} */

/* {{{ read_word */
/* A run of non-space characters. Answers its length. */
static size_t read_word(const char *s)
{
    size_t n = 0;
    while (s[n] && !is_space(s[n])) n++;
    return n;
}
/* }}} */

/* {{{ read_int */
/* A non-negative decimal integer; answers characters consumed (0 if none). */
static size_t read_int(const char *s, int *out)
{
    size_t n = 0;
    int v = 0;
    while (is_digit(s[n]) && n < 9) {
        v = v * 10 + (s[n] - '0');
        n++;
    }
    *out = v;
    return n;
}
/* }}} */
/* }}} */

/* {{{ map_kind_word */
const char *map_kind_word(int kind)
{
    static const char *const words[KIND_COUNT] = {
        [KIND_PLAIN] = "station", [KIND_COMPARATOR] = "comparator", [KIND_ITERATOR] = "iterator",
        [KIND_RANDOM] = "random", [KIND_WEIGHTED] = "weighted", [KIND_SPREAD] = "spread",
    };
    return kind >= 0 && kind < KIND_COUNT ? words[kind] : "station";
}
/* }}} */

/* {{{ kind_of_word */
static int kind_of_word(const char *w, size_t n)
{
    for (int k = 0; k < KIND_COUNT; k++) {
        const char *word = map_kind_word(k);
        if (text_length(word) == n && bytes_equal(word, w, n)) {
            return k;
        }
    }
    return -1;
}
/* }}} */

/* {{{ the address resolver */
/* {{{ normalise */
/* Collapse "//", drop "./", and let ".." eat the segment before it. */
static void normalise(char *path)
{
    const char *seg_at[64];
    size_t seg_len[64];
    int count = 0;
    int absolute = path[0] == '/';
    const char *p = path;
    /* Split into segments, keeping a stack: "." is dropped, ".." pops the
     * segment before it (or is kept, at the front of a relative path). */
    while (*p) {
        while (*p == '/') p++;
        if (!*p) break;
        const char *seg = p;
        while (*p && *p != '/') p++;
        size_t len = (size_t)(p - seg);
        if (len == 1 && seg[0] == '.') continue;
        int is_up = len == 2 && seg[0] == '.' && seg[1] == '.';
        if (is_up && count > 0 && !(seg_len[count - 1] == 2 && seg_at[count - 1][0] == '.' && seg_at[count - 1][1] == '.')) {
            count--;
            continue;
        }
        if (is_up && absolute) continue;
        if (count < 64) {
            seg_at[count] = seg;
            seg_len[count] = len;
            count++;
        }
    }
    char out[MAP_ADDRESS];
    size_t n = 0;
    if (absolute) out[n++] = '/';
    for (int i = 0; i < count; i++) {
        if (i && n + 1 < sizeof out) out[n++] = '/';
        if (n + seg_len[i] < sizeof out) {
            bytes_copy(out + n, seg_at[i], seg_len[i]);
            n += seg_len[i];
        }
    }
    out[n] = 0;
    bytes_copy(path, out, n + 1);
}
/* }}} */

/* {{{ map_resolve */
void map_resolve(const struct map_description *d, const char *written, char *out, size_t size)
{
    char joined[MAP_ADDRESS * 2];
    char path[MAP_ADDRESS];
    char function[MAP_NAME] = "";
    /* Split "boxes/063-text.c:say" at its last colon. */
    size_t len = text_length(written);
    size_t colon = len;
    for (size_t i = 0; i < len; i++) if (written[i] == ':') colon = i;
    copy_name(path, sizeof path, written, colon);
    if (colon < len) copy_name(function, sizeof function, written + colon + 1, len - colon - 1);

    /* The first segment may be a shortcut's name. */
    size_t first = 0;
    while (path[first] && path[first] != '/') first++;
    const char *rest = path + first;
    const char *base = (const char *)0;
    for (int i = 0; i < d->n_shortcuts; i++) {
        if (text_length(d->shortcuts[i].name) == first && bytes_equal(d->shortcuts[i].name, path, first)) {
            base = d->shortcuts[i].path;
        }
    }
    if (base) {
        text_format(joined, sizeof joined, "%s%s%s", base, *rest ? "/" : "", *rest ? rest + 1 : "");
    } else {
        bytes_copy(joined, path, text_length(path) + 1);
    }
    /* Relative to the file the description sits in, unless absolute. */
    char full[MAP_ADDRESS * 3];
    if (joined[0] == '/') {
        bytes_copy(full, joined, text_length(joined) + 1);
    } else if (d->home[0]) {
        text_format(full, sizeof full, "%s/%s", d->home, joined);
    } else {
        bytes_copy(full, joined, text_length(joined) + 1);
    }
    full[MAP_ADDRESS - 1] = 0;
    normalise(full);
    if (function[0]) {
        text_format(out, size, "%s:%s", full, function);
    } else {
        text_format(out, size, "%s", full);
    }
}
/* }}} */
/* }}} */

/* {{{ map_station_named */
struct map_station *map_station_named(const struct map_description *d, const char *name)
{
    for (int i = 0; i < d->n_stations; i++) {
        if (text_equal(d->stations[i].name, name)) {
            return &d->stations[i];
        }
    }
    return (struct map_station *)0;
}
/* }}} */

/* The reader's state while walking one file. */
struct reading {
    const char             *path;
    struct map_arena       *arena;
    struct map_description *d;
    struct map_problems    *problems;
    struct map_station     *current;     /* the station line the port lines belong to */
    int                     seen_station;
    int                     station_capacity;
    int                     shortcut_capacity;
    int                     include_capacity;
    int                     line;
};

/* {{{ grow_array */
static void *grow_array(struct map_arena *a, void *old, int count, int *capacity, size_t size)
{
    if (count < *capacity) {
        return old;
    }
    int cap = *capacity ? *capacity * 2 : 16;
    void *bigger = map_arena_take(a, (size_t)cap * size);
    if (bigger && old) {
        bytes_copy(bigger, old, (size_t)count * size);
    }
    *capacity = cap;
    return bigger;
}
/* }}} */

/* {{{ valid_name */
/* A station or shortcut name: not empty, no ':' '/' '.' '$' or quote —
 * each of those means something else on a port line or in an address. */
static int valid_name(const char *s, size_t n)
{
    if (n == 0 || n >= MAP_NAME) return 0;
    for (size_t i = 0; i < n; i++) {
        char c = s[i];
        if (c == ':' || c == '/' || c == '.' || c == '$' || c == '"' || c == '(' || c == ')' || c == '=') return 0;
    }
    return 1;
}
/* }}} */

/* {{{ read_shortcut */
/* name = path */
static void read_shortcut(struct reading *r, const char *s, size_t name_len)
{
    if (r->seen_station) {
        map_problem(r->problems, r->path, r->line, "a shortcut must come before the first station");
        return;
    }
    if (!valid_name(s, name_len)) {
        map_problem(r->problems, r->path, r->line, "\"%s\" cannot be a shortcut's name — no ':', '/' or '.' in a name", s);
        return;
    }
    const char *eq = skip_space(s + name_len);
    const char *path = skip_space(eq + 1);
    size_t plen = read_word(path);
    if (plen == 0) {
        map_problem(r->problems, r->path, r->line, "a shortcut needs a path after '='");
        return;
    }
    for (int i = 0; i < r->d->n_shortcuts; i++) {
        if (text_length(r->d->shortcuts[i].name) == name_len && bytes_equal(r->d->shortcuts[i].name, s, name_len)) {
            map_problem(r->problems, r->path, r->line, "the shortcut %s is declared twice (first on line %d)",
                        r->d->shortcuts[i].name, r->d->shortcuts[i].line);
            return;
        }
    }
    r->d->shortcuts = grow_array(r->arena, r->d->shortcuts, r->d->n_shortcuts, &r->shortcut_capacity, sizeof(struct map_shortcut));
    struct map_shortcut *sc = &r->d->shortcuts[r->d->n_shortcuts++];
    copy_name(sc->name, sizeof sc->name, s, name_len);
    /* A trailing slash means nothing, the way it means nothing to a shell. */
    while (plen > 1 && path[plen - 1] == '/') plen--;
    copy_name(sc->path, sizeof sc->path, path, plen);
    sc->line = r->line;
}
/* }}} */

/* {{{ read_include */
static void read_include(struct reading *r, const char *rest)
{
    rest = skip_space(rest);
    size_t n = read_word(rest);
    if (n == 0) {
        map_problem(r->problems, r->path, r->line, "include needs a file or directory");
        return;
    }
    char written[MAP_ADDRESS];
    copy_name(written, sizeof written, rest, n);
    r->d->includes = grow_array(r->arena, r->d->includes, r->d->n_includes, &r->include_capacity, sizeof(struct map_include));
    struct map_include *inc = &r->d->includes[r->d->n_includes++];
    map_resolve(r->d, written, inc->path, sizeof inc->path);
    inc->line = r->line;
}
/* }}} */

/* {{{ read_station */
/* KIND name (address) */
static void read_station(struct reading *r, int kind, const char *rest)
{
    r->seen_station = 1;
    r->current = (struct map_station *)0;
    rest = skip_space(rest);
    size_t n = 0;
    while (rest[n] && !is_space(rest[n]) && rest[n] != '(') n++;
    if (!valid_name(rest, n)) {
        char shown[MAP_NAME];
        copy_name(shown, sizeof shown, rest, n);
        map_problem(r->problems, r->path, r->line, "\"%s\" cannot be a station's name — it must be one word with no ':', '/', '.' or '$'", shown);
        return;
    }
    char name[MAP_NAME];
    copy_name(name, sizeof name, rest, n);
    struct map_station *twin = map_station_named(r->d, name);
    if (twin) {
        map_problem(r->problems, r->path, r->line, "a second station named %s (the first is on line %d)", name, twin->line);
        return;
    }
    const char *open = skip_space(rest + n);
    const char *close = open;
    while (*close && *close != ')') close++;
    if (*open != '(' || *close != ')') {
        map_problem(r->problems, r->path, r->line, "%s needs its box in parentheses: %s %s (file.c:function)",
                    name, map_kind_word(kind), name);
        return;
    }
    const char *address = skip_space(open + 1);
    size_t alen = (size_t)(close - address);
    while (alen && is_space(address[alen - 1])) alen--;
    if (alen == 0) {
        map_problem(r->problems, r->path, r->line, "%s names no box between its parentheses", name);
        return;
    }
    r->d->stations = grow_array(r->arena, r->d->stations, r->d->n_stations, &r->station_capacity, sizeof(struct map_station));
    struct map_station *st = &r->d->stations[r->d->n_stations++];
    copy_name(st->name, sizeof st->name, name, text_length(name));
    st->kind = kind;
    copy_name(st->written, sizeof st->written, address, alen);
    map_resolve(r->d, st->written, st->address, sizeof st->address);
    /* Two kinds of address: file:function (a box) or a .map file (a
     * program placed inside this one, issue 309). */
    int has_colon = 0;
    for (size_t i = 0; i < alen; i++) if (address[i] == ':') has_colon = 1;
    size_t wl = text_length(st->written);
    st->is_program = !has_colon && wl > 4 && text_equal(st->written + wl - 4, ".map");
    if (!has_colon && !st->is_program) {
        map_problem(r->problems, r->path, r->line, "%s's box \"%s\" names no function — write file.c:function, or a .map file",
                    name, st->written);
    }
    st->line = r->line;
    r->current = st;
}
/* }}} */

/* {{{ add_port_line */
static struct map_port_line *add_port_line(struct reading *r)
{
    struct map_station *st = r->current;
    st->ports = grow_array(r->arena, st->ports, st->n_ports, &st->capacity, sizeof(struct map_port_line));
    struct map_port_line *pl = &st->ports[st->n_ports++];
    pl->line = r->line;
    return pl;
}
/* }}} */

/* {{{ read_end */
/* After "-": empty (no source), "K$" (a door), or "station.number". */
static int read_end(struct reading *r, const char *s, struct map_port_line *pl, int is_in)
{
    s = skip_space(s);
    if (!*s) {
        if (!is_in) {
            map_problem(r->problems, r->path, r->line, "an out line needs somewhere to go: out N - station.port, or out N - K$");
            return 0;
        }
        pl->kind = MAP_IN_NONE;
        return 1;
    }
    int k;
    size_t n = read_int(s, &k);
    if (n && s[n] == '$') {
        pl->kind = is_in ? MAP_IN_DOOR : MAP_OUT_DOOR;
        pl->door = k;
        if (*skip_space(s + n + 1)) {
            map_problem(r->problems, r->path, r->line, "something follows %d$ on this line", k);
        }
        return 1;
    }
    size_t w = 0;
    while (s[w] && !is_space(s[w]) && s[w] != '.') w++;
    if (s[w] != '.' || !valid_name(s, w)) {
        map_problem(r->problems, r->path, r->line, "expected station.number or N$ after '-'");
        return 0;
    }
    copy_name(pl->other, sizeof pl->other, s, w);
    size_t m = read_int(s + w + 1, &pl->other_number);
    if (!m || *skip_space(s + w + 1 + m)) {
        map_problem(r->problems, r->path, r->line, "expected a number after \"%s.\"", pl->other);
        return 0;
    }
    pl->kind = is_in ? MAP_IN_WIRE : MAP_OUT_WIRE;
    return 1;
}
/* }}} */

/* {{{ read_port */
/* in N ... / out N ... */
static void read_port(struct reading *r, int is_in, const char *rest)
{
    if (!r->current) {
        map_problem(r->problems, r->path, r->line, "an %s line with no station line above it", is_in ? "in" : "out");
        return;
    }
    rest = skip_space(rest);
    int number;
    size_t n = read_int(rest, &number);
    if (!n) {
        map_problem(r->problems, r->path, r->line, "%s needs a port number", is_in ? "in" : "out");
        return;
    }
    const char *s = skip_space(rest + n);
    struct map_port_line pl;
    bytes_zero(&pl, sizeof pl);
    pl.number = number;
    pl.line = r->line;
    /* Three things can follow the number: "-" (a source or a
     * destination), "=" (a fixed value — in only), or "xN" (a starting
     * depth — in only). */
    if (*s == '-') {
        if (!read_end(r, s + 1, &pl, is_in)) return;
    } else if (*s == '=' && is_in) {
        const char *v = skip_space(s + 1);
        size_t vl = text_length(v);
        while (vl && is_space(v[vl - 1])) vl--;
        if (!vl) {
            map_problem(r->problems, r->path, r->line, "in %d = needs a value", number);
            return;
        }
        pl.kind = MAP_IN_VALUE;
        pl.value = map_arena_take(r->arena, vl + 1);
        bytes_copy(pl.value, v, vl);
        pl.value[vl] = 0;
    } else if (*s == 'x' && is_in) {
        size_t m = read_int(s + 1, &pl.depth);
        if (!m || pl.depth <= 0) {
            map_problem(r->problems, r->path, r->line, "in %d x needs a starting depth, like x64", number);
            return;
        }
        pl.kind = MAP_IN_DEPTH;
    } else {
        map_problem(r->problems, r->path, r->line, "%s %d must be followed by %s", is_in ? "in" : "out", number,
                    is_in ? "'-', '=' or 'x'" : "'-'");
        return;
    }
    struct map_port_line *slot = add_port_line(r);
    int line = slot->line;
    *slot = pl;
    slot->line = line;
}
/* }}} */

/* {{{ read_logical_line */
/* Dispatch on the first word: a table of keywords, then the two shapes
 * that are not keywords (a shortcut's "name =", and a mistake). */
static void read_logical_line(struct reading *r, const char *s)
{
    s = skip_space(s);
    if (!*s) {
        return;
    }
    size_t n = read_word(s);
    const char *rest = s + n;
    if (n == 2 && bytes_equal(s, "in", 2)) { read_port(r, 1, rest); return; }
    if (n == 3 && bytes_equal(s, "out", 3)) { read_port(r, 0, rest); return; }
    if (n == 7 && bytes_equal(s, "include", 7)) { read_include(r, rest); return; }
    int kind = kind_of_word(s, n);
    if (kind >= 0) {
        read_station(r, kind, rest);
        return;
    }
    const char *after = skip_space(rest);
    size_t name_len = n;
    for (size_t i = 0; i < n; i++) if (s[i] == '=') { name_len = i; after = s + i; break; }
    if (*after == '=') {
        read_shortcut(r, s, name_len);
        return;
    }
    char word[MAP_NAME];
    copy_name(word, sizeof word, s, n);
    map_problem(r->problems, r->path, r->line, "a line starting \"%s\" is not something a map says "
                "(station, comparator, iterator, random, weighted, spread, in, out, include, or name = path)", word);
}
/* }}} */

/* {{{ home_of */
/* The directory part of a path: "src/maps/greeting.map" → "src/maps". */
static void home_of(const char *path, char *out, size_t size)
{
    size_t n = text_length(path);
    while (n && path[n - 1] != '/') n--;
    if (n) n--;
    copy_name(out, size, path, n);
}
/* }}} */

/* {{{ map_read */
int map_read(const char *path, const char *text, size_t length, struct map_arena *arena,
             struct map_description *out, struct map_problems *problems)
{
    int before = problems->count;
    bytes_zero(out, sizeof *out);
    copy_name(out->path, sizeof out->path, path, text_length(path));
    home_of(path, out->home, sizeof out->home);
    struct reading r;
    bytes_zero(&r, sizeof r);
    r.path = path;
    r.arena = arena;
    r.d = out;
    r.problems = problems;

    char logical[MAP_LINE];
    size_t used = 0;
    int depth = 0;           /* braces open across lines */
    int opened_on = 0;
    int line = 1;
    size_t i = 0;
    while (i <= length) {
        /* Take one physical line. */
        size_t start = i;
        while (i < length && text[i] != '\n') i++;
        size_t end = i;
        int too_long = 0;
        /* Strip its comment, counting braces and tracking quotes in one
         * pass, so the two cannot disagree about where a string begins. */
        int in_quote = 0;
        const char *p = text + start;
        size_t k = start;
        if (depth > 0) {
            while (k < end && is_space(text[k])) k++;      /* a continuation drops its indent */
            if (used + 1 < sizeof logical) logical[used++] = ' ';
        }
        for (; k < end; k++) {
            char c = text[k];
            if (c == '"' && (k == start || text[k - 1] != '\\')) in_quote = !in_quote;
            if (!in_quote && c == '#') break;
            if (!in_quote && c == '{') { if (depth == 0) opened_on = line; depth++; }
            if (!in_quote && c == '}') depth--;
            if (used + 1 >= sizeof logical) { too_long = 1; break; }
            logical[used++] = c;
        }
        (void)p;
        if (too_long) {
            map_problem(problems, path, line, "a line longer than %d characters cannot be read; nothing was split", MAP_LINE - 1);
            used = 0;
            depth = 0;
        } else if (depth <= 0) {
            logical[used] = 0;
            r.line = depth < 0 ? line : (opened_on && used ? opened_on : line);
            if (depth < 0) {
                map_problem(problems, path, line, "a '}' with no '{' before it");
            } else {
                r.line = opened_on ? opened_on : line;
                read_logical_line(&r, logical);
            }
            used = 0;
            depth = 0;
            opened_on = 0;
        }
        line++;
        i++;
    }
    if (depth > 0) {
        map_problem(problems, path, opened_on, "the file ends with a '{' from this line still open");
    }
    return problems->count - before;
}
/* }}} */
