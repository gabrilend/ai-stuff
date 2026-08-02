# Table of Contents

Every document in `docs/` and `notes/`. Source files and issue tickets are not
listed here; they are reached through the roadmap and the issue directory.

File indices count upward across the whole project rather than per directory, so
the documents can be read in order as one story. The highest index in use is kept
in `.file-index-counter` at the project root. A letter suffix means a document
belongs beside its neighbour rather than after it: `003a` is the downward half of
`003` and is read with it.

```
every-software-image-able/
├── notes/
│   ├── vision ....................... the page it started from
│   └── 007-deferred.md .............. worked out, then set aside, and why
│
├── docs/
│   ├── table-of-contents.md ......... this file
│   ├── 001-concept-overview.md ...... what this is, and what it refuses to promise
│   │
│   ├── 002-datapath-the-interpreter.md  the operation table, and the three kernel jobs
│   ├── 003-datapath-the-bootstrap.md   memory, body, channels — in an order that cannot move
│   ├── 003a-datapath-careful-exploration.md  learning hardware without destroying it
│   ├── 004-datapath-compilation.md ... text to source to runnable, and the picture that justifies it
│   ├── 005-datapath-the-four-rungs.md  use it, alter it, build it, condense it
│   ├── 006-datapath-status-and-tolerance.md  the colourshape, the square, and walking backward
│   │
│   ├── 008-open-questions.md ........ every question, closed and open, in one place
│   └── 010-datapath-the-mind.md ..... what arrives rather than being built, and changing it
│
├── strategems/
│   └── 009-ask-do-not-schedule.md ... say what is wanted; leave the method alone
│
├── llm-transcripts/ ................. the dialogue this was built out of
├── issues/ .......................... tickets; blueprints for building this
│   └── completed/
│       └── demos/ ................... one runnable demo per completed phase
│
├── src/ ............................. the machine, once there is one
├── libs/ ............................ external code
├── assets/
├── input/ ........................... what the programs read at startup
├── output/ .......................... what they return, ending in goodbye
├── desire/ .......................... notes on what should be better
├── faith/ ........................... expectation of boons and blessings
└── tmp/ ............................. symlink to RAM; nothing here is kept
```

---

## Reading orders

**To understand the design:** `001`, then `005` for what the machine does with
its life, then `003` and `003a` for how it gets far enough to do it. `002` and
`006` are the two mechanisms everything stands on and can be read in either
order.

**To understand one mechanism:** go straight to its datapath document. Each names
its data down to primitives and ends with what is still open about it.

**Before writing any code:** `008`, then `strategems/009`. Nothing is blocking.
What remains open are the things whoever writes the code will meet while writing
it, and three of the answered questions came out the same way — handed to the
machine rather than settled by a rule written here.

**To find out what was deliberately not decided:** `notes/007-deferred.md`. The
canvas, the people, the game, the mail between machines, and the cheap backward
reach through ring buffers are all parked rather than rejected, and the note says
what would un-park each.

---

## The story in one line

Find memory, find the body, learn to work the body, open every channel the body
provides — then answer whatever arrives through them, by using what is here, or
altering what is here, or making room and building it, and afterward squeezing
out the duplication so the room came from verbosity rather than from capability.

---

## Not yet written

- **The roadmap.** Phases are not defined yet, so the phase table that belongs in
  this file is absent. The clusters are visible in the documents — the
  interpreter, the bootstrap, learning hardware, compilation, the rungs, the
  status reading — and nothing is blocking the work of grouping them now.
- **Issue files.** None. Every one depends on the roadmap. The thing to watch
  while writing them: a ticket that dictates how the machine must be organised is
  the same mistake as a schedule (`strategems/009`).
- **The HTML build** at `docs/HTML/`, cross-linked, with the status square as
  something you can move around in and the four rungs as something you can watch
  a request descend.
- **`*.info.md` files**, one per source file, once source exists.
