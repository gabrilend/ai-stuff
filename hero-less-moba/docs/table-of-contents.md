# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Source files and issue
files are not listed here; source files are found through their companion
`.info.md` pages and issues are found through
[the roadmap](019-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order, not a
per-directory sequence.

```
hero-less-moba/
│
├── LICENSE ................................... The GNU Affero General Public
│                                               License, version 3, verbatim.
├── COPYING.md ................................ What the AGPL asks of you, and the
│                                               notice every source file carries.
│
├── run-prototype ............................. The front door. Opens the window,
│                                               or runs the same match headless,
│                                               in a terminal, or as a screenshot.
├── run-tests ................................. Both halves at once: the document
│                                               validator and the invariants.
├── run-phase-demo ............................ Asks which phase demo to run,
│                                               and runs it.
├── validate-documentation .................... Checks the documents and issues
│                                               against each other. A compiler
│                                               for the written half.
├── new-source-file ........................... The only sanctioned way to bring a
│                                               source file in. Claims the next
│                                               index, stamps the licence, writes
│                                               the companion stub.
├── fill-source-file .......................... Rewrites a file's body without ever
│                                               disturbing its licence notice.
│
├── main.lua .................................. LOVE insists on this name at the
│                                               root, so it is the one unnumbered
│                                               source file. A doorway, not a room.
├── conf.lua .................................. The window's shape, and which engine
│                                               modules are started at all.
│
├── src/ ...................................... The simulation and the viewer.
│                                               Numbered 028 upward. Not listed
│                                               here — each file is found through
│                                               its companion .info.md page.
├── assets/ ................................... The catalogue tables. Every balance
│                                               number in the game is in one of
│                                               these and in no document.
├── tests/ .................................... The invariants, 051.
│
├── notes/
│   ├── vision ................................ Where all of this came from, in the
│   │                                           author's own words. Read first.
│   ├── vision-2 .............................. The second vision: what it looks
│   │                                           like and what your hands do. Runes
│   │                                           on the towers, and a camera that
│   │                                           zooms out when you pick one up.
│   └── vision-3 .............................. The third vision: what the enemy
│                                               actually is. Coal statues that
│                                               emit fear, the paladins who answer
│                                               them, and an economy of dice.
│
├── docs/
│   ├── 001-what-this-game-is ................. The subtraction premise, the three
│   │                                           replacement layers, design pillars,
│   │                                           and the project vocabulary.
│   │
│   ├── ── The world ──
│   ├── 002-the-map-and-its-milestones ........ The path graph, the three lanes, the
│   │                                           three junctions, and the
│   │                                           milestones that measure a push.
│   ├── 003-the-simulation-tick ............... The heartbeat: order of operations,
│   │                                           named random streams, where the
│   │                                           thread pool goes, the world record.
│   │
│   ├── ── Things that move ──
│   ├── 004-a-unit-and-what-it-carries ........ The soldier record and its brain.
│   │                                           One body type for waves, heroes,
│   │                                           guards, and monsters.
│   ├── 005-waves-and-when-one-is-finished .... Spawn cadence and the bookkeeping
│   │                                           that turns a wipe into a draw.
│   ├── 006-combat-and-damage ................. Buffered damage, armour, kill
│   │                                           attribution, where abilities fit.
│   │
│   ├── ── Things that stand ──
│   ├── 007-guard-towers-and-their-guards ..... Where stone stands, what it shoots,
│   │                                           the patrols around it, and the
│   │                                           three-upgrade prize for felling it.
│   ├── 008-the-base-and-the-library .......... The win condition, and the rule that
│   │                                           picks a lane for a hero spawned on
│   │                                           the library.
│   │
│   ├── ── The chest ──
│   ├── 009-the-shared-upgrade-pool ........... Upgrade kinds and instances, drawing,
│   │                                           placing, contributing, and the
│   │                                           rule.
│   ├── 010-upgrades-slotted-into-stone ....... Tower slots, and the rule that makes
│   │                                           every lane's stone defend the base.
│   │
│   ├── ── The players ──
│   ├── 011-commanders-and-personal-resource .. The second economy: a private
│   │                                           currency that buys nothing but
│   │                                           bodies.
│   ├── 012-hero-units ........................ What you buy, where it may appear,
│   │                                           and what happens when it dies.
│   ├── 013-signposts-and-lane-routing ........ Four objects in the world that steer
│   │                                           every hero that passes them.
│   │
│   ├── ── The shape of a match ──
│   ├── 014-the-siege-surge ................... The phase where the chest cannot be
│   │                                           touched and every body carries a
│   │                                           share of it, dealt three ways.
│   ├── 015-boons-and-the-challenge ........... What you are handed, and the three
│   │                                           named things that come out of the
│   │                                           middle. The last one cannot be killed.
│   ├── 016-players-teams-and-commands ........ Six players, and the single door all
│   │                                           player intent comes through.
│   │
│   ├── ── Building it ──
│   ├── 017-the-viewing-layer ................. The second program: what it may read
│   │                                           and what it may never do.
│   ├── 018-the-shape-of-the-code ............. House style. Numbering, folds,
│   │                                           companions, dispatch tables, and the
│   │                                           rule against fallbacks.
│   ├── 019-roadmap ........................... Nine phases, the issues under them,
│   │                                           and what is deliberately absent.
│   ├── 020-open-questions .................... Every decision made and unmade,
│   │                                           in three states: answered, awaiting
│   │                                           evidence, and needing a decision.
│   ├── 021-nobody-remembers-why .............. The setting. An automated war nobody
│   │                                           started, two archives nobody has read,
│   │                                           and the one thing that remembers.
│   ├── 022-standing-off-and-falling-back ..... What a body does that is not
│   │                                           walking forward and swinging:
│   │                                           keeping range, leaving the line
│   │                                           to mend, and who a healer picks.
│   ├── 023-ways-this-could-go-wrong .......... Failure modes, not decisions.
│   │                                           Shapes the game could settle into
│   │                                           that nobody wants, each with what
│   │                                           resists it and what would show it.
│   │
│   ├── table-of-contents ..................... This page.
│   ├── balance-updates ....................... Append-only ledger of knobs turned
│   │                                           and levers pulled, with reasons.
│   └── HTML/ ................................. Generated browsable copy of all of
│                                               the above. Built by a tool; never
│                                               edited by hand.
│
├── issues/ ................................... Phase-numbered issue files. Blueprints
│   └── completed/                              for building the software, not work
│       └── demos/ .......................      logs. Each phase's demo lives here.
│
├── src/ ...................................... Numbered source files, each with a
│                                               companion .info.md.
├── libs/ ..................................... Third-party code, renumbered high.
├── assets/ ................................... Sprites, sounds, catalogue tables.
│
├── input/ .................................... Read first, at startup.
├── output/ ................................... Written last. Goodbye goes here.
├── desire/ ................................... What we would like to be better.
├── faith/ .................................... Expectation of boons and blessings.
├── strategems/ ............................... Data-flow patterns that keep working.
│
└── tmp/ ...................................... → /tmp/hero-less-moba (RAM, executable)
    └── shared-memory/ ...................... → /dev/shm/hero-less-moba (RAM, artefacts)
```

## The phases

Defined here as well as in [the roadmap](019-roadmap.md), because they are how the
functionality is grouped and not only how the work is ordered. Lower numbers are
more foundational, not earlier in time.

| Phase | Name | What it clusters |
| --- | --- | --- |
| 1 | The Ground and the Clock | The map, the tick, determinism, snapshots, the command door. Everything with no gameplay in it. |
| 2 | Things That Walk and Fight | The soldier: one record, one brain, one combat system, used by everything that ever moves. |
| 3 | Things That Stand and Hold | Stone: towers, guards, the base, the library, and the first winnable match. |
| 4 | The Shared Chest | Upgrades, the pool, placement, and the lock-and-objection negotiation. The centre of the game. |
| 5 | Commanders and Heroes | The second economy, the bodies it buys, and the sign-posts that steer them. |
| 6 | The Surge and the Challenge | The layer that takes the board apart three times a match. |
| 7 | Watching It Happen | The real viewer, and the documentation as browsable HTML. |
| 8 | Six Players | Networking, a lobby, a measuring bot, batch balance runs, and the capstone match. |
| 9 | An Opponent Worth Playing | Single-player: a bot built to be played against rather than measured with, including the two that share your chest. The only optional phase. |
