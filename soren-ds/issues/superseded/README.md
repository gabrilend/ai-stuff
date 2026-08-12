# Superseded — the first phases 2 and 3

These twenty-two issues described the engine and the runtime above it
against an earlier soramech design. They are kept because they are the
record of what was believed and why, and because the reasoning inside
them is still worth reading — several of the arguments survived into
the replacements unchanged.

They are **not** a plan anybody should build from. The current phase 2
is issues 201 through 215 in the directory above, and the current phase
3 is 301 through 312.

## What changed

The new design comes from
`/home/ritz/programming/ai-playground/minimal-soramech/`, where it was
built and measured rather than only drawn.

| | the design here | the design that replaced it |
|---|---|---|
| the thing that runs | a box, gated by its own atomic | a **station** — one placement of a box |
| deciding a run may happen | one critical section per box, entered by one thread at a time | a claim that walks the ports in ascending order and rolls back on failure |
| where the output goes | a unique return slot reserved per fire | nowhere; the core that ran the box walks the destinations itself |
| holding values in flight | a ring buffer with a head and a tail | cells that each carry their own state, found by scanning from a hint |
| growing a buffer | reallocate, copy, unwrap, fix the indices | append a page; nothing is copied and nothing moves |
| memory ordering | an issue that audited and tagged every atomic | one rule: build a thing completely, then publish it |
| the catalogue of boxes | a static array written by hand | generated from box sources — and that moved to phase 3 |
| ending | the program ends when the work runs out | programs end because they were asked to |

## What did not change

The firing rule. A station runs when, and only when, every one of its
inputs holds a value. Everything above is machinery for deciding that
cheaply and safely; the rule itself is the same sentence it always was.

## The files

| file | replaced by |
|---|---|
| 201 multi-core bring-up | 202 — waking the other cores |
| 202 worker thread bootstrap | 205 — workers and the run loop |
| 203 task struct and return slot | 210 — the task |
| 204 ring-buffered work queue | 204 — the task ring |
| 205 slot store with ring cells | 208 — what an input port is |
| 206 atomic gathering primitive | 209 — the readiness check and the claim |
| 207 release/acquire memory ordering | absorbed into 201 and 208 |
| 208 box descriptor table | 207 — the station table, and phase 3's catalogue |
| 209 worker scheduling loop | 205 and 211 — the delivery walk |
| 210 worker idle and wake | 206 — sleeping and waking |
| 211 phase 2 demo: torture test | 215 — the endurance test |

Nothing in the old set corresponds to 201 (the memory map that turns
the caches on), 203 (memory each core owns), 212 (maps built by hand),
213 (asked to stop, and parking), or 214 (when a box removes itself).
Those are gaps the old design had rather than pieces it arranged
differently.

## Phase 3 — what changed

| | the design here | the design that replaced it |
|---|---|---|
| what a box is | a JSON file naming a C function | the C function itself. Nothing is written twice. |
| where shapes come from | maintained by hand beside each box | `sizeof` expressions the compiler computes |
| what a map is | a directory of files, one per box | one text file, line-oriented |
| types in a map | declared in the file | never mentioned; the catalogue knows both ends |
| the loader | built maps its own way | calls the same three operations a person calls |
| starting a program | submit a task per entry box, then watch for quiescence | write the fixed values. That is the whole of it. |
| ending a program | quiescence, detected by polling three conditions | being asked (phase 2's 213) |
| cycles | refused at load time | **required** — the only way a program carries state |
| routing | seven kinds, one of which kept state on the station | six ways to pick an exit; the seventh was never routing |
| history | a JSONL transcript, always on | counted error slots always, a rolling ring in debug builds |

| file | replaced by |
|---|---|
| 301 in-memory map representation | phase 2's 207 — the station table |
| 302 box source format | 301 — what a box source is, and 305 — the map file |
| 303 map loader | 306 — the loader |
| 304 wire connector | absorbed into 306 and phase 2's wire operation |
| 305 encapsulation splicer | 309 — a map that is one station |
| 306 cycle detector | **deleted.** 307 says why. |
| 307 routing dispatcher | 308 — the kinds that pick an exit |
| 308 map execution and quiescence | **deleted.** Phase 2's 209 starts a program and 213 stops one. |
| 309 launch utility boxes | 310 — the launch box library |
| 310 RAM transcript ring | 311 — the transcript ring, now debug-only |
| 311 phase 3 demo | 312 — a program written down |

Nothing in the old set corresponds to 302 (the generator), 303 (types),
304 (the generator in the build), or 307's collect-everything reporting.
Those exist because the shape of a box stopped being something a person
maintains.

## Still to convert

Phases 4 through 10 lean on the engine and were written against the old
one. Their content is superseded in the same way these files are, so
their references have deliberately **not** been renumbered — pointing a
stale sentence at a new file would make it look converted when it is
not. Each phase's progress file carries a note saying so.

| phase | issues describing the old engine | what changed under them |
|---|---|---|
| 4 | 406, 407, 409, 410, 411, 412 | boxes come from a generated catalogue, not a table things are added to; rebuilding a box replaces each running station's call pointer, and old code is released by a per-core pass counter rather than reference counts |
| 5 | 501, 502, 505 | there is no quiescence — a program ends when asked; every station is already safe to run twice at once, so that stops being a property some boxes have |
| 6 | 602, 610 | a value is delivered into a cell whose own state is the lock; there is no gathering function |
| 7 | 709, 710 | the box catalogue is generated |
| 9 | 902, 906, 907, 908, 909 | there is no map object; a station is suppressed by giving its input no source, which is the same mechanism as parking and as a box removing itself |
| 10 | 1007 | flattening a placed map is mostly naming now |

## Two deletions worth reading

**The cycle detector.** It refused a map whose graph had a loop, because
a station waiting on a value derived from its own output could never
receive it. That is true of the old engine and exactly backwards for
this one: a box cannot remember anything between calls, so routing an
output back to an input is the *only* way a program carries state. The
reasoning is in 307.

**The timer box.** It armed itself and fired periodically, and the cycle
detector had to be taught to allow it. There is nothing to build: when
every core runs out of work the idle path already arms the chip's timer,
parks, wakes at the deadline, and writes a fixed value — which runs a
station. A tick is the engine waking up. The reasoning is in 310.
