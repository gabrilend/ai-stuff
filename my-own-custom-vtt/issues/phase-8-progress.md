# Phase 8 — Content generation

**Goal:** nothing needs to be hand-placed.

**Status: complete.** All seven issues done. `./run-phase-demo 8` turns a written
description into a place and then walks into it.

## The issues

| Issue | What it established |
| --- | --- |
| [801 a description is validated first](completed/801-a-description-is-validated-first.md) | A closed vocabulary and a wall, not a net. |
| [802 the layout is a graph](completed/802-the-layout-is-a-graph.md) | Rooms and corridors before any coordinate exists. |
| [803 the graph becomes geometry](completed/803-the-graph-becomes-geometry.md) | Doorways as holes in a run of segments. |
| [804 furnishing asks the ruleset](completed/804-furnishing-asks-the-ruleset.md) | Lights, props, and a stage that never learned what a tavern is. |
| [805 the world writer](completed/805-the-world-writer.md) | Provenance in the header, and the first version converter. |
| [806 the generator checks its own work](completed/806-the-generator-checks-its-own-work.md) | Is this the world that was *described*? |
| [807 the phase eight demo](completed/807-the-phase-eight-demo.md) | The capstone. |

## What is built

| Source | What it is |
| --- | --- |
| `076-describe` | The vocabulary, and every fault reported at once. |
| `078-generate` | Layout, geometry, furnishing, and the check. |
| `080-generate-main` | `generate <description> <seed> <output>`. |
| `081-demo-phase-8` | The chain, shown rather than the result. |

Plus two descriptions in `input/descriptions/`, since that is where a program's
opening decisions live.

## Two bugs the demo found that the tests had not

**The loop count was quietly wrong.** A description asking for one loop routinely
got none: the placer drew two rooms per loop and gave up on a collision, and
`generate_check` only *capped* the count rather than requiring it. So a generator
ignoring its description sailed through the check that exists to catch exactly
that.

Both halves were wrong. Loops are now retried with a bound, an impossible request
is refused by name, and the check requires the **exact** count. A check that can
only catch too many is half a check.

**The dungeon was a row of sealed boxes.** The graph was perfectly connected. The
validator passed — every wall was well-formed. And `realise` emitted four solid
walls per room, so the layout claimed passages the geometry did not have.

Nothing caught it. **The demo drew a picture and that is the only reason anybody
noticed** — which is the argument for phase demos being part of the product
rather than development scrap, made concrete.

Doorways are now holes in a run of segments, corridors join neighbours, loops
route up over the row, and `generate_check` floods the geometry on a one-metre
grid to ask whether you can actually walk between the rooms. A test seals a real
dungeon on purpose so the new check cannot be vacuous.

## A decision reversed while building

Issue 801 argued for Lua as the description parser. That was **reconsidered**: any
module touching the Lua API needs an exemption from the floating-point check,
`073-rules` has one earned, and a second exemption for a second module is how a
ban stops being a ban.

What Lua buys is expressiveness, which a closed vocabulary of scalar fields does
not want. A description is data; a ruleset is a program. The issue records the
change of mind rather than being quietly deviated from.

## The version ladder stopped being theoretical

The world file's format went to version 2 to carry the description name and the
seed, and the converter for 1-to-2 is **the first rung of a ladder built empty on
purpose in phase 1**. It converts by reading less.

A world can now say where it came from, which is the difference between a map you
can edit and a map you can only replace.

## What phase 9 inherits

A project that no longer needs a hand-written fixture, and a `describe` hook whose
answers still nothing draws.
