# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Source files and issue
files are not listed here; source files are found through their companion
`.info.md` pages and issues are found through [the roadmap](015-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order, not a
per-directory sequence.

```
supcom-derivative-clone/
│
├── README.md ................................. The game design, and only the game
│                                               design. Start here if you want to
│                                               know what this is.
├── LICENSE ................................... The GNU Affero General Public
│                                               License, version 3, verbatim.
├── COPYING.md ................................ What the AGPL asks of you, and the
│                                               notice every source file carries.
│
├── compile ................................... Parses every Lua file and packages
│                                               the computer build; knows the
│                                               shape of the handheld build and
│                                               refuses it by name until phase 8.
├── dependencies-version-updater .............. What the project needs beyond
│                                               LuaJIT: updates the manifest's pins,
│                                               installs from them, compiles.
├── update-dependencies ....................... → the updater, doing only the first.
├── install-dependencies ...................... → the updater, doing only the second.
├── run-tests ................................. Both halves at once: the document
│                                               validator and every test program.
├── validate-documentation .................... Checks the documents, issues, and
│                                               tests against each other. A
│                                               compiler for the written half.
├── build-documentation ....................... Turns all of this into browsable,
│                                               cross-linked HTML in docs/HTML/.
├── run-phase-demo ............................ Asks which phase demo to run, and
│                                               runs it.
├── new-source-file ........................... The only sanctioned way to bring a
│                                               source file in. Claims the next
│                                               index, stamps the licence, writes
│                                               the companion stub.
├── new-document .............................. The same for a document in docs/.
├── new-issue ................................. The same for an issue: the frame,
│                                               the metadata table, the row in the
│                                               phase tracker.
├── complete-issue ............................ Moves a finished issue into
│                                               completed/, rewrites its links,
│                                               marks the phase tracker.
├── fill-source-file .......................... Rewrites a file's body without ever
│                                               disturbing its licence notice.
│
├── src/ ...................................... The simulation and the viewers.
│                                               Empty until the tests say what
│                                               goes in it. Numbered, each with a
│                                               companion .info.md.
├── tests/ .................................... The specification. One program per
│                                               cluster of mechanics, each naming
│                                               the issues it covers. Written first.
├── scripts/ .................................. Tools that read the project rather
│                                               than run it: the HTML generator.
├── assets/ ................................... The catalogue tables. Every balance
│                                               number in the game is in one of
│                                               these and in no document.
├── libs/ ..................................... Third-party code, numbered into the
│                                               900 band, installed from the
│                                               manifest in input/.
│
├── notes/
│   └── vision ................................ Where all of this came from, in the
│                                               author's own words. Read first.
│
├── docs/
│   ├── 001-what-this-game-is ................. The two changes -- nothing out of
│   │                                           range, units that stop listening --
│   │                                           and everything that follows from
│   │                                           them. The vocabulary.
│   │
│   ├── ── The ground ──
│   ├── 002-the-dunes-and-the-sightlines ...... The heightfield, raised by a tool
│   │                                           from a seed. What a sightline is
│   │                                           and what it costs to ask.
│   ├── 003-the-tick-and-the-timers ........... The heartbeat as a dispatch table,
│   │                                           and the one shape every periodic
│   │                                           effect takes: a pair of integers.
│   │
│   ├── ── Things that move ──
│   ├── 004-a-unit-and-what-it-carries ........ One record for everything on the
│   │                                           field. Infinite range, falloff,
│   │                                           buffered damage, shared healing.
│   │
│   ├── ── The economy ──
│   ├── 005-territory-mass-and-energy ......... Territory painted on cells. Mass
│   │                                           from ground, energy built on it,
│   │                                           four buttons, the roster, thorns.
│   ├── 006-factories-and-patterns-in-the-sand  Lines you did not design, patterns
│   │                                           drawn once, and the invariant that
│   │                                           everything is queued.
│   │
│   ├── ── The air ──
│   ├── 007-the-cloud ......................... The air war, somewhere else. Rounds
│   │                                           on a counter, fight or avoid,
│   │                                           defensive planes over the guns.
│   ├── 008-the-command-truck-and-its-plane ... The player's presence, the compass
│   │                                           wheel, and a scout with one missile.
│   │
│   ├── ── The big things ──
│   ├── 009-enforcers-and-experimentals ....... The tier-two walker that eats, and
│   │                                           the experimentals everyone shares.
│   │
│   ├── ── Building it ──
│   ├── 010-the-views ......................... The second program. Lenses, the
│   │                                           always-open menu, drawing in the
│   │                                           sand, the terminal viewer.
│   ├── 011-other-players ..................... Lockstep and why. The wire on a
│   │                                           computer, and the wire on the
│   │                                           handheld with its numbers pending.
│   ├── 012-the-handheld ...................... The two-screen device, what a
│   │                                           program is there, and why this
│   │                                           game already fits in a box.
│   ├── 013-the-shape-of-the-code ............. House style. Numbering, folds,
│   │                                           companions, dispatch tables, and
│   │                                           the rule against fallbacks.
│   ├── 014-the-tests-come-first .............. The contract between the tests and
│   │                                           the source that does not exist yet.
│   ├── 015-roadmap ........................... Nine phases, the issues under them,
│   │                                           and what is deliberately absent.
│   ├── 016-open-questions .................... Every decision made and unmade, in
│   │                                           three states: working ruling,
│   │                                           awaiting evidence, direction set.
│   │
│   ├── table-of-contents ..................... This page.
│   ├── balance-updates ....................... Append-only ledger of knobs turned
│   │                                           and levers pulled, with reasons.
│   └── HTML/ ................................. Generated browsable copy of all of
│                                               the above. Built by a tool; never
│                                               edited by hand.
│
├── issues/ ................................... Phase-numbered issue files. Blueprints
│   ├── phase-N-progress.md                     for building the software, not work
│   └── completed/                              logs. Each phase's demo lives here.
│       └── demos/
│
├── input/ .................................... Read first, at startup. The seed,
│                                               and the dependency manifest.
├── output/ ................................... Written last. Goodbye goes here.
├── desire/ ................................... What we would like to be better.
├── faith/ .................................... Expectation of boons and blessings.
├── strategems/ ............................... Data-flow patterns that keep working.
├── llm-transcripts/ .......................... The whole development, as
│                                               conversation. Rides with every commit.
│
└── tmp/ ...................................... → /tmp/supcom-derivative-clone (RAM, executable)
    └── shared-memory/ ...................... → /dev/shm/supcom-derivative-clone (RAM, artefacts)
```

## The phases

Defined here as well as in [the roadmap](015-roadmap.md), because they are how the
functionality is grouped and not only how the work is ordered. Lower numbers are
more foundational, not earlier in time.

| Phase | Name | What it clusters |
| --- | --- | --- |
| 1 | The Dunes and the Clock | The field, sightlines, the tick, timers, streams, the command door, snapshots, territory. Everything with no gameplay in it. |
| 2 | Things That Roll, Fly, and Sail | The unit: one record, three domains, infinite range, buffered damage, shared healing, bones, the truck, the enforcer. |
| 3 | Inflows and Outflows | Mass from ground, energy on ground, the four-button menu, the roster, streaming construction, lines and patterns, thorns. |
| 4 | The Cloud | The air war: the swarm, rounds, fight or avoid, defensive flight over the guns, reports and bombing runs. |
| 5 | The Big Things | Experimentals for everyone, carriers that build while moving, and the sea's counters. |
| 6 | Watching It Happen | The window, lenses, the menu on screen, drawing in the sand, the cloud window, the compass wheel, the generated tileset. |
| 7 | Other Players | Lockstep, scheduling, transports on a computer and the handheld, discovery, desyncs, rejoining. |
| 8 | The Handheld | The simulation as boxes, two screens, the stylus, the handheld build. |
| 9 | An Opponent | A bot that plays and measures. The only optional phase. |
