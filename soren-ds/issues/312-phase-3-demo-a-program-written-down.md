# 312 — Phase 3 demo: a program written down

## Current behavior

**Issues 301 through 311 turn a program from something you build by
calling into the engine into something you write down.**

Phase 2's endurance test proved the engine. Nothing yet proves the
round trip: text in, program running, program back out as text.

## Intended behavior

**The smallest program that is unmistakably a program, read from a
file, running on the device.**

```
   # greeting.map

   greeting   constant      plain
   shout      to-upper      plain
   speak      say           plain

   in greeting.0 = "world"

   out greeting.0 -> shout.0
   out shout.0    -> speak.0
```

The device reads that, and `WORLD` comes out the serial line onto the
laptop. Nothing in the kernel knows what a greeting is.

### What each scene proves

| scene | shows |
|---|---|
| **the round trip** | the file above loads, runs, and writes itself back out as a file that reads into the same program |
| **the catalogue is the joint** | the same map with `to-uppr` misspelled refuses, naming the name and where box sources live |
| **the wire check** | the same map with `speak` taking a number refuses, naming both stations, the port, and both type names |
| **all of them at once** | a map with one of every mistake reports the whole list in one run |
| **the loop is the counter** | a map counting to ten through an arrow that points backwards, which the old design would have refused |
| **every way of choosing an exit** | one map per kind, each with a closed-form expected distribution, over enough values that a wrong picker cannot pass by luck |
| **a map inside a map** | the greeting placed twice inside a parent, producing two independent copies that do not interfere |
| **a box takes itself out** | the deliberately-refusing box stops, its error slot counts, the rest keeps running, and rewiring its input brings it back |

**The counting map is the one worth watching**, because it is the scene
that would have been illegal a week ago:

```
        ┌──────────────────────────────────┐
        │                                  │
        ▼                                  │
   ┌─────────┐       ┌────────────┐        │
   │ add one │ ────→ │ below ten? │ ──yes──┘
   └─────────┘       └────────────┘
        ▲                   └──no──→ say
        │
   start = 0, written once
```

Ten lines out the serial port, and the demo asserts they are 1 through
10 in order — which they will be, because there is only one value in
flight at a time and the loop is what carries it.

### Told as a word problem

Each scene states its problem in the engine's own vocabulary, offers an
image to hold it by, tabulates what corresponds to what, justifies every
row of that correspondence, measures, and ends with a finding. A scene
that cannot justify a row does not get the row.

Numbers go out the serial line and the results are drawn on the bottom
screen, the same as phase 2's — a device sitting on a desk should answer
"how did it go" by being looked at.

A script at `issues/completed/demos/phase-3/run.sh` builds, flashes,
opens the stream, and reports pass or fail. Hard-coded `${DIR}` at the
top, overridable as the first argument, every path relative to it.

## Suggested implementation steps

1. The map files as text compiled into the image, since phase 4 is where
   they get to be paths.
2. The `to-upper` box, and whatever each scene needs, as ordinary box
   sources.
3. One scene at a time, each measuring into a record of facts and
   telling from it afterwards, so a rewording cannot disturb a
   measurement.
4. The refusal scenes assert their messages word for word. The message
   is the deliverable in three of the eight scenes.
5. The shell script.
6. A run that is not attached to a terminal prints every scene at once,
   with no paging and no waiting, and says so rather than pretending.

## Open questions

- *Does the demo dump the running program to prove the round trip, or
  is that its own issue?* Writing a running program back out as text is
  a real piece of work — it is the cheapest possible proof that loading
  produced a real program, and it is what a person editing on the
  device will use constantly. It may deserve its own issue rather than
  arriving as a demo requirement.
- *Which scenes survive into phase 4?* The map files become paths and
  the compile pipeline arrives, so at least the first scene is rewritten
  rather than kept. Knowing that now means writing the scenes so the
  story survives the mechanism changing underneath it.

## Blocked by

All of 301 through 311, and phase 2 closing.

## Closes

Phase 3.

## Related

- [305 — The map file](305-the-map-file.md), the format on display
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  three of the eight scenes
- [215 — Phase 2 demo: the endurance test](215-phase-2-demo-the-endurance-test.md),
  which this sits on top of
