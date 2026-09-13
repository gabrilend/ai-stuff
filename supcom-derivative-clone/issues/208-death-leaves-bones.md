# 208 — Death leaves bones

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 206 |
| Blocks | 211 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Nothing. The test program `tests/020-things-that-roll-fly-and-sail.lua` names
this issue, looks for the stem `bones`, and asserts that bones carry mass.

## Intended behavior

**A dead unit leaves bones.** Bones are a row in a **separate flat array** from
the units: a position, a mass, and nothing else. The mass is a share of what the
unit cost — a catalogue fraction of its `cost_mass` — and it is the only thing a
death puts back into the world.

Bones do nothing. They do not block movement, do not block sightlines, and
belong to nobody; bones on ground that changes hands are still bones. The one
thing that reads them is the enforcer (issue 211), which eats them, and eating
removes the row.

Bones are a separate array rather than a flag on the unit row for the reason the
unit row is flat: the unit arrays are walked every tick by every sliced system,
and a dead row that stayed in them would be a row every walk has to skip. The
die pass (issue 206) hands the row over, the unit's row is freed, and the bones
array — walked only by the enforcer's eat pass — holds what remains.

The bones array is allocated once, sized from the parameters, and **refuses when
full** by name. That is the honest outcome: a field with more bones than the
parameters allowed is a parameter that was wrong, not a case to paper over by
forgetting the oldest.

The terminal viewer draws bones as a mark of their own, so a match report can be
read for where the fighting was.

## Suggested implementation steps

1. Claim `src/NNN-bones.lua` with `./new-source-file bones`.
2. Write the array: `x`, `y` as doubles, `mass` as an integer, a count. Allocate
   it in issue 104's world.
3. Write `leave(world, unit)`: reads the dead unit's position and kind, computes
   the mass share from the catalogue, appends a row. Called by the die pass and
   by nothing else.
4. Write `eat(world, unit, bone)`: returns the bone's mass to the caller, moves
   the last row into the freed slot, lowers the count. Called by issue 211's eat
   pass and by nothing else.
5. Write `near(world, x, y, radius)`: the bone rows within a radius, as a range
   walk, for the eat pass.
6. Export the bones to the snapshot (issue 109) so the viewers can draw them and
   the hash includes them — a machine that forgot a bone would otherwise agree
   with one that did not.

## Related documents and tools

- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — the bones section
- [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) — what eats them
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

Nothing beyond the questions in the table. Whether bones should decay after a
long time is not asked by the vision and is not built; a field that fills with
bones over a long match is something the proving ground will show.
