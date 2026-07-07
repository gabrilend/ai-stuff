# 307 — Phase 3 spell-system demo (capstone)

> Phase 3 · Spell System · the capstone that shows the whole verb working and
> recombines earlier phases' tools. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) (the full flow).
> Depends on: all of 301–306. Lands the phase demo per the project's demo
> discipline.

## Current Behavior

None of this exists yet. There is no runnable demonstration of the spell system,
and — until this issue — no `issues/completed/demos/` entry for Phase 3 nor a
numbered slot for it in the project-root demo launcher.

## Intended Behavior

A runnable **phase demo** that is part of the deliverable, not just an artifact.
It shows the whole datapath end to end and, per roadmap guidance, **recombines
earlier phases' tools alongside this phase's new ones**:

- **From Phase 1:** a square room with a monster (a zombie) standing in it, drawn
  by the Phase 1 renderer.
- **From Phase 2:** aim fed through the input-abstraction seam — real dual-mouse
  aim if available, otherwise the 303 stub aim source, so the demo runs headless
  too. The demo should read the `role` seed (player vs NCP) and aim identically
  either way, showing "aim once, aim everywhere."
- **New in Phase 3:** pick a spell from the book (301/302), cast it **three
  different ways** on the same target (gesture, charge-and-release, two-hand
  combination — 304b), watch it resolve to the **same effect** (305a), apply to
  the monster **and** trip an example magic-effect subscriber standing in for a
  Phase 4 puzzle (305b), and render the flash/beam/impact (306).

The demo **focuses on statistics and real outputs over description** (project demo
discipline): it should surface concrete datapoints — e.g. path/level counts from
the 301 validator, the spell chosen, the three methods' resolved effect events
side by side (proving sameness), damage dealt, and whether the magic-effect seam
fired — and, where feasible, a **visual** demonstration (the room with the spell
going off) rather than only a textual report.

It is launched by a simple bash script and reachable from the project-root demo
launcher as the Phase 3 selection. The script obeys the project convention: a
hard-coded `${DIR}` at the top, overridable by argument, all paths relative to
`${DIR}`, and it ensures the RAM-backed `tmp/` symlink exists before writing any
logs.

## Suggested Implementation Steps

1. Assemble the scene: load a Phase 1 room + monster; place the caster; obtain aim
   (Phase 2 if present, else the 303 stub).
2. Drive the full flow three times over one spell — one per 304b method — building
   cast requests (303), dispatching (304a), resolving (305a), applying (305b),
   rendering (306).
3. Register an example magic-effect subscriber (the "torch/puzzle stand-in") so
   the Phase 4 seam visibly fires, previewing the Phase 4 handshake.
4. Collect and display the statistics: 301 validator counts, the three methods'
   effect events (asserting equality), damage/monster-state deltas, seam-fired
   flags. Prefer a visual window if the Phase 1 renderer supports one; fall back to
   the log renderer (306) for headless, and **say so** when the fallback is used.
5. Write the launcher bash script into `issues/completed/demos/` per convention,
   and add the Phase 3 entry to the project-root phase-demo launcher (the script
   that asks for a number 1–y and runs the chosen phase demo).
6. Update `issues/phase-3-progress.md` to reflect the phase's completion against
   its goals as issues close (this file lives in `issues/` even after the phase
   completes).

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — the flow the demo
  walks end to end.
- [roadmap.md](../docs/roadmap.md#phase-3--spell-system) — the demo-as-deliverable
  and tool-recombination guidance.
- 301–306 — every stage the demo exercises.
- [strategems/](../strategems/README) — "Aim once, aim everywhere," shown live by
  the player-vs-NCP aim path.
