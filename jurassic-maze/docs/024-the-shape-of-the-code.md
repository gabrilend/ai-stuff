# The Shape Of The Code

Every source file is numbered from one counter that counts across the whole
project, so reading them in order reads the project as one story rather than as
five directories that each start over. This is the map of that story.

## The layers, and which way they are allowed to look

    the stone            knows about nothing
    the maze on it       knows about the stone
    the bodies in it     know about the stone and the maze
    the tick             knows about the bodies
    the viewer           knows about all of it, and none of it knows about the viewer

That last clause is the one with a test behind it. Nothing under `src/` that is
part of the simulation may mention the game engine by name, and a test greps for
it. See [seeing it without a window](009-seeing-it-without-a-window.md) for why.

## The files

| File | What it is | Page |
| --- | --- | --- |
| `028-maze-parameters` | every knob the generator has, in one table | [carving](003-carving-the-maze.md) |
| `029-random-streams` | the named seeded generators | [streams](005-randomness-comes-from-named-streams.md) |
| `030-the-stone` | the column array, the surface bits, headroom | [the stone](002-the-stone-and-what-is-inferred.md) |
| `031-carving` | the five passes that make a maze | [carving](003-carving-the-maze.md) |
| `032-the-validator` | connectivity, pits, invariants, the report | [carving](003-carving-the-maze.md) |
| `033-moving` | the four-answer rule and the component labels | [moving](004-standing-somewhere-and-going-elsewhere.md) |
| `034-the-body-store` | the flat arrays, the free list, the buckets | [a body](011-a-body-and-what-it-carries.md) |
| `035-creature-table` | every number that distinguishes one creature from another. In `assets/`. | [a body](011-a-body-and-what-it-carries.md) |
| `036-locomotion` | the dispatch table and the shared machinery its rows call | [locomotion](012-locomotion-is-a-dispatch-table.md) |
| `037-rolling` | the row with momentum in it | [rolling](013-rolling-with-momentum.md) |
| `038-walking` | the row that walks the graph | [walking](014-walking-the-surface-graph.md) |
| `039-the-tick` | the pass table and the fixed timestep | [the tick](010-the-tick.md) |
| `040-the-projection` | world to screen, and back | [projection](006-the-isometric-projection.md) |
| `041-the-palette` | three tones, the per-cell mottle, the creature colours | [drawing](007-drawing-a-pile-of-stones.md) |
| `042-the-renderer` | the linear sweep that turns faces into polygons | [drawing](007-drawing-a-pile-of-stones.md) |
| `043-the-camera` | pan, zoom, follow | [the camera](008-the-camera-and-what-it-watches.md) |
| `044-the-director` | what is worth watching | [the camera](008-the-camera-and-what-it-watches.md) |
| `045-the-viewer` | the engine's callbacks, the panel, the accumulator | [the tick](010-the-tick.md) |
| `046-the-terminal-viewer` | one layer, as characters | [without a window](009-seeing-it-without-a-window.md) |
| `047-the-headless-runner` | no window at all | [without a window](009-seeing-it-without-a-window.md) |
| `048-the-report` | the numbers a run produces | [without a window](009-seeing-it-without-a-window.md) |
| `049`–`054` | the tests, in `tests/`. Run by `./run-tests`. | |
| `055-the-documentation-builder` | Markdown to a cross-linked site, with three pages you can move things on | |
| `056-the-document-validator` | every link, every companion page, every issue the roadmap promises | |
| `057-the-relinker` | repairs the links an issue's move just broke | |
| `058-meeting` | the one pass where two bodies affect each other | [meeting](016-two-bodies-meeting.md) |
| `059`–`066` | more tests, in `tests/` | |
| `060-duels` | a duel is a record with two bodies in it | [fencing](017-fencing.md) |
| `062-sight` | marching a line through stone, and finding cover | [sight](018-line-of-sight-through-stone.md) |
| `063-games` | roles, a swap rule, and an ending | [games](020-games-that-creatures-play.md) |
| `065-the-delve` | fire, riding, and three monsters | [the delve](021-the-delve.md) |

`main.lua` and `conf.lua` sit at the root and carry no index, because the engine
insists on those exact names in that exact place. `main.lua` is a doorway and not
a room: it works out where the project is, loads the viewer, and forwards
callbacks. The moment it starts making decisions, there is a piece of program
sitting outside the reading order.

## The front doors

| Script | What it opens |
| --- | --- |
| `./run-maze` | the window, the terminal, headless, or a screenshot |
| `./run-many-mazes` | the overnight sweep, one worker per core |
| `./run-tests` | both halves: the invariants and the document validator |
| `./run-phase-demo` | asks which phase, runs its demo |
| `./build-documentation` | turns all of this into cross-linked HTML |
| `./validate-documentation` | a compiler for the written half |
| `./complete-issue` | moves a finished issue and repairs the links |
| `./new-source-file` | the only sanctioned way to add a source file |
| `./new-document` | the same, for prose |
| `./fill-source-file` | rewrites a body, never the licence |

## Two things that are deliberately not layers

**There is no entity system.** A body is an index into arrays. There is no
component registry, no query language, and nothing that iterates "everything with
a position and a velocity". The passes know which arrays they touch because
somebody wrote it down. See
[a body and what it carries](011-a-body-and-what-it-carries.md).

**There is no event bus.** Passes run in a fixed order and write to fields the
next pass reads. A queue of messages delivered at an unspecified time would make
the order of effects depend on the order of subscription, which is the thing the
whole tick design is arranged to avoid.

## Where a change goes

| If you are changing | Edit |
| --- | --- |
| what a maze looks like | `028-maze-parameters` |
| how a maze is built | `031-carving`, and the validator will tell you if you broke it |
| how a creature moves | one row of `036-locomotion`, and the file it names |
| what a creature is like | `035-creature-table`, and record why in `balance-updates.md` |
| how anything is drawn | `041-the-palette` or `042-the-renderer`, and never the simulation |
| what happens between two creatures | the meet table |

| an issue's state | `./complete-issue`, never `mv` |
| a document | anything, then `./validate-documentation` |

If a change does not fit any of those rows, that is worth stopping over. Either
the table is out of date, or the change is bigger than it looks.

## Three pieces of bookkeeping that nobody does by hand

Each of these is the sort of thing that rots the moment a person is asked to
remember it, so a tool does it instead.

- **The licence notice and the file index.** `new-source-file` claims the next
  number, stamps the notice, and writes the companion stub; `fill-source-file`
  replaces a body and refuses outright to write into an unstamped file.
- **The links an issue's move breaks.** Moving a file into `issues/completed/`
  silently invalidates every relative link inside it and every link to it — a
  hundred and nine of them, the first time it was checked. `./complete-issue`
  moves it and repairs them; the repair is idempotent and can be run alone.
- **Whether the written half still holds together.** `./validate-documentation`
  checks every link, every companion page, every issue the roadmap promises, and
  the index counter against what is on disk. It runs as part of `./run-tests`.

## Related documents and tools

- [Roadmap](025-roadmap.md) — which of these exist yet
- [Table of contents](table-of-contents.md) — everything, in reading order
