/*
 * 101-demo-phase-10.c -- a file that is a picture that is a spreadsheet.
 *
 * Phase ten's claim is that one artifact can be an interface element, a
 * persistence format and an artwork at once, without being worse at any of them.
 *
 * Six parts:
 *
 *   A SESSION           run for real, with commands, refusals and a rollback,
 *                       so that the numbers are numbers rather than invention.
 *   THE CARVING         a creature nobody chose in advance -- the seed picked it.
 *   THE ROUND TRIP      read back into variables, then engraved again from those
 *                       variables and compared BYTE FOR BYTE.
 *   ALL FOUR CREATURES  the same statistics, four animals, so you can see that
 *                       the carving is the table rather than a picture beside it.
 *   BROKEN ON PURPOSE   one digit typed into one cell, and the animal deforms.
 *   HANDED OVER         where the files are, and the script that shares one.
 *
 * Run through ./run-phase-demo 10.
 */

#include "096-engrave.h"
#include "097-read-engraving.h"
#include "094-creature.h"
#include "053-session.h"
#include "037-fixture.h"
#include "035-worldfile.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define SCRATCH    "/dev/shm/my-own-custom-vtt"
#define ENGRAVINGS SCRATCH "/engravings"

/* {{{ static void rule */
static void rule(const char *title)
{
    size_t i;
    size_t width = strlen(title);

    printf("\n  %s\n  ", title);
    for (i = 0; i < width; i++) {
        printf("-");
    }
    printf("\n\n");
}
/* }}} */

/*
 * A real session: bodies that move, orders that are refused, and a turn taken
 * back. Invented statistics would make the carving a picture of nothing, and the
 * whole point of the format is that it is a record.
 */
/* {{{ static void run_a_session */
static void run_a_session(struct record *r, struct world *w, struct pool *threads)
{
    struct session s;
    uint32_t innkeeper;
    uint32_t patron;
    uint32_t cup;
    int beat;

    fixture_make_two_rooms(w);

    innkeeper = world_add_thing(w);
    patron    = world_add_thing(w);
    cup       = world_add_thing(w);

    {
        struct thing *t = world_thing(w, innkeeper);
        t->x = M(4); t->y = M(4); t->radius = (uint16_t)(WC_ONE / 2); t->region = 1;
    }
    {
        struct thing *t = world_thing(w, patron);
        t->x = M(8); t->y = M(5); t->radius = (uint16_t)(WC_ONE / 2); t->region = 1;
    }
    {
        struct thing *t = world_thing(w, cup);
        t->x = M(6); t->y = M(6); t->radius = (uint16_t)(WC_ONE / 8); t->region = 1;
    }

    session_start(&s, w, threads, 918273, 8, 5);

    printf("    A tavern with three things in it, and five beats to a turn.\n\n");

    for (beat = 0; beat < 40; beat++) {
        if (beat % 5 == 0) {
            /* Somebody walks somewhere. */
            session_command(&s, VERB_ORDER_MOVE, innkeeper,
                            M(6 + (beat % 3)), M(7));
            session_command(&s, VERB_DRIVE, patron, (int32_t)(beat * 2048), 40);
        }

        if (beat % 7 == 0) {
            /* And somebody asks for something that cannot be done. Refusals are
             * one of the eight cells and a carving with a zero there would be a
             * carving of a session where nobody made a mistake. */
            session_command(&s, VERB_ORDER_MOVE, 0, M(1), M(1));
            session_command(&s, VERB_ORDER_MOVE, 9999, M(1), M(1));
        }

        session_tick(&s);

        /* One turn taken back, in the middle, so the rollback cell is not zero
         * either. */
        if (beat == 22 && session_can_roll_back_to(&s, s.turn - 1u)) {
            session_rollback(&s, s.turn - 1u, ROLLBACK_RETCON);
        }
    }

    record_gather(r, &s, 4);

    printf("      beats      %llu\n", (unsigned long long)r->value[CELL_BEATS]);
    printf("      turns      %llu\n", (unsigned long long)r->value[CELL_TURNS]);
    printf("      seats      %llu\n", (unsigned long long)r->value[CELL_SEATS]);
    printf("      commands   %llu\n", (unsigned long long)r->value[CELL_COMMANDS]);
    printf("      refused    %llu\n", (unsigned long long)r->value[CELL_REFUSED]);
    printf("      rollbacks  %llu\n", (unsigned long long)r->value[CELL_ROLLBACKS]);
    printf("      things     %llu\n", (unsigned long long)r->value[CELL_THINGS]);
    printf("      checksum   %016llX\n",
           (unsigned long long)r->value[CELL_CHECKSUM]);

    session_release(&s);
}
/* }}} */

