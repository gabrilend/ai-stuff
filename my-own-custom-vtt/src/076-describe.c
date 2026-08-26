/*
 * 076-describe.c -- a closed vocabulary, and a wall rather than a net.
 *
 * Interface and reasoning are in 076-describe.h.
 *
 * The vocabulary table below is the single place a field's name, type, and
 * bounds are written down. The reader, the bounds check, the suggestions, and
 * the documentation all come from it -- a vocabulary with two homes drifts, and
 * the symptom is a description that one half accepts and the other rejects.
 */

#include "076-describe.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* {{{ struct word */
struct word {
    const char *name;
    uint32_t    lowest;
    uint32_t    highest;
    uint32_t    fallback;    /* Used when the field is ABSENT, which is */
                             /* vocabulary. Never when it is malformed, */
                             /* which is a fault. */
    const char *means;
};
/* }}} */

/*
 * THE VOCABULARY. A description may use these words and no others.
 *
 * `name` and `require` are handled separately because they are text rather than
 * numbers, and `require` may appear more than once.
 */
static const struct word vocabulary[] = {
    { "rooms",    2,  64, 6,  "how many rooms" },
    { "smallest", 3,  40, 5,  "the smallest room, in metres across" },
    { "largest",  4, 120, 12, "the largest room, in metres across" },
    { "loops",    0,  16, 1,  "connections beyond a bare tree" },
    { "lights",   0,  64, 2,  "how many rooms get a light" }
};

#define VOCABULARY_COUNT (sizeof(vocabulary) / sizeof(vocabulary[0]))

static const char *const extra_words[] = { "name", "require" };

/* {{{ const char *const *description_vocabulary */
const char *const *description_vocabulary(uint32_t *count)
{
    /*
     * Built once, so that a demo listing the vocabulary is listing the same
     * table the reader uses rather than a copy somebody typed out.
     */
    static const char *names[VOCABULARY_COUNT + 2];
    static int built = 0;
    uint32_t i;

    if (!built) {
        for (i = 0; i < VOCABULARY_COUNT; i++) {
            names[i] = vocabulary[i].name;
        }
        names[VOCABULARY_COUNT] = extra_words[0];
        names[VOCABULARY_COUNT + 1] = extra_words[1];
        built = 1;
    }

    *count = VOCABULARY_COUNT + 2;
    return names;
}
/* }}} */

/* {{{ static uint32_t edit_distance */
static uint32_t edit_distance(const char *a, const char *b)
{
    /*
     * Levenshtein, in the small. The vocabulary is a handful of short words, so
     * the quadratic cost is nothing and the value is high: a misspelling is the
     * commonest fault and "did you mean" ends the investigation immediately.
     */
    uint32_t la = (uint32_t)strlen(a);
    uint32_t lb = (uint32_t)strlen(b);
    uint32_t previous[DESCRIPTION_NAME_MAX + 2];
    uint32_t current[DESCRIPTION_NAME_MAX + 2];
    uint32_t i;
    uint32_t j;

    if (la > DESCRIPTION_NAME_MAX) la = DESCRIPTION_NAME_MAX;
    if (lb > DESCRIPTION_NAME_MAX) lb = DESCRIPTION_NAME_MAX;

    for (j = 0; j <= lb; j++) {
        previous[j] = j;
    }

    for (i = 1; i <= la; i++) {
        current[0] = i;

        for (j = 1; j <= lb; j++) {
            uint32_t swap = previous[j - 1] + ((a[i - 1] == b[j - 1]) ? 0 : 1);
            uint32_t drop = previous[j] + 1;
            uint32_t add = current[j - 1] + 1;
            uint32_t best = swap;

            if (drop < best) best = drop;
            if (add < best) best = add;

            current[j] = best;
        }

        for (j = 0; j <= lb; j++) {
            previous[j] = current[j];
        }
    }

    return previous[lb];
}
/* }}} */

/* {{{ static const char *nearest_word */
static const char *nearest_word(const char *given)
{
    const char *const *words;
    uint32_t count = 0;
    uint32_t i;
    uint32_t best_distance = 0xFFFFFFFFu;
    const char *best = NULL;

    words = description_vocabulary(&count);

    for (i = 0; i < count; i++) {
        uint32_t distance = edit_distance(given, words[i]);

        if (distance < best_distance) {
            best_distance = distance;
            best = words[i];
        }
    }

    /*
     * Only offered when it is actually close. Suggesting "rooms" for "banana"
     * is worse than suggesting nothing -- it sends somebody looking for a
     * relationship that is not there.
     *
     * The second condition catches what a fixed distance alone misses: three
     * edits is the whole of a three-letter word, so a bare "<= 3" cheerfully
     * offers a suggestion for a word that is empty or nearly so, where nothing
     * of what was typed survives into the suggestion. The distance has to be
     * shorter than the word it claims to be correcting.
     */
    if (best_distance <= 3 && best_distance < (uint32_t)strlen(given)) {
        return best;
    }

    return NULL;
}
/* }}} */

