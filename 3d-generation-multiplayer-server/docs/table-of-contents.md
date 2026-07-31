# 3d-generation-multiplayer-server — table of contents

An existing server we did not write, cloned fresh on every build and never
committed, narrowed patch by reversible patch until the game it hosts is
movement, one click, and waiting — played by pink star squiggles in a world of
squares and triangles.

Source files and issue files are not listed here. The source order is given by
the index at the head of each filename; the issues are indexed by
`docs/roadmap.md`.

```
3d-generation-multiplayer-server/
│
├── notes/                              the ask, and what was said while building
│   ├── vision ............................ the original request, unedited
│   └── spoken-while-building.md .......... the person's words during the making, verbatim
│
├── docs/
│   ├── table-of-contents.md .............. this file
│   ├── architecture.md ................... three trees, two protocols, one thesis
│   ├── roadmap.md ........................ six phases, and the open questions
│   │
│   ├── datapath-the-patch-machine.md ..... clone → apply → build → revert → audit
│   ├── datapath-the-handshake.md ......... a proof that never carries the password
│   ├── datapath-the-world-stream.md ...... encrypted headers, opcodes, update blocks
│   ├── datapath-the-whisp.md ............. how a pink star squiggle is made
│   ├── datapath-the-world-of-shapes.md ... terrain, four schemes, and custom maps
│   │
│   ├── balance-updates.md ................ knobs turned and levers pulled, append-only
│   ├── patches/ .......................... generated: the registry, and audit reports
│   └── HTML/ ............................. generated documentation pages (phase 6)
│
├── strategems/                         patterns that proved useful beyond this project
│   └── the-tree-is-a-build-artifact.md ... version the intent, regenerate the result
│
├── desire/
│   └── what-would-be-better.md ........... wanting that has not earned a blueprint yet
│
├── faith/
│   └── expectation-of-boons.md ........... what is being counted on
│
├── input/                              read first; how the program learns to start
│   ├── account.example ................... where to log in; copy to input/account
│   ├── realm.example ..................... which world to enter; copy to input/realm
│   └── world/ ............................ scratch geometry: renderer fixtures, NOT the map format
│
├── output/                             written last; where goodbye goes
│   └── sessions/ ......................... recorded packet logs, gitignored, replayable
│
├── upstream/                           ◀── THE CLONE. gitignored. disposable.
│   └── azerothcore/ ...................... never edited by hand; only by patches/
│
├── patches/                            the real source of truth for every change
│   ├── patches.sh ........................ the orchestrator: profiles and drivers
│   ├── P###-*.sh ......................... pre-build: source patches, exactly reversible
│   ├── I###-*.sh ......................... post-build: staging setup
│   └── C###-*.sh ......................... post-deploy: live tuning
│
├── modules/                            the seam upstream already cut; preferred over patches
│
├── scripts/                            the machinery, not the procedure
│   ├── scaffold-patch .................... emits a new patch skeleton
│   ├── verify-patches .................... asserts round-trip and match count; a gate
│   ├── gen-registry ...................... rebuilds the registry from patch headers
│   ├── audit-patches ..................... the pruning machine
│   ├── redownload-source ................. wipe the clone; the tree is regenerable
│   ├── install ........................... clone, then build
│   └── compile ........................... apply → build → unapply
│
├── src/                                our client, and eventually our engine
│   ├── net/ .............................. sockets, crypto, packets. Knows no whisps.
│   ├── world/ ............................ what exists and where. Knows no screen.
│   └── draw/ ............................. geometry and colour. Knows no socket.
│
├── tools/                              generators: geometry into what the server needs
├── tests/                              a proof beside each module
├── libs/                               symlinks to the shared shelf
├── assets/                             generated and extracted data, gitignored
│
├── issues/                             blueprints, not work logs
│   ├── phase-1-progress.md ............... and one per phase as they complete
│   └── completed/
│       └── demos/ ........................ a runnable demonstration per finished phase
│
└── tmp/ → /tmp/3d-generation-multiplayer-server          RAM, exec tier
    └── shared-memory/ → /dev/shm/3d-generation-multiplayer-server   RAM, logs
```

## The phases

Each phase is a cluster of functionality, not a stretch of calendar. They are
detailed in `docs/roadmap.md`.

| Phase | Name | What it is |
|---|---|---|
| 1 | **The Tree That Isn't Ours** | changing code we did not write, safely and reversibly, forever |
| 2 | **The Handshake** | the login conversation; a session key, headless |
| 3 | **The World Stream** | the encrypted duplex stream, and a model of what exists |
| 4 | **The World of Shapes** | the first time anyone sees anything |
| 5 | **The Narrowing** | taking things away, one reversible patch at a time |
| 6 | **One Project** | the client and the engine become one thing |

## Where to start reading

**To understand what this is:** `notes/vision`, then `docs/architecture.md`.

**To understand the one idea everything rests on:**
`docs/datapath-the-patch-machine.md`. The clone is a build artifact; the patches
are the project.

**To understand what it looks like:** `docs/datapath-the-whisp.md`, and the
three words in `notes/spoken-while-building.md` it grew from.

**To build on it:** `docs/roadmap.md` — including its open questions, which are
live — then the issue files for the phase you are in.

**To find a pattern worth stealing:** `strategems/`.
