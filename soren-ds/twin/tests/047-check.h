/*
 * 047-check.h — the smallest possible test harness for the twin's tests.
 *
 * General description: CHECK(condition, "what should be true") counts a
 * pass or prints a failure with the file and line; a test program ends
 * with CHECK_DONE(), which prints a one-line summary and exits nonzero if
 * anything failed. scripts/test-twin runs every test program and reads the
 * exit status.
 */
#ifndef SOREN_CHECK_H
#define SOREN_CHECK_H

#include <stdio.h>
#include <stdlib.h>

static int check_passed;
static int check_failed;

#define CHECK(cond, ...) do {                                              \
    if (cond) {                                                            \
        check_passed++;                                                    \
    } else {                                                               \
        check_failed++;                                                    \
        fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__);               \
        fprintf(stderr, __VA_ARGS__);                                      \
        fprintf(stderr, "\n");                                             \
    }                                                                      \
} while (0)

#define CHECK_DONE(name) do {                                              \
    printf("%-40s %s  (%d passed, %d failed)\n", name,                     \
           check_failed ? "FAIL" : "ok", check_passed, check_failed);      \
    exit(check_failed ? 1 : 0);                                            \
} while (0)

#endif
