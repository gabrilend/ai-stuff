# dominions-interpreter — table of contents

    dominions-interpreter/
    │
    ├── notes/
    │   └── vision ......................... the original ask, unedited
    │
    ├── docs/
    │   ├── architecture.md ................ the loop, the six parts, and who this is for
    │   ├── roadmap.md ..................... seven phases, foundational-first
    │   ├── table-of-contents.md ........... this file
    │   ├── balance-updates.md ............. knobs turned, and why
    │   ├── dominions-file-formats.md ...... what is known about the bytes, and how
    │   │
    │   ├── datapath-the-reading.md ........ savegame → world table
    │   ├── datapath-the-court.md .......... who can be spoken to
    │   ├── datapath-the-chronicle.md ...... append-only memory, three kinds of line
    │   ├── datapath-the-ledger.md ......... intended moves, as a file
    │   ├── datapath-the-doors.md .......... the cluster and its three roles
    │   └── datapath-the-hand.md ........... orders written, and judged by the game
    │
    ├── strategems/
    │   └── a-connection-must-name-its-evidence.md
    │
    ├── desire/
    │   └── what-would-be-better.md
    │
    ├── faith/
    │   └── expectation-of-boons.md
    │
    ├── input/
    │   ├── cluster.example ................ the door roster format
    │   └── game.example ................... which savegame, and where the game lives
    │
    ├── src/ ............................... numbered, front to back as one story
    │   └── *.info.md ...................... one per source file; read these, not the code
    │
    ├── issues/
    │   ├── 101 … 108 ...................... phase 1, the blueprints
    │   └── phase-1-progress.md ............ where the phase stands, and what it taught
    │
    ├── survey ............................. report what a savegame collection contains
    ├── tests-run .......................... run every check, against the real collection
    │
    ├── output/
    └── tmp/ ............................... symlink into the RAM tiers

## The phases

The roadmap's phases are groups of functionality, not stages of a schedule.

| Phase | Name | One line |
|---|---|---|
| 1 | The Reading | a savegame becomes a table describing a world |
| 2 | The Chronicle | somewhere expensive, unrepeatable work lands safely |
| 3 | The Court | the part of the world that can be spoken to |
| 4 | The Ledger | the intended moves, as a file, useful on their own |
| 5 | The Doors | three little machines, reached over HTTP |
| 6 | The Conversation | where a person actually plays |
| 7 | The Hand | orders written into the game's own file, and judged by it |

## Reading order for somebody new

1. `notes/vision` — what was asked for
2. `docs/architecture.md` — what it turned into
3. `docs/dominions-file-formats.md` — the ground truth everything stands on
4. `docs/roadmap.md` — the order it gets built in
5. whichever datapath covers the part you are touching

## Neighbouring projects worth knowing about

| Project | Where | Why it matters here |
|---|---|---|
| **chronicler** | inside the Dominions folder | version-controls savegames; first established the obfuscation and header |
| **gif-generator** | the monorepo | its porch defines the door roster format |
| **backwards-reader** | the monorepo | the price-as-load-balancer mechanism, and the doors convention |
| **dominions-modernization** | the monorepo | a separate vision: generating nations, not playing turns |
