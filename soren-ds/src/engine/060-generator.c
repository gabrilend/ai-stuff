/*
 * 060-generator.c — the box generator (issues 301–304).
 *
 * General description: three stages. Blanking copies each source with
 * every comment, string and character literal's contents, and
 * preprocessor line replaced by spaces — keeping every newline, so line
 * numbers survive and a brace inside a string cannot mislead anything.
 * Reading walks the blanked text at the outermost level, where only
 * three things matter: a function definition (a box, or a helper if it
 * is private to its file, or an ordering if its name ends in __compare),
 * a struct definition (a value type), and everything else (skipped).
 * Emitting writes C that the compiler will check.
 *
 * It does not understand C and does not need to. It fails rather than
 * guesses: anything it cannot read is a named error, and every error is
 * collected before any is reported.
 *
 * Self-contained on purpose: no standard library and nothing from the
 * rest of the engine, so the same file builds as a laptop tool and, later,
 * runs on the device.
 */
#include "060-generator.h"

#define MAX_TOKENS 64
#define MAX_TOKEN 96

/* {{{ small string tools */
/* {{{ g_len */
static size_t g_len(const char *s)
{
    size_t n = 0;
    while (s[n]) n++;
    return n;
}
/* }}} */

/* {{{ g_eq */
static int g_eq(const char *a, const char *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}
/* }}} */

/* {{{ g_ends_with */
static int g_ends_with(const char *s, const char *tail)
{
    size_t a = g_len(s), b = g_len(tail);
    return a >= b && g_eq(s + a - b, tail);
}
/* }}} */

/* {{{ g_starts_with */
static int g_starts_with(const char *s, const char *head)
{
    while (*head) {
        if (*s++ != *head++) return 0;
    }
    return 1;
}
/* }}} */

/* {{{ g_copy */
static void g_copy(void *dst, const void *src, size_t n)
{
    char *d = dst;
    const char *s = src;
    while (n--) *d++ = *s++;
}
/* }}} */

/* {{{ g_alloc */
static void *g_alloc(struct gen_memory *m, size_t size)
{
    char *p = m->grow(m->ctx, (void *)0, 0, size ? size : 1);
    for (size_t i = 0; i < size; i++) p[i] = 0;
    return p;
}
/* }}} */

/* {{{ g_dup */
static char *g_dup(struct gen_memory *m, const char *s, size_t n)
{
    char *p = g_alloc(m, n + 1);
    g_copy(p, s, n);
    p[n] = 0;
    return p;
}
/* }}} */

/* {{{ gen_append */
void gen_append(struct gen_memory *m, struct gen_text *t, const char *s)
{
    size_t n = g_len(s);
    if (t->length + n + 1 > t->capacity) {
        size_t cap = t->capacity ? t->capacity : 256;
        while (cap < t->length + n + 1) cap *= 2;
        t->data = m->grow(m->ctx, t->data, t->capacity, cap);
        t->capacity = cap;
    }
    g_copy(t->data + t->length, s, n);
    t->length += n;
    t->data[t->length] = 0;
}
/* }}} */

/* {{{ append_int */
static void append_int(struct gen_memory *m, struct gen_text *t, long v)
{
    char buf[24];
    int n = 0;
    int neg = v < 0;
    unsigned long u = neg ? (unsigned long)(-(v + 1)) + 1 : (unsigned long)v;
    do { buf[n++] = (char)('0' + u % 10); u /= 10; } while (u);
    char out[26];
    int k = 0;
    if (neg) out[k++] = '-';
    while (n) out[k++] = buf[--n];
    out[k] = 0;
    gen_append(m, t, out);
}
/* }}} */

/* {{{ append_error */
static void append_error(struct gen_memory *m, struct gen_text *errors, const char *path, int line,
                         const char *a, const char *b, const char *c)
{
    gen_append(m, errors, path);
    gen_append(m, errors, ":");
    append_int(m, errors, line);
    gen_append(m, errors, ": ");
    gen_append(m, errors, a);
    if (b) gen_append(m, errors, b);
    if (c) gen_append(m, errors, c);
    gen_append(m, errors, "\n");
}
/* }}} */
/* }}} */

/* {{{ blank */
/* The copy the reader walks: comments, literal contents and preprocessor
 * lines become spaces; newlines stay. */
static char *blank(struct gen_memory *m, const char *s, size_t n)
{
    char *b = g_alloc(m, n + 1);
    size_t i = 0;
    int line_start = 1;
    while (i < n) {
        char c = s[i];
        /* Five situations, each consuming a stretch of text: a line
         * comment, a block comment, a string or character literal, a
         * preprocessor line (with its continuations), or ordinary text. */
        if (c == '/' && i + 1 < n && s[i + 1] == '/') {
            while (i < n && s[i] != '\n') b[i++] = ' ';
            continue;
        }
        if (c == '/' && i + 1 < n && s[i + 1] == '*') {
            b[i] = ' '; b[i + 1] = ' ';
            i += 2;
            while (i < n && !(s[i] == '*' && i + 1 < n && s[i + 1] == '/')) {
                b[i] = s[i] == '\n' ? '\n' : ' ';
                i++;
            }
            if (i < n) { b[i] = ' '; b[i + 1] = ' '; i += 2; }
            continue;
        }
        if (c == '"' || c == '\'') {
            b[i++] = c;
            while (i < n && s[i] != c && s[i] != '\n') {
                if (s[i] == '\\' && i + 1 < n) { b[i++] = ' '; }
                b[i++] = ' ';
            }
            if (i < n) { b[i] = s[i]; i++; }
            continue;
        }
        if (line_start && c == '#') {
            while (i < n && s[i] != '\n') {
                if (s[i] == '\\' && i + 1 < n && s[i + 1] == '\n') { b[i++] = ' '; b[i++] = '\n'; continue; }
                b[i++] = ' ';
            }
            continue;
        }
        if (c == '\n') line_start = 1;
        else if (c != ' ' && c != '\t' && c != '\r') line_start = 0;
        b[i] = c;
        i++;
    }
    b[n] = 0;
    return b;
}
/* }}} */

