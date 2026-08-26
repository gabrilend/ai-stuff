# Table of Contents

Every document in `docs/` and `notes/`. Blueprints and issue tickets are not
listed here; the blueprints are reached through the roadmap and the issue
directory, and there are eighty-four of the first and ninety-four of the second.

File indices count upward across the whole project rather than per directory, so
that a number identifies a file uniquely and a reference like `037` needs no path.
The highest index in use is kept in `.file-index-counter` at the project root.
Everything numbered `091` and above is an instrument or a generated listing rather
than a part of the machine, so `090` is where a reader stops if they came only to
read the design. `101` is the odd one in that range: it is a generated document
and not a program, which is why the instruments run `091`–`100` and then skip it.

Two indices appear twice on purpose. `088` and `089` each name a blueprint in
`src/` and a document in `docs/`, and the document is the blueprint rendered —
the same content with the symbols replaced by their values. That is the same
relationship an `.info.md` companion has to the file it sits beside, and it is
the only case where a number is allowed to repeat.

```
six-sided-dice-layer-cake/
├── notes/
│   └── vision ....................... the page it started from
│
├── docs/
│   ├── table-of-contents.md ......... this file
│   ├── 000-concept-overview.md ...... what the cube is, and what it refuses to promise
│   ├── 001-roadmap.md ............... fourteen phases, one per component
│   ├── 002-the-notation.md .......... how to read a blueprint; required before src/
│   │
│   ├── 003-datapath-a-token.md ...... one token, arrival to successor
│   ├── 004-datapath-a-weight.md ..... one weight, platter to multiplier
│   ├── 005-datapath-a-joule.md ...... one joule, junction to room
│   ├── 006-datapath-an-ampere.md .... one ampere, wall to gate
│   ├── 007-datapath-a-pane.md ....... two mebibytes, leaving at once
│   │
│   ├── 008-where-the-vision-fights-physics.md  six substitutions, and what survived
│   ├── 009-open-questions.md ........ every question; blocking, open, answered
│   ├── balance-updates.md ........... knobs turned, in the order they were turned
│   │
│   ├── 088-bill-of-materials.md ..... generated: every part, count, mass, cost
│   ├── 089-specification.md ......... generated: the one page you hand somebody
│   ├── 101-every-number.md .......... generated: every symbol in the project, with its derivation
│   └── HTML/ ........................ all of this, cross-linked; built, never edited
│
├── src/
│   ├── 010–090 ...................... eighty-four blueprints, one per component
│   ├── *.info.md .................... one companion per blueprint: what it exports
│   ├── 091–100 ...................... ten instruments; the programs that read the above
│   └── 102–103 ...................... two more, which answer what the notation cannot ask
│
├── issues/
│   ├── phase-N-progress.md .......... fourteen, one per phase; what is done and what is not
│   └── completed/
│       ├── (ninety-four tickets) .... blueprints for the blueprints
│       └── demos/ ................... fourteen runnable demonstrations, one per phase
│
├── run-checks ....................... every constraint, evaluated, in under a second
├── run-demo ......................... pick a phase, watch it answer questions about itself
│
├── libs/ ............................ external code; empty — the instruments use only LuaJIT
├── assets/ .......................... reference data the blueprints cite
├── llm-transcripts/ ................. the dialogue this was built out of
├── input/ ........................... what the instruments read at startup
├── output/ .......................... what they return, ending in goodbye
├── desire/ .......................... notes on what should be better
├── faith/ ........................... expectation of boons and blessings
├── strategems/ ...................... dataflow patterns that keep proving useful
└── tmp/ ............................. symlink to RAM; nothing here is kept
```

---

## Reading orders

**To find out what this is in five minutes:** `000`. It has the cube, the numbers,
and the four things the design will not do.

**To understand how the parts are joined:** the five datapath documents, `003`
through `007`, in any order. Each follows one thing all the way through the
machine — a token, a weight, a joule, an ampere, a pane of bits on its way out —
and between them they touch every phase. This is the fastest route to
understanding, and considerably faster than reading blueprints.

