# Table of Contents — First Person Spellcraft docs

> The master index of the project's documentation. Every doc is reachable from
> here, and every doc should link back toward here. Issue files and source code
> are intentionally NOT listed — only `docs/`, `notes/`, and similarly narrative
> directories belong in this tree.
>
> Entries marked *(planned)* are forward-declarations: the file does not exist
> yet, but its exact filename is fixed here so that per-phase agents create it at
> the right path and every cross-link resolves.

---

## Document tree

```
notes/
  vision ................................. the source of truth (and the poetry)
  vision-control-scheme ................. the two-mouse locomotion / fire control map
  note-to-claude-ai ..................... the single-namespace coding-methodology note

docs/
  vision-overview.md .................... structured distillation of the vision
  roadmap.md ............................ time-gated, dependency-driven phase plan
  table-of-contents.md .................. this file
  soramech-notes.md .................... dataflow-substrate patterns (shared w/ SoraMech)
  datapath-engine-foundation.md ........ (planned) Phase 1 datapath
  datapath-dual-mouse-input.md ......... (planned) Phase 2 datapath
  datapath-spell-system.md ............. (planned) Phase 3 datapath
  datapath-puzzles-and-traps.md ........ (planned) Phase 4 datapath
  datapath-ncp-characters.md ........... (planned) Phase 5 datapath
  datapath-dungeon-master.md ........... (planned) Phase 6 datapath
  datapath-economy-settlement.md ....... (planned) Phase 7 datapath
  datapath-territory-majesty.md ........ (planned) Phase 8 datapath
  datapath-platform-packaging.md ....... (planned) Phase 9 datapath
  HTML/ ................................. (planned) unified docs website
```

---

## Documents

### Narrative source
- [notes/vision](../notes/vision) — the original vision. Source of truth, and in
  places source of poetry; treated as sacrosanct.
- [notes/vision-control-scheme](../notes/vision-control-scheme) — the dual-mouse
  control scheme: the "helicopter jetpack" locomotion map, the fire/alt split, and
  the screen-center grip↔trigger swap. Implemented by issue 208 (208a/208b);
  sacrosanct where it speaks in specifics.
- [notes/note-to-claude-ai](../notes/note-to-claude-ai) — the project's proposed
  single-namespace / narrative-`main()` coding methodology (contiguous file with
  include-continuation, story-named functions, "a step beyond could be assembly").
  Kept as a narrative note, not an issue: it is a project-wide coding-style intent,
  cross-referenced here so it stays discoverable.

### Overview & planning
- [vision-overview.md](vision-overview.md) — structured feature distillation,
  target platforms, language policy, statistics discipline.
- [roadmap.md](roadmap.md) — the nine phases as **time-gated** milestone buckets
  with an explicit dependency graph.
- [table-of-contents.md](table-of-contents.md) — this index.
- [soramech-notes.md](soramech-notes.md) — design patterns found while building the
  engine on a SoraMech-style dataflow substrate (long-running circular maps,
  two-tier value transport, drain-and-sum, build-then-publish ownership, the
  bucketed sorted index). Canonical here; a copy is shared into the SoraMech
  project so lessons learned downstream reach it upstream.

### Per-phase datapath docs *(planned — one per phase)*
Each describes how data flows through that phase's feature. Created by the
per-phase work, not yet present:
- [datapath-engine-foundation.md](datapath-engine-foundation.md) *(planned)* — Phase 1
- [datapath-dual-mouse-input.md](datapath-dual-mouse-input.md) *(planned)* — Phase 2
- [datapath-spell-system.md](datapath-spell-system.md) *(planned)* — Phase 3
- [datapath-puzzles-and-traps.md](datapath-puzzles-and-traps.md) *(planned)* — Phase 4
- [datapath-ncp-characters.md](datapath-ncp-characters.md) *(planned)* — Phase 5
- [datapath-dungeon-master.md](datapath-dungeon-master.md) *(planned)* — Phase 6
- [datapath-economy-settlement.md](datapath-economy-settlement.md) *(planned)* — Phase 7
- [datapath-territory-majesty.md](datapath-territory-majesty.md) *(planned)* — Phase 8
- [datapath-platform-packaging.md](datapath-platform-packaging.md) *(planned)* — Phase 9

### Docs website *(planned)*
- `docs/HTML/` *(planned)* — a unified-style HTML rendering of all documentation,
  with a left-hand table of contents linking every page to every other page,
  charts/sliders/toys, syntax-highlighted code, and clickable issue numbers.
  Noted as a future deliverable; not built yet.

---

## Phases (organizational groupings — NOT time-gated)

This section **defines** the nine phases as functional groupings of capability.
It is deliberately time-free; sequencing and milestones are the
[roadmap](roadmap.md)'s job. The numbers order the groupings by **dependency**,
so a low-numbered phase is a foundation others rest on — not necessarily the
first thing finished.

1. **Engine Foundation** — the Doom-style square-room world: map representation,
   rendering, player movement, collision, and the core game loop. The taproot
   everything else grows from.
2. **Dual-Mouse Aiming & Input** — the signature two-mouse boomstick/wand
   peripheral (each mouse a hand), hand animation from that input, and the input
   abstraction layer later systems aim through. Home of the documented BCI +
   ceiling-headset stretch goals.
3. **Spell System** — Dominions-style spell paths and levels, multiple distinct
   ways to cast each spell, and aimed spell effects.
4. **Puzzles, Mechanisms & Traps** — mechanisms with multiple triggers and
   multiple solutions (plus equal-seeming red-herring triggers), platforming
   puzzles, magic-effect-driven solutions, and traps that fire on failure.
5. **NCP Characters & LLM Companions** — autonomous New Character Person
   adventurers, growing LLM companion speech, summarized character templates,
   the weaker puzzle-solving AI the NPCs use, and player-controlled aiming.
6. **AI Dungeon Master & Learning** — the powerful local AI that generates lairs,
   remembers party capability, re-conceives what a "level" means, and runs the
   library / fairy-tale learning mechanic.
7. **Economy & Settlement Management** — treasure types, the template-only
   configuration UI, market-fulfilled NPC requests, worker-allocation trade-offs,
   and chore-handling service staff.
8. **Territory & Majesty Formula** — relationship-dependent province yields, the
   Majesty clear-and-control loop, and the union that ends an unkind ruler.
9. **Platform & Packaging** — the Anbernic handheld target and the whimsical
   cassette → gameboy-control-interface → pico-8-style delivery. The capstone.