/* {{{ tokens */
struct tokens {
    char text[MAX_TOKENS][MAX_TOKEN];
    int  n;
};

/* {{{ is_ident */
static int is_ident_start(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }
static int is_ident_char(char c) { return is_ident_start(c) || (c >= '0' && c <= '9'); }
/* }}} */

/* {{{ tokenize */
/* Split a stretch of blanked text into identifiers, numbers and single
 * punctuation characters. Answers 0 if there were too many. */
static int tokenize(const char *s, size_t n, struct tokens *t)
{
    t->n = 0;
    size_t i = 0;
    while (i < n) {
        char c = s[i];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { i++; continue; }
        if (t->n >= MAX_TOKENS) return 0;
        size_t start = i;
        if (is_ident_char(c)) {
            while (i < n && is_ident_char(s[i])) i++;
        } else {
            i++;
        }
        size_t len = i - start < MAX_TOKEN - 1 ? i - start : MAX_TOKEN - 1;
        g_copy(t->text[t->n], s + start, len);
        t->text[t->n][len] = 0;
        t->n++;
    }
    return 1;
}
/* }}} */

/* {{{ join_tokens */
/* Tokens [from, to) as C text with single spaces, `*` attached. */
static char *join_tokens(struct gen_memory *m, const struct tokens *t, int from, int to)
{
    char buf[512];
    size_t k = 0;
    for (int i = from; i < to; i++) {
        size_t n = g_len(t->text[i]);
        if (k && t->text[i][0] != '*' && t->text[i][0] != '[' && t->text[i][0] != ']' &&
            buf[k - 1] != '[' && k + 1 < sizeof buf) {
            buf[k++] = ' ';
        } else if (k && t->text[i][0] == '*' && buf[k - 1] != '*' && k + 1 < sizeof buf) {
            buf[k++] = ' ';
        }
        if (k + n >= sizeof buf) break;
        g_copy(buf + k, t->text[i], n);
        k += n;
    }
    return g_dup(m, buf, k);
}
/* }}} */
/* }}} */

/* {{{ type facts */
/* {{{ integer_kind */
/* Answers GEN_FIELD_SIGNED or GEN_FIELD_UNSIGNED for an integer type
 * spelled as C spells it, or -1 for anything else. */
static int integer_kind(const char *type)
{
    static const char *const signed_names[] = {
        "int", "long", "short", "char", "signed char", "long long", "long int", "short int",
        "signed", "signed int", "int8_t", "int16_t", "int32_t", "int64_t", "intptr_t", "ptrdiff_t", 0
    };
    static const char *const unsigned_names[] = {
        "unsigned", "unsigned int", "unsigned long", "unsigned short", "unsigned char",
        "unsigned long long", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "uintptr_t",
        "size_t", "_Bool", "bool", 0
    };
    const char *t = type;
    if (g_starts_with(t, "const ")) t += 6;
    for (int i = 0; signed_names[i]; i++) if (g_eq(t, signed_names[i])) return GEN_FIELD_SIGNED;
    for (int i = 0; unsigned_names[i]; i++) if (g_eq(t, unsigned_names[i])) return GEN_FIELD_UNSIGNED;
    return -1;
}
/* }}} */

/* {{{ is_type_word */
/* A word that can only be part of a type, never a parameter's name. */
static int is_type_word(const char *w)
{
    static const char *const words[] = {
        "int", "long", "short", "char", "signed", "unsigned", "const", "volatile", "struct",
        "enum", "union", "void", "float", "double", "_Bool", "bool", 0
    };
    for (int i = 0; words[i]; i++) if (g_eq(w, words[i])) return 1;
    return g_ends_with(w, "_t");
}
/* }}} */

/* {{{ strip_const */
static const char *strip_const(const char *type)
{
    return g_starts_with(type, "const ") ? type + 6 : type;
}
/* }}} */
/* }}} */

/* {{{ growable arrays */
/* {{{ push */
/* Append one element of `size` bytes to an array held as (items, count),
 * growing it by doubling. */
static void *push(struct gen_memory *m, void **items, int *count, size_t size)
{
    int n = *count;
    int cap = 4;
    while (cap < n) cap *= 2;
    if (n == 0 || n == cap) {
        int new_cap = n == 0 ? 4 : cap * 2;
        *items = m->grow(m->ctx, *items, (size_t)cap * size * (n ? 1 : 0), (size_t)new_cap * size);
    }
    char *slot = (char *)*items + (size_t)n * size;
    for (size_t i = 0; i < size; i++) slot[i] = 0;
    *count = n + 1;
    return slot;
}
/* }}} */
/* }}} */

/* {{{ line_of */
static int line_of(const char *text, size_t pos)
{
    int line = 1;
    for (size_t i = 0; i < pos; i++) if (text[i] == '\n') line++;
    return line;
}
/* }}} */

/* {{{ matching_brace */
/* Position just past the brace that closes the one at `open`, or `n`. */
static size_t matching_brace(const char *b, size_t n, size_t open)
{
    int depth = 0;
    for (size_t i = open; i < n; i++) {
        if (b[i] == '{') depth++;
        else if (b[i] == '}') {
            depth--;
            if (depth == 0) return i + 1;
        }
    }
    return n;
}
/* }}} */

