# Roadmap — First Person Spellcraft

> **Phase numbers are functional capability slices, ordered by DEPENDENCY — not
> a chronological completion order.** It is not uncommon for the final issue
> completed in a project to be from phase 1 or 2. A late polish pass on movement
> (Phase 1) can land after the Dungeon Master (Phase 6) is already generating
> lairs. Read the numbers as "what must exist before what," not "what happens
> first on the calendar."
>
> This file is where the **time-gating** lives — rough milestone buckets and
> sequencing of work. For the phases as pure organizational groupings (no time),
> see [table-of-contents.md](table-of-contents.md). For the feature distillation,
> see [vision-overview.md](vision-overview.md).

---

## Dependency graph (at a glance)

```
        (1) Engine Foundation
             |        \
             v         v
   (2) Dual-Mouse    (4) Puzzles/Traps ....... needs 1 and 3
      Input               ^
        \                 |
         v                |
        (3) Spell System -+
             |
             v
        (5) NCP Characters & Companions ....... needs 1, 3, 4
             |
             v
        (6) AI Dungeon Master & Learning ...... needs 4, 5
             |
   +---------+
   |         |
   v         v
 (7) Economy & Settlement ...... needs 5
             |
             v
        (8) Territory & Majesty ...... needs 6, 7
             |
             v
        (9) Platform & Packaging ..... needs all
```

Longest dependency chain: 1 → 3 → 4 → 5 → 6 → 8 → 9. That chain is the critical
path; everything else can be worked in parallel around it as hands are free.

---

## Milestone buckets

These buckets group phases by how far along the game feels, not by dates. Work
inside a bucket can interleave; a later bucket should not *start its capstone*
until its dependencies are demonstrable.

- **Bucket A — "It's a world you can move in."** Phases 1, 2.
- **Bucket B — "It's a game you can play."** Phases 3, 4.
- **Bucket C — "It plays itself, and it's alive."** Phases 5, 6.
- **Bucket D — "It's a kingdom you run."** Phases 7, 8.
- **Bucket E — "It's in someone's hands."** Phase 9.

Each phase, when its issues complete, ends with a phase demo living in
`issues/completed/demos/`, and the project-root demo launcher gains one more
selectable number. The demos are part of the deliverable, not just an artifact —
they should show earlier phases' tools recombined in new ways alongside the new
phase's tools.

---

## Phase 1 — Engine Foundation
- **Capability:** Doom-style square-room world — map representation, rendering,
  player movement, collision, and the core game loop.
- **Dependencies:** none. This is the taproot.
- **Time-gate / milestone:** Bucket A, earliest. Nothing else can be *shown*
  until a player can move through a room and hit a wall. Expect to revisit it
  late for polish (movement feel, room "specialness").
- **Datapath doc:** [datapath-engine-foundation.md](datapath-engine-foundation.md)

## Phase 2 — Dual-Mouse Aiming & Input
- **Capability:** the two-mouse boomstick/wand peripheral; each mouse drives one
  hand; hand animation from dual-mouse input; an input abstraction layer.
- **Dependencies:** Phase 1 (needs a world and loop to aim within).
- **Time-gate / milestone:** Bucket A, right after a walkable world exists. The
  input abstraction layer is the load-bearing deliverable — later systems (3, 5)
  aim through it. BCI + ceiling headset are **stretch**, explicitly out of the
  time-gate; documented, not scheduled.
- **Datapath doc:** [datapath-dual-mouse-input.md](datapath-dual-mouse-input.md)

## Phase 3 — Spell System
- **Capability:** Dominions-style spell paths & levels; multiple distinct casts
  per spell; aimed spell effects routed through the input layer.
- **Dependencies:** Phases 1, 2.
- **Time-gate / milestone:** Bucket B, opening move. Turns "a world you move in"
  into "a game with a verb." The multiple-casts-per-spell requirement means this
  phase keeps growing after it first ships.
- **Datapath doc:** [datapath-spell-system.md](datapath-spell-system.md)

## Phase 4 — Puzzles, Mechanisms & Traps
- **Capability:** mechanisms with multiple triggers AND multiple solutions plus
  equal-seeming red-herring triggers; platforming puzzles; magic-effect-driven
  solutions; traps that fire on failure (disarming can itself be a puzzle).
- **Dependencies:** Phases 1, 3 (needs a world and spell effects to solve with).
- **Time-gate / milestone:** Bucket B, alongside/after the spell system. This is
  the raw material the Dungeon Master (Phase 6) will later generate and remix.
- **Datapath doc:** [datapath-puzzles-and-traps.md](datapath-puzzles-and-traps.md)

## Phase 5 — NCP Characters & LLM Companions
- **Capability:** autonomous New Character Person adventurers; LLM companion
  speech that grows between interactions; character templates saved as
  *summarized* patterns; the weaker puzzle-solving AI the NPCs use; player can
  aim while controlling an NCP.
- **Dependencies:** Phases 1, 3, 4.
- **Time-gate / milestone:** Bucket C, opening move. The moment the game "plays
  itself." Companion speech coherence (summarized patterns) is the risk to watch.
- **Datapath doc:** [datapath-ncp-characters.md](datapath-ncp-characters.md)

## Phase 6 — AI Dungeon Master & Learning
- **Capability:** the powerful local AI that generates lairs (~3 puzzles + 4
  combats), remembers each party's demonstrated capability, updates its notion of
  a "level" to estimate character intellect, and runs the library / fairy-tale
  learning mechanic; difficulty tuned to per-stat levels.
- **Dependencies:** Phases 4, 5.
- **Time-gate / milestone:** Bucket C capstone. The heaviest AI work; local model
  constraints on the handheld will pressure earlier design. Gate its capstone on
  NCPs (5) actually solving hand-made puzzles (4) first.
- **Datapath doc:** [datapath-dungeon-master.md](datapath-dungeon-master.md)

## Phase 7 — Economy & Settlement Management
- **Capability:** treasure types (gold, gems, resource notes, trial logs); the
  template-configuration UI (templates, never instantiations); NPC requests met
  from player-configured markets; worker allocation trade-offs; service staff
  granting a production speed bonus.
- **Dependencies:** Phase 5 (NPCs are who make requests and bring back treasure).
- **Time-gate / milestone:** Bucket D. Can run in parallel with Phase 6 since it
  only strictly needs Phase 5, but it feeds Phase 8, so land it before Majesty.
- **Datapath doc:** [datapath-economy-settlement.md](datapath-economy-settlement.md)

## Phase 8 — Territory & Majesty Formula
- **Capability:** neighboring provinces yield resources by relationship (peaceful
  ally / hostile training ground / left-unclaimed for monsters to fight-over or
  cultivate); the Majesty clear-and-control loop; unkindness to too many spawns a
  **union** that ends you.
- **Dependencies:** Phases 6, 7.
- **Time-gate / milestone:** Bucket D capstone. Needs the DM to generate the
  province trials (6) and the economy to price their yields (7).
- **Datapath doc:** [datapath-territory-majesty.md](datapath-territory-majesty.md)

## Phase 9 — Platform & Packaging
- **Capability:** running on the Anbernic handheld ("give one copy to each
  european"); the cassette → gameboy-control-interface → pico-8-style binary-
  sound recording delivery concept.
- **Dependencies:** all prior phases.
- **Time-gate / milestone:** Bucket E, the delivery capstone. Constraints from
  here (handheld memory, LuaJIT-only syntax) should have been honored since Phase
  1, so this bucket is packaging and porting, not rewriting.
- **Datapath doc:** [datapath-platform-packaging.md](datapath-platform-packaging.md)
