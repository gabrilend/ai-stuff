/*
 * 076-describe.h -- what somebody asked for, and the wall in front of it.
 *
 * A description is a small declarative file saying what kind of place this is,
 * how big, and how connected. A few hundred bytes that name a whole dungeon when
 * paired with a seed.
 *
 * THE VOCABULARY IS CLOSED. A description may use a fixed set of words and no
 * others -- not because completeness is unachievable, but because anything
 * generating descriptions will invent plausible neighbouring words that do not
 * exist, confidently and in good style. A short allowlist has nowhere for the
 * analogy to go.
 *
 * See docs/013-content-is-generated.md and issues/801.
 */

#ifndef VTT_DESCRIBE_H
#define VTT_DESCRIBE_H

#include <stdint.h>

#define DESCRIPTION_MAX_REQUIRED 8
#define DESCRIPTION_NAME_MAX 63
#define DESCRIPTION_MAX_FAULTS 16

struct description {
    char     name[DESCRIPTION_NAME_MAX + 1];

    uint32_t rooms;          /* How many. */
    uint32_t smallest;       /* Metres across. */
    uint32_t largest;
    uint32_t loops;          /* Extra connections beyond a bare tree. */
    uint32_t lights;         /* How many rooms get one. */

    /* Named features that must exist. "cellar", "well", "bar". */
    char     required[DESCRIPTION_MAX_REQUIRED][DESCRIPTION_NAME_MAX + 1];
    uint32_t required_count;
};

/*
 * One thing wrong with a description. Every field is filled: which line, which
 * word, what was there, and -- where the word was merely misspelled -- the
 * nearest legal one.
 */
struct fault {
    uint32_t line;
    char     word[DESCRIPTION_NAME_MAX + 1];
    char     found[DESCRIPTION_NAME_MAX + 1];
    const char *expected;
    const char *nearest;     /* NULL when nothing is close. */
};

struct fault_list {
    struct fault faults[DESCRIPTION_MAX_FAULTS];
    uint32_t     count;
    uint32_t     overflowed;   /* More faults than would fit. */
};

/*
 * Read a description from text. Returns 1 when it is entirely sound.
 *
 * On failure, EVERY fault is reported, not the first -- stopping at the first
 * turns fixing a description into one guess per run.
 */
int description_read(struct description *d, const char *text,
                     struct fault_list *faults);

/* Read from a file. Same rules; a missing file is one fault, named. */
int description_read_file(struct description *d, const char *path,
                          struct fault_list *faults);

/* Write one fault as a sentence. */
const char *fault_describe(const struct fault *f, char *buffer, uint32_t capacity);

/* Print every fault, which is what a caller almost always wants. */
void faults_report(const struct fault_list *faults, const char *source);

/* The vocabulary, so the documentation and a demo can list it. */
const char *const *description_vocabulary(uint32_t *count);

#endif