/* {{{ read_struct */
static void read_struct(struct gen_memory *m, const struct gen_source *src, int source_index,
                        const char *b, size_t open, size_t close, const char *name, int line,
                        struct gen_description *d, struct gen_text *errors)
{
    struct gen_struct *st = push(m, (void **)&d->structs, &d->n_structs, sizeof *st);
    st->name = g_dup(m, name, g_len(name));
    st->source = source_index;
    st->line = line;
    /* Fields are the ';'-separated declarations inside the braces. */
    size_t i = open + 1;
    size_t start = i;
    for (; i < close - 1; i++) {
        if (b[i] == '{') {
            append_error(m, errors, src->path, line_of(b, i), "struct ", name,
                         ": a value type may not define another inside itself; define it separately");
            d->n_errors++;
            return;
        }
        if (b[i] != ';') continue;
        struct tokens t;
        if (!tokenize(b + start, i - start, &t) || t.n < 2) {
            append_error(m, errors, src->path, line_of(b, start), "struct ", name, ": a field could not be read");
            d->n_errors++;
            start = i + 1;
            continue;
        }
        /* The type is every token up to the first name; a line may name
         * several fields sharing it ("int a, b;"). */
        int type_end = 0;
        while (type_end < t.n && (is_type_word(t.text[type_end]) ||
               (type_end > 0 && g_eq(t.text[type_end - 1], "struct")))) {
            type_end++;
        }
        if (type_end == 0 && t.n >= 2) type_end = 1;           /* a typedef'd name the list does not know */
        char *type = join_tokens(m, &t, 0, type_end);
        int k = type_end;
        while (k < t.n) {
            if (g_eq(t.text[k], "*")) {
                append_error(m, errors, src->path, line_of(b, start), "struct ", name,
                             ": a field may not be a pointer — a value is copied, and a pointer would share what it points at");
                d->n_errors++;
                break;
            }
            struct gen_field *f = push(m, (void **)&st->fields, &st->n_fields, sizeof *f);
            f->name = g_dup(m, t.text[k], g_len(t.text[k]));
            f->type = type;
            f->line = line_of(b, start);
            k++;
            if (k < t.n && g_eq(t.text[k], "[")) {
                int close_bracket = k + 1;
                while (close_bracket < t.n && !g_eq(t.text[close_bracket], "]")) close_bracket++;
                f->count = join_tokens(m, &t, k + 1, close_bracket);
                k = close_bracket + 1;
            }
            /* Five kinds of field: a char array (text), another array, a
             * nested value type, a plain integer, or something the device
             * cannot hold (floating point) or the reader cannot name. */
            int ik = integer_kind(type);
            if (f->count && (g_eq(strip_const(type), "char"))) {
                f->kind = GEN_FIELD_TEXT;
            } else if (f->count && ik >= 0) {
                f->kind = GEN_FIELD_ARRAY;
            } else if (g_starts_with(strip_const(type), "struct ")) {
                f->kind = GEN_FIELD_STRUCT;
            } else if (ik >= 0) {
                f->kind = ik;
            } else if (g_eq(type, "float") || g_eq(type, "double")) {
                append_error(m, errors, src->path, f->line, "field ", f->name,
                             ": floating point cannot be carried — the kernel is built without it (issue 103f)");
                d->n_errors++;
            } else {
                append_error(m, errors, src->path, f->line, "field ", f->name, ": its type is not one the reader knows");
                d->n_errors++;
            }
            if (k < t.n && g_eq(t.text[k], ",")) k++;
        }
        start = i + 1;
    }
}
/* }}} */

/* {{{ read_function */
static void read_function(struct gen_memory *m, const struct gen_source *src, int source_index,
                          const char *b, size_t start, size_t open, struct gen_description *d,
                          struct gen_text *errors)
{
    /* The signature is everything from the chunk start to the brace. The
     * name sits just before the first '('. */
    size_t paren = start;
    while (paren < open && b[paren] != '(') paren++;
    size_t close = paren;
    int depth = 0;
    for (; close < open; close++) {
        if (b[close] == '(') depth++;
        else if (b[close] == ')' && --depth == 0) break;
    }
    struct tokens head;
    if (!tokenize(b + start, paren - start, &head) || head.n < 2) {
        append_error(m, errors, src->path, line_of(b, paren), "a function whose name and return type could not be read", 0, 0);
        d->n_errors++;
        return;
    }
    int line = line_of(b, paren);
    const char *name = head.text[head.n - 1];
    int is_static = 0, is_inline = 0;
    for (int i = 0; i < head.n - 1; i++) {
        if (g_eq(head.text[i], "static")) is_static = 1;
        if (g_eq(head.text[i], "inline")) is_inline = 1;
    }
    /* Three things a function can be: a helper private to its file, an
     * ordering for a value type, or a box. */
    if (is_static || is_inline) {
        struct gen_helper *h = push(m, (void **)&d->helpers, &d->n_helpers, sizeof *h);
        h->name = g_dup(m, name, g_len(name));
        h->source = source_index;
        return;
    }
    int ret_from = 0;
    while (ret_from < head.n - 1 && (g_eq(head.text[ret_from], "extern"))) ret_from++;
    char *returns = join_tokens(m, &head, ret_from, head.n - 1);

