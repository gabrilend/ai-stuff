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
| a map file declares types | it never mentions one — the catalogue knows both ends of every wire |
| a loader that builds maps its own way | a loader that **calls** the same three operations a person calls |
| refuse a map with a cycle | a cycle is the engine's **only** way to carry state |
| `map_run`, entry boxes, quiescence | writing the fixed values is what starts it; nothing polls; programs end when asked |
| seven routing kinds | six ways to pick an exit, and one that was never routing at all |
| a JSONL transcript, always on | counted error slots always; the rolling transcript in debug builds |

Two deletions are worth reading on their own, because both remove a
thing rather than replace it: **why there is no cycle detector** (in
307) and **why there is no timer box** (in 310).

## The story of the phase

| # | issue | what it lands |
|---|---|---|
| 301 | what a box source is | a box is a C function in a known place, and the rules it has to keep |
| 302 | the generator | one call site per box, and a catalogue with every size computed by the compiler |
| 303 | types, by name and by width | the wire check, orderings for comparators, field tables for fixed values |
| 304 | the generator in the build | it runs first, and a failure writes nothing into place |
| 305 | the map file | one text file. names, no types, no sizes, no grammar |
| 306 | the loader | a caller of phase 2's three operations, not a mechanism of its own |
| 307 | everything wrong with a map, said at once | collect, report, stop once — and why there is no cycle detector |
| 308 | the kinds that pick an exit | six rows in one table, and the seventh kind becoming two boxes and an arrow |
| 309 | a map that is one station | encapsulation, which is now mostly naming |
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
| does a map file with errors load partially, or not at all? | 307 | it is the same policy as a broken box removing itself, one layer up |
| what records that a group of stations belongs together? | 306, 309, and phase 2's 213 | three separate places now want one mechanism |
| does the generator run on the device? | 304 | phase 4's on-device authoring either uses it or invents a second route |
| entrances and exits: numbered or named? | 309 | the rest of the project has chosen named every time it was asked |

## Phase demo

`issues/completed/demos/phase-3/run.sh` will exist once the phase
closes. It builds and flashes the image, reads a three-line greeting map
out of the kernel, and shows eight scenes: the round trip, three
refusals and their messages, a counter built out of a loop, every way of
choosing an exit, a map placed inside a map, and a box taking itself out
of service while everything else keeps running.
