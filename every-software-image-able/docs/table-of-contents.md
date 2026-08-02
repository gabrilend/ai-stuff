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
│   ├── 007-deferred.md .............. worked out, then set aside, and why
│   └── 014-spoken-while-building.md . things said in passing, kept whole
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
│   ├── 010-datapath-the-mind.md ..... what arrives rather than being built, and changing it
│   ├── 011-roadmap.md ............... seven phases; what people build, not what it becomes
│   ├── 012-datapath-the-proving-ground.md  testing it without a computer, and what that hides
│   └── 013-datapath-the-context.md .. atoms; what the machine is thinking with, and its choosing
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

## The phases

Defined in `011-roadmap.md`. They organise the work of building **the seed** —
not the machine, which builds itself. Lower numbers are more foundational, so the
last ticket finished may well be an early-phase one.

| Phase | Cluster |
|---|---|
| 1 | The engine — weights in, tokens out, on one architecture |
| 2 | The hands — memory, ports, storage, console, status, and running what it wrote |
| 3 | What it is told — instruction, patterns, device descriptions |
| 4 | Three tongues — the other two architectures, and choosing between them |
| 5 | The image — recipe, board descriptions, build, flash, verify |
| 6 | Waking — first light, and the first thing it makes unaided |
| 7 | The proving ground — an emulated computer, and devices that can be destroyed |

Phase 6 is the capstone and the only one that proves anything. What happens after
it is not planned, on purpose.

Phase 7 is numbered last and built first: nothing in it ever ships, which is what
its number means. `701` is where the other twenty-two tickets get developed.

**Issue names** are `{PHASE}{ID}-{description}`, with the ID two digits — read
from the right, so `204` is the fourth issue of phase 2. A trailing letter marks a
sub-issue of the ticket it shares a number with. Each names what blocks it and
what it blocks, so dependency order comes from the tickets rather than from their
numbering.

## The story in one line

Find memory, find the body, learn to work the body, open every channel the body
provides — then answer whatever arrives through them, by using what is here, or
altering what is here, or making room and building it, and afterward squeezing
out the duplication so the room came from verbosity rather than from capability.

---

## Not yet written

- **Any code at all.** Twenty-two tickets describe the seed and none of them have
  been started.
- **The demos**, and the runner in the project root that asks which phase to
  show. Blocked on there being a completed phase.
- **The HTML build** at `docs/HTML/`, cross-linked, with the status square as
  something you can move around in and the four rungs as something you can watch
  a request descend.
- **`*.info.md` files**, one per source file, once source exists.