    struct tokens params;
    if (!tokenize(b + paren + 1, close - paren - 1, &params)) {
        append_error(m, errors, src->path, line, "box ", name, ": too many parameter words to read");
        d->n_errors++;
        return;
    }
    if (g_ends_with(name, "__compare")) {
        size_t base = g_len(name) - 9;
        char type_name[MAX_TOKEN];
        g_copy(type_name, name, base);
        type_name[base] = 0;
        /* Recorded by name; matched to its struct once every file is read. */
        struct gen_struct *st = 0;
        for (int i = 0; i < d->n_structs; i++) {
            if (g_eq(d->structs[i].name, type_name)) st = &d->structs[i];
        }
        if (!st) {
            append_error(m, errors, src->path, line, "ordering ", name,
                         ": no value type of that name was defined above it");
            d->n_errors++;
        } else {
            st->compare = g_dup(m, name, g_len(name));
        }
        return;
    }

    struct gen_box *box = push(m, (void **)&d->boxes, &d->n_boxes, sizeof *box);
    box->name = g_dup(m, name, g_len(name));
    box->returns = returns;
    box->source = source_index;
    box->line = line;

    if (g_ends_with(returns, "*")) {
        append_error(m, errors, src->path, line, "box ", name,
                     g_eq(strip_const(returns), "char *")
                     ? ": a box may not return a string — borrowed memory has no owner; return a struct holding a char array"
                     : ": a box may not return a pointer — a value is copied, and a pointer would share what it points at");
        d->n_errors++;
    }
    if (g_eq(returns, "float") || g_eq(returns, "double")) {
        append_error(m, errors, src->path, line, "box ", name, ": floating point cannot be carried (issue 103f)");
        d->n_errors++;
    }
    /* Parameters: split at commas. "void" alone means none. */
    int from = 0;
    if (params.n == 1 && g_eq(params.text[0], "void")) {
        params.n = 0;
    }
    for (int i = 0; i <= params.n; i++) {
        if (i < params.n && !g_eq(params.text[i], ",")) continue;
        if (i == from) {
            if (params.n) {
                append_error(m, errors, src->path, line, "box ", name, ": an empty parameter");
                d->n_errors++;
            }
            from = i + 1;
            continue;
        }
        const char *last = params.text[i - 1];
        struct gen_param *p = push(m, (void **)&box->params, &box->n_params, sizeof *p);
        /* An unnamed parameter is one whose last word is still part of a
         * type — "int", "struct text" — which is usually a mistake, and
         * the generator needs the name for its messages. */
        int unnamed = i - from < 2 || is_type_word(last) || (i - from >= 2 && g_eq(params.text[i - 2], "struct"));
        if (g_eq(last, "]")) {
            append_error(m, errors, src->path, line, "box ", name, ": an array parameter is a pointer in disguise; wrap it in a struct");
            d->n_errors++;
        } else if (g_eq(last, ".")) {
            append_error(m, errors, src->path, line, "box ", name, ": a box cannot take a variable number of inputs");
            d->n_errors++;
        } else if (unnamed) {
            append_error(m, errors, src->path, line, "box ", name, ": every parameter must be named");
            d->n_errors++;
        }
        p->name = g_dup(m, last, g_len(last));
        p->type = join_tokens(m, &params, from, i - (unnamed ? 0 : 1));
        if (g_ends_with(p->type, "*")) {
            append_error(m, errors, src->path, line, "box ", name,
                         ": a value type is a struct, not a bare pointer — a pointer on a wire shares what it points at");
            d->n_errors++;
        }
        if (g_eq(strip_const(p->type), "float") || g_eq(strip_const(p->type), "double")) {
            append_error(m, errors, src->path, line, "box ", name, ": floating point cannot be carried (issue 103f)");
            d->n_errors++;
        }
        from = i + 1;
    }
    if (box->n_params == 0) {
        append_error(m, errors, src->path, line, "box ", name,
                     ": a box with no inputs can never be made to run — give it a trigger input it ignores (issue 310)");
        d->n_errors++;
    }
}
/* }}} */

/* {{{ read_source */
static void read_source(struct gen_memory *m, const struct gen_source *src, int source_index,
                        struct gen_description *d, struct gen_text *errors)
{
    char *b = blank(m, src->text, src->length);
    size_t n = src->length;
    size_t chunk = 0;
    size_t i = 0;
    while (i < n) {
        char c = b[i];
        if (c == ';') {
            chunk = ++i;
            continue;
        }
        if (c != '{') {
            i++;
            continue;
        }
        size_t close = matching_brace(b, n, i);
        struct tokens t;
        tokenize(b + chunk, i - chunk, &t);
        int has_paren = 0;
        for (size_t k = chunk; k < i; k++) if (b[k] == '(') has_paren = 1;
        int s = 0;
        if (t.n && g_eq(t.text[0], "typedef")) s = 1;
        /* Three shapes open a brace at the outermost level: a struct
         * definition (a value type), a function definition (a box, a
         * helper or an ordering), or anything else — an initialiser, an
         * enum — which is skipped whole. */
        if (!has_paren && t.n >= s + 2 && g_eq(t.text[s], "struct")) {
            read_struct(m, src, source_index, b, i, close, t.text[s + 1], line_of(b, i), d, errors);
        } else if (has_paren) {
            read_function(m, src, source_index, b, chunk, i, d, errors);
        }
        i = close;
        /* After a struct or initialiser comes its own ';'; after a
         * function body there is none. Either way the next chunk starts
         * here. */
        while (i < n && (b[i] == ' ' || b[i] == '\n' || b[i] == '\t' || b[i] == '\r')) i++;
        if (i < n && b[i] == ';') i++;
        chunk = i;
    }
}
/* }}} */

/* {{{ find_struct */
static int find_struct(const struct gen_description *d, const char *type)
{
    const char *t = strip_const(type);
    if (!g_starts_with(t, "struct ")) return -1;
    t += 7;
    for (int i = 0; i < d->n_structs; i++) {
        if (g_eq(d->structs[i].name, t)) return i;
    }
    return -1;
}
/* }}} */

