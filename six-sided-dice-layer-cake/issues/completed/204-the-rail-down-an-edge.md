# 204 — The rail down an edge

Produces `src/016-edge-rail.md`.

## Current behavior

**Done.** `src/016-edge-rail.md` exists, with the two channels stacked rather
than side by side, because a four millimetre section will not hold them any other
way once the walls are real.

**The finding is that the rail cannot be transparent.** A rail feeds one face's
microchannel field, which wants a sixth of the machine's flow. Fitting two
channels inside four millimetres leaves about four and a third square millimetres
each, so the flow runs at over two metres a second, turns turbulent, and costs
something near five kilopascals against the field's eleven. That is a third of
the loop, not a twentieth.

Three ways out were available and only the third is honest: widening the rail
pushes the face plate below the die block and the cube grows; reducing the flow
buys less than it costs; or the claim goes. The claim went, and what actually
balances this network is the parity topology in `023`, which was always the
stronger argument and simply was not the one being relied on.

Eight constraints. Four wait on `024`'s flow. The geometry ones hold.

## Intended behavior

**One part, made twelve times.** A rail occupies the four millimetre square strip
along one edge of the cube, spans the sixty millimetres between two corner blocks,
and carries **two channels side by side** — one supply, one return — separated by
a web and surrounded by enough wall to hold proof pressure.

```drawing
edge rail cross-section, looking along the edge

        ├──────── [w_rail] ────────┤
        ┌──────────────────────────┐   ─┬─
        │  ╭──────╮      ╭──────╮  │    │
        │  │supply│      │return│  │  [w_rail]
        │  ╰──────╯      ╰──────╯  │    │
        └──────────────────────────┘   ─┴─
              ▲          ▲
              │          │
         two chambers, never joined except
         through a corner block or a face field
```

Both networks reach every edge, which is what gives `022` the freedom to run a
face's microchannel field in whichever direction suits it. Opposite faces should
run their fields perpendicular to each other, so that the load on the two networks
is spread rather than concentrated on one pair of rails.

## Why the rails are not the restriction

At design flow a rail carries roughly three tenths of a litre a minute at about a
metre a second, and loses on the order of five hundred pascals over its sixty
millimetres. The microchannel field it feeds loses eleven thousand. **The rail is
twenty times more transparent than the thing it supplies**, which is the correct
ratio for a manifold and is what makes the flow distribution in `024` insensitive
to exactly which rail feeds which field.

Getting this backwards — a restrictive manifold feeding a permissive load — is how
liquid cooling loops end up with one channel doing all the work, and it is worth
one paragraph in the blueprint saying so.

## What the rail also is

Structure. The twelve rails are the cube's frame; the face plates are panels
between them. `206` will find that the rails carry most of the bending load, and
`201`'s tolerance stack closes around them rather than around the plates.

## Symbols this must publish

The two channel cross-sections and their hydraulic diameters, the web and wall
thicknesses, the rail length between corner block faces, the velocity and Reynolds
number at design flow, the pressure drop, the second moment of area about both
bending axes, and the mass.

## Constraints this must assert

- Rail pressure drop is under a twentieth of the microchannel field's. The
  transparency requirement.
- Wall and web thickness exceed what the proof pressure in `205` requires, with
  the web checked as a flat plate rather than as a cylinder, because it is one.
- The two channels plus their walls plus the web fit inside the rail square.
- Reynolds number is reported; the rail is expected to be transitional and the
  blueprint must say which friction correlation was used and where it stops being
  valid.

## Suggested implementation steps

1. Draw the cross-section and dimension it in symbols.
2. Size the channels from the flow in `024` rather than picking a number — the
   flow comes first and the geometry follows.
3. Derive the pressure drop and compare against the field's.
4. Work the second moment of area for `206`.
5. Draw the interface to a corner block and confirm it matches `203`.

## Blocks

`205`, `206`, `305`, `306`.

## Blocked by

`103`, `203`.

## Related documents

`005`. `023` for how the two networks are fed. `024` for the flow that sizes this.
