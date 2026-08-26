# 020-test-harness

Three macros and a counter. The smallest thing that can tell you what broke.

Tests here are meant to be cheap and numerous, so writing one has to be nearly
free. Included by every `*-test-*.c` file; there is nothing to link.

## What it offers

| Macro | Use |
| --- | --- |
| `TEST_CASE(name)` | Names the group of checks that follow. Printed only when something in the group fails, so a passing run stays quiet. |
| `CHECK(expression)` | A check with no values worth printing. |
| `CHECK_EQ(found, expected)` | Two integers. Separate from `CHECK` because the values are the whole diagnostic — "expected 512, found 511" ends an investigation that "a == b was false" only begins. |
| `CHECK_NEAR(found, expected, tolerance)` | Within a tolerance. Needed because a value read from a fixed-point table may sit a step or two off exact. Every use should be able to say why its tolerance is what it is. |

`vtt_test_finish(name)` ends a test program and returns the process exit code —
zero when everything passed — so the build can just read the status.

## Two decisions worth knowing

**It does not stop at the first failure.** When a change breaks six things at
once, six lines is a shape you can recognise; one line is a mystery you have to
iterate on.

**Every failure names file, line, case, expectation, and actual value.** A test
that says "failed" and nothing else costs more to diagnose than it saved.
