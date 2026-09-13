# Phase 3 progress — a program you can write down

Phase 2 built an engine that runs a program somebody assembled by
calling into it. Phase 3 is everything that lets a program be *written
down*: read out of the C that actually runs, written into a file, read
back, and checked before it starts.

By the end of the phase the device can be handed a few lines of text and
answer with a running program — and can hand the running program back as
a few lines of text.

## The design changed, and these issues are new

The original phase 3 was written against the older soramech design. The
eleven old issues are kept in `issues/superseded/`.

| the old design said | the ceramic design says |
|---|---|
| a box is a JSON file naming a C function | a box **is** a C function; nothing is written twice, so nothing can disagree |
| box shapes are maintained by hand | every size is a `sizeof` the compiler computes; the generator does not guess |
| a map is a directory of JSON files | a map is one text file, line-oriented |
| a map file declares types | it never mentions one — the catalogue knows both ends, and compares them by width |
| a loader that builds maps its own way | a loader that **calls** the same three operations a person calls |
| refuse a map with a cycle | a cycle is the engine's **only** way to carry state |
| `map_run`, entry boxes, quiescence | writing the fixed values is what starts it; nothing polls; programs end when asked |
| seven routing kinds | six ways to pick an exit, and one that was never routing at all |
| an encapsulation splicer that flattens sub-maps | **a map is a box.** A program declares two doors and a parent wires to them |
| the generator is build tooling | it is a C program with no dependency on the engine, so the device can call it |
| a JSONL transcript, always on | counted error slots always; the rolling transcript in debug builds |

Two deletions are worth reading on their own, because both remove a
thing rather than replace it: **why there is no cycle detector** (in
307) and **why there is no timer box** (in 310).

## And then the format stopped being a narrowed one

These issues were first written against a *simplified* version of the
parent's map file, on a stated premise: that the parent's format was a
directory of files, one per box, built for a machine with a filesystem and
a text editor. **That premise was never true.** The parent's format is one
line-oriented text file as well, and the two designs were never far apart.

So the format here is now the parent's, unnarrowed, and five things arrived
with it. Each was paid for by somebody running into the thing it prevents,
which is the whole reason for taking them rather than re-deriving them:

| | what it prevents |
|---|---|
| **the kind is the first word** (`station`, `comparator`, `iterator`) | every line announcing itself is what lets the format gain a keyword later without taking a name away from a map already written |
| **a box address names its file** (`boxes/text.c:say`) | a description that says nothing about what it is made of. **This device needs it most**: a box compiled at the touchscreen has to say which file it came from or the program cannot be rebuilt |
| **paths relative to the file they are written in, nothing searched for** | two readers resolving one name differently — which the parent had, and the symptom was a description one accepted and the other refused |
| **every wire written at both ends** | reading one station telling you half the truth, so that knowing what feeds it means scanning the file |
| **a door is a `$` on a port, not a station** | an argument costing a station, a mutex, a ring buffer, and per value a task and a dispatch. On four cores that is the one of these five that shows up in a measurement |

Two things followed that were not part of the format at all:

**Saying a program is finished became a fourth act** (306). An earlier
draft ended at three and said so proudly; the `$` numbering cannot be
checked until every line has been read, and neither can anything else that
is a fact about a whole program. It is repeatable, which is what makes
editing a running program and loading a file end the same way.

**A station can be removed** (207), which the parent overturned after this
device's issues had been written against the restriction. Cutting every
wire that names a station is one walk, because a wire exists only as a
destination record on some station's output port; with none left, nothing
stale survives to be followed, so no wire needs a generation tag and
delivery pays nothing. It made 411 and 909 shorter rather than longer, and
410 reaches further: a page of code is no longer reachable forever merely
because some station once placed a box from it.

## The story of the phase

