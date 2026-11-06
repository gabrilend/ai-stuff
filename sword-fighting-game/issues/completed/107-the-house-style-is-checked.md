# 107 — The House Style Is Checked

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | none |
| Blocks | 108 |
| Files | `scripts/lint`, `docs/style-guide.md` |

## Current behavior

Built as `scripts/lint`, a table of rule functions over every Lua file in
src/, tests/, assets/, mods/, scripts/ and the two engine files. Two
departures from the plan: the column limit is 110, not 100 (reason in
docs/style-guide.md), and the fold rule follows the owner's format exactly:
the comment goes above the fold line, the fold line names the function
with empty parentheses, the definition is on the next line. Running it found
that format broken across the whole codebase once, and a one-off script
rewrote every fold.

## Intended behavior

`scripts/lint` reads every Lua file under src/, tests/ and scripts/ and reports
each breach with file and line. Every finding is an error (warnings are
errors). It checks:

1. **Reading order** — every src/ and tests/ file name starts with a
   three-digit index, no index is used twice, and none is above
   `.file-index-counter`.
2. **Companion page** — every src/ file has a `.info.md` beside it.
3. **Header** — the first lines are a comment saying what the file is.
4. **Folds** — every function definition is directly preceded by a
   `-- {{{ name` line and its `end` is followed by a `-- }}}` line; opens and
   closes balance.
5. **LuaJIT syntax only** — no integer division `//`, no `<const>` or
   `<close>` attributes, no bitwise operator symbols (`&`, `|`, `~` as binary,
   `<<`, `>>`) outside strings and comments.
6. **Indentation by tabs** — as st and dwm are written.
7. **Line length** at most 100 columns (tabs counted as 8, as in st).
8. **Dispatch, not chains** — an if-chain with three or more `elseif` is
   reported, with the suggestion to make it a table.

The style guide document explains each rule and where it came from.

## Suggested implementation steps

1. Write the linter as one Lua script with one function per rule and a table
   of rules, so a new rule is a new row.
2. Run it over the code as each phase lands; `./run-tests` runs it first.
