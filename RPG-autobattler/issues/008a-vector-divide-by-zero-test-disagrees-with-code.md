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
