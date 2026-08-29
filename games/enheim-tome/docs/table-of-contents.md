# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Source files and issue files
are not listed here; source files are found through their companion `.info.md`
pages, and issues are found through [the roadmap](009-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order, not a
per-directory sequence.

```
enheim-tome/
│
├── notes/
│   └── vision ................................ Where all of this came from, in the
│                                               author's own words. A city that is
│                                               not at war and not in peril, only
│                                               rigid, and the wish to loosen it.
│                                               Read first.
│
├── assets/
│   └── vision-map.png ........................ The painting. 6148 by 4092, an
│                                               oblique aerial view of a walled
│                                               city at a river's confluence.
│                                               This single image is the entire
│                                               game board.
│
├── docs/
│   ├── 001-what-this-game-is ................. The premise, the governing idea that
│   │                                           the map is a model rather than a
│   │                                           camera, the project vocabulary, the
│   │                                           refusal to claim distances, and the
│   │                                           rule about colour.
│   │
│   ├── ── The drawn half ──
│   ├── 002-the-map-surface ................... One painting as one texture. Pan,
│   │                                           zoom, the five-fold range, the
│   │                                           block-identity buffer, the glow,
│   │                                           and the four things the map is ever
│   │                                           allowed to draw.
│   ├── 003-the-fence-network ................. Blocks are faces of a network, not
│   │                                           polygons. Vertices, edges, loops,
│   │                                           junctions against shape points, and
│   │                                           adjacency as a shared edge.
│   ├── 004-the-tracing-tool .................. The second program. The click that
│   │                                           does three different things, and
│   │                                           why adopting a whole edge is what
│   │                                           makes hand-tracing survivable.
│   ├── 005-filters-and-the-weave ............. Ways of looking at the city. Why a
│   │                                           reading of *nothing* is the most
│   │                                           important value, the three stacking
│   │                                           modes, and the parity rule that
│   │                                           lets hatchings pass through each
│   │                                           other instead of burying each other.
│   │
│   ├── ── The written half ──
│   ├── 006-the-tome .......................... The column that holds every word in
│   │                                           the game. Three regions, the chip
│   │                                           row, the button pane, and going to
│   │                                           a place by name.
│   ├── 007-the-day-and-the-curve ............. The hour as a global axis, the
│   │                                           reason the time is only ever now,
│   │                                           and a person's day as a sweepable
│   │                                           shape 225 pixels wide.
│   │
│   ├── ── Building it ──
│   ├── 008-the-shape-of-the-code ............. House style. Two programs, folds,
│   │                                           companions, dispatch tables, the
│   │                                           rule against fallbacks, and where
│   │                                           files live in RAM.
│   ├── 009-roadmap ........................... Six phases, the issues intended
│   │                                           under them, and what is
│   │                                           deliberately absent.
│   ├── 010-open-questions .................... Seventeen answered with their
│   │                                           rejected alternatives, twelve still
│   │                                           open, and five problems this design
│   │                                           does not have.
│   │
│   └── table-of-contents ..................... This page.
│
├── issues/ ................................... Phase-numbered issue files.
│   └── completed/                              Blueprints for building the
│       └── demos/ ...........................  software, not work logs. Empty —
│                                               the roadmap has not been broken
│                                               into issues yet.
│
├── src/ ...................................... Numbered source files, each with a
│                                               companion .info.md. Empty.
├── libs/ ..................................... Third-party code, renumbered high.
│
├── input/ .................................... Read first, at startup.
├── output/ ................................... Written last. Goodbye goes here.
├── desire/ ................................... What we would like to be better.
├── faith/ .................................... Expectation of boons and blessings.
├── strategems/ ............................... Data-flow patterns that keep working.
├── llm-transcripts/ .......................... The full development conversation.
│
└── tmp/ ...................................... → /tmp/enheim-tome (RAM, executable)
    └── shared-memory/ ....................... → /dev/shm/enheim-tome (RAM, artefacts)
```

## The phases

Defined here as well as in [the roadmap](009-roadmap.md), because they are how the
functionality is grouped and not only how the work is ordered. **Lower numbers are
more foundational, not earlier in time.**

| Phase | Name | What it clusters |
| --- | --- | --- |
| 1 | The Canvas | One painting on screen, pannable and zoomable. No game in it at all, and runnable as a pure viewer forever after. |
| 2 | The Cage | The fence network as a structure and as an appearance. Adjacency, the identity buffer, and the one-pixel line that fades on each block's own size. |
| 3 | The Tracing Tool | The second program. The instrument for defining a city by hand, and the only thing that ever writes a network. |
| 4 | Filters and the Weave | Ways of looking at the city, drawn over it. The readings first, checkable with nothing on screen; the hatching after. |
| 5 | The Tome | The written half. Three regions, the chips, the buttons, the text, and the search. |
| 6 | The Day | The hour as a global axis, and the small horizontal object that lets you sweep through somebody's day. |

**The mechanics are deliberately absent** and will form later phases once they
exist. Everything above is interface, worked out ahead of the systems it will
show — which constrains those systems usefully, since a game whose map cannot
carry text and cannot express a radius is a different game from one that can.
