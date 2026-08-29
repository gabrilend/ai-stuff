# 311 — Autosave to the RAM Tier

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 301 |
| Blocks | — |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | — |

## Current behavior

Work exists only in memory until somebody saves.

## Intended behavior

The network is written to `tmp/shared-memory/` at intervals and at every natural
pause, because **losing an hour of tracing is the worst thing that could happen
to this project**.

Not a hypothetical worst case — a real one. The campaign is two thousand traced
loops and ten thousand placed zones, done over months of evenings. An hour lost is
an evening lost, and a few of those are enough to stop somebody continuing.

### Why the RAM tier rather than beside the network

Autosaves are ephemeral artefacts, not the record. They belong in
`tmp/shared-memory/`, which is RAM-backed and never committed, so they cannot be
confused with the real file or accidentally versioned.

The **real** save — the one that goes into `assets/` and into git — stays
deliberate, and runs the validator first. Autosave never runs the validator and
never refuses: it captures whatever state exists, including a half-traced loop,
because its job is to lose nothing rather than to be correct.

### Keeping several

One rolling file is enough to survive a crash and not enough to survive a
mistake. Several, named by time, cover both — the case where you notice an hour
later that something went wrong, and the network has been saved over since.

Old ones expire by count, not by age.

### It must say where they are

On startup, if autosaves exist that are newer than the network on disk, **say so
loudly and name them**. An autosave nobody knows about is the same as no autosave.

This is the fallback-announcement rule from
[the shape of the code](../docs/010-the-shape-of-the-code.md): recovering from an
autosave is a fallback, and a silent one would let somebody carry on from a stale
file without ever knowing a newer one existed.

## Suggested implementation steps

1. Ensure `tmp/shared-memory/` exists at startup — the run script does this, and
   the program checks rather than assuming.
2. Write on a timer and after each committed action, whichever comes first.
3. Name by timestamp, keep a fixed number, remove the oldest.
4. Write to a temporary name and rename into place, so a crash mid-write cannot
   leave a truncated autosave that looks complete.
5. On startup, compare autosave times to the network file and report anything
   newer, with the command to recover it.
6. Test by killing the process mid-session and confirming the newest autosave
   loads and matches what was on screen.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [The shape of the code](../docs/010-the-shape-of-the-code.md) — the RAM tiers, and announcing fallbacks
