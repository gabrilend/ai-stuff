/*
 * 020-test-harness.h -- the smallest thing that can tell you what broke.
 *
 * Tests in this project are cheap and there are meant to be a great many of
 * them, so the machinery for writing one has to be nearly free. This is that
 * machinery: three macros and a counter.
 *
 * It deliberately does not stop at the first failure. A run reports every check
 * that failed, because when a change breaks six things at once, six lines is a
 * shape you can recognise and one line is a mystery you have to iterate on.
 *
 * Every failure names the file, the line, what was expected, and what was found.
 * A test that says "failed" and nothing else is a test that costs more to
 * diagnose than it saved.
 */

#ifndef VTT_TEST_HARNESS_H
#define VTT_TEST_HARNESS_H

#include <stdio.h>
#include <stdint.h>

static int vtt_checks_run    = 0;
static int vtt_checks_failed = 0;
static const char *vtt_current_case = "(none)";

/*
 * Names the group of checks that follow. Printed only when something inside the
 * group fails, so a passing run stays quiet and a failing one says where it was.
 */
#define TEST_CASE(name) \
    do { vtt_current_case = (name); } while (0)

/* {{{ static inline void vtt_report_failure */
static inline void vtt_report_failure(const char *file, int line, const char *expression)
{
    vtt_checks_failed++;
    fprintf(stderr, "    FAIL  %s:%d\n", file, line);
    fprintf(stderr, "          case: %s\n", vtt_current_case);
    fprintf(stderr, "          check: %s\n", expression);
}
/* }}} */

/* A check with no values worth printing. */
#define CHECK(expression)                                                     \
    do {                                                                      \
        vtt_checks_run++;                                                     \
        if (!(expression)) {                                                  \
            vtt_report_failure(__FILE__, __LINE__, #expression);              \
        }                                                                     \
    } while (0)

/*
 * A check between two integers. Separate from CHECK because the two values are
 * the entire diagnostic -- "expected 512, found 511" ends an investigation that
 * "a == b was false" only begins.
 */
#define CHECK_EQ(found, expected)                                             \
    do {                                                                      \
        int64_t vtt_f = (int64_t)(found);                                     \
        int64_t vtt_e = (int64_t)(expected);                                  \
        vtt_checks_run++;                                                     \
        if (vtt_f != vtt_e) {                                                 \
            vtt_checks_failed++;                                              \
            fprintf(stderr, "    FAIL  %s:%d\n", __FILE__, __LINE__);         \
            fprintf(stderr, "          case: %s\n", vtt_current_case);        \
            fprintf(stderr, "          %s\n", #found);                        \
            fprintf(stderr, "          expected %lld, found %lld\n",          \
                    (long long)vtt_e, (long long)vtt_f);                      \
        }                                                                     \
    } while (0)

/*
 * A check that two integers are within a tolerance of each other. Needed because
 * a fixed-point value read from a table is allowed to be a step or two off the
 * exact answer, and pretending otherwise would mean either a useless test or a
 * table with impossible precision.
 *
 * Every use of this should be able to say why its tolerance is what it is.
 */
#define CHECK_NEAR(found, expected, tolerance)                                \
    do {                                                                      \
        int64_t vtt_f = (int64_t)(found);                                     \
        int64_t vtt_e = (int64_t)(expected);                                  \
        int64_t vtt_d = (vtt_f > vtt_e) ? (vtt_f - vtt_e) : (vtt_e - vtt_f);  \
        vtt_checks_run++;                                                     \
        if (vtt_d > (int64_t)(tolerance)) {                                   \
            vtt_checks_failed++;                                              \
            fprintf(stderr, "    FAIL  %s:%d\n", __FILE__, __LINE__);         \
            fprintf(stderr, "          case: %s\n", vtt_current_case);        \
            fprintf(stderr, "          %s\n", #found);                        \
            fprintf(stderr, "          expected %lld +/- %lld, found %lld"    \
                            " (off by %lld)\n",                               \
                    (long long)vtt_e, (long long)(tolerance),                 \
                    (long long)vtt_f, (long long)vtt_d);                      \
        }                                                                     \
    } while (0)

/*
 * Ends a test program. Returns the process exit code: zero when everything
 * passed, one otherwise, so that the build can simply look at the status.
 */
/* {{{ static inline int vtt_test_finish */
static inline int vtt_test_finish(const char *program)
{
    if (vtt_checks_failed == 0) {
        printf("    %d checks passed  (%s)\n", vtt_checks_run, program);
        return 0;
    }

    fprintf(stderr, "    %d of %d checks failed  (%s)\n",
            vtt_checks_failed, vtt_checks_run, program);
    return 1;
}
/* }}} */

#endif
