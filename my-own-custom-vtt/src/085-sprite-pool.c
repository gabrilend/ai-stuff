/*
 * 085-sprite-pool.c -- the library, and the two ways of judging it.
 *
 * The interesting parts of this file are the things it does not do. It never
 * deletes an entry, it never reads a clock, and it never lets one rating
 * overwrite another rating made by somebody else. Each of those is one line that
 * is absent, and each one absent is a whole class of question that stays
 * answerable a year from now.
 *
 * See 085-sprite-pool.h for why, and issues 903, 904, 906 and 907.
 */

#include "085-sprite-pool.h"

#include <stdio.h>
#include <string.h>

/*
 * How many entries a pool starts with room for. It grows, so this is a starting
 * point rather than a limit -- but a large starting point costs nothing and a
 * pool that reallocates while somebody is adding ten thousand dandelions is
 * doing work nobody asked for.
 */
#define POOL_STARTING_CAPACITY 1024

/* The first line of an index file. Its version is the format's, not the project's. */
#define POOL_FILE_HEADER "vtt-sprite-pool 1"

/* Longest line a written index produces, with room to spare for a reader. */
#define POOL_LINE_MAX 512

/* {{{ int pool_init */
int pool_init(struct sprite_pool *p, uint8_t algorithm)
{
    memset(p, 0, sizeof(*p));

    if (!block_init(&p->entries, (uint32_t)sizeof(struct pool_entry),
                    POOL_STARTING_CAPACITY)) {
        return 0;
    }

    p->algorithm = algorithm;

    /*
     * Taken once, here, rather than recomputed per entry. It is eight sprites
     * and eight encodes -- cheap, but not free, and doing it on every add would
     * make adding ten thousand entries do eighty thousand pieces of work for an
     * answer that cannot change while the program is running.
     */
    p->paintbrush_now = sprite_paintbrush_fingerprint();

    return 1;
}
/* }}} */

/* {{{ void pool_release */
void pool_release(struct sprite_pool *p)
{
    block_release(&p->entries);
    memset(p, 0, sizeof(*p));
}
/* }}} */

