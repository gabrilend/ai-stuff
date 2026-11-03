# Issue 044: lua-menu.sh multistate items get their states

## Status
- **Priority**: Medium
- **Type**: Bug fix
- **Status**: Completed
- **Created**: 2026-11-03

## Current Behavior

`menu_add_item ... "multistate" ...` in `libs/lua-menu.sh` stored the value
but always sent the Lua menu an empty list of states. The menu cycles
through that list, so the item drew as `<[]>` and h, l and space had
nothing to step through. This was found while building issue 009's menu,
which used a radio list instead. `neocities-modernization/generate-embeddings.sh`'s
model picker is a multistate item and has the same problem.

## Intended Behavior

A multistate item cycles through its states, given either way that is
already written down:

- menu.sh's form: value `"state1,state2,state3:default"`. Without
  `:default`, the first state is the default.
- `README-lua-menu-dev.md`'s form: value `"default"`, with the states as the
  description, `"state1,state2,state3"`. This is the form
  generate-embeddings.sh uses.

## Suggested Implementation Steps

1. [x] Parse both forms in `menu_add_item` and store the states as the
       item's config.
2. [x] Correct the README's note on where the options go.
3. [x] Tests: `tests/test-lua-menu-multistate.sh`.

## What Happened

**2026-11-03.** Built. `tests/test-lua-menu-multistate.sh` has 12 checks,
which all fail on main. Five of them type keys into a real menu. The menu
screen test still passes 7/0.

Decisions:

- **Which form a call uses:**
  - A value containing `,` or `:` is menu.sh's form.
  - Otherwise, the description is read as the states, but only when it is
    a comma list with no spaces that includes the value. An ordinary
    description ("one thing, then another") never is.
  - Anything else is a single state, which cycles onto itself instead of
    stepping into an empty list.
- **The description is kept in the README form.** It shows the list in the
  description line, which is what generate-embeddings.sh already displays.
- **generate-embeddings.sh is not edited.** It belongs to
  neocities-modernization, and its picker starts cycling with no change
  there. Its processing-mode radio list is left as it is.
