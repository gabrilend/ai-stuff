# 309 — A map that is one station on somebody else's canvas

## Current behavior

**Every program is flat, and past about a dozen stations a flat program
stops being readable.**

The compositor, the input router, and the engine's own utility maps all
have obvious internal structure — a piece that does one thing, used
from three places. Written flat, that piece is copied three times, and
the three copies drift.

## Intended behavior

**A map file can be placed as though it were a box, and the loader
flattens it into the same station table as everything else.**

```
   what somebody writes                what actually exists

   ┌─────────────────────┐             greet.hello ──→ greet.shout
   │                     │                                  │
   │  in ──→ [ greet ] ──→ out    ══→        (the sub-map's stations,
   │           ▲                             with their names prefixed)
   │           └── greeting.map │                           │
   └─────────────────────┘             ... ──→ greet.speak ──→ ...

   the placed station does not survive loading. it was a
   way of writing, not a thing that runs.
```

**There is no merging, because there is nothing to merge into.** Phase
2 has one station table and a program is only whichever stations are
wired together — so a sub-map's stations are placed exactly like any
others. The old design had to fold one map object into another; here
that step does not exist.

**What is left is names and a boundary.**

| step | what happens |
|---|---|
| names | every station from the sub-map is placed with the parent's name for it as a prefix, so `greeting.map`'s `shout` becomes `greet.shout` |
| entrances | the sub-map says which of its ports are its inputs, in order. The parent's arrow into `greet.0` is drawn to that port instead. |
| exits | the sub-map says which of its exits are its outputs, in order. An arrow out of `greet.0` is drawn from that exit instead. |
| nesting | a sub-map may place sub-maps. Repeat until no placed maps remain. |

The sub-map declares its own boundary, in its own file:

```
   entrance 0  shout.0          ← the parent's input 0 arrives here
   exit     0  speak.out        ← the parent's output 0 leaves here
```

**A boundary declaration is a promise about shape**, and it is the one
thing the catalogue cannot check, because a map file is not compiled. A
parent wiring into `greet.0` gets whatever type `shout.0` takes, which
is checked normally the moment the arrow is drawn — so the type safety
is not lost, it just arrives one indirection later.

### Loops in wiring are fine; loops in nesting are not

Worth putting side by side, because they look like the same word.

| | what it is | verdict |
|---|---|---|
| an arrow pointing back at an earlier station | finite structure, values going round it | **necessary** — the engine's only way to hold state (307) |
| a map that places itself | infinite structure — flattening never terminates | **an error**, named with the chain that got there |

A depth limit catches it. Hitting the limit reports the chain of file
names that led there, because "too deep" without the chain is not
something anybody can act on.

## Suggested implementation steps

1. A station line whose box name resolves to a map file rather than a
   catalogue entry, and the two boundary line forms.
2. Loading a sub-map with a name prefix, reusing the ordinary loader —
   the recursion is the whole implementation.
3. Boundary rewriting: the parent's arrows to and from the placed
   station become arrows to and from the named inner ports.
4. Repeat until no placed maps remain, with a depth limit and a message
   carrying the chain.
5. A test that a map placed twice produces two independent sets of
   stations that do not interfere.
6. A test that writing the flattened program back out and reading it in
   gives the same program — the cheapest proof that flattening produced
   something real rather than something almost real.

## Open questions

- *Are entrances and exits numbered or named?* Numbered is positional
  and terse and breaks silently when somebody inserts one. Named costs
  a lookup and produces an error instead. The rest of this project has
  gone the named way every time it was asked.
- *Should the prefix be visible in error messages?* `greet.shout` says
  where the station came from, which is exactly what somebody debugging
  wants — and it also means a station's name depends on where it was
  placed, so the same sub-map's error reads differently in two parents.
  That is probably right and it should be a decision rather than a
  side effect.
- *Can a sub-map be edited while a parent is running it?* The stations
  are ordinary stations, so rewiring them works. But nothing records
  that a group of stations came from one file, so "re-place this
  sub-map with a newer version" has nothing to grab. That is the same
  missing answer 213's parking and 306's name-scoping both ran into,
  which is now three places wanting one mechanism.

## Blocked by

305, 306.

## Blocks

312.

## Related

- [306 — The loader](306-the-loader.md), which this is a recursion of
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  the other kind of loop
- [213 — Asked to stop, and parking](213-asked-to-stop-and-parking.md),
  which wants the same "which stations belong together" answer