| # | issue | what it lands |
|---|---|---|
| 301 | what a box source is | a box is a C function in a known place, and the rules it has to keep |
| 302 | the generator | one call site per box, and a catalogue with every size computed by the compiler |
| 303 | types compared by width | a wire is legal when both sides count the same bytes; orderings; field tables |
| 304 | the generator in the build | it runs first, and a failure writes nothing into place |
| 305 | the map file | one text file, in the parent's own format. kinds first, addresses naming their file, wires at both ends, no types, no sizes, no grammar |
| 306 | the loader | a caller of phase 2's three operations, not a mechanism of its own — plus the repeatable act of saying a program is finished |
| 307 | everything wrong with a map, said at once | collect, report, stop once — and why there is no cycle detector |
| 308 | the kinds that pick an exit | six rows in one table, and the seventh kind becoming two boxes and an arrow |
| 309 | the two doors | a door is a **port**, so an argument costs no station — and composition falling out of it |
| 310 | the launch box library | the boxes later phases assume, and why a source needs a trigger |
| 311 | the transcript ring | recent history, in debug builds, replacing phase 1's card log |
| 312 | phase 3 demo | eight scenes, ending with a program written down and read back |

## Completed issues

None yet.

## Open issues

All of 301 through 312.

## Open questions still to work through

Every issue carries its own. The ones that reach beyond a single issue:

| question | lives in | why it matters beyond its issue |
|---|---|---|
| **does this device keep a catalogue at all?** | 302, 303, 305, 306, 409, 411 | **the open one, and the largest.** See below |
| does a map file with errors load partially, or not at all? | 307 | it is the same policy as a broken box removing itself, one layer up |
| what records that a group of stations belongs together? | 306, 309, and phase 2's 213 | three separate places now want one mechanism |
| what is a path relative to, when the description is a string constant in the kernel image? | 305 | the phase 3 demo's map is exactly this case, so it needs an answer before the demo |
| how do two copies of one sub-program get distinct names? | 309 | a prefix is the one piece of the old splicer worth keeping |

*Can a program have more than one door out?* stopped being a question
when the door moved onto the port (309). Several marked output ports are
several numbered results, and a caller asks for the one it wants by
number. It only looked hard while a door was a station, because then two
doors out meant two stations each claiming to be the end.

### The catalogue question

**The parent deleted its catalogue and this device may not be able to
follow.** Worth writing down carefully, because the reasoning is what
decides it and the reasoning does not transfer whole.

The parent's table held, per box, a name, a call site, each input's type
and size, the return type and size, and the exact task size. It is gone —
not shrunk, gone. Two things replaced it:

- **A generated placement function per box**, which writes a station
  directly, with every width already folded in as a constant the C
  compiler computed. Nothing is looked up because nothing is stored; the
  numbers are immediates in the instruction stream.
- **The operating system's own symbol table**, for finding a box that
  arrived after the program started. The parent's argument was that every
  process already carries such a table, maintained by somebody else, so
  keeping a second one was keeping a copy.

**The first half transfers and the second does not.** This device *is* the
operating system. It has no dynamic linker, no shared objects, and 409
compiles a late box into a page marked executable — there is no table to
ask. So the parent's reason for deleting the catalogue is a reason that
does not exist here: the table it leaned on is a table this device would
have to write, and a table this device writes is the catalogue.

Three answers, and none is chosen:

| | what it costs |
|---|---|
| **keep the catalogue, and say why the parent's route is closed here** | least work, and an honest fork. The runtime document already says the fork exists. |
| **take the placement functions, keep a name table** | the widths stop being stored and become constants in code, which is the half that transfers cleanly; what remains is one column — an address to a placement function — rather than a row of seven. |
| **write the symbol table** | the parent's design transfers whole, and a linker-shaped thing moves into the kernel. Worth knowing that cost before choosing it rather than after. |

The middle one looks right and has not been argued through. **Until this
is settled, the issues in this phase describe a catalogue**, which is what
they always described; the only thing the map-file change did to it is
make its key a file-and-function address rather than a bare name (305).

## Phase demo

`issues/completed/demos/phase-3/run.sh` will exist once the phase
closes. It builds and flashes the image, reads a three-line greeting map
out of the kernel, and shows eight scenes: the round trip, three
refusals and their messages, a counter built out of a loop, every way of
choosing an exit, a program placed inside a program, and a box taking
itself out of service while everything else keeps running.