/* {{{ static void add_fault */
static void add_fault(struct fault_list *faults, uint32_t line,
                      const char *word, const char *found,
                      const char *expected, const char *nearest)
{
    struct fault *f;

    if (faults->count >= DESCRIPTION_MAX_FAULTS) {
        faults->overflowed = 1;
        return;
    }

    f = &faults->faults[faults->count];
    faults->count++;

    f->line = line;
    snprintf(f->word, sizeof(f->word), "%s", (word != NULL) ? word : "");
    snprintf(f->found, sizeof(f->found), "%s", (found != NULL) ? found : "");
    f->expected = expected;
    f->nearest = nearest;
}
/* }}} */

/* {{{ static char *trim */
static char *trim(char *text)
{
    char *end;

    while (*text == ' ' || *text == '\t') {
        text++;
    }

    end = text + strlen(text);

    while (end > text &&
           (end[-1] == ' ' || end[-1] == '\t' ||
            end[-1] == '\n' || end[-1] == '\r')) {
        end--;
    }

    *end = '\0';

    return text;
}
/* }}} */

/* {{{ static int read_number */
static int read_number(const char *text, uint32_t *out)
{
    uint32_t value = 0;
    uint32_t i;

    if (text[0] == '\0') {
        return 0;
    }

    for (i = 0; text[i] != '\0'; i++) {
        if (text[i] < '0' || text[i] > '9') {
            return 0;
        }

        value = (value * 10) + (uint32_t)(text[i] - '0');

        /* A number nobody meant. Refused rather than wrapped. */
        if (value > 1000000) {
            return 0;
        }
    }

    *out = value;
    return 1;
}
/* }}} */

/* {{{ int description_read */
int description_read(struct description *d, const char *text,
                     struct fault_list *faults)
{
    char line[512];
    uint32_t line_number = 0;
    uint32_t at = 0;
    uint8_t seen[VOCABULARY_COUNT];
    uint32_t i;

    memset(d, 0, sizeof(struct description));
    memset(faults, 0, sizeof(struct fault_list));
    memset(seen, 0, sizeof(seen));

    while (text[at] != '\0') {
        uint32_t length = 0;
        char *cut;
        char *key;
        char *value;

        while (text[at] != '\0' && text[at] != '\n' &&
               length < sizeof(line) - 1) {
            line[length] = text[at];
            length++;
            at++;
        }

        line[length] = '\0';

        while (text[at] != '\0' && text[at] != '\n') {
            at++;   /* A line longer than the buffer. Skip its tail. */
        }

        if (text[at] == '\n') {
            at++;
        }

        line_number++;

        key = trim(line);

        /* Blank lines and comments. */
        if (key[0] == '\0' || key[0] == '#') {
            continue;
        }

        cut = strchr(key, '=');

        if (cut == NULL) {
            add_fault(faults, line_number, key, "",
                      "a line of the form 'word = value'", NULL);
            continue;
        }

        *cut = '\0';
        value = trim(cut + 1);
        key = trim(key);

        if (strcmp(key, "name") == 0) {
            if (value[0] == '\0') {
                add_fault(faults, line_number, "name", "",
                          "some text", NULL);
                continue;
            }
            snprintf(d->name, sizeof(d->name), "%s", value);
            continue;
        }

        if (strcmp(key, "require") == 0) {
            if (value[0] == '\0') {
                add_fault(faults, line_number, "require", "",
                          "the name of a feature", NULL);
                continue;
            }

            if (d->required_count >= DESCRIPTION_MAX_REQUIRED) {
                add_fault(faults, line_number, "require", value,
                          "at most eight required features", NULL);
                continue;
            }

            snprintf(d->required[d->required_count],
                     sizeof(d->required[0]), "%s", value);
            d->required_count++;
            continue;
        }

        {
            int known = 0;

            for (i = 0; i < VOCABULARY_COUNT; i++) {
                uint32_t number;

                if (strcmp(key, vocabulary[i].name) != 0) {
                    continue;
                }

                known = 1;

                if (!read_number(value, &number)) {
                    add_fault(faults, line_number, key, value,
                              "a whole number", NULL);
                    break;
                }

                if (number < vocabulary[i].lowest ||
                    number > vocabulary[i].highest) {
                    static char bounds[VOCABULARY_COUNT][64];

                    snprintf(bounds[i], sizeof(bounds[i]),
                             "a number between %u and %u",
                             vocabulary[i].lowest, vocabulary[i].highest);

                    add_fault(faults, line_number, key, value, bounds[i], NULL);
                    break;
                }

                switch (i) {
                case 0: d->rooms = number;    break;
                case 1: d->smallest = number; break;
                case 2: d->largest = number;  break;
                case 3: d->loops = number;    break;
                default: d->lights = number;  break;
                }

                seen[i] = 1;
                break;
            }

            if (!known) {
                /*
                 * The nearest legal word, because a misspelling is the commonest
                 * fault and "did you mean" ends the investigation immediately.
                 */
                add_fault(faults, line_number, key, value,
                          "one of the words this description language has",
                          nearest_word(key));
            }
        }
    }