/* {{{ gen_read */
int gen_read(const struct gen_source *sources, int n_sources, struct gen_memory *memory,
             struct gen_description *out, struct gen_text *errors)
{
    for (int s = 0; s < n_sources; s++) {
        read_source(memory, &sources[s], s, out, errors);
    }
    /* Checks that need every file read: each value type a box names must
     * be defined in some box source (so it has a field table), and no
     * value type may be defined twice. */
    for (int i = 0; i < out->n_structs; i++) {
        for (int j = i + 1; j < out->n_structs; j++) {
            if (g_eq(out->structs[i].name, out->structs[j].name)) {
                append_error(memory, errors, sources[out->structs[j].source].path, out->structs[j].line,
                             "struct ", out->structs[j].name, " is defined twice among the box sources");
                out->n_errors++;
            }
        }
        for (int f = 0; f < out->structs[i].n_fields; f++) {
            struct gen_field *fd = &out->structs[i].fields[f];
            if (fd->kind == GEN_FIELD_STRUCT && find_struct(out, fd->type) < 0) {
                append_error(memory, errors, sources[out->structs[i].source].path, fd->line,
                             fd->type, " is not defined in any box source", 0);
                out->n_errors++;
            }
        }
    }
    for (int i = 0; i < out->n_boxes; i++) {
        struct gen_box *b = &out->boxes[i];
        const char *path = sources[b->source].path;
        for (int p = 0; p < b->n_params; p++) {
            const char *type = b->params[p].type;
            /* Pointers and floating point were already reported where the
             * parameter was read; say each problem once. */
            if (integer_kind(type) < 0 && find_struct(out, type) < 0 && !g_ends_with(type, "*") &&
                !g_eq(strip_const(type), "float") && !g_eq(strip_const(type), "double")) {
                append_error(memory, errors, path, b->line, "box ", b->name, ": ");
                errors->length--;                             /* rejoin the message on one line */
                gen_append(memory, errors, "parameter ");
                gen_append(memory, errors, b->params[p].name);
                gen_append(memory, errors, " has type ");
                gen_append(memory, errors, type);
                gen_append(memory, errors, ", which is neither an integer nor a value type defined in a box source\n");
                out->n_errors++;
            }
        }
        if (!g_eq(b->returns, "void") && integer_kind(b->returns) < 0 && find_struct(out, b->returns) < 0 &&
            !g_ends_with(b->returns, "*") && !g_eq(b->returns, "float") && !g_eq(b->returns, "double")) {
            append_error(memory, errors, path, b->line, "box ", b->name, ": its return type is neither an integer nor a value type defined in a box source");
            out->n_errors++;
        }
        for (int j = i + 1; j < out->n_boxes; j++) {
            if (out->boxes[j].source == b->source && g_eq(out->boxes[j].name, b->name)) {
                append_error(memory, errors, path, out->boxes[j].line, "box ", b->name, " is defined twice in one file");
                out->n_errors++;
            }
        }
    }
    return out->n_errors;
}
/* }}} */

/* {{{ gen_describe */
void gen_describe(const struct gen_source *sources, const struct gen_description *d,
                  struct gen_memory *m, struct gen_text *out)
{
    for (int i = 0; i < d->n_structs; i++) {
        const struct gen_struct *st = &d->structs[i];
        gen_append(m, out, "value type  struct ");
        gen_append(m, out, st->name);
        gen_append(m, out, "  (");
        gen_append(m, out, sources[st->source].path);
        gen_append(m, out, ":");
        append_int(m, out, st->line);
        gen_append(m, out, st->compare ? ", ordered by " : ", no ordering");
        if (st->compare) gen_append(m, out, st->compare);
        gen_append(m, out, ")\n");
        for (int f = 0; f < st->n_fields; f++) {
            gen_append(m, out, "    ");
            gen_append(m, out, st->fields[f].type);
            gen_append(m, out, " ");
            gen_append(m, out, st->fields[f].name);
            if (st->fields[f].count) {
                gen_append(m, out, "[");
                gen_append(m, out, st->fields[f].count);
                gen_append(m, out, "]");
            }
            gen_append(m, out, "\n");
        }
    }
    for (int i = 0; i < d->n_boxes; i++) {
        const struct gen_box *b = &d->boxes[i];
        gen_append(m, out, "box  ");
        gen_append(m, out, sources[b->source].path);
        gen_append(m, out, ":");
        gen_append(m, out, b->name);
        gen_append(m, out, "  (");
        for (int p = 0; p < b->n_params; p++) {
            if (p) gen_append(m, out, ", ");
            gen_append(m, out, b->params[p].type);
            gen_append(m, out, " ");
            gen_append(m, out, b->params[p].name);
        }
        gen_append(m, out, ") -> ");
        gen_append(m, out, b->returns);
        gen_append(m, out, "   line ");
        append_int(m, out, b->line);
        gen_append(m, out, "\n");
    }
    for (int i = 0; i < d->n_helpers; i++) {
        gen_append(m, out, "helper  ");
        gen_append(m, out, sources[d->helpers[i].source].path);
        gen_append(m, out, ":");
        gen_append(m, out, d->helpers[i].name);
        gen_append(m, out, "\n");
    }
}
/* }}} */

/* {{{ emitting */
/* {{{ emit_renames */
/* Every function a source defines is renamed while that source is
 * included, so two box sources may each define `add` (or a static helper
 * `clamp`) without colliding in the one file the catalogue is compiled
 * as. After the include the names are released again. */
