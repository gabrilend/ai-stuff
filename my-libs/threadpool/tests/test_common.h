/*
 * Test helpers shared by the threadpool test files.
 *
 * No framework: an assertion that fails prints where and returns 1 from the
 * test function, a pass prints the test's name, and WAIT_UNTIL polls a
 * condition every millisecond up to a generous timeout so that tests wait for
 * work to happen instead of sleeping a fixed time and hoping.
 */

#ifndef THREADPOOL_TEST_COMMON_H
#define THREADPOOL_TEST_COMMON_H

#include "../src/threadpool_platform.h"
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

/* {{{ Test Macros */
#define TEST_ASSERT(cond, msg) do { \
    if (!(cond)) { \
        fprintf(stderr, "FAIL: %s:%d: %s\n", __FILE__, __LINE__, msg); \
        return 1; \
    } \
} while(0)

#define TEST_PASS(name) printf("PASS: %s\n", name)
/* }}} */

/* {{{ test_now_ms
 * Milliseconds on the monotonic clock. */
static inline uint64_t test_now_ms(void) {
    return tp_time_us() / 1000ULL;
}
/* }}} */

/* {{{ WAIT_UNTIL
 * Polls cond every 1ms until it holds or timeout_ms passes. A statement, not
 * a value: assert the condition afterwards. Sanitizer builds run slowly, so
 * timeouts are seconds even where the work takes microseconds. */
#define WAIT_UNTIL(cond, timeout_ms) \
    for (uint64_t wait_deadline_ = test_now_ms() + (timeout_ms); \
         !(cond) && test_now_ms() < wait_deadline_; ) \
        tp_sleep_us(1000)
/* }}} */

#endif /* THREADPOOL_TEST_COMMON_H */