/* {{{ static void show_the_carving */
static void show_the_carving(const struct record *r, char *text, uint32_t capacity)
{
    const char *why = "";
    uint32_t length;

    rule("The carving");

    length = engrave_to_text(r, ALPHABET_CARVED, text, capacity, &why);

    if (length == 0) {
        printf("    It could not be carved: %s\n", why);
        return;
    }

    printf("    Nobody chose the animal. The seed did, and the seed came from the\n");
    printf("    session -- so the creature belongs to that run.\n\n");

    fputs(text, stdout);

    printf("\n    Every line you can see is a cell wall. There is no picture layer\n");
    printf("    over a data layer; reading the engraving and reading the table are\n");
    printf("    the same act.\n");
}
/* }}} */

/* {{{ static void show_the_round_trip */
static void show_the_round_trip(const struct record *written, const char *first)
{
    struct engraving found;
    struct engraving_error why;
    struct record read_back;
    char sentence[256];
    char again[ENGRAVING_MAX_BYTES];
    const char *refusal = "";
    uint32_t length;
    uint32_t cell;

    rule("Read back, and then engraved again");

    if (!engraving_read_text(&found, first, &why)) {
        printf("    It would not read: %s\n",
               engraving_error_sentence(&why, sentence, sizeof(sentence)));
        return;
    }

    printf("    The reader does not know which animal this is. It scanned the\n");
    printf("    characters, found the rectangles that walls enclose, and read a\n");
    printf("    label and a number out of each one. It found %u chambers.\n\n",
           (unsigned)found.cell_count);

    if (!engraving_to_record(&found, &read_back, &why)) {
        printf("    It is a picture and not a record: %s\n",
               engraving_error_sentence(&why, sentence, sizeof(sentence)));
        return;
    }

    printf("      cell        engraved             read back\n");
    printf("      ---------   ------------------   ------------------\n");

    for (cell = 0; cell < RECORD_CELLS; cell++) {
        char a[RECORD_VALUE_MAX + 8];
        char b[RECORD_VALUE_MAX + 8];

        record_value_text(written, cell, a, sizeof(a));
        record_value_text(&read_back, cell, b, sizeof(b));

        printf("      %-9s   %-18s   %-18s  %s\n",
               record_label(cell), a, b,
               written->value[cell] == read_back.value[cell] ? "" : "<-- DIFFERS");
    }

    /*
     * The second half, and the one that matters. A reader that recovered a value
     * from somewhere other than its own chamber -- from the header, from a
     * default -- passes the comparison above and fails this one.
     */
    length = engrave_to_text(&read_back, ALPHABET_CARVED, again, sizeof(again),
                             &refusal);

    printf("\n    Engraved again, from what was read: %u bytes against %u,",
           (unsigned)length, (unsigned)strlen(first));
    printf(" and they are\n    %s.\n",
           (length == strlen(first) && memcmp(first, again, length) == 0)
               ? "IDENTICAL BYTE FOR BYTE" : "DIFFERENT, WHICH IS WRONG");

    printf("\n    That second comparison is the one worth having. A reader that\n");
    printf("    recovered a number by accident -- from the header, from a\n");
    printf("    default, from the chamber next door -- passes the table above and\n");
    printf("    fails the bytes.\n");
}
/* }}} */

