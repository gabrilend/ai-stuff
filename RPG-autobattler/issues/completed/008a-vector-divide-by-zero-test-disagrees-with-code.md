# Issue 008a: Vector Divide-by-Zero Test Disagrees with the Code

## Current Behavior
`tests/test_vector_math.lua`'s `test_edge_cases` expects
`Vector2:new(1, 1):divide(0)` to return a zero vector. `Vector2:divide` in
`src/utils/vector2.lua` raises "Division by zero in Vector2:divide" instead.
The `return Vector2:new(0, 0)` after that `error` can never run, which
suggests the error was added later on purpose. The suite stops at that
test, so the tests after it never run. This was hidden while the suite
hung on `Vector2.lerp`; it fails the same way on main without that fix.

## Intended Behavior
The test and the code agree, and the whole vector suite runs to the end.

## Suggested Implementation Steps
1. Decide which is right. An error finds bugs early; a zero vector keeps a
   frame from crashing when two units share a position.
2. Change the other one to match: either the test expects an error (with
   `pcall`), or `divide` drops the `error` line. `divide_in_place` should
   behave the same way.
3. Run `tests/test_vector_math.lua` under luajit and lua 5.4 to the end.

## Related Issues
- 008-implement-vector-math-utilities.md (completed)

## What Happened

The code was wrong, and the test is right. `Vector2:divide(0)` now returns
the zero vector, and `divide_in_place(0)` sets it. The whole
`tests/test_vector_math.lua` suite now runs to the end under LuaJIT and
Lua 5.4, and `run` runs it.

### Decisions
- **Zero vector, not an error.** The evidence for the intent:
  - the test says "Division by zero should return zero vector";
  - the `return Vector2:new(0, 0)` written after the `error` shows the
    same intent;
  - `normalize` already returns the zero vector for a zero length;
  - issue 008 asks to "handle edge cases (zero vectors, etc.)".
  In a game loop, two units on the same spot shouldn't crash a frame.
  Both lines came in the same commit, so history doesn't say which came
  first.
- **The callers are all safe.** All three in
  `obstacle_avoidance_system.lua` divide by a count or by 2. None relied
  on the error.
- **A check for `divide_in_place(0)` was added** to the edge-case test, so
  the two stay in step.
