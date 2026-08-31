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
│   ├── 014-spoken-while-building.md . things said in passing, kept whole
│   └── 023-what-the-emulator-lies-about.md  differences, with what each cost
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
│   ├── 006-datapath-runaway-programs.md  threads, a clock, and walking backward
│   │
│   ├── 008-open-questions.md ........ every question, closed and open, in one place
│   ├── 010-datapath-the-mind.md ..... what arrives rather than being built, and changing it
│   ├── 010a-datapath-the-loop.md .... what drives it, and why nothing can type at it
│   ├── 011-roadmap.md ............... seven phases; what people build, not what it becomes
│   ├── 012-datapath-the-proving-ground.md  testing it without a computer, and what that hides
│   ├── 013-datapath-the-context.md .. atoms; what the machine is thinking with, and its choosing
│   ├── 042-whitepaper.md ............ the ways of being wrong without being told
│   ├── 102-adding-a-new-machine.md .. the procedure for a computer the seed does not yet run on
│   ├── 146-a-walkthrough.md ......... the seven things a person can run, and what each does
│   ├── HTML/ ........................ all of this, cross-linked and clickable; built, never edited
│   └── Everything I own, owned - schlarp.com.html   somebody else's writing,
│                                     kept whole. See below.
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

**To read all of this with links instead of numbers:** build the site into
`docs/HTML/` and open its front page. Every reference becomes something you click,
every page says what points at it, and the counts on the front page are taken
while it is being built. `146` gives the command.

**To run it rather than read about it:** `146`. Seven things can be started by a
person — the checks, the demonstrations, the front door that makes a seed, the
launcher, the one that lets you sit and watch a machine, and the two that rebuild
this documentation — and it says what each asks, what comes back, and how long you
will be waiting.

**To understand the design:** `001`, then `005` for what the machine does with
its life, then `003` and `003a` for how it gets far enough to do it. `002` is the
mechanism most of it stands on; `006` is short and is about the one thing that can
go wrong that the machine cannot write its way out of.

**To understand one mechanism:** go straight to its datapath document. Each names
its data down to primitives and ends with what is still open about it.

**To understand what actually runs the mind:** `010a`. It is the newest document
and the one everything else quietly assumed — the loop that holds the context,
re-prompts itself, and acts through tool calls. Nothing types at these machines.

**Before writing any code:** `008`, then `strategems/009`. One question is
blocking — **what a row of the operation table receives** — and it blocks the
interpreter alone, which is far enough off that it should be decided when the
interpreter is written rather than before, because the machine writing it will
have opinions the seed does not.

Everything else open is what whoever writes the code will meet while writing it,
and several of the answered questions came out the same way — handed to the
machine rather than settled by a rule written here.

**Two of the answers are rules about other people's property**, which nothing
else in this project is, and they are worth reading before touching storage: data
already on a device is never overwritten unless somebody asks, and where the
machine puts things depends on what the medium is made of, because flash wears
out and disks do not.

**To find out what was deliberately not decided:** `notes/007-deferred.md`. The
canvas, the people, the game, the mail between machines, and the cheap backward
reach through ring buffers are all parked rather than rejected, and the note says
what would un-park each.

---

## Borrowed reading

One file in `docs/` was not written here and is not ours.

**Everything I own, owned** — by Chaz Schlarp, at
`https://schlarp.com/posts/everything-i-own-owned/`, saved on 2026-08-23 as the
page and its pictures. Five devices the author owns — a webcam, a monitor, a key
light, a microphone and a capture card — taken apart at the firmware level: the
update format, what the checksum actually protects, whether anything verifies a
signature, and in the webcam's case a patched table that stops the recording lamp
from lighting.

It is kept because of where it touches this project. The webcam applies its
update by writing a staged file onto an internal FAT filesystem and rebooting
into it, which is the same route a seed takes onto a card, seen from the far end
— and the account of firmware that checks a hash but never asks who wrote it is
the outward-facing seam the whitepaper's ninth finding is about.

**The words and the pictures in that file are the author's, under whatever terms
they granted, and nothing here claims otherwise.** It is inspiration, cited, and
kept in the open so a reader can see where an idea came in. Nothing in this
project is derived from its text.

---

## The phases

Defined in `011-roadmap.md`. They organise the work of building **one seed** — not
the machine, which builds itself, and not the generator, which is what the seeds
come out of. Lower numbers are more foundational, so the
last ticket finished may well be an early-phase one.

| Phase | Cluster |
|---|---|
| 1 | The engine — weights in, tokens out, on one architecture |
| 2 | The hands — memory, ports, storage, console, status, and running what it wrote |
| 3 | What it is told — instruction, patterns, device descriptions |
| 4 | Three tongues — the other two architectures, and choosing between them |
| 5 | The image — recipe, board descriptions, build, flash, verify |
| 6 | Waking — first light, and the machine installing itself |
| 7 | The proving ground — an emulated computer, and devices that can be destroyed |

Phase 6 is the capstone and the only one that proves anything. What happens after
it is the crank: watch what the machine does with its life, change the seed, and
build another one. That is the seed generation system earning its name, and it is
the actual deliverable — a seed is a sample.

Phase 7 is numbered last and built first: nothing in it ever ships, which is what
its number means. `701` is where the other twenty-two tickets get developed.

**Issue names** are `{PHASE}{ID}-{description}`, with the ID two digits — read
from the right, so `204` is the fourth issue of phase 2. A trailing letter marks a
sub-issue of the ticket it shares a number with. Each names what blocks it and
what it blocks, so dependency order comes from the tickets rather than from their
numbering.

## The story in one line

Find memory, find somewhere to keep things, find the body, learn to work the body,
open every channel the body provides — then keep giving yourself things to do, by
using what is here, or altering what is here, or making room and building it, and
afterward squeezing out the duplication so the room came from verbosity rather
than from capability. Nobody asks. Nothing arrives. The wanting comes from
inside.

---

## Not yet written

**This list was written before any code existed and was not revised as code
appeared. Corrected 2026-08-21.** There are now well over a hundred source files
and the progress notes in `issues/` are the honest account of what runs; this page
should not be read as a status.

- **The rest of the seed generation system.** The pieces were joined on 2026-08-22:
  one command takes a recipe and a board and produces an image, a manifest and an
  identity, and it refuses rather than guessing in about a dozen places. What the
  deliverable still lacks is the `input/` directory as the roadmap describes it —
  a place an engineer drops whatever they want the machine to have, rather than one
  recipe file naming an instruction, some patterns and some device descriptions.
- **A fault handler that prints.** Named on 2026-08-21 as the highest-value thing
  not on the chip: about a hundred instructions per architecture that turn this
  project's dominant failure mode from silence into a sentence.
- **The four rungs as something you can watch a request descend.** The HTML build
  below exists now; this was the other half of that entry and it does not. It would
  be the one page on the site that shows a mechanism rather than a document.

Done since this list was written:

- **The demos** and the runner in the project root that asks which phase to show —
  one per completed phase, and it reads what each shows from the demo itself.
- **The HTML build** at `docs/HTML/`, built on 2026-08-22 by a generator rather
  than written. Every document, note, strategem, ticket and companion page,
  cross-linked in both directions, with a filterable list of everything down the
  left and a front page of counts taken during the build. Run it with the
  documentation site builder; `146` says how.
- **`*.info.md` files**, one per source file, including the one in `assets/`. Most
  are lifted from each file's own comments and are rebuilt rather than edited; the
  ones written by hand are left alone and say what no signature can. Which is
  which, and which are thin, is on the site's coverage page rather than counted
  here.
