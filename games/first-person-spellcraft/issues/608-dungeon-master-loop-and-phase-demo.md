# 608 — The Dungeon Master loop, the statistics utility, and the phase demo (capstone)

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** every prior Phase-6 issue (601–607) and Phase 5 (the solver +
NCP memory).
**Blocks:** the Bucket-C capstone; a forward hook into Phase 8.

## Current Behavior

None of this exists yet. The pieces from 601–607 are stages without a conductor:
nothing runs estimate → tune → generate → attempt → re-estimate in order, nothing
reports the phase's live counts, and there is no runnable demonstration that the
loop actually tightens over repeated visits.

## Intended Behavior

Three deliverables that turn the parts into a working, observable whole.

- **The DM tick / orchestration.** One entry point that owns the lifecycle:
  1. **estimate** the party (602),
  2. **tune** a difficulty target + choose a modality (603, 606, reading the
     library discount from 605b),
  3. **generate** a fresh lair (607a) and **instantiate** it (607b),
  4. hand it to the **Phase-5 weak solver** and collect **attempt outcomes**,
  5. **re-estimate** the capability and stretch the yardstick (604),
  6. loop — the next lair is tuned to the sharper belief.
  The library side loop (605) can run between ticks. Ordering is explicit and
  commented so a future reader sees *why* each stage precedes the next.

- **The Phase-6 statistics utility.** A runnable that reports the phase's live
  counts — puzzle types available, fairy-tale corpus size, modality count, stat
  count, and the current puzzle band around "three-ish." Docs and the demo
  reference **this**, never a hardcoded number, so figures never rot. (The one
  fixed number, exactly-4-combats, is validated in 607a, not reported as a knob.)

- **The phase demo** (in `issues/completed/demos/`). Runs a single NCP (a party
  of one) through **several successive lairs** and shows, as data, the loop
  working: the per-stat capability estimate climbing, the level yardstick
  stretching after each conquest, a library visit visibly easing a later puzzle,
  and the modality shifting to press a weak stat. It should recombine earlier
  phases' tools — Phase-4 primitives instantiated live, the Phase-5 solver
  attempting them — alongside this phase's generator and learning. Prefer a
  visual read (a small rendered panel or an HTML page of charts) over prose, per
  project demo policy. Launchable from a simple bash script (hard-coded `${DIR}`,
  overridable by argument, all paths relative to `${DIR}`), and wired into the
  project-root demo launcher as the next selectable number.

## Suggested Implementation Steps

1. Write the **DM tick** entry point sequencing stages 1–6 above, with the seam's
   strong handle for generation and the Phase-5 weak handle for solving.
2. Write the **statistics utility** reporting live counts; have it error if a
   count source is missing rather than reporting a zero.
3. Build the **demo**: run N successive lairs on one NCP, log the estimate,
   yardstick, learning ledger, and chosen modality per visit into the project
   `tmp/` (RAM-backed) directory, then render the trend.
4. Write the **launcher bash script** (`${DIR}` convention) and add its entry to
   the root demo launcher.
5. Companion `*.info.md` for the tick and the statistics utility.
6. Tests: a full tick runs end to end on a stub seam (announced as a stub);
   across several ticks the yardstick stretches monotonically for a party that
   keeps conquering; a library visit measurably lowers a later puzzle's target;
   the statistics utility's counts match the actual tables.

## Meta

- **Demo is a deliverable,** not an artifact — it ships with the phase and should
  reach feature parity with the loop it demonstrates.
- **Sequel hook:** the same tick, pointed at a province instead of a party,
  becomes the Phase-8 trial generator — leave the entry point general enough to
  be re-aimed later, but do not build Phase 8 here.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — the full
  loop diagram (stages A–E and the side loop) this issue realizes.
- [roadmap.md](../docs/roadmap.md) — Phase 6 is the Bucket-C capstone; gate this
  on Phase 5 solving hand-made puzzles first.
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  the weak solver and NCP memory the loop drives.
