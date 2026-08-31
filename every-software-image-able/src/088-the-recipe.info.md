# 088-the-recipe — info

Two descriptions that do not name each other: a recipe saying what the seed IS, and a board description saying what it RUNS ON. Issue 501.

One file says what goes on the chip, another says what machine the chip is for, and neither mentions the other. Supporting a new computer is then a new file and no code at all -- which is the whole portability claim, and the only way to test it is to add one.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `088-the-recipe.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/088-the-recipe.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.RECIPE_FIELDS` | what a recipe must say |
| `M.BOARD_FIELDS` | what a board description must say |
| `M.check_recipe(recipe)` |  |
| `M.check_board(board)` |  |
| `M.manifest(recipe, board, components)` | The honest account of what an image is. |
| `M.identity(manifest)` | The image's identity: a number computed from the manifest, so somebody with the same recipe, the same board description and the same components arr... |

### In more detail

**`M.manifest(recipe, board, components)`**

The honest account of what an image is. The image itself is a pile of
bytes; this is what those bytes were meant to be.

Ordered rather than gathered, because the identity below is computed from
it and two builds that listed the same things in a different order would
otherwise be different images.

**`M.identity(manifest)`**

The image's identity: a number computed from the manifest, so somebody
with the same recipe, the same board description and the same components
arrives at the same one.

This is the only kind of reproducibility the project has, and it stops
mattering the moment the machine starts growing -- which is the answer to
the fifth open question in docs/008 rather than a limitation.

## The recipe never names a board, and the board never names a part of the seed

This is checked rather than intended: a recipe that mentions a board has quietly become a recipe for that board, and the next person to want a different machine has to edit it rather than write beside it.

## Nothing secret and nothing machine-specific

An image is copied onto every card in a batch, so anything particular to one machine is particular to all of them. The seed is generic by construction; everything individual about a machine happens after it wakes.

## Worth knowing

The board descriptions already in src/015 through src/017 and src/030 through src/032 are this file's board half at an earlier stage: they were written for the emulator harness before there was a builder to read them. An emulated machine is a board, so they are the same kind of thing, and this checks them the same way.

## Where it sits

**Belongs to** `501`.

**Checked by** `090-test-the-image`.

