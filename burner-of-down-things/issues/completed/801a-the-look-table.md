# 801a — The look table

The first piece of 801: one Lua table holding the owner's style, matching
[067](../docs/067-datapath-the-studio.md)'s "the look, as data" exactly.

## Current Behavior

Built. `src/070-the-look.lua` holds `DEFAULTS` (`ground`, `flair`,
`line_weight`, `arrow`) and `FIELDS` (the closed list of names 801b's
overrides will check against). `palette` is not stored: it has no default
of its own, only a rule ("follows `ground`"), so `default_palette(ground)`
computes it, and `defaults()` returns a fresh table with `palette` resolved.
Checked by `tests/071-checking-the-look.lua`, which also greps docs/067 for
every default value and field name so the two cannot quietly drift apart.

## Intended Behavior

A module holding `ground` (`black`, `gray`, `white`; default `black`),
`palette` (`night` or `day`; default follows `ground`), `flair` (on or off;
default on), `line_weight` (pixels; default 2), `arrow` (`there-here`;
default `there-here`) — the single table every paintbrush reads.

## Suggested Implementation Steps

1. The table and its defaults, matching docs/067's own table field for
   field. **Test:** every default in the table appears in the document (a
   search of docs/067 finds each default value against its setting name).
   Done: `070-the-look.lua`'s `DEFAULTS`/`default_palette`/`defaults`.

## Blocked by

None