/* {{{ int pool_category_is_sound */
int pool_category_is_sound(const char *category)
{
    uint32_t i;

    if (category[0] == '\0') {
        return 0;
    }

    for (i = 0; category[i] != '\0'; i++) {
        char c = category[i];

        /* Lowercase letters, digits, and dashes. Nothing else, because this
         * becomes a filename and a category with a slash in it names a file
         * somewhere else entirely. */
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-') {
            continue;
        }
        return 0;
    }

    if (i > SPRITE_NAME_MAX) {
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ static struct pool_entry *entry_at */
static struct pool_entry *entry_at(struct sprite_pool *p, uint32_t entry)
{
    if (entry == POOL_NOTHING || entry >= p->entries.count) {
        /* Index 0 is the zeroed sentinel, which reads as an entry nobody has
         * rated in a category with no name. A caller that ignores the return
         * value of the function that handed it this index gets nothing rather
         * than somebody else's record. */
        return (struct pool_entry *)block_at(&p->entries, POOL_NOTHING);
    }

    return (struct pool_entry *)block_at(&p->entries, entry);
}
/* }}} */

/* {{{ const struct pool_entry *pool_at */
const struct pool_entry *pool_at(const struct sprite_pool *p, uint32_t entry)
{
    if (entry == POOL_NOTHING || entry >= p->entries.count) {
        return (const struct pool_entry *)block_at_const(&p->entries, POOL_NOTHING);
    }

    return (const struct pool_entry *)block_at_const(&p->entries, entry);
}
/* }}} */

/* {{{ uint32_t pool_count */
uint32_t pool_count(const struct sprite_pool *p)
{
    /* The sentinel at index 0 is not an entry anybody put there. */
    return p->entries.count - 1u;
}
/* }}} */

/* {{{ uint32_t pool_add */
uint32_t pool_add(struct sprite_pool *p, const char *category, uint64_t seed,
                  uint64_t when)
{
    uint32_t index;
    struct pool_entry *e;
    uint32_t already;

    if (!pool_category_is_sound(category)) {
        return POOL_NOTHING;
    }

    /*
     * The same description twice is the same picture twice. Handing back the
     * existing entry rather than making a second one keeps a rating attached to
     * a picture rather than to one of several identical rows -- otherwise a
     * person rates a goblin, the generator offers the same goblin again, and the
     * pool holds one rated and one unrated copy of the same thing.
     */
    already = pool_find(p, category, seed);
    if (already != POOL_NOTHING) {
        return already;
    }

    index = block_alloc(&p->entries);
    if (index == POOL_NOTHING) {
        return POOL_NOTHING;
    }

    e = entry_at(p, index);

    snprintf(e->category, sizeof(e->category), "%.31s", category);
    e->seed       = seed;
    e->paintbrush = p->paintbrush_now;
    e->canvas     = SPRITE_CANVAS;

    /*
     * Under rate-on-arrival the machine speaks immediately, because if
     * everything is kept and only a little is ever looked at, the pool is
     * overwhelmingly unrated -- and a floor of "tier four or better" would then
     * exclude nearly the whole library. Under judge-then-curate nothing is rated
     * until a person looks, which is the point of that algorithm.
     */
    if (p->algorithm == POOL_RATE_ON_ARRIVAL) {
        pool_rate_by_machine(p, index, when);
    }

    return index;
}
/* }}} */

/* {{{ uint32_t pool_find */
uint32_t pool_find(const struct sprite_pool *p, const char *category, uint64_t seed)
{
    uint32_t i;

    for (i = 1; i < p->entries.count; i++) {
        const struct pool_entry *e = pool_at(p, i);

        if (e->seed == seed && strcmp(e->category, category) == 0) {
            return i;
        }
    }

    return POOL_NOTHING;
}
/* }}} */

/* {{{ int pool_sprite */
int pool_sprite(const struct sprite_pool *p, uint32_t entry, struct sprite *into)
{
    const struct pool_entry *e = pool_at(p, entry);

    if (e->category[0] == '\0') {
        return 0;
    }

    sprite_make(into, e->category, e->seed);

    /*
     * Made, not checked against the paintbrush it was made by. That is on
     * purpose: if the paintbrush has changed, this returns the CURRENT picture
     * for that description, which is what somebody looking at the pool today
     * wants to see. Whether it is the picture that was rated is a separate
     * question, answered by comparing the entry's fingerprint with the pool's --
     * and conflating the two would leave a caller unable to ask either.
     */
    return 1;
}
/* }}} */

/* {{{ int pool_rate_by_machine */
int pool_rate_by_machine(struct sprite_pool *p, uint32_t entry, uint64_t when)
{
    struct pool_entry *e = entry_at(p, entry);
    struct sprite s;

    if (e->category[0] == '\0') {
        return 0;
    }

    sprite_make(&s, e->category, e->seed);

    e->machine_tier = sprite_machine_tier(&s);
    e->machine_when = when;

    /* Nothing here touches the person's fields. That is the whole design. */
    return 1;
}
/* }}} */

/* {{{ int pool_rate_by_person */
int pool_rate_by_person(struct sprite_pool *p, uint32_t entry, uint8_t tier,
                        const char *who, uint64_t when)
{
    struct pool_entry *e = entry_at(p, entry);

    if (e->category[0] == '\0') {
        return 0;
    }

    /* One to five. Zero means unrated and is not a rating somebody can give;
     * anything above five is a caller with a different scale in mind, and
     * quietly clamping it would record an opinion nobody held. */
    if (tier < 1u || tier > 5u) {
        return 0;
    }

    if (who[0] == '\0' || strlen(who) > RATER_NAME_MAX) {
        return 0;
    }

    /*
     * A name with a space in it would split a line of the index into more fields
     * than the reader expects, and the reader would then quietly mis-parse every
     * entry after it. Refused here rather than escaped everywhere.
     */
    if (strchr(who, ' ') != NULL || strchr(who, '\n') != NULL) {
        return 0;
    }

    e->person_tier = tier;
    e->person_when = when;
    snprintf(e->person_name, sizeof(e->person_name), "%.31s", who);

    /* And nothing here touches the machine's fields, so the correction is
     * recorded without destroying what it corrected. */
    return 1;
}
/* }}} */

/* {{{ uint8_t pool_tier */
uint8_t pool_tier(const struct sprite_pool *p, uint32_t entry)
{
    const struct pool_entry *e = pool_at(p, entry);

    /* The person's where there is one. That is the whole of "both write the same
     * field and the person's wins", except that nothing was overwritten. */
    if (e->person_tier != TIER_UNRATED) {
        return e->person_tier;
    }

    return e->machine_tier;
}
/* }}} */

/* {{{ uint8_t pool_tier_provenance */
uint8_t pool_tier_provenance(const struct sprite_pool *p, uint32_t entry)
{
    const struct pool_entry *e = pool_at(p, entry);

    if (e->person_tier != TIER_UNRATED) {
        return RATED_BY_PERSON;
    }
    if (e->machine_tier != TIER_UNRATED) {
        return RATED_BY_MACHINE;
    }
    return RATED_BY_NOBODY;
}
/* }}} */

/* {{{ uint32_t pool_survivors */
uint32_t pool_survivors(const struct sprite_pool *p, const char *category,
                        uint8_t floor, uint8_t trust,
                        uint32_t *into, uint32_t capacity)
{
    uint32_t found = 0;
    uint32_t i;

    for (i = 1; i < p->entries.count; i++) {
        const struct pool_entry *e = pool_at(p, i);
        uint8_t tier;

        if (strcmp(e->category, category) != 0) {
            continue;
        }

        /*
         * Under TRUST_A_PERSON an unrated-by-a-person entry does not survive,
         * however well the machine thought of it. That is a smaller and more
         * trustworthy answer to a different question, and offering only the
         * larger one would lose the distinction exactly when it matters.
         */
        if (trust == TRUST_A_PERSON) {
            tier = e->person_tier;
        } else {
            tier = pool_tier(p, i);
        }

        if (tier == TIER_UNRATED || tier < floor) {
            continue;
        }

        /*
         * Counted whether or not it fitted. A caller comparing two floors with a
         * small array still gets the true trade, and a count that silently
         * stopped at the array's end would report raising a floor as free.
         */
        if (found < capacity) {
            into[found] = i;
        }
        found++;
    }

    return found;
}
/* }}} */

/* {{{ uint32_t pool_in_category */
uint32_t pool_in_category(const struct sprite_pool *p, const char *category)
{
    uint32_t found = 0;
    uint32_t i;

    for (i = 1; i < p->entries.count; i++) {
        if (strcmp(pool_at(p, i)->category, category) == 0) {
            found++;
        }
    }

    return found;
}
/* }}} */

/* {{{ uint32_t pool_from_another_paintbrush */
uint32_t pool_from_another_paintbrush(const struct sprite_pool *p)
{
    uint32_t found = 0;
    uint32_t i;

    for (i = 1; i < p->entries.count; i++) {
        if (pool_at(p, i)->paintbrush != p->paintbrush_now) {
            found++;
        }
    }

    return found;
}
/* }}} */

/* ------------------------------------------------------------------------- */
/* Writing it down.                                                            */
/* ------------------------------------------------------------------------- */

/*
 * The index is text, one line per entry, fields separated by single spaces.
 *
 * Text because a person has to be able to read it, because it has to diff, and
 * because a binary index of a library nobody may delete from is a library
 * nobody can repair. A name with a space in it is refused at the moment of
 * rating rather than escaped here -- one refusal instead of an escaping rule at
 * every place that ever writes a line.
 */
/* {{{ static void write_entry_line */
static void write_entry_line(const struct pool_entry *e, char *into, uint32_t capacity)
{
    snprintf(into, capacity,
             "%.31s %llu %016llX %u %u %llu %u %llu %.31s\n",
             e->category,
             (unsigned long long)e->seed,
             (unsigned long long)e->paintbrush,
             (unsigned)e->canvas,
             (unsigned)e->machine_tier,
             (unsigned long long)e->machine_when,
             (unsigned)e->person_tier,
             (unsigned long long)e->person_when,
             e->person_name[0] == '\0' ? "-" : e->person_name);
}
/* }}} */

/* {{{ int pool_write */
int pool_write(const struct sprite_pool *p, const char *directory, const char **why)
{
    static char reason[256];
    char path[512];
    FILE *index;
    uint32_t i;

    snprintf(path, sizeof(path), "%.400s/index", directory);

    index = fopen(path, "w");
    if (index == NULL) {
        snprintf(reason, sizeof(reason),
                 "the pool's index could not be opened for writing at %.150s"
                 " -- does the directory exist?", path);
        *why = reason;
        return 0;
    }

    fprintf(index, "%s\n", POOL_FILE_HEADER);
    fprintf(index, "algorithm %s\n",
            p->algorithm == POOL_RATE_ON_ARRIVAL ? "rate-on-arrival"
                                                 : "judge-then-curate");
    fprintf(index, "paintbrush %016llX\n", (unsigned long long)p->paintbrush_now);
    fprintf(index, "# category seed paintbrush canvas"
                   " machine-tier machine-when person-tier person-when who\n");
    fprintf(index, "# a tier of 0 means nobody said. no line is ever removed.\n");

    for (i = 1; i < p->entries.count; i++) {
        char line[POOL_LINE_MAX];

        write_entry_line(pool_at(p, i), line, sizeof(line));
        fputs(line, index);
    }

    fclose(index);

    /*
     * And one file per entry, holding the picture itself.
     *
     * Written even though the description regenerates it, because the point of
     * choosing a format somebody can open is that somebody can open it. A pool
     * that stored only descriptions would be a pool you need this program to
     * look at.
     */
    for (i = 1; i < p->entries.count; i++) {
        const struct pool_entry *e = pool_at(p, i);
        struct sprite s;
        char svg[4096];
        uint32_t length;
        FILE *file;

        sprite_make(&s, e->category, e->seed);
        length = sprite_to_svg(&s, svg, sizeof(svg));

        if (length == 0) {
            snprintf(reason, sizeof(reason),
                     "%.31s seed %llu would not fit in the encoder's buffer",
                     e->category, (unsigned long long)e->seed);
            *why = reason;
            return 0;
        }

        snprintf(path, sizeof(path), "%.400s/%.31s-%llu.svg",
                 directory, e->category, (unsigned long long)e->seed);

        file = fopen(path, "w");
        if (file == NULL) {
            snprintf(reason, sizeof(reason),
                     "could not write %.200s", path);
            *why = reason;
            return 0;
        }

        fwrite(svg, 1, length, file);
        fclose(file);
    }

    *why = "";
    return 1;
}
/* }}} */

/* {{{ static int read_hex */
static int read_hex(const char *text, uint64_t *value)
{
    uint64_t result = 0;
    uint32_t i;

    for (i = 0; text[i] != '\0'; i++) {
        char c = text[i];
        uint64_t digit;

        if (c >= '0' && c <= '9') {
            digit = (uint64_t)(c - '0');
        } else if (c >= 'A' && c <= 'F') {
            digit = (uint64_t)(c - 'A') + 10u;
        } else if (c >= 'a' && c <= 'f') {
            digit = (uint64_t)(c - 'a') + 10u;
        } else {
            return 0;
        }

        result = (result << 4) | digit;
    }

    if (i == 0) {
        return 0;
    }

    *value = result;
    return 1;
}
/* }}} */

/* {{{ int pool_read */
int pool_read(struct sprite_pool *p, const char *directory, const char **why)
{
    static char reason[256];
    char path[512];
    char line[POOL_LINE_MAX];
    FILE *index;
    uint32_t line_number = 0;

    snprintf(path, sizeof(path), "%.400s/index", directory);

    index = fopen(path, "r");
    if (index == NULL) {
        snprintf(reason, sizeof(reason),
                 "there is no pool index at %.200s", path);
        *why = reason;
        return 0;
    }

    if (fgets(line, sizeof(line), index) == NULL
        || strncmp(line, POOL_FILE_HEADER, strlen(POOL_FILE_HEADER)) != 0) {
        fclose(index);
        snprintf(reason, sizeof(reason),
                 "%.120s does not begin with '%.20s', so it is not a pool"
                 " index -- or it is a version this program does not know",
                 path, POOL_FILE_HEADER);
        *why = reason;
        return 0;
    }
    line_number = 1;

    while (fgets(line, sizeof(line), index) != NULL) {
        char category[SPRITE_NAME_MAX + 8];
        char paintbrush_text[32];
        char who[RATER_NAME_MAX + 8];
        unsigned long long seed = 0;
        unsigned long long machine_when = 0;
        unsigned long long person_when = 0;
        unsigned canvas = 0;
        unsigned machine_tier = 0;
        unsigned person_tier = 0;
        uint64_t paintbrush = 0;
        uint32_t index_of_entry;
        struct pool_entry *e;
        int fields;

        line_number++;

        /* Comments and the two header lines that are not entries. */
        if (line[0] == '#' || line[0] == '\n'
            || strncmp(line, "algorithm ", 10) == 0
            || strncmp(line, "paintbrush ", 11) == 0) {
            if (strncmp(line, "algorithm judge-then-curate", 27) == 0) {
                p->algorithm = POOL_JUDGE_THEN_CURATE;
            } else if (strncmp(line, "algorithm rate-on-arrival", 25) == 0) {
                p->algorithm = POOL_RATE_ON_ARRIVAL;
            }
            continue;
        }

        fields = sscanf(line, "%39s %llu %31s %u %u %llu %u %llu %39s",
                        category, &seed, paintbrush_text, &canvas,
                        &machine_tier, &machine_when,
                        &person_tier, &person_when, who);

        /*
         * Nine fields or the line is not understood, and a line not understood
         * stops the read.
         *
         * A reader that skipped a line it did not like would be a pool quietly
         * deleting entries, which is the one thing this whole file exists to
         * prevent -- and it would do it silently, at load, months after whatever
         * corrupted the line.
         */
        if (fields != 9) {
            fclose(index);
            snprintf(reason, sizeof(reason),
                     "line %u of the pool index has %d fields where 9 were"
                     " expected, and a pool must not lose an entry it could not"
                     " read", (unsigned)line_number, fields);
            *why = reason;
            return 0;
        }

        if (!read_hex(paintbrush_text, &paintbrush)) {
            fclose(index);
            snprintf(reason, sizeof(reason),
                     "line %u names a paintbrush '%.32s' that is not"
                     " hexadecimal", (unsigned)line_number, paintbrush_text);
            *why = reason;
            return 0;
        }

        if (!pool_category_is_sound(category)) {
            fclose(index);
            snprintf(reason, sizeof(reason),
                     "line %u names a category '%.40s' that a pool cannot hold"
                     " -- lowercase letters, digits and dashes only",
                     (unsigned)line_number, category);
            *why = reason;
            return 0;
        }

        if (machine_tier > 5u || person_tier > 5u) {
            fclose(index);
            snprintf(reason, sizeof(reason),
                     "line %u has a tier above 5, which is not a tier on this"
                     " scale", (unsigned)line_number);
            *why = reason;
            return 0;
        }

        index_of_entry = block_alloc(&p->entries);
        if (index_of_entry == POOL_NOTHING) {
            fclose(index);
            snprintf(reason, sizeof(reason),
                     "ran out of memory reading line %u", (unsigned)line_number);
            *why = reason;
            return 0;
        }

        e = entry_at(p, index_of_entry);

        snprintf(e->category, sizeof(e->category), "%.31s", category);
        e->seed         = (uint64_t)seed;
        e->paintbrush   = paintbrush;
        e->canvas       = (uint32_t)canvas;
        e->machine_tier = (uint8_t)machine_tier;
        e->machine_when = (uint64_t)machine_when;
        e->person_tier  = (uint8_t)person_tier;
        e->person_when  = (uint64_t)person_when;

        if (strcmp(who, "-") != 0) {
            snprintf(e->person_name, sizeof(e->person_name), "%.31s", who);
        }
    }

    fclose(index);
    *why = "";
    return 1;
}
/* }}} */
