# 809a — The card schema

The first piece of 809.

## Current Behavior

Built. `src/076-the-pool.lua` holds `FIELDS` (a card's closed field list),
`card(fields)` (builds and checks one, refusing a missing field by name),
`write_card`/`read_card` (through 014's record writer: a neighbour file,
then a rename). The pool's folder is `project.pool` (013), added for this
piece — kept in the project, outside git, per docs/010 open question 13's
own stated default. Checked by `tests/077-checking-the-pool.lua`.

## Intended Behavior

A `.card` file beside every asset: what, category, each parameter by
name, seed, paintbrush and version, the canvas, and an empty ratings list.

## Suggested Implementation Steps

1. The card schema as a Lua table. Done: `076-the-pool.lua`'s `FIELDS`/`card`.
2. Writing one card beside one asset. **Test:** a card holds every field
   docs/067 lists. Done: `write_card`/`read_card`.

## Blocked by

None
