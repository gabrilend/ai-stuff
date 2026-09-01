# 035-creature-table

Every number that distinguishes one creature from another.

Read this page rather than the source; the source is a table and reads itself.

## What it is for

This file and `src/028-maze-parameters.lua` hold **every balance number in the
project**, and no document restates one. Why a number was changed goes in
`docs/balance-updates.md`, appended to, never edited. What it is now is here.

## Exports

| Name | What it is |
| --- | --- |
| `KINDS` | one row per creature, indexed by kind number |
| `POPULATIONS` | how many of each kind a named scene keeps alive |
| `by_name(name)` | the index and the row, or raises |
| `ROLLING`, `WALKING`, `STRIDING`, `LUMBERING`, `CREEPING`, `CARRIED`, `STILL` | the locomotion row numbers, named so a creature says how it moves in words |

## Fields every kind has

| Field | Meaning |
| --- | --- |
| `name` | what the palette and the report call it |
| `locomotion` | which row of the dispatch table moves it |
| `radius` | in cells; its footprint and what it collides with |
| `body_height` | in layers; how much headroom it needs to enter a cell |
| `drop_limit` | how far it may descend before that is falling rather than stepping |
| `health`, `team` | for the phases that have fighting in them |

## The kinds

**ball** — rolls, with `gravity`, `roll_friction`, `restitution`,
`bounce_floor`, `max_speed`, `rest_seconds` and `slope_gain`.

Its `drop_limit` is effectively infinite: what a walker treats as a wall to route
around, a ball treats as the interesting part and goes over.

Its `restitution` is 0.85, which is bouncier than stone has any right to be, and
that is deliberate. At a realistic third, a ball loses nearly all its energy on
the first wall it meets — in a maze made entirely of walls, which it meets within
a cell or two of being dropped. Measured over nine hundred ticks: at 0.32 the
average ball travels two cells and thirty-six of them are motionless; at 0.85 it
travels seventeen and one is.

**guy** — walks, with `step_seconds`, `reverse_weight`, `idle_chance`,
`notice_seconds` and `search_budget`.

Its `drop_limit` is **one**, not two. A wall stands two layers above its corridor
and a terrace four above the one below it, so a limit of two lets a walker step
off a terrace edge onto the top of a wall and then walk along it. There is no
wall height that avoids that while staying unclimbable from below, so the limit
goes here instead — and at one, a walker moves only where the maze is mutually
reachable, which is exactly the connectivity the validator checks.

## Scenes

`balls`, `guys`, `both`, `empty`. Which kinds are present is a parameter of the
run rather than a property of what has been built: balls and little guys share
one maze, and the locomotion table is what makes that cost nothing.