/* {{{ static void show_all_four */
static void show_all_four(const struct record *r)
{
    uint8_t kind;

    rule("The same numbers, four animals");

    for (kind = 0; kind < CREATURE_COUNT; kind++) {
        struct record mine = *r;
        char text[ENGRAVING_MAX_BYTES];
        const char *why = "";
        uint64_t seed;

        /* Find a seed that draws this one. The mapping is a stirred hash, so
         * hunting for a seed is easier than inverting it and is exactly what a
         * caller who wants a particular animal would have to do. */
        for (seed = 1; seed < 100000u; seed++) {
            if (creature_from_seed(seed) == kind) {
                mine.seed = seed;
                break;
            }
        }

        printf("    --- %s ---\n\n", creature_name(kind));

        if (engrave_to_text(&mine, ALPHABET_CARVED, text, sizeof(text), &why) == 0) {
            printf("      could not be carved: %s\n", why);
            continue;
        }

        /* Only the carving, without the three header lines -- they are the same
         * three lines every time and this is about the shapes. */
        {
            const char *body = strstr(text, "\n\n");

            fputs(body != NULL ? body + 2 : text, stdout);
        }
        printf("\n");
    }

    printf("    Four tilings of the same eight cells. The chambers move, the\n");
    printf("    ornament follows them, and every number is in exactly one place.\n");
}
/* }}} */

/*
 * The argument for the fragility, demonstrated rather than claimed.
 */
/* {{{ static void print_line_at */
static void print_line_at(const char *text, uint32_t which, const char *prefix)
{
    const char *at = text;
    uint32_t line = 0;
    const char *stop;

    while (line < which && at != NULL) {
        at = strchr(at, '\n');
        if (at != NULL) {
            at++;
        }
        line++;
    }

    if (at == NULL) {
        return;
    }

    stop = strchr(at, '\n');
    printf("      %s|%.*s|\n", prefix,
           stop != NULL ? (int)(stop - at) : (int)strlen(at), at);
}
/* }}} */

/* {{{ static uint32_t line_number_of */
static uint32_t line_number_of(const char *text, const char *at)
{
    uint32_t line = 0;
    const char *p;

    for (p = text; p < at && *p != '\0'; p++) {
        if (*p == '\n') {
            line++;
        }
    }
    return line;
}
/* }}} */

/*
 * The argument for the fragility, demonstrated rather than claimed.
 */
/* {{{ static void break_it_on_purpose */
static void break_it_on_purpose(const char *sound, uint32_t length)
{
    static char damaged[ENGRAVING_MAX_BYTES];
    struct engraving found;
    struct engraving_error why;
    struct record r;
    char sentence[256];
    const char *at;
    uint32_t offset;
    uint32_t damaged_line;

    rule("Now one digit is typed into one cell");

    /*
     * The topmost band's first number, because that is where a shift is most
     * obvious: the row it is on moves and the three bands under it do not, so
     * every join between them stops meeting.
     */
    at = strstr(sound, record_label(CELL_BEATS));
    if (at == NULL) {
        printf("    (the beats chamber could not be found)\n");
        return;
    }

    /* The value sits on the line under the label. */
    at = strchr(at, '\n');
    if (at == NULL) {
        return;
    }
    at++;

    /* The first digit on that line. */
    while (*at != '\0' && !(*at >= '0' && *at <= '9')) {
        at++;
    }

    offset = (uint32_t)(at - sound);
    damaged_line = line_number_of(sound, at);

    memcpy(damaged, sound, offset);
    damaged[offset] = '9';
    memcpy(damaged + offset + 1u, sound + offset, length - offset);
    damaged[length + 1u] = '\0';

    printf("    Somebody opens it in an editor and puts a 9 in front of the\n");
    printf("    number of beats.\n\n");

    fputs(damaged, stdout);

    printf("\n    One character. Everything to the right of it on that line moved\n");
    printf("    one column, so the walls stopped meeting the walls below them:\n\n");

    printf("      before\n");
    print_line_at(sound, damaged_line, "  ");
    print_line_at(sound, damaged_line + 1u, "  ");
    printf("      after\n");
    print_line_at(damaged, damaged_line, "  ");
    print_line_at(damaged, damaged_line + 1u, "  ");

    printf("\n    That is the whole argument for the fragility. A corrupted binary\n");
    printf("    file looks exactly like a good one until something reads it. A\n");
    printf("    corrupted engraving LOOKS corrupted, from across the room, with\n");
    printf("    nothing running.\n");

    printf("\n    And the reader refuses it, with a place:\n\n");

    if (engraving_read_text(&found, damaged, &why)
        && engraving_to_record(&found, &r, &why)) {
        printf("      it was accepted, which is WRONG\n");
        return;
    }

    printf("      %s\n", engraving_error_sentence(&why, sentence, sizeof(sentence)));

    printf("\n    There is no salvage pass and no \"we recovered four of the eight\n");
    printf("    cells\". A record log that gets mangled is a record log that is\n");
    printf("    gone. That is the honest cost of the trade, and the sharing\n");
    printf("    script is the other half of it.\n");
}
/* }}} */

