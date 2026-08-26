/*
 * 100-read-engraving-main.c -- the reader, as a program you can run.
 *
 * WHAT THIS IS: the other half of the pair. Hand it a carving and it tells you
 * the eight numbers that are in it, or tells you exactly which line and column
 * it stopped at and why.
 *
 * It does not know which animal it is looking at. It scans the characters, finds
 * the rectangles that walls enclose, and reads the label and the number out of
 * each one -- which is the strongest form the independence can take, because the
 * writer could get the anatomy wrong in a way that still produced a valid tiling
 * and this would not care.
 *
 * IT IS FRAGILE ON PURPOSE. A whitespace change is refused. A hand-edit is
 * refused. There is no salvage pass and no "we recovered four of the eight
 * cells". The argument is that the art is a checksum you can see: a corrupted
 * binary file looks exactly like a good one until something reads it, and a
 * corrupted engraving LOOKS corrupted from across the room. A record log that
 * gets mangled is a record log that is gone, and that is what the sharing script
 * is for.
 *
 * Usage:
 *   100-read-engraving <path>              -- print the values
 *   100-read-engraving <path> --check      -- say nothing; the exit status is the answer
 *   100-read-engraving <path> --cells      -- print the chambers as they were found
 */

#include "097-read-engraving.h"
#include "094-creature.h"

#include <stdio.h>
#include <string.h>

/* {{{ int main */
int main(int argc, char **argv)
{
    struct engraving found;
    struct engraving_error why;
    struct record r;
    char sentence[256];
    const char *path = NULL;
    int quiet = 0;
    int cells_only = 0;
    int i;

    setvbuf(stdout, NULL, _IOLBF, 0);

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--check") == 0) {
            quiet = 1;
        } else if (strcmp(argv[i], "--cells") == 0) {
            cells_only = 1;
        } else if (argv[i][0] == '-') {
            printf("100-read-engraving: '%s' is not an option this program"
                   " knows.\n", argv[i]);
            return 1;
        } else {
            path = argv[i];
        }
    }

    if (path == NULL) {
        printf("100-read-engraving: no path given. Say which engraving to read.\n");
        return 1;
    }

    if (!engraving_read_file(&found, path, &why)) {
        if (!quiet) {
            printf("This is not a carving that can be read.\n  %s\n",
                   engraving_error_sentence(&why, sentence, sizeof(sentence)));
        }
        return 1;
    }

    if (cells_only) {
        /* What was actually on the page, before anything decided whether it
         * amounts to a record. The two questions are separate. */
        for (i = 0; i < (int)found.cell_count; i++) {
            printf("  line %u column %u  %-10s %s\n",
                   (unsigned)found.cells[i].row,
                   (unsigned)found.cells[i].column,
                   found.cells[i].label,
                   found.cells[i].value);
        }
        return 0;
    }

    if (!engraving_to_record(&found, &r, &why)) {
        if (!quiet) {
            printf("This is a well-formed carving and not a record.\n  %s\n",
                   engraving_error_sentence(&why, sentence, sizeof(sentence)));
        }
        return 1;
    }

    if (quiet) {
        return 0;
    }

    printf("A %s, seed %016llX.\n\n",
           creature_name(creature_from_seed(found.seed)),
           (unsigned long long)found.seed);

    for (i = 0; i < (int)RECORD_CELLS; i++) {
        char text[RECORD_VALUE_MAX + 8];

        record_value_text(&r, (uint32_t)i, text, sizeof(text));
        printf("  %-10s %s\n", record_label((uint32_t)i), text);
    }

    return 0;
}
/* }}} */
