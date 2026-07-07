# 502 — NCP Memory Store: append-only accumulating context

> The ledger an NCP carries through its life. Puzzle outcomes go in; the Phase-6
> library writes fairy-tales in; the companion voice and the weak solver read out.
> It is the seam through which learning enters this phase — so it must be honest
> (append-only) and easy to write from the outside (Phase 6).
>
> Depends on issue 501 (an instance owns a memory-store handle). NCP = New
> Character Person; see [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. An NCP instance (501) has nowhere to remember what it
did, and Phase 6's learning mechanic has nowhere to write the fairy-tales that
would make later puzzles easier.

## Intended Behavior

Each NCP instance owns one **memory store**: an **append-only** ledger of
accumulating context. Append-only is a design choice, not a limitation — history
should be honest, and no later run should be able to quietly rewrite what an
adventurer learned. The store accumulates:

- **Puzzle outcomes** and **trial logs** — what was attempted, what happened,
  which stat carried the attempt (written by the capability signal, issue 506b).
- **Fairy-tales learned** — the Phase-6 library / learning mechanic writes these
  in: little lessons that "teach them mechanics of existence like three-
  dimensional rotations (quaternions) or newtons laws of bio-impedence, and other
  such magical-histories." The more of these a store holds, the easier the weak
  solver (506) and the DM's later puzzles become. **This is the seam Phase 6
  writes into.**

The store exposes exactly two doors: **append a line** and **gather relevant
context**. There is no edit door and no delete door. "Gather relevant context"
returns a bounded, recent, or relevance-filtered slice suitable for feeding a
persona utterance (504) or a solver attempt (506) — because the raw ledger will
outgrow any single prompt, retrieval must summarize or window rather than dump.

Growth is bounded by *retrieval*, not by *forgetting*: the ledger keeps
everything, but a read returns only what fits and matters. (How much fits is a
config value / validator-reported number, not a hardcoded constant.)

## Suggested Implementation Steps

1. Define the **memory line** shape: a typed entry (outcome | trial-log |
   fairy-tale | note) with enough structure that retrieval can filter by kind and
   recency. Keep it plain data.
2. Define the **memory store** structure as an ordered, append-only sequence of
   lines, created fresh per instance by the stamp operation in 501.
3. Write the **append operation** — the only writer. It must be callable both from
   inside Phase 5 (capability signal) and from outside (Phase 6 library). Make the
   external entry point clean and documented in the `.info.md`, since Phase 6
   depends on it.
4. Write the **gather-context operation** — bounded retrieval for a prompt or a
   solver attempt. Start simple (most-recent-N, kind-filtered); leave a clear seam
   for smarter relevance ranking later. Do not silently drop context without
   surfacing that it was windowed — a windowed read is a fact the caller may want.
5. Assert append-only at the boundary: there must be no supported path that
   rewrites or removes an existing line. Add a test that appends, reads, and
   confirms earlier lines are unchanged after later appends.
6. Write the file's `.info.md` documenting the two external doors and their
   inputs/outputs — Phase 6 will read this rather than the source.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Memory store
  — the append-only ledger," and the Phase-6 inbound seam.
- Feeds: companion persona (504), weak solver (506). Written by: capability
  signal (506b) and Phase 6's learning mechanic.
