# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Source files and issue files
are not listed here; source files are found through their companion `.info.md`
pages, and issues are found through [the roadmap](011-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a **reading order**, not the order
things were written. They are renumbered whenever the story changes, which has
already happened once.

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
├── inspiration-pictures/ ..................... **Not ours.** Reference artwork,
│   ├── NOTICE.md ............................. gathered because it shows the city
│   │                                           better than description can. The
│   │                                           board is a stand-in and cannot
│   │                                           ship — read this before doing
│   │                                           anything with any of it.
│   ├── vision-map.png ........................ The painting. 6148 by 4092, an
│   │                                           oblique aerial view of a walled
│   │                                           city at a river's confluence.
│   │                                           What the game is developed against.
│   └── vision-map-2.webp ..................... The same city flat and from above,
│                                               2518 by 2400, districts and gates
│                                               already lettered. A second view,
│                                               wanted eventually, which must
│                                               register with the painting exactly.
│
├── assets/ ................................... The project's own material: the
│                                               fence network, the sun's path, the
│                                               catalogue tables, and one day a map
│                                               nobody has to apologise for. Empty.
│
├── docs/
│   ├── 001-what-this-game-is ................. The premise; the governing idea that
│   │                                           the map is one *person's* model of
│   │                                           the city; playing as whoever lives
│   │                                           in a house; the vocabulary; the
│   │                                           refusal to claim distances; and the
│   │                                           rule about colour.
│   │
│   ├── ── The drawn half ──
│   ├── 002-the-map-surface ................... One painting as one texture. Pan,
│   │                                           zoom, the five-fold range, the zoom
│   │                                           choosing what a click selects, the
│   │                                           identity buffer, the glow, and the
│   │                                           four things the map may ever draw.
│   ├── 003-the-places-of-the-city ............ Six levels from group down to house,
│   │                                           one of them absent beyond the wall.
│   │                                           Why a quadrant is a social horizon,
│   │                                           why everything above the block is
│   │                                           free, and the stone that roots
│   │                                           people.
│   ├── 004-the-fence-network ................. Blocks are faces of a network, not
│   │                                           polygons. Vertices, edges, loops,
│   │                                           junctions against shape points,
│   │                                           intersections as content, and
│   │                                           adjacency as a shared edge.
│   ├── 005-the-tracing-tool .................. The second program. The click that
│   │                                           does three different things, why
│   │                                           adopting a whole edge is what makes
│   │                                           hand-tracing survivable, and the
│   │                                           four other things it authors.
│   ├── 006-filters-and-the-weave ............. Ways of looking. Why the reading
│   │                                           takes a *person*, why a reading of
│   │                                           *nothing* is the most important
│   │                                           value, the three stacking modes,
│   │                                           and the parity rule that lets
│   │                                           hatchings pass through each other
│   │                                           instead of burying each other.
│   │
│   ├── ── The written half ──
│   ├── 007-the-tome .......................... The column holding every word in the
│   │                                           game. Three regions, the chip row,
│   │                                           the button pane, descending to a
│   │                                           person, and going somewhere by name.
│   ├── 008-the-day-and-the-curve ............. The hour as a global axis, the
│   │                                           reason the time is only ever now,
│   │                                           and a person's day as a sweepable
│   │                                           shape 225 pixels wide.
│   ├── 009-events-and-what-people-know ....... One hidden ordinary fact per block,
│   │                                           and eventually per house. Why
│   │                                           knowledge and the filters are one
│   │                                           system, and the rule against it
│   │                                           becoming a story.
│   │
│   ├── ── Building it ──
│   ├── 010-the-shape-of-the-code ............. House style. Two programs, folds,
│   │                                           companions, dispatch tables, the
│   │                                           rule against fallbacks, and where
│   │                                           files live in RAM.
│   ├── 011-roadmap ........................... Eight phases, the issues intended
│   │                                           under them, the writing campaign
│   │                                           that is not a phase, and what is
│   │                                           deliberately absent.
│   ├── 012-open-questions .................... Thirty-seven answered with their
│   │                                           rejected alternatives, fourteen still open,
│   │                                           and six problems this design does
│   │                                           not have.
│   │
│   └── table-of-contents ..................... This page.
│
├── issues/ ................................... Sixty-seven phase-numbered issue
│   │                                           files: blueprints for building the
│   │                                           software, not work logs. Numbered
│   │                                           by phase, so 3xx is the tracing
│   │                                           tool. None completed yet.
│   ├── phase-N-progress ...................... One per phase. What that phase is
│   │                                           for, what it settled before
│   │                                           anything was written, and what it
│   │                                           is blocked on.
│   └── completed/                              Where an issue moves when it is
│       └── demos/                              done. Each phase's demo lives here.
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

Defined here as well as in [the roadmap](011-roadmap.md), because they are how the
functionality is grouped and not only how the work is ordered. **Lower numbers are
more foundational, not earlier in time.**

| Phase | Name | What it clusters |
| --- | --- | --- |
| 1 | The Canvas | One painting on screen, pannable and zoomable. No game in it at all, and runnable as a pure viewer forever after. |
| 2 | The Cage | The fence network as a structure and an appearance. Adjacency, the identity buffer, and the line that fades on each place's own size. |
| 3 | The Tracing Tool | The second program. The instrument for defining a city by hand, and the only thing that ever writes a network. |
| 4 | The Places | Everything above and below the block — groups, quadrants, districts, buildings, houses. Mostly bookkeeping; almost no geometry. |
| 5 | Filters and the Weave | Ways of looking, drawn over the city. Readings first, checkable with nothing on screen; hatching after. |
| 6 | The Tome | The written half. Three regions, the chips, the buttons, the text, the search, and descending to a person. |
| 7 | The Day | The hour as a global axis, and the small horizontal object that lets you sweep through somebody's day. |
| 8 | Events, and What Is Known | The hidden layer, and the long writing campaign that fills it. |

**The mechanics are deliberately absent** and will form later phases once they
exist. Everything above is interface and world, worked out ahead of the systems
that will move them — which constrains those systems usefully, since a game whose
map cannot carry text and cannot express a radius is a different game from one
that can.