static void emit_renames(struct gen_memory *m, struct gen_text *o, const struct gen_description *d, int s, int undo)
{
    for (int i = 0; i < d->n_boxes; i++) {
        if (d->boxes[i].source != s) continue;
        gen_append(m, o, undo ? "#undef " : "#define ");
        gen_append(m, o, d->boxes[i].name);
        if (!undo) {
            gen_append(m, o, " gen_fn__");
            append_int(m, o, s);
            gen_append(m, o, "__");
            gen_append(m, o, d->boxes[i].name);
        }
        gen_append(m, o, "\n");
    }
    for (int i = 0; i < d->n_helpers; i++) {
        if (d->helpers[i].source != s) continue;
        gen_append(m, o, undo ? "#undef " : "#define ");
        gen_append(m, o, d->helpers[i].name);
        if (!undo) {
            gen_append(m, o, " gen_helper__");
            append_int(m, o, s);
            gen_append(m, o, "__");
            gen_append(m, o, d->helpers[i].name);
        }
        gen_append(m, o, "\n");
    }
    for (int i = 0; i < d->n_structs; i++) {
        if (d->structs[i].source != s || !d->structs[i].compare) continue;
        gen_append(m, o, undo ? "#undef " : "#define ");
        gen_append(m, o, d->structs[i].compare);
        if (!undo) {
            gen_append(m, o, " gen_order_fn__");
            gen_append(m, o, d->structs[i].compare);
        }
        gen_append(m, o, "\n");
    }
}
/* }}} */

/* {{{ file_stem */
/* "src/boxes/062-arithmetic.c" → "arithmetic": the readable part of a
 * source's name, used in the box record's C name. */
static void file_stem(const char *path, char *out, size_t size)
{
    const char *base = path;
    for (const char *p = path; *p; p++) if (*p == '/') base = p + 1;
    const char *dash = base;
    while (*dash >= '0' && *dash <= '9') dash++;
    if (*dash == '-') base = dash + 1;
    size_t k = 0;
    while (base[k] && base[k] != '.' && k + 1 < size) {
        out[k] = is_ident_char(base[k]) ? base[k] : '_';
        k++;
    }
    out[k] = 0;
}
/* }}} */

/* {{{ emit_type_row */
static void emit_type_row(struct gen_memory *m, struct gen_text *o, const char *type, int kind,
                          const char *fields, int n_fields, const char *order)
{
    gen_append(m, o, "    { \"");
    gen_append(m, o, type);
    gen_append(m, o, "\", sizeof(");
    gen_append(m, o, type);
    gen_append(m, o, "), ");
    append_int(m, o, kind);
    gen_append(m, o, ", ");
    gen_append(m, o, fields);
    gen_append(m, o, ", ");
    append_int(m, o, n_fields);
    gen_append(m, o, ", ");
    gen_append(m, o, order);
    gen_append(m, o, " },\n");
}
/* }}} */

/* {{{ gen_emit */
void gen_emit(const struct gen_source *sources, int n_sources, const struct gen_description *d,
              struct gen_memory *m, struct gen_text *o)
{
    gen_append(m, o,
        "/*\n"
        " * GENERATED by the box generator (src/engine/060-generator.c) from every\n"
        " * file under src/boxes/. Do not edit: change a box source and rebuild.\n"
        " *\n"
        " * What is here: each box source included once, its functions renamed\n"
        " * while it is included so two files may share a name; one adapter per\n"
        " * box that copies a task's bytes into real arguments and the return\n"
        " * value back out; a record per box; a field table per value type; and\n"
        " * the catalogue, keyed by each box's address. Every size and offset is\n"
        " * a sizeof or offsetof the compiler works out.\n"
        " */\n"
        "#include <stddef.h>\n#include <stdint.h>\n"
        "#include \"027-primitives.h\"\n#include \"031-engine.h\"\n#include \"070-catalogue.h\"\n\n");

    for (int s = 0; s < n_sources; s++) {
        emit_renames(m, o, d, s, 0);
        gen_append(m, o, "#include \"");
        gen_append(m, o, sources[s].include_path);
        gen_append(m, o, "\"\n");
        emit_renames(m, o, d, s, 1);
        gen_append(m, o, "\n");
    }

    /* Orderings: an adapter from two byte blocks to the typed function. */
    for (int i = 0; i < d->n_structs; i++) {
        const struct gen_struct *st = &d->structs[i];
        if (!st->compare) continue;
        gen_append(m, o, "static int gen_order__");
        gen_append(m, o, st->name);
        gen_append(m, o, "(const void *a, const void *b)\n{\n    struct ");
        gen_append(m, o, st->name);
        gen_append(m, o, " x, y;\n    bytes_copy(&x, a, sizeof x);\n    bytes_copy(&y, b, sizeof y);\n    return gen_order_fn__");
        gen_append(m, o, st->compare);
        gen_append(m, o, "(x, y);\n}\n\n");
    }

