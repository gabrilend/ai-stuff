# 403 — Mechanism Activation & the Equal-Plausibility Red-Herring Model

> Phase 4 — Stage 2 of the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md), plus the
> phase's beating heart: making the real solution and the decoys **"seem suitably
> equal in likely."** This is the issue that most directly implements the vision's
> lines ~116-122.

## Meta

- **Phase:** 4
- **Blocked by:** 401 (mechanism/binding shapes), 402 (trigger events to route).
- **Blocks:** 404 (runtime routes events through here), 407 (the plausibility
  auditor is a primitive the generator must call).

## Current Behavior

None of this exists yet. A trigger can fire an event (once 402 lands) but nothing
routes it to a mechanism, mechanisms have no use-modes, and there is no notion of
a red herring or of two options being equally plausible.

## Intended Behavior

Two halves, tightly related.

### Half A — mechanism activation (the two multiplicities)

A **mechanism** *provides the solution*: it holds a solution effect and a set of
**use-modes**, chosen through a **dispatch table keyed by mechanism kind** (lever,
plate, glyph, gate, ward, ...). Each kind's row says what use-modes it exposes and
how each use-mode moves its state. **Activation bindings** (from 401) wire trigger
events to use-modes. Routing an event applies every binding that event drives,
per the vision's two multiplicities:

1. **Multiple solving triggers -> one mechanism.** Several `solving`-tagged
   bindings all push a mechanism toward its solution — redundant correct paths
   (flame-bolt *or* pushed-crate *or* hard-landing all throw the same lever).
2. **Multiple non-solving uses -> red herrings.** Other bindings *use* the
   mechanism but do not provide the solution. Their tag decides what happens:
   - `inert` — nothing meaningful; it just "clicks."
   - `misleading` — visibly does something (a light, a grind, a partial move) that
     leads nowhere.
   - `arms-trap` — advances a failure condition / arms or springs a trap (issue
     405 owns the trap; this side only flips the state).

### Half B — the equal-plausibility auditor (the ruler)

A red herring is worthless if it *looks* like one. Every binding carries an
**apparent-plausibility profile**: the surface cues an observer can perceive
*before* trying it — visual salience, proximity to the goal, thematic fit,
affordance strength (how operable it looks), and tool-match (how well it fits the
party's carried spells/tools). The **equal-plausibility auditor** scores the
`solving` bindings and the red-herring bindings and reports the **spread** between
the two groups. A puzzle **passes** only when the spread is within tolerance —
i.e., a fresh observer, seeing only surfaces, could not rank the real solution
above the decoys.

Phase 4 owns this **ruler**; [Phase 6](../docs/datapath-dungeon-master.md) does
the measuring-and-adjusting (propose wiring -> audit -> nudge -> re-audit). The
auditor is therefore a public primitive with a stable, testable verdict.

## Suggested Implementation Steps

1. Create the mechanism-activation source file (indexed name + `.info.md`).
2. Build the **mechanism-kind dispatch table** (dispatch table #2 of four) and its
   registration function; seed it with a few kinds (lever, plate, glyph, gate,
   ward), each declaring use-modes and a state-transition function per use-mode.
3. Implement **route-event-to-bindings**: given a trigger event, find the bindings
   it drives and apply each binding's use-mode to its mechanism; honour the tag
   (`solving` / `inert` / `misleading` / `arms-trap`) when deciding the state
   move. Do not evaluate the puzzle here — that is 404's job; only move states.
4. Define the **apparent-plausibility profile** structure (the five cues above)
   and attach one to every binding (fill the slot 401 reserved).
5. Implement the **equal-plausibility auditor**: aggregate each group's profiles,
   compute the spread (per-cue and overall), and return a pass/fail verdict plus
   the offending cues when it fails, against a configurable tolerance.
6. Provide a small **plausibility-balancing helper** the generator can lean on:
   given a proposed wiring that fails, suggest which decoy cues to raise/lower to
   close the spread. (Phase 6 decides; Phase 4 advises.)
7. Tests: an event with two solving bindings drives the mechanism home via either
   path; an `arms-trap` binding flips the failure slot; the auditor **passes** a
   balanced puzzle and **fails** one where the solving lever is spot-lit and the
   decoy is in a dark corner, naming visual-salience as the offender.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 2
  and the whole "equal-plausibility constraint (the heart of the phase)" section.
- `notes/vision` lines ~116-122 — the source lines this issue implements.
- Downstream: [404](404-puzzle-runtime-state-machine-and-solution-checking.md)
  (routes through here), [407](407-composition-and-outcome-seam-for-the-dungeon-master.md)
  (generator calls the auditor).
