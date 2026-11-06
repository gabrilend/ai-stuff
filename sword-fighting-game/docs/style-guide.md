# Style guide

The house style for source files, and where each rule comes from. Every rule
here is checked by `scripts/lint`, which `./run-tests` runs first; a finding
is an error.

| Rule | From | Checked as |
| --- | --- | --- |
| Files read in order: `NNN-name.lua`, counted by `.file-index-counter` | the owner | index present in src/ and tests/, unique, not above the counter |
| A companion page `name.info.md` beside every source file | the owner | present; made by `scripts/build-info-pages` from the source's comments |
| A header comment saying what the file is | the owner | first line (after `#!`) is a comment |
| Every named function in a fold: comment above, then `-- {{{ name()`, then the definition, then `-- }}}` after its `end` | the owner | fold line directly above each named function; closes after an `end`; balanced |
| LuaJIT syntax only | the owner | no `//`, `<const>`, `<close>`, `&`, `\|`, binary `~`, `<<`, `>>` |
| Tabs for indentation | st, dwm | no space-indented code lines |
| Short lines | st, dwm | at most 110 columns, tabs counted as 8 |
| Tables of functions, not if-chains | the owner, dwm's handler[] | no if-chain with more than two `elseif` |

## Things taken from st and dwm beyond the linter

- **config.def and config**: every knob's default in one aligned table with
  a trailing comment per line (src/001-config.def.lua); a person's overrides
  in config.lua. dwm copies config.def.h to config.h; here the overrides are
  laid over the defaults instead, and an override naming an unknown knob is
  an error.
- **keys[]**: bindings are rows { key, action, argument } dispatched by
  lookup (src/029-the-front-desk.lua), as dwm's keys[] and buttons[].
- **die()**: one way to stop with a message naming the program
  (src/002-util.lua).

## Why 110 columns and not 80

Lua nests deeper than C (closures inside tables inside functions), and at
tab width 8 the third level of indentation already spends 24 columns. 110
keeps lines readable at st's tab width without forcing awkward wraps. This
is a deliberate departure, written down so it can be revisited.
