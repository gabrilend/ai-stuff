# Issue 054: menu libraries keep their tables when sourced in a function

## Current Behavior

`libs/lua-menu.sh` makes its tables with plain `declare -A` / `declare -a` at
the top of the file. Bash makes every `declare` inside a function local to that
function, and a file sourced from a function runs inside it. So a script that
loads the library from a helper function (delta-version found this) loses every
table when that helper returns. The next `MENU_SECTION_TITLES[opts]=...` then
makes an ordinary indexed array where every name counts as 0: all section
titles land on top of each other, and the second item added is refused as a
"Duplicate item_id" of the first. `menu.sh`, `checkbox.sh` and
`multistate.sh` declare their tables the same way and break the same way.

## Intended Behavior

The libraries work wherever they are sourced, at the top level or from inside
a function.

## Suggested Implementation Steps

1. Make every top-level table with `declare -gA` / `declare -ga`, which always
   creates the global table (bash 4.2 and later).
2. Say why in a comment beside the tables.
3. Add a test that sources each library from inside a function and checks the
   tables survive, then builds a menu that way.

## Decisions

- **`declare -g` rather than documenting a rule.** It changes nothing for a
  script that sources the libraries at the top level (the tables are global
  either way), and it removes a trap nobody can see from the call site. Bash
  4.2 has had `-g` since 2011, and `transcript-discovery.sh` already uses it.
- **All four menu libraries, not only `lua-menu.sh`.** `menu.sh` sources
  `checkbox.sh` and `multistate.sh`, and all three had the same plain
  declares. Fixing only `lua-menu.sh` would leave the bash menu with the same
  failure.
- **The test reads each library's table list from the library itself**, so a
  table added later (the dropdown branch adds two to `lua-menu.sh`) is
  checked without editing the test, and fails the test if it is added with
  a plain `declare`.

## What Happened

Built on branch `claude/lua-menu-global-tables`.

- `libs/lua-menu.sh`, `libs/menu.sh`, `libs/checkbox.sh`,
  `libs/multistate.sh`: every top-level `declare -A`/`-a` is now
  `declare -gA`/`-ga`, with a three-line comment saying why.
- `tests/test-menu-libraries-sourced-in-function.sh` (49 checks): sources each
  library from inside a function in a fresh bash and checks every top-level
  table is still there with the right kind, then builds a two-section menu
  with `lua-menu.sh` (checking `_menu_build_json`) and with `menu.sh`
  (checking the tables) and checks titles and items stay with their own
  sections. Before the fix 44 of the 49 checks fail; after it all pass.
- `libs/test-menu-screen.sh` still passes 7/0.

## Renumbered

**2026-11-04:** this issue was 040, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 054.
