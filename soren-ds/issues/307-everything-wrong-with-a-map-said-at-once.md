# 307 — Everything wrong with a map, said at once

## Current behavior

**The loader refuses one thing at a time, so fixing a new map is a
sequence of runs.**

Every check in 306 stops at the first failure. Somebody who has just
written a map with four mistakes in it finds them one per run, and each
run is a build and a flash.

## Intended behavior

**Collect every failure, print them together, then stop once.**

That is the whole of this issue's shape, and it outlives any particular
rule in the list. A person fixing a new program wants the list.

```
   3 problems in greeting.map:

     line  4  no box named "to-uppr" — box sources live in src/boxes/
     line  9  shout has no port 2 — to-upper takes 1 input
     line 11  shout -> speak.0: box returns a 32-bit integer,
              slot takes a 32-bit float
```

**Most checks are not here.** They belong at the moment both ends are
known — per arrow, per placement — which is where 306 already puts
them, and which is what lets somebody drawing a wire on a running
device get the identical check from the identical code. This issue is
only the collecting and the reporting.

**And the whole-program checks that are left are a report rather than a
refusal.**

| once thought to be an error | what it actually is |
|---|---|
| a station nothing is wired to | **ordinary.** A program can be built a piece at a time; *not connected yet* is a different statement from *wrong*. |
| a port with no source | **ordinary**, and the mechanism behind parking a program and removing a broken box |
| a cycle | **necessary.** See below. |

So the thing that needs the whole program present is somebody *asking*
"what is not finished here?" — and the answer is information, not a
verdict.

## Why there is no cycle detector

The old design refused a map whose graph had a loop, on the reasoning
that a station waiting for a value that depends on its own output could
never receive it.

**That reasoning was correct about the old engine and it is exactly
backwards for this one.**

A box cannot remember anything between calls — two cores can be inside
it at the same instant, so anything it stored would be shared between
them. Which means the only place state can live is on the wires. And
the only way to carry a value from one run of a station to the next is
to route its output back around to its own input.

```
   counting to ten, built out of boxes that cannot remember:

         ┌───────────────────────────────────┐
         │                                   │
         ▼                                   │
    ┌─────────┐        ┌────────────┐        │
    │ add one │ ─────→ │ below ten? │ ──yes──┘
    └─────────┘        └────────────┘
         ▲                    └──no──→ done
         │
      start — a fixed value, written once

   the loop is not a hazard. it is the counter.
```

Nothing waits. A value travelling backwards along that arrow lands in a
ring port and sits there like any other value, and the station runs
when its inputs are all present, exactly as always. There is no
difference at all between an arrow that points forward and one that
points back — the engine cannot even tell, because a wire is two
numbers and neither of them is a direction.

**A blanket cycle check would forbid the engine's only mechanism for
state.** So there is no check, and the old detector is deleted rather
than relaxed.

What a loop *can* still do is run forever, which is a program somebody
wrote and not an error the loader can identify. A map that spins is a
map that spins; the phase 2 counters make it visible, and 213's stop
operation is how it ends.

## Suggested implementation steps

1. A collector the per-edge and per-placement checks report into,
   rather than stopping at.
2. The report, printed once, in file order, each entry naming its line.
3. The asked-for report of what is unfinished: stations nothing feeds,
   ports with no source. Available on request, never on its own.
4. Delete the cycle detector and write the reasoning above where
   somebody would look for it.
5. A test with a map containing one of every error, asserting all of
   them appear in one run.
6. A test that a map with a loop in it loads and runs, since that is
   the behaviour being deliberately kept.

## Open questions

- *Does a file with errors load partially, or not at all?* The
  consistent answer with the rest of this project is that it loads: a
  station whose box name is unknown simply is not placed, the error is
  recorded, and everything else works — leaving a program with holes
  you can see rather than a device that will not start. That matches
  what a broken box does at runtime (214) and it keeps the device
  usable while somebody is halfway through writing something. It is
  also genuinely arguable the other way, because a partial program is a
  program nobody asked for, and this is the fork worth settling before
  the loader is written rather than after.
- *Does the unfinished-work report belong on the device's screen?*
  Somebody authoring at a touchscreen with no laptop attached is
  exactly who it is for, and the serial line is exactly where they
  cannot see it.

## Blocked by

303, 306.

## Blocks

312.

## Related

- [306 — The loader](306-the-loader.md), whose checks report into this
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  the same policy one layer down
- [208 — What an input port is](208-what-an-input-port-is.md), where
  *no source* is defined