    /* Field tables, one per value type. */
    for (int i = 0; i < d->n_structs; i++) {
        const struct gen_struct *st = &d->structs[i];
        gen_append(m, o, "static const struct catalogue_field gen_fields__");
        gen_append(m, o, st->name);
        gen_append(m, o, "[] = {\n");
        for (int f = 0; f < st->n_fields; f++) {
            const struct gen_field *fd = &st->fields[f];
            gen_append(m, o, "    { \"");
            gen_append(m, o, fd->name);
            gen_append(m, o, "\", \"");
            gen_append(m, o, fd->type);
            gen_append(m, o, "\", offsetof(struct ");
            gen_append(m, o, st->name);
            gen_append(m, o, ", ");
            gen_append(m, o, fd->name);
            gen_append(m, o, "), sizeof(((struct ");
            gen_append(m, o, st->name);
            gen_append(m, o, " *)0)->");
            gen_append(m, o, fd->name);
            gen_append(m, o, "), ");
            if (fd->count) {
                gen_append(m, o, "sizeof(((struct ");
                gen_append(m, o, st->name);
                gen_append(m, o, " *)0)->");
                gen_append(m, o, fd->name);
                gen_append(m, o, "[0]), ");
            } else {
                gen_append(m, o, "0, ");
            }
            append_int(m, o, fd->kind);
            gen_append(m, o, " },\n");
        }
        if (st->n_fields == 0) gen_append(m, o, "    { 0, 0, 0, 0, 0, 0 },\n");
        gen_append(m, o, "};\n\n");
    }

    /* The type table: every value type, then every integer type a box uses. */
    gen_append(m, o, "const struct catalogue_type catalogue_types[] = {\n");
    int n_types = 0;
    for (int i = 0; i < d->n_structs; i++) {
        char type[128] = "struct ";
        g_copy(type + 7, d->structs[i].name, g_len(d->structs[i].name) + 1);
        char fields[160] = "gen_fields__";
        g_copy(fields + 12, d->structs[i].name, g_len(d->structs[i].name) + 1);
        char order[160] = "0";
        if (d->structs[i].compare) {
            g_copy(order, "gen_order__", 11);
            g_copy(order + 11, d->structs[i].name, g_len(d->structs[i].name) + 1);
        }
        emit_type_row(m, o, type, GEN_FIELD_STRUCT, fields, d->structs[i].n_fields, order);
        n_types++;
    }
    /* integers, each named once */
    const char *seen[256];
    int n_seen = 0;
    for (int i = 0; i < d->n_boxes; i++) {
        for (int p = -1; p < d->boxes[i].n_params; p++) {
            const char *t = p < 0 ? d->boxes[i].returns : strip_const(d->boxes[i].params[p].type);
            int kind = integer_kind(t);
            if (kind < 0) continue;
            int dup = 0;
            for (int k = 0; k < n_seen; k++) if (g_eq(seen[k], t)) dup = 1;
            if (dup || n_seen >= 256) continue;
            seen[n_seen++] = t;
            emit_type_row(m, o, t, kind, "0", 0, "0");
            n_types++;
        }
    }
    gen_append(m, o, "};\nconst int catalogue_type_count = ");
    append_int(m, o, n_types);
    gen_append(m, o, ";\n\n");

    /* Per box: offsets, the adapter, the parameter list, the record. */
    for (int i = 0; i < d->n_boxes; i++) {
        const struct gen_box *b = &d->boxes[i];
        char stem[64];
        file_stem(sources[b->source].path, stem, sizeof stem);
        gen_append(m, o, "/* ");
        gen_append(m, o, sources[b->source].path);
        gen_append(m, o, ":");
        append_int(m, o, b->line);
        gen_append(m, o, " — ");
        gen_append(m, o, b->name);
        gen_append(m, o, " */\n");
        for (int p = 0; p < b->n_params; p++) {
            gen_append(m, o, "#define GEN_OFF_");
            append_int(m, o, i);
            gen_append(m, o, "_");
            append_int(m, o, p);
            if (p == 0) {
                gen_append(m, o, " ((size_t)0)\n");
            } else {
                gen_append(m, o, " ((GEN_OFF_");
                append_int(m, o, i);
                gen_append(m, o, "_");
                append_int(m, o, p - 1);
                gen_append(m, o, " + sizeof(");
                gen_append(m, o, strip_const(b->params[p - 1].type));
                gen_append(m, o, ") + 7) & ~(size_t)7)\n");
            }
        }
        gen_append(m, o, "static void gen_call__");
        append_int(m, o, i);
        gen_append(m, o, "(const void *in, void *out)\n{\n");
        for (int p = 0; p < b->n_params; p++) {
            gen_append(m, o, "    ");
            gen_append(m, o, strip_const(b->params[p].type));
            gen_append(m, o, " a");
            append_int(m, o, p);
            gen_append(m, o, ";\n    bytes_copy(&a");
            append_int(m, o, p);
            gen_append(m, o, ", (const unsigned char *)in + GEN_OFF_");
            append_int(m, o, i);
            gen_append(m, o, "_");
            append_int(m, o, p);
            gen_append(m, o, ", sizeof a");
            append_int(m, o, p);
            gen_append(m, o, ");\n");
        }
        int sink = g_eq(b->returns, "void");
        gen_append(m, o, sink ? "    (void)out;\n    " : "    ");
        if (!sink) {
            gen_append(m, o, strip_const(b->returns));
            gen_append(m, o, " r = ");
        }
        gen_append(m, o, "gen_fn__");
        append_int(m, o, b->source);
        gen_append(m, o, "__");
        gen_append(m, o, b->name);
        gen_append(m, o, "(");
        for (int p = 0; p < b->n_params; p++) {
            if (p) gen_append(m, o, ", ");
            gen_append(m, o, "a");
            append_int(m, o, p);
        }
        gen_append(m, o, ");\n");
        if (!sink) gen_append(m, o, "    bytes_copy(out, &r, sizeof r);\n");
        gen_append(m, o, "}\n");
        gen_append(m, o, "static const struct box_param gen_params__");
        append_int(m, o, i);
        gen_append(m, o, "[] = {\n");
        for (int p = 0; p < b->n_params; p++) {
            gen_append(m, o, "    { \"");
            gen_append(m, o, b->params[p].name);
            gen_append(m, o, "\", \"");
            gen_append(m, o, strip_const(b->params[p].type));
            gen_append(m, o, "\", (uint32_t)sizeof(");
            gen_append(m, o, strip_const(b->params[p].type));
            gen_append(m, o, "), (uint32_t)GEN_OFF_");
            append_int(m, o, i);
            gen_append(m, o, "_");
            append_int(m, o, p);
            gen_append(m, o, " },\n");
        }
        gen_append(m, o, "};\n");
        gen_append(m, o, "const struct box box__");
        gen_append(m, o, stem);
        gen_append(m, o, "__");
        gen_append(m, o, b->name);
        gen_append(m, o, " = {\n    \"");
        gen_append(m, o, b->name);
        gen_append(m, o, "\", \"");
        gen_append(m, o, sources[b->source].path);
        gen_append(m, o, "\", gen_call__");
        append_int(m, o, i);
        gen_append(m, o, ", ");
        append_int(m, o, b->n_params);
        gen_append(m, o, ", gen_params__");
        append_int(m, o, i);
        gen_append(m, o, ",\n    (uint32_t)(GEN_OFF_");
        append_int(m, o, i);
        gen_append(m, o, "_");
        append_int(m, o, b->n_params - 1);
        gen_append(m, o, " + sizeof(");
        gen_append(m, o, strip_const(b->params[b->n_params - 1].type));
        gen_append(m, o, ")), ");
        if (sink) {
            gen_append(m, o, "0, \"void\", 0\n};\n\n");
        } else {
            gen_append(m, o, "(uint32_t)sizeof(");
            gen_append(m, o, strip_const(b->returns));
            gen_append(m, o, "), \"");
            gen_append(m, o, strip_const(b->returns));
            gen_append(m, o, "\", ");
            int st = find_struct(d, b->returns);
            if (st >= 0 && d->structs[st].compare) {
                gen_append(m, o, "gen_order__");
                gen_append(m, o, d->structs[st].name);
            } else {
                gen_append(m, o, "0");
            }
            gen_append(m, o, "\n};\n\n");
        }
    }

