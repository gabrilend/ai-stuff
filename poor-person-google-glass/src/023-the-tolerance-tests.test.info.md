<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 009 (tolerance calculations): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 023-the-tolerance-tests.test

Checks the engine against hand-known answers (a linear stack's worst case is the sum of tolerances, its spread the root-sum-square), that a size still has a spread, that broken files are refused with every problem named, and that every calculation in input/calculations/ works out the same twice. Run by scripts/run-tests.
