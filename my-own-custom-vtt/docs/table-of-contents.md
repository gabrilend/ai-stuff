# Table of Contents

Start at [what this is](001-what-this-is.md). Everything else is reachable
from there, and everything here is reachable from the site
[build-docs](../build-docs) makes.

Everything in `docs/` and `notes/`, in reading order. Source files and issue files
are not listed here; source files are found through their companion `.info.md`
pages, and issues are found through [the roadmap](015-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order, not a
per-directory sequence. The documents occupy the low band; the source continues
from where they stop. See [the shape of the code](014-the-shape-of-the-code.md).

```
my-own-custom-vtt/
│
├── run-phase-demo ............................ Asks which phase demo to run,
│                                               and runs it.
│
├── notes/
│   └── vision ................................ Where all of this came from, in
│                                               the author's own words, with the
│                                               questions it raised left in.
│                                               Read first.
│
├── docs/
│   ├── 001-what-this-is ...................... The whole picture in one page.
│   │                                           System-agnostic, three programs,
│   │                                           geometry not pictures, sight as a
│   │                                           boundary, control as a dial.
│   │
│   ├── ── How it is arranged ──
│   ├── 002-the-three-programs ................ Server, bridge, and view. What
│   │                                           each is forbidden from doing, and
│   │                                           why the bridge exists rather than
│   │                                           the browser talking to the server.
│   ├── 003-the-door-and-the-private-port ..... How a person becomes a connection.
│   │                                           The join request field by field,
│   │                                           what a port per participant buys,
│   │                                           and what it costs.
│   │
│   ├── ── What the world is made of ──
│   ├── 004-the-world-and-its-tick ............ Flat arrays, indices not pointers,
│   │                                           zero as a sentinel, and the seven
│   │                                           passes of the heartbeat.
│   ├── 019-the-turn-is-a-transaction ......... Simultaneous declaration, one
│   │                                           resolution, and an undo. What
│   │                                           rolling back does to everybody
│   │                                           who already watched it happen.
│   ├── 005-a-thing-in-the-world .............. One record for a goblin, a coffee
│   │                                           cup, and a door. Why fixed point
│   │                                           rather than floating point.
│   ├── 006-the-map-is-geometry-not-a-picture . Walls as segments, regions as
│   │                                           polygons, lights, doors, and where
│   │                                           the grid actually lives.
│   │
│   ├── ── Seeing, and being allowed to see ──
│   ├── 007-sight-and-what-it-remembers ....... The angular sweep, the visibility
│   │                                           polygon, and the fog bitmap. Sight
│   │                                           and memory are different things.
│   ├── 008-who-controls-what ................. The dial: one body, a few, a
│   │                                           region, the map. Two membership
│   │                                           rules and a driving style.
│   ├── 009-what-a-viewer-is-allowed-to-know .. The one rule the server never
│   │                                           breaks, the four gates, the single
│   │                                           function that may write to a
│   │                                           socket, and the leak test.
│   ├── 010-commands-enter-through-one-door ... The command record, the verbs, the
│   │                                           five-gate gauntlet, and why every
│   │                                           refusal is a sentence.
│   │
│   ├── ── What is loaded rather than built in ──
│   ├── 011-the-rules-layer ................... LuaJIT in the server. The hooks,
│   │                                           the narrow interface, named
│   │                                           streams, and where dice live.
│   ├── 013-content-is-generated .............. Five stages from a description to
│   │                                           a world. Why the layout graph is
│   │                                           separate from the geometry.
│   │
│   ├── ── What it looks like ──
│   ├── 012-the-dynamic-picture ............... State not frames. Interpolation,
│   │                                           prediction, and the light the
│   │                                           security model already paid for.
│   ├── 017-the-sprite-studio ................. Where appearances come from. An
│   │                                           animated SVG per sprite, a pool
│   │                                           that keeps everything, and two
│   │                                           ways of deciding what is good.
│   │
│   ├── ── What survives the session ──
│   ├── 018-the-record-log-is-an-engraving .... A text file that is a carving that
│   │                                           is a spreadsheet. Read by one
│   │                                           script, written by another,
│   │                                           fragile on purpose.
│   │
│   ├── ── How it is written ──
│   ├── 014-the-shape-of-the-code ............. Numbering, companion files,
│   │                                           vimfolds, dispatch tables, the
│   │                                           thread pool, and the three kinds
│   │                                           of test.
│   │
│   ├── ── Phase 13, designed and not built ──
│   ├── 109-the-world-is-an-edge-graph ........ Three dimensions. A vertex, its
│   │                                           connections, and a material on
│   │                                           each. The edges are the model.
│   │                                           Structures, and the ground.
│   ├── 110-visibility-is-one-equation ........ Authored reveal, thresholds per
│   │                                           class, a distance field that goes
│   │                                           round corners, and why the unseen
│   │                                           is a surface rather than a hole.
│   ├── 111-the-question-window ............... A key, the DM as gate, and an AI
│   │                                           holding exactly the DM's verbs.
│   │                                           Ignorant by arithmetic.
│   │
│   ├── ── What is settled and what is not ──
│   ├── 015-roadmap ........................... Thirteen phases, each a cluster of
│   │                                           functionality, each ending in a
│   │                                           demo that is part of the product.
│   ├── 016-open-questions .................... Every question raised and not
│   │                                           answered, filed under the phase it
│   │                                           blocks. Worked through one at a
│   │                                           time.
│   │
│   └── HTML/ ................................. The documents rendered as a linked
│                                               site. Built by a tool in phase 9,
│                                               never hand-written.
│
├── input/ .................................... What the programs read first.
├── output/ ................................... What they write last.
├── desire/ ................................... What would be better. Wishes, not
│                                               issues.
├── faith/ .................................... What is believed before there is
│                                               evidence, so it is clear later
│                                               which beliefs the evidence broke.
├── strategems/ ............................... Data-flow patterns that turned out
│                                               to be right more than once.
│
├── src/ ...................................... The server, the bridge, the
│                                               generators. Numbered on from the
│                                               documents; each file beside its
│                                               companion .info.md.
├── libs/ ..................................... Third-party code, renumbered into
│                                               a high band so a reader can skip a
│                                               contiguous range.
├── assets/ ................................... Everything that is not code and
│                                               not prose.
│
├── issues/ ................................... One file per piece of the build.
│   │                                           Blueprints, not work logs.
│   ├── phase-N-progress.md ................... Where each phase stands.
│   └── completed/ ............................ Issues that are done.
│       └── demos/ ............................ The phase demos. Part of the
│                                               product, kept working, shipped.
│
├── llm-transcripts/ .......................... The full development record.
└── tmp/ ...................................... Symlink to the RAM tiers. Nothing
                                                here is ever committed.
```

## Reading order note

Four documents sit out of numeric order in the grouping above, and all four are
deliberate. `019-the-turn-is-a-transaction` follows `004`, because a turn is built
out of ticks and reading about one without the other is reading half a mechanism.
`013-content-is-generated` is grouped with the rules layer, because both are things
loaded rather than compiled in. `017-the-sprite-studio` is grouped with the dynamic
picture, because it is where that picture's parts come from. And
`018-the-record-log-is-an-engraving` sits before `014`, because what a session
leaves behind belongs with what it looked like rather than with how the code is
laid out.

And three sit far out of order rather than slightly: `109`, `110` and `111` are
documents wearing source-file numbers. The document band, `001` to `019`, was
full — the source starts at `020` — so phase 13's documents took the next values
from the counter, which is the counter's rule working exactly as written and
producing an answer nobody wants.

The pattern is worth naming: **the numbers are creation order made permanent, and
the grouping is meaning.** They agreed perfectly at the start and have drifted
apart five times since, which is what a project doing new thinking looks like.
The gap is now load-bearing rather than cosmetic, so the fix is the one this note
has always pointed at: **renumber, rather than keep explaining.**

It is **deferred on purpose**, not forgotten. It belongs with regrouping the
thirteen phases into the six the software is actually shaped like, and the right
moment for both is after the writing has been slimmed and it is clear how much
there is -- not while a phase is still being designed. See
[what would be better](../desire/what-would-be-better).

## The phases

Defined in full in [the roadmap](015-roadmap.md). Summarised here because the
phases are the project's main organising idea and a reader should meet them early:

| Phase | Cluster |
| --- | --- |
| 1 | **The world holds still** -- the data model, and a validator that refuses to guess. |
| 2 | **The world can be seen** -- the angular sweep, fog, and the thread pool. |
| 3 | **The world ticks, and turns can be taken back** -- passes, motion, determinism, replay, and undo. |
| 4 | **People connect** -- ports, protocol, the outbound filter, leak tests. |
| 5 | **The bridge and the browser** -- the first thing you can actually play. |
| 6 | **Control is a dial** -- scopes in full, from one body to the whole map. |
| 7 | **The rules layer** -- LuaJIT, hooks, and two rulesets over one server. |
| 8 | **Content generation** -- a description and a seed become a world. |
| 9 | **The sprite studio** -- generated appearances, a rated pool, and two ways of judging it. |
| 10 | **The engraving** -- statistics persisted as a carving that is also a spreadsheet. |
| 11 | **The second view** -- a terminal renderer, proving the split, and the HTML docs. |
| 12 | **The table, as it is actually played** -- commanding is not affecting, the host can show somebody out, and one keyboard drives four bodies. |
| 13 | **The world becomes solid** -- three dimensions, an edge graph, and visibility decided rather than computed. *Designed, not built.* |