    gen_append(m, o, "const struct catalogue_row catalogue_rows[] = {\n");
    for (int i = 0; i < d->n_boxes; i++) {
        char stem[64];
        file_stem(sources[d->boxes[i].source].path, stem, sizeof stem);
        gen_append(m, o, "    { \"");
        gen_append(m, o, sources[d->boxes[i].source].path);
        gen_append(m, o, ":");
        gen_append(m, o, d->boxes[i].name);
        gen_append(m, o, "\", &box__");
        gen_append(m, o, stem);
        gen_append(m, o, "__");
        gen_append(m, o, d->boxes[i].name);
        gen_append(m, o, " },\n");
    }
    if (d->n_boxes == 0) gen_append(m, o, "    { 0, 0 },\n");
    gen_append(m, o, "};\nconst int catalogue_row_count = ");
    append_int(m, o, d->n_boxes);
    gen_append(m, o, ";\n");
}
/* }}} */

/* {{{ gen_emit_header */
void gen_emit_header(const struct gen_source *sources, const struct gen_description *d,
                     struct gen_memory *m, struct gen_text *o)
{
    gen_append(m, o,
        "/*\n"
        " * GENERATED by the box generator: the name of every box record, so C\n"
        " * code (tests, programs built by hand) can place a box without looking\n"
        " * it up by address. Do not edit.\n"
        " */\n#ifndef SOREN_CATALOGUE_BOXES_H\n#define SOREN_CATALOGUE_BOXES_H\n"
        "#include \"031-engine.h\"\n\n");
    for (int i = 0; i < d->n_boxes; i++) {
        char stem[64];
        file_stem(sources[d->boxes[i].source].path, stem, sizeof stem);
        gen_append(m, o, "extern const struct box box__");
        gen_append(m, o, stem);
        gen_append(m, o, "__");
        gen_append(m, o, d->boxes[i].name);
        gen_append(m, o, ";\n");
    }
    gen_append(m, o, "\n#endif\n");
}
/* }}} */

/* {{{ gen_emit_maps */
void gen_emit_maps(const struct gen_source *maps, int n_maps, struct gen_memory *m, struct gen_text *o)
{
    gen_append(m, o,
        "/*\n"
        " * GENERATED by the box generator from the map files under src/maps/.\n"
        " * Before the device has a filesystem (phase 4), the maps it ships with\n"
        " * travel inside the kernel image as these strings; each keeps the path it\n"
        " * was read from, so the addresses inside it resolve exactly as they would\n"
        " * from the file (issue 305's open question, answered in 305).\n"
        " */\n#include \"070-catalogue.h\"\n\nconst struct embedded_map embedded_maps[] = {\n");
    for (int i = 0; i < n_maps; i++) {
        gen_append(m, o, "    { \"");
        gen_append(m, o, maps[i].path);
        gen_append(m, o, "\",\n      \"");
        char esc[3] = { 0, 0, 0 };
        for (size_t k = 0; k < maps[i].length; k++) {
            char c = maps[i].text[k];
            if (c == '\n') {
                gen_append(m, o, "\\n\"\n      \"");
                continue;
            }
            if (c == '"' || c == '\\') { esc[0] = '\\'; esc[1] = c; gen_append(m, o, esc); continue; }
            esc[0] = c; esc[1] = 0;
            gen_append(m, o, esc);
        }
        gen_append(m, o, "\" },\n");
    }
    if (n_maps == 0) gen_append(m, o, "    { 0, 0 },\n");
    gen_append(m, o, "};\nconst int embedded_map_count = ");
    append_int(m, o, n_maps);
    gen_append(m, o, ";\n");
}
/* }}} */
/* }}} */
