# 506 — Submarines and torpedo planes

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 203, 504 |
| Blocks | — |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing, and **deliberately nothing until the demo is finished.** The vision
is explicit: "There's no anti-submarine units in the demo but in the full game
there'll be subs and torpedo launching planes." This issue is blocked by the
demo's completion — the phase 2 and phase 3 demos having run and shown whether
the sightline idea works — and not by any design question; every rule it needs
is stated below and rests on machinery the earlier issues build. The `submerged`
flag from issue 504 exists, and today nothing but the underwater carrier sets it
and nothing at all can shoot through it. `tests/023-the-big-things.lua` has no
assertion for this issue yet; it gets one when the issue is opened for work.

## Intended behavior

The vision notes that, except for the carrier once it has surfaced, "there's not
much that torpedos can do to contest the player" — meaning the underwater
carrier has no counter until this issue. These two kinds are that counter, and
they are one rule and two rows.

**The rule: submerged is a fourth reach.** Issue 405's `reaches` bitmask has
three bits, one per domain. This issue adds a fourth, `submerged`. A unit whose
`submerged` flag is set is excluded from every shooter's candidates unless the
shooter's reach carries the submerged bit — the same filter issue 405 uses for
the cloud, one more bit in the test. A torpedo is a weapon whose reach carries
that bit.

**The submarine** is a sea kind whose `submerged` flag is set whenever it moves
and stays set when it stands — unlike the carrier, it does not surface to act.
Its weapon is a torpedo: it reaches sea and submerged, not land and not air. It
follows a sea pattern like a frigate and holds at the end. What can hurt it is
another torpedo, and nothing else, which is the point of the second row.

**The torpedo plane** is an air kind with `flies_pattern` set, like the gunship,
whose weapon is a torpedo: it reaches sea and submerged and nothing else. It
flies its pattern over the water at flight height, fires at any submerged thing
it can see — a submarine, a moving underwater carrier — and is shot by anti-air
the whole way, which is the counter to the counter.

A submerged unit's **profile is below the water line**, so a sightline to it is
a sightline to the surface above it: the sightline question is asked against
the surface cell's height, not the unit's own. That is one line in `domains`
and it is what makes the sea a place where the dunes stop mattering and the
shore starts.

## Suggested implementation steps

1. Add the fourth bit beside the three domain bits in `domains`, and extend
   `targeting`'s candidate filter to test `submerged` against the shooter's
   reach, with a comment naming what each path means.
2. Add two rows to the unit catalogue: submarine (sea, reaches sea and
   submerged, tier one or two by the ledger's judgement) and torpedo plane (air,
   `flies_pattern`, reaches sea and submerged). Add their lines.
3. In the move pass, set `submerged` for the submarine on every tick, not only
   when it moved; a one-row table keyed by kind decides who surfaces when
   standing and who does not.
4. In `domains`, give the sightline question a profile height for submerged
   rows that is the water line rather than the unit's own.
5. Write the test's assertions, when the issue opens: a submarine is not shot
   by a frigate; it is shot by a torpedo plane that sees the water above it; the
   torpedo plane is shot by anti-air.
6. Update the companions of `domains`, `targeting`, and the catalogue.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — reach and candidates
- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) — the water line
- `tests/023-the-big-things.lua`

## Still open

- Whether a submerged unit should be seen at all by anything that cannot hurt
  it — a frigate that knows a submarine is there but cannot fire is a different
  game from one that does not know. Seen but not a candidate is the working
  ruling, because sight and reach are already separate facts.
- Whether the demo's completion should be measured by the phase 3 demo or by a
  person having played it. The latter; this issue waits for a person.