**Before opening anything in `src/`:** `002`. The blueprints are written in a
notation with a strict grammar, because a program reads them, and none of them
will make sense without it.

**To find one number:** `089` if it is a headline figure, `101` if it is not.
`101` is generated from the blueprints and lists every symbol in the project with
its unit, its derivation, and the sentence saying what it is for. Nothing in prose
anywhere in this repository is authoritative; the generated listings are, because
they are recomputed rather than remembered.

**To argue with the design:** `008`, then `009`. `008` is the six places the
original page was overruled, each with the number that overruled it. `009` is
everything still undecided, sorted into what blocks the handoff, what is open with
its dependents named, and what has been answered along with the answer.

**To build it:** `001` for the phase structure, then `090`, which is the handoff
package and says what to read in what order and what you will still have to find
out yourself.

**To check it:** `./run-checks`. Every blueprint loaded, every symbol resolved,
every constraint evaluated, and every name in every drawing matched against a
symbol that exists. It writes nothing except to `tmp/shared-memory/`.

**To watch it work:** `./run-demo`. Pick a phase and it recomputes that phase's
figures in front of you rather than printing stored ones.

---

## The phases

Defined in `001`. Fourteen, one per component. They organise *what the machine is
made of*, not when anything happens — nothing here is time-gated. The set was
written roughly in phase order, but that is a coincidence of convenience and not a
dependency: phase 14 was built first because nothing can be checked until the
checker exists, and the early-phase blueprints went on being revised to the very
end, because a late phase discovering it does not fit is a report about an early
one. The corner block grew from eight millimetres to twelve because of a chamber
drawn in phase 3; the spout's bond temperature dropped forty kelvin because
phase 12 laid the bonding steps out in order and found one of them hotter than
the step before it, which would have melted the joint it was standing on.

| Phase | Cluster | Blueprints |
|---|---|---|
| 1 | **Datum** — the frame, the materials, the master dimensions | `010`–`012` |
| 2 | **The Body** — envelope, face stack, corners, edges, seals | `013`–`019` |
| 3 | **The Corners** — heat, fluid, microchannels, the loop | `020`–`027` |
| 4 | **The Rails** — budget, domains, network, decoupling | `028`–`033` |
| 5 | **The Yolk** — the shared memory core | `034`–`040` |
| 6 | **The Faces** — one compute face, six times | `041`–`049` |
| 7 | **The Sieve** — the six radial links and the pipeline on them | `050`–`055` |
| 8 | **The Feed** — port field and storage lines | `056`–`061` |
| 9 | **The Spout** — the face that became a tube of wire | `062`–`069b` |
| 10 | **The Metronome** — clock, reset, cross-face agreement | `070`–`074` |
| 11 | **The Recipe** — cutting a model up and pouring it through | `075`–`080` |
| 12 | **The Kiln** — process, assembly, yield, test, bring-up | `081`–`086` |
| 13 | **The Whole Cake** — integration, materials, the spec sheet | `087`–`090` |
| 14 | **The Instruments** — the programs that check all of it | `091`–`100`, `102`–`103` |

Phase 13 is the capstone. Phase 14 is numbered last and built first, because
nothing else can be checked until it exists, and none of it ships to whoever
builds the machine.

Three blueprints carry a letter — `069a`, `069b`, `076a`. Each is a piece that
grew out of another one after that other one was written, and a letter says so
more honestly than renumbering everything after it would.

**Issue names** are `{phase}{id}-{description}`, the id always two digits, read
from the right — so `304` is the fourth ticket of phase 3 and `1106` is the sixth
of phase 11. A trailing letter marks a sub-issue. Each ticket names what blocks it
and what it blocks, so dependency order comes from the tickets and not from their
numbering.

## The story in one line

Hold every weight of a language model still, in one block of static memory at the
centre of a cube; put a processor on each of the six faces looking inward, each
owning a run of the model's layers; pour tokens in and let them fall through the
six of them the way grain falls through a stack of sieves; pump the corners so the
whole thing does not melt; and spend one face on a bundle of sixteen million wires
so that whatever the middle is holding can be somewhere else in thirty-three
microseconds.
