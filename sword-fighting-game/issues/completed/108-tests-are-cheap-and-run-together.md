# 108 — Tests Are Cheap And Run Together

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 107 |
| Blocks | every issue's completion |
| Files | `run-tests`, `tests/000-run-all.lua`, `tests/0NN-*.lua` |

## Current behavior

Built: `./run-tests` runs the linter, then `tests/000-run-all.lua`, which
runs every numbered test file (031 the spine, 032 bodies, 033 the sword, 034
seeing it, 035 command and growth). Every stated rule that can be checked
without a window has a case; the fixed bugs (allies re-swapping forever,
first-strike bias) have regression cases.

## Intended behavior

`./run-tests` runs the linter, then every numbered test file under tests/
in order, under LuaJIT with no window. A test file returns a list of named
cases; each case is a function that raises an error on failure. The runner
prints one line per case and a total, and exits non-zero if anything failed.

Tests are written for every rule in docs/game-rules.md that can be stated as
"given this, that happens", and for every bug fixed.

## Suggested implementation steps

1. Write the runner and a tiny assertion helper (equal, near, truthy, raises).
2. Each later issue adds its own test file.