    /*
     * ABSENT OPTIONAL FIELDS TAKE THEIR DOCUMENTED DEFAULTS. That is vocabulary
     * -- it is written down in the table above and appears in the companion file.
     *
     * A MALFORMED field is a fault and never takes a default. The difference is
     * the whole line between vocabulary and a fallback, and a fallback is a
     * warning, and a warning is an error.
     */
    for (i = 0; i < VOCABULARY_COUNT; i++) {
        if (!seen[i]) {
            switch (i) {
            case 0: d->rooms = vocabulary[i].fallback;    break;
            case 1: d->smallest = vocabulary[i].fallback; break;
            case 2: d->largest = vocabulary[i].fallback;  break;
            case 3: d->loops = vocabulary[i].fallback;    break;
            default: d->lights = vocabulary[i].fallback;  break;
            }
        }
    }

    if (d->name[0] == '\0') {
        snprintf(d->name, sizeof(d->name), "somewhere");
    }

    /* A relationship between two fields, which no single-field check catches. */
    if (d->smallest > d->largest) {
        add_fault(faults, 0, "smallest", "",
                  "a number no larger than 'largest'", NULL);
    }

    return faults->count == 0 && !faults->overflowed;
}
/* }}} */

/* {{{ int description_read_file */
int description_read_file(struct description *d, const char *path,
                          struct fault_list *faults)
{
    FILE *f = fopen(path, "rb");
    char *text;
    long size;

    memset(faults, 0, sizeof(struct fault_list));

    if (f == NULL) {
        memset(d, 0, sizeof(struct description));
        add_fault(faults, 0, path, "", "a description file that exists", NULL);
        return 0;
    }

    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);

    text = malloc((size_t)size + 1);
    if (text == NULL) {
        fclose(f);
        add_fault(faults, 0, path, "", "enough memory to read it", NULL);
        return 0;
    }

    if (fread(text, 1, (size_t)size, f) != (size_t)size) {
        free(text);
        fclose(f);
        add_fault(faults, 0, path, "", "a file that could be read", NULL);
        return 0;
    }

    text[size] = '\0';
    fclose(f);

    {
        int sound = description_read(d, text, faults);
        free(text);
        return sound;
    }
}
/* }}} */

/* {{{ const char *fault_describe */
const char *fault_describe(const struct fault *f, char *buffer, uint32_t capacity)
{
    /*
     * One shape for every message. "Invalid input" is not an error message, it
     * is an apology -- so this names the line, the word, what was there, and
     * what was wanted.
     */
    if (f->nearest != NULL) {
        snprintf(buffer, (size_t)capacity,
                 "line %u: '%s' is not a word here -- did you mean '%s'?",
                 (unsigned)f->line, f->word, f->nearest);
    } else if (f->found[0] != '\0') {
        snprintf(buffer, (size_t)capacity,
                 "line %u: '%s' was given '%s'; expected %s.",
                 (unsigned)f->line, f->word, f->found, f->expected);
    } else if (f->line == 0) {
        snprintf(buffer, (size_t)capacity,
                 "'%s': expected %s.", f->word, f->expected);
    } else {
        snprintf(buffer, (size_t)capacity,
                 "line %u: '%s' -- expected %s.",
                 (unsigned)f->line, f->word, f->expected);
    }

    return buffer;
}
/* }}} */

/* {{{ void faults_report */
void faults_report(const struct fault_list *faults, const char *source)
{
    char message[512];
    uint32_t i;

    if (faults->count == 0 && !faults->overflowed) {
        return;
    }

    printf("  %s has %u problem%s:\n\n",
           source, faults->count, (faults->count == 1) ? "" : "s");

    /*
     * All of them, together. Stopping at the first turns fixing a description
     * into one guess per run.
     */
    for (i = 0; i < faults->count; i++) {
        printf("    %s\n", fault_describe(&faults->faults[i], message, sizeof(message)));
    }

    if (faults->overflowed) {
        printf("\n    ...and more than %u problems, which were not listed.\n",
               DESCRIPTION_MAX_FAULTS);
    }

    printf("\n");
}
/* }}} */
