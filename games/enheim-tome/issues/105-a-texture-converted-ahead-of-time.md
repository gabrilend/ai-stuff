# 105 — A Texture Converted Ahead of Time

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | 101 |
| Blocks | — |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

The painting is decoded from PNG every time a program starts.

## Intended behavior

A **build step that converts the painting once**, into a compressed texture format
the card reads natively, so that starting a program is a read rather than a
decode.

### Why this matters more than it looks

Decoding 25 million pixels takes on the order of **a second**. Today that is a
slow start, which is merely irritating. It becomes a real fault the moment
anything wants to swap boards while running — the seasons idea parked at 2.0 does
exactly that, and would freeze the game at the precise moment the season turns.
Building the converter now costs little and removes the trap before anything is
built on top of it.

It also cuts the resident cost. Raw, the painting is about 96 MiB, 128 with
mipmaps. In a compressed form the card samples directly it is roughly 24 MiB, 32
with mipmaps — which is what would make several boards resident at once possible
rather than impossible.

### Where the output goes

**Not beside the original.** The converted form is a build artefact, so it belongs
in the RAM tier at `tmp/shared-memory/`, and is regenerated rather than
committed. The originals in `inspiration-pictures/` are not ours and are never
written to or beside — see [the notice](../inspiration-pictures/NOTICE.md).

### Staleness

The converter re-runs when the source is newer than the output, and the program
falls back to decoding the original when no converted form exists.

**That fallback must announce itself every time.** A silent fallback is a slow
start nobody diagnoses for a month. Print what happened, why, and what to run.

## Suggested implementation steps

1. A script, runnable from any directory, that reads the painting and writes a
   compressed texture into `tmp/shared-memory/`.
2. Choose the format for quality first — a painting with subtle colour across
   large areas suffers badly under aggressive block compression, so compare the
   candidates by eye at native zoom before choosing on size.
3. Have the programs prefer the converted form and fall back to the original,
   printing a warning naming the script to run.
4. Regenerate when the source is newer.
5. Report both timings at startup — decode versus load — so the gain is a
   measured number rather than an assumption.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [The shape of the code](../docs/011-the-shape-of-the-code.md) — the RAM tiers, and the rule about announcing fallbacks
