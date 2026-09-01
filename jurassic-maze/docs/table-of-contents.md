# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Source files and issue
files are not listed here; source files are found through their companion
`.info.md` pages, and issues are found through
[the roadmap](025-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order rather than a
per-directory sequence. Documents hold 001 through 027; source files begin at 028.

```
jurassic-maze/
│
├── LICENSE ................................... The GNU Affero General Public
│                                               License, version 3, verbatim.
├── COPYING.md ................................ What the AGPL asks of you, and
│                                               the notice every source file
│                                               carries.
│
├── run-maze .................................. The front door. Opens a window, a
│                                               terminal, a screenshot, or no
│                                               window at all.
├── run-many-mazes ............................ Plays it a great many times with
│                                               nobody watching, one worker per
│                                               core, and prints the table you
│                                               read in the morning.
├── run-tests ................................. Both halves at once: the document
│                                               validator and the invariants.
├── run-phase-demo ............................ Asks which phase demo to run, and
│                                               runs it.
├── build-documentation ....................... Turns all of this into browsable,
│                                               cross-linked HTML in docs/HTML/,
│                                               with three pages you can move
│                                               things on.
├── validate-documentation .................... A compiler for the written half.
│                                               Every link, every companion page,
│                                               every issue the roadmap promises.
├── complete-issue ............................ Moves a finished issue into
│                                               completed/ and repairs the links
│                                               that move just broke. Moving one
│                                               by hand breaks a hundred of them
│                                               in silence.
├── new-source-file ........................... The only sanctioned way to bring a
│                                               source file in. Claims the next
│                                               index, stamps the licence, writes
│                                               the companion stub.
├── new-document .............................. The same, for prose.
├── fill-source-file .......................... Rewrites a file's body without ever
│                                               disturbing its licence notice.
│
├── main.lua .................................. The engine insists on this name at
│                                               the root, so it is one of the two
│                                               unnumbered source files. A doorway,
│                                               not a room.
├── conf.lua .................................. The window's shape, and which engine
│                                               modules are started at all.
│
├── docs/
│   ├── 001-what-this-is.md ................... The project in a page. Read first.
│   │                                           Its HTML page carries the numbers
│   │                                           a real maze came out as, measured
│   │                                           when the site was built.
│   │
│   │                                           ── the stone, and the maze cut
│   │                                              into it ──
│   ├── 002-the-stone-and-what-is-inferred.md . One integer per cell holds an entire
│   │                                           vertical stack. The single most
│   │                                           load-bearing idea here.
│   ├── 003-carving-the-maze.md ............... Five passes from a seed to a maze.
│   │                                           Terraces, a spanning tree, and
│   │                                           staircases cut rather than built.
│   ├── 004-standing-somewhere-and-going-elsewhere.md
│   │                                           Where a body is, and the four
│   │                                           answers to whether it may move.
│   ├── 005-randomness-comes-from-named-streams.md
│   │                                           Why there is no global generator,
│   │                                           and why the camera has its own.
│   │
│   │                                           ── looking at it ──
│   ├── 006-the-isometric-projection.md ....... Three numbers in, two out. And the
│   │                                           reason the draw order is the array's
│   │                                           own memory order.
│   ├── 007-drawing-a-pile-of-stones.md ....... The renderer never draws a block. It
│   │                                           draws disagreements between
│   │                                           neighbouring columns.
│   ├── 008-the-camera-and-what-it-watches.md . Pan, zoom, follow — and the director,
│   │                                           which decides what is worth looking
│   │                                           at and when it stops being.
│   ├── 009-seeing-it-without-a-window.md ..... Headless, a terminal, a screenshot.
│   │                                           Why a simulation only a person can
│   │                                           observe has no tests.
│   │
│   │                                           ── things that move ──
│   ├── 010-the-tick.md ....................... A fixed sixtieth of a second, and a
│   │                                           table of passes rather than a
│   │                                           function with seven calls in it.
│   ├── 011-a-body-and-what-it-carries.md ..... A body is an integer. Flat arrays,
│   │                                           a free list, and a generation
│   │                                           counter that catches stale ids.
│   ├── 012-locomotion-is-a-dispatch-table.md . Two kinds of motion were asked for
│   │                                           by name. So there is no "how bodies
│   │                                           move" — there is a table.
│   ├── 013-rolling-with-momentum.md .......... The balls. An interpolated floor,
│   │                                           gravity down its gradient, faces and
│   │                                           corners, and going over cliffs.
│   ├── 014-walking-the-surface-graph.md ...... The little guys. A step that takes a
│   │                                           fixed time, and smoothing that
│   │                                           belongs entirely to the renderer.
│   ├── 015-idling-and-being-idle-together.md . Standing still is the harder half.
│   │                                           Two timers set to the same value
│   │                                           read as a conversation.
│   ├── 016-two-bodies-meeting.md ............. The one pass that is not independent
│   │                                           per body, kept small because it is
│   │                                           the one that cannot be split.
│   ├── 017-fencing.md ........................ A duel is a record with two bodies
│   │                                           in it, and it ends.
│   │
│   │                                           ── the habitat ──
│   ├── 018-line-of-sight-through-stone.md .... Marching a line and testing bits.
│   │                                           Hiding is meaningless without it.
│   ├── 019-dinosaurs-in-a-habitat.md ......... A body wider than one cell cannot go
│   │                                           everywhere a small one can, and that
│   │                                           is the most interesting thing here.
│   ├── 020-games-that-creatures-play.md ...... Roles, a swap rule, and an ending.
│   │                                           Nothing knows it is playing.
│   │
│   │                                           ── the delve ──
│   ├── 021-the-delve.md ...................... Humans and dinosaurs against three
│   │                                           monsters that undo each other. The
│   │                                           word it turns on is "solve".
│   ├── 022-riding-and-being-ridden.md ........ Two bodies, one thing that moves, and
│   │                                           a derived position that cannot drift.
│   ├── 023-the-monsters-of-the-delve.md ...... Stone, vine, and burning wood. Each
│   │                                           one is another one's answer.
│   │
│   │                                           ── the project itself ──
│   ├── 024-the-shape-of-the-code.md .......... Which file is which, which way the
│   │                                           layers are allowed to look, and where
│   │                                           a given change goes.
│   ├── 025-roadmap.md ........................ Seven phases. Clusters of
│   │                                           functionality, not a schedule.
│   ├── 026-open-questions.md ................. Twelve of them, what each blocks, and
│   │                                           what was assumed to keep going.
│   ├── 027-ways-this-could-go-wrong.md ....... Written before most of it exists,
│   │                                           which is the only honest time.
│   │
│   ├── balance-updates.md .................... Append-only. Every number that was
│   │                                           turned, and why.
│   ├── table-of-contents.md .................. This page.
│   └── HTML/ ................................. The browsable view. Generated by
│                                               ./build-documentation; not committed.
│
├── notes/
│   └── vision ................................ Where all of this came from, in four
│                                               sentences, in the author's own words.
│                                               Read it before believing anything above.
│
├── inspiration/
│   ├── inspiration-maze.png .................. The picture that started it.
│   └── NOTICE.md ............................. **Not ours and not under this
│                                               project's licence.** Read before
│                                               doing anything with it. Also holds
│                                               every number measured off it.
│
├── src/ ...................................... The simulation and the viewer.
│                                               Numbered 028 upward. Not listed here —
│                                               each file is found through its
│                                               companion .info.md page, and the map
│                                               of which is which is in
│                                               024-the-shape-of-the-code.md.
├── assets/ ................................... The catalogue tables. Every balance
│                                               number in the project is in one of
│                                               these and in no document.
├── tests/ .................................... The invariants. Run by ./run-tests.
├── scenarios/ ................................ Described worlds, written by hand. A
│                                               scenario that reproduces a bug is a
│                                               bug report anybody can run.
├── issues/ ................................... Blueprints, one per piece of the
│   │                                           machine. Found through the roadmap.
│   ├── phase-N-progress.md ................... What each phase built, what went
│   │                                           wrong on the way, and what the
│   │                                           going wrong taught. Seven of them.
│   └── completed/demos/ ...................... The phase demos. Part of the
│                                               deliverable, not a development
│                                               artifact. `./run-phase-demo`.
│
├── input/ .................................... What goes into the box.
├── output/ ................................... What comes back out. The last thing a
│                                               run does is write goodbye here.
├── desire/ ................................... Notes about what should be better.
├── faith/ .................................... An expectation of boons and blessings.
├── strategems/ ............................... Data flow patterns that turned out to
│                                               work in more than one place.
│
└── tmp/ ...................................... Symlink into RAM. tmp/ is the exec
                                                tier at /tmp/jurassic-maze;
                                                tmp/shared-memory/ is the artifact
                                                tier at /dev/shm/jurassic-maze.
                                                Nothing here is ever committed.
```

## The phases, as clusters rather than a schedule

The [roadmap](025-roadmap.md) has the issues. The clusters themselves:

| Phase | What it is a cluster of |
| --- | --- |
| 1 — The Stone | the world's representation, its generator, and the rule for whether a body may move. Nothing moves and nothing is drawn. |
| 2 — The Eye | making it visible, three ways, one of which has no pixels in it. |
| 3 — The Rolling | the body store, the tick, and the first locomotion row. Balls. |
| 4 — The Wandering | the second locomotion row, idling, meeting, and the camera deciding what is worth watching. |
| 5 — The Fencing | a duel as a record, buffered damage, and endings. |
| 6 — The Habitat | bodies wider than a cell, sight, hiding, and games. |
| 7 — The Delve | a second mode: riding, fire that spreads, and three monsters that undo one another. |