/* {{{ static void show_where_they_are */
static void show_where_they_are(const struct record *r)
{
    const char *why = "";
    char path[512];
    uint8_t kind;

    rule("Where they are, and handing one over");

    mkdir(SCRATCH, 0755);
    mkdir(ENGRAVINGS, 0755);

    for (kind = 0; kind < CREATURE_COUNT; kind++) {
        struct record mine = *r;
        uint64_t seed;

        for (seed = 1; seed < 100000u; seed++) {
            if (creature_from_seed(seed) == kind) {
                mine.seed = seed;
                break;
            }
        }

        snprintf(path, sizeof(path), "%s/%s.engraving",
                 ENGRAVINGS, creature_name(kind));

        if (engrave_to_file(&mine, ALPHABET_CARVED, path, &why)) {
            printf("      %s\n", path);
        } else {
            printf("      %s could not be written: %s\n", path, why);
        }
    }

    /* And the plain alphabet, which is a different artifact rather than a
     * degraded one -- for a terminal that cannot show the other. */
    snprintf(path, sizeof(path), "%s/plain.engraving", ENGRAVINGS);
    if (engrave_to_file(r, ALPHABET_PLAIN, path, &why)) {
        printf("      %s   (the plain alphabet)\n", path);
    }

    printf("\n    They are text. One file each. You can look at one before you\n");
    printf("    run anything, because it is a picture of an animal with numbers\n");
    printf("    in it.\n");

    printf("\n    To hand one to somebody:\n\n");
    printf("      ./share-engraving --list\n");
    printf("      ./share-engraving %s/dragon.engraving <where>\n", ENGRAVINGS);
    printf("      ./share-engraving --print %s/dragon.engraving\n", ENGRAVINGS);

    printf("\n    It validates before it copies, because handing somebody a broken\n");
    printf("    carving wastes both people's time and the reader already knows\n");
    printf("    how to tell.\n");

    printf("\n    And during play, the bridge hangs the last session's carving in\n");
    printf("    the action bar -- the strip that would ordinarily hold buttons.\n");
    printf("    A table's history is visible while the table is playing.\n");
}
/* }}} */

/* {{{ int main */
int main(void)
{
    static char text[ENGRAVING_MAX_BYTES];
    struct record r;
    struct world w;
    struct pool *threads = pool_start(2);

    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("\n");
    printf("  ===============================================================\n");
    printf("   PHASE TEN -- a file that is a picture that is a spreadsheet\n");
    printf("  ===============================================================\n");

    rule("A session, run for real");
    run_a_session(&r, &w, threads);

    show_the_carving(&r, text, sizeof(text));
    show_the_round_trip(&r, text);
    show_all_four(&r);
    break_it_on_purpose(text, (uint32_t)strlen(text));
    show_where_they_are(&r);

    printf("\n  ===============================================================\n");
    printf("   One thing, not three easier things.\n");
    printf("  ===============================================================\n\n");

    world_release(&w);
    pool_stop(threads);
    return 0;
}
/* }}} */
