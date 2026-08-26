/*
 * 099-engrave-main.c -- the writer, as a program you can run.
 *
 * WHAT THIS IS, for somebody who has never opened it: at the end of a session
 * the server has eight numbers about the evening -- how long it ran, how many
 * things people asked for, how many were refused, and a checksum saying the
 * whole thing could be replayed. This turns those eight numbers into a text file
 * that is drawn as an ornate metal carving of an animal, where the animal's
 * lines ARE the walls of the table the numbers sit in.
 *
 * It is one of a pair pointing in opposite directions, and the two share no code
 * at all. This one composes the creature around the values; 100-read-engraving
 * walks a finished carving and pulls the values back out as a stranger would.
 * Two implementations that share a parser agree with each other about their own
 * mistakes.
 *
 * Usage:
 *   099-engrave <path>                        -- engrave, with made-up numbers
 *   099-engrave <path> --seed <hex>           -- choose the animal
 *   099-engrave <path> --plain                -- the plain alphabet
 *   099-engrave <path> --beats N --turns N ...
 *
 * Named values so a person can engrave a specific record by hand. Everything
 * unnamed keeps a small default rather than zero, because a carving of all
 * zeroes tells you nothing about whether the widths are right.
 */

#include "096-engrave.h"
#include "094-creature.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* {{{ static int value_argument */
static int value_argument(const char *given, const char *name, uint64_t *into,
                          const char *next)
{
    char wanted[32];

    snprintf(wanted, sizeof(wanted), "--%.24s", name);

    if (strcmp(given, wanted) != 0) {
        return 0;
    }

    if (next == NULL) {
        printf("099-engrave: %s needs a number after it.\n", wanted);
        exit(1);
    }

    *into = strtoull(next, NULL, 0);
    return 1;
}
/* }}} */

/* {{{ int main */
int main(int argc, char **argv)
{
    struct record r;
    const char *path = NULL;
    const char *why = "";
    uint8_t alphabet = ALPHABET_CARVED;
    int i;

    setvbuf(stdout, NULL, _IOLBF, 0);

    memset(&r, 0, sizeof(r));

    /* Small defaults rather than zeroes. A carving of all zeroes says nothing
     * about whether the chambers are the right size. */
    r.value[CELL_BEATS]     = 1200;
    r.value[CELL_TURNS]     = 12;
    r.value[CELL_SEATS]     = 4;
    r.value[CELL_COMMANDS]  = 96;
    r.value[CELL_REFUSED]   = 3;
    r.value[CELL_ROLLBACKS] = 1;
    r.value[CELL_THINGS]    = 37;
    r.value[CELL_CHECKSUM]  = 0x0123456789ABCDEFull;
    r.seed = 1;

    for (i = 1; i < argc; i++) {
        const char *next = (i + 1 < argc) ? argv[i + 1] : NULL;
        uint32_t cell;
        int taken = 0;

        if (strcmp(argv[i], "--plain") == 0) {
            alphabet = ALPHABET_PLAIN;
            continue;
        }

        if (strcmp(argv[i], "--seed") == 0) {
            if (next == NULL) {
                printf("099-engrave: --seed needs a hexadecimal number.\n");
                return 1;
            }
            r.seed = strtoull(next, NULL, 16);
            i++;
            continue;
        }

        for (cell = 0; cell < RECORD_CELLS && !taken; cell++) {
            if (value_argument(argv[i], record_label(cell), &r.value[cell], next)) {
                taken = 1;
                i++;
            }
        }

        if (taken) {
            continue;
        }

        if (argv[i][0] == '-') {
            printf("099-engrave: '%s' is not an option this program knows.\n",
                   argv[i]);
            return 1;
        }

        path = argv[i];
    }

    if (path == NULL) {
        printf("099-engrave: no path given. Say where the engraving should go.\n");
        return 1;
    }

    if (!engrave_to_file(&r, alphabet, path, &why)) {
        printf("099-engrave: %s\n", why);
        return 1;
    }

    printf("Engraved a %s at %s\n",
           creature_name(creature_from_seed(r.seed)), path);
    return 0;
}
/* }}} */
