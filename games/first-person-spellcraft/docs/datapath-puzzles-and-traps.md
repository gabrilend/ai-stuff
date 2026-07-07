# Datapath — Puzzles, Mechanisms & Traps (Phase 4)

> How a puzzle turns player action into an outcome. This document traces the
> **data flow** through Phase 4's primitives, names the structures and functions
> by their role (not by a final code name), and marks every **seam** where
> another phase reaches in or reads out. It is the map; the
> [issue files](../issues/) for Phase 4 are the turn-by-turn directions.
>
> Back to the [table of contents](table-of-contents.md). Sibling datapaths:
> [engine foundation](datapath-engine-foundation.md) (the world and platforming
> that feed triggers), [spell system](datapath-spell-system.md) (the magic
> effects that feed triggers), [dungeon master](datapath-dungeon-master.md) (the
> generator that composes these primitives), and
> [ncp characters](datapath-ncp-characters.md) (the weak solver that reads the
> outcomes).

---

## The one-line flow

```
puzzle definition
   -> a trigger fires          (from a magic effect, a physical act, or a platforming act)
   -> a mechanism changes state (a solving use, or a red-herring use)
   -> the solution-set is checked
   -> SOLVED  -> the solution effect fires (door opens, path revealed) -> outcome reported OUT
      or
      FAILED  -> a trap fires                                          -> outcome reported OUT
```

Everything in Phase 4 exists to make that line run, to make the solving use and
the red-herring uses **seem suitably equal in likely**, and to hand the final
SOLVED/FAILED verdict to the phases that learn from it.

---

## Division of labor (read this first)

Phase 4 builds the **building blocks and the runtime that turns them over**. It
does **not** build the thing that decides which blocks to place. That decider is
the [Phase 6 Dungeon Master](datapath-dungeon-master.md), a generator that
*composes* Phase 4 primitives into a lair of "three-ish puzzles and four
combats." So this datapath deliberately stops at a **catalogue** and a
**builder API**: Phase 4 says "here are the parts and here is how to assemble one
puzzle correctly," and Phase 6 says "assemble these particular parts, this many,
this hard." Keeping that line clean is the whole point of the phase.

---

## The pipeline, stage by stage

### Stage 0 — The puzzle definition (data at rest)

Before anything fires, a puzzle exists as **pure data**: a goal, the mechanisms
it contains, the wiring between triggers and mechanisms, which wirings count as
solving versus red-herring, the failure conditions, and the trap(s) that fire on
failure. This is authored two ways:

- **By hand**, for the Phase 4 demo and for tests (a small library of fixed
  puzzles we can assert against).
- **By the generator**, at lair-spawn time, freshly each visit ("newly created
  each time a group of adventurers wanders on").

Both paths produce the *same* definition shape, so the runtime cannot tell a
hand-made puzzle from a generated one. That parity is a hard requirement — it is
what lets the demo and the tests stand in for the generator.

### Stage 1 — A trigger fires (the input edge)

A **trigger** is a latent condition watching the world. When its condition
becomes true it emits a **trigger event** naming itself. Triggers come in three
families, chosen through a **dispatch table keyed by trigger type** (never an
if/else ladder — the table is how new trigger families are added without editing
the runtime):

| Trigger family | Watches | Fed by |
| --- | --- | --- |
| magic-effect | a magic effect of a given path/level landing in a given place | [Phase 3 spell system](datapath-spell-system.md) |
| physical | stepping / pressure / a moved object resting somewhere | [Phase 1 world & collision](datapath-engine-foundation.md) |
| platforming | reaching a height, landing on a ledge, a traversal completed | [Phase 1 platforming/verticality](datapath-engine-foundation.md) |

The magic-effect family **subscribes to Phase 3's "magic effect" seam** — it
does not poll spells and does not know how a spell is cast; it only learns that
"an effect of this path, this level, landed at this point." The platforming and
physical families **read Phase 1's world state** — footfalls, occupied volumes,
heights reached. This is the phase's IN edge.

### Stage 2 — A mechanism changes state

A **mechanism** is the part that *provides the solution* — it holds a
**solution effect** (open a door, reveal a path, disarm a trap). It is reached
through **activation bindings**. Each binding pairs one trigger with one
**use-mode** of the mechanism. Two multiplicities live here, straight from the
vision:

1. **Multiple solving triggers -> one mechanism.** Several different bindings all
   drive the mechanism toward its solution (redundant correct paths: a lever the
   flame-bolt *or* the pressure of a pushed crate *or* landing hard on it can
   throw).
2. **Multiple non-solving uses -> red herrings.** Other bindings *use* the same
   family of mechanism but do **not** provide the solution. A red-herring use may
   be inert, may mislead (visibly "do something" that leads nowhere), or may
   **arm/spring a trap** (a failure).

When a trigger fires, the runtime looks up the bindings that trigger drives and
applies each binding's use-mode to its mechanism, moving that mechanism's state.

### Stage 3 — The solution-set is checked

The puzzle carries a **solution-set**: a predicate over mechanism states that is
true exactly when the goal is met (e.g., "the gate mechanism is OPEN"; or "all
three glyph mechanisms are LIT"; or "the trap mechanism is DISARMED"). After any
mechanism state change, the runtime re-evaluates:

- the **solution predicate** — did we just solve it?
- the **failure predicate(s)** — did we just fail it (a trap sprung, a budget of
  attempts/time exhausted, a required mechanism destroyed)?

These predicates are the puzzle's brain. They are data-driven so the generator
can assemble them without new code.

### Stage 4a — SOLVED

The mechanism's **solution effect** fires (the door opens, the path is revealed,
the enchantment lifts). The puzzle's state machine moves to `solved`. An
**outcome record** is emitted on the phase's OUT edge.

### Stage 4b — FAILED -> a trap fires

A **trap** fires. Trap behaviour is chosen through a **dispatch table keyed by
trap type** (dart volley, floor drop, gas, seal-the-room, summon, magical
backlash, ...). Two vision-mandated shapes matter:

- **Disarm-as-puzzle.** The trap starts `armed` and the puzzle's *goal* is to
  reach a mechanism state of `disarmed`. Here the trap and the solution-set are
  the same object seen from two sides.
- **Enchantment challenge.** The obstacle is "a magical style enchantment"; the
  solving triggers are magic-effect triggers of the right path/level. Failure is
  a magical backlash trap.

The puzzle's state machine moves to `failed`. An **outcome record** is emitted on
the OUT edge. (Failure is not always terminal — a trap may spring, the party may
survive, and the puzzle may remain `in-progress` with a raised cost. The state
machine, not the trap, owns that call.)

### Stage 5 — The outcome is reported OUT (the output edge)

Every terminal (and every notable non-terminal) transition emits an **outcome
record**: which puzzle, which archetype, solved or failed, which triggers were
tried, which were solving, which red herrings were taken, how long, how much it
cost. This is published on an **outcome bus** that two phases read:

- [Phase 5's weak solver](datapath-ncp-characters.md) consumes outcomes to steer
  the NCP's next guess and to know when it has won or lost.
- [Phase 6's capability memory](datapath-dungeon-master.md) consumes outcomes to
  remember "they are that potentialed" and to re-tune future difficulty.

Phase 4 only *emits*. It never reaches into how those phases learn — another
clean seam.

---

## The equal-plausibility constraint (the heart of the phase)

> "make them each seem suitably equal in likely."

A red herring is worthless if it looks like a red herring. So every activation
binding carries an **apparent-plausibility profile** — a small bundle of surface
cues the observer can perceive *before* trying it: visual salience, proximity to
the goal, thematic fit, affordance strength (how much it "looks operable"),
and how well it matches the tools the party is carrying. An
**equal-plausibility auditor** scores the solving bindings and the red-herring
bindings and reports the *spread* between them. A puzzle passes only if the
spread is within tolerance — i.e., a fresh observer, seeing only the surfaces,
could not rank the real solution above the decoys.

This auditor is a **Phase 4 primitive that Phase 6 must call**: the generator
proposes a wiring, the auditor grades its fairness, the generator adjusts until
the grade passes. Phase 4 owns the *ruler*; Phase 6 does the *measuring-and-
adjusting*. The demo exercises the ruler on hand-made puzzles so the ruler is
trustworthy before the generator ever leans on it.

---

## The seams (where phases touch)

```
        Phase 3 magic effects            Phase 1 world & platforming
                 |                                 |
                 v                                 v
        +-------------------- Stage 1: triggers fire --------------------+
        |   (magic-effect family)   (physical family) (platforming fam.) |
        +----------------------------------|-----------------------------+
                                           v
                        Stages 2-4: mechanisms / solution-set / trap
                                           |
   Phase 6 generator ---COMPOSES--->  puzzle definitions (Stage 0)
   (picks & wires primitives,              |
    calls the plausibility auditor)        v
                                  Stage 5: outcome bus ---> Phase 5 weak solver
                                                        \-> Phase 6 capability memory
```

- **IN — Phase 3 (magic effects):** the magic-effect trigger family subscribes to
  the spell system's published "an effect landed here" seam. Phase 4 never casts.
- **IN — Phase 1 (world & platforming):** physical and platforming trigger
  families read footfalls, occupied volumes, and heights from the world/collision
  state. Phase 4 never simulates physics itself.
- **COMPOSE — Phase 6 (generator):** the Dungeon Master picks archetypes, places
  mechanisms, wires triggers (solving and red-herring), sets failure conditions
  and traps, and runs the equal-plausibility auditor — all through Phase 4's
  **builder API and primitive catalogue**. Phase 4 supplies the parts and the
  assembly rules; Phase 6 supplies the choices.
- **OUT — Phases 5 & 6 (outcome bus):** SOLVED/FAILED outcome records flow out to
  the weak solver and the capability memory. Phase 4 emits; it does not learn.

---

## Structures, by role

- **Puzzle definition** — the at-rest description: goal, contained mechanisms,
  trigger wiring, solving-vs-red-herring tags, failure conditions, trap(s),
  archetype tag. Shared shape whether hand-authored or generated.
- **Puzzle state** — the live half: which state machine node (`in-progress`,
  `solved`, `failed`), per-mechanism current states, attempt/time budgets spent,
  which bindings have been tried.
- **Mechanism** — the solution-provider: its current state, its solution effect,
  and the set of use-modes it exposes.
- **Activation binding** — one (trigger -> mechanism use-mode) wire, tagged
  `solving` / `inert` / `misleading` / `arms-trap`, and carrying an
  apparent-plausibility profile.
- **Trigger** — a latent condition plus the trigger-family it belongs to; emits a
  named trigger event when its condition turns true.
- **Trigger event** — the fired signal: which trigger, where, with what magnitude
  (e.g., which magic path/level, how hard the footfall).
- **Solution-set predicate** & **failure predicate(s)** — data-driven tests over
  mechanism states and budgets.
- **Trap** — a trap type, an `armed`/`disarmed`/`sprung` state, its effect
  payload, and (for disarm-as-puzzle) a back-reference the solution-set reads.
- **Apparent-plausibility profile** — the perceivable surface cues of a binding.
- **Outcome record** — the emitted verdict and its statistics.
- **Primitive catalogue** — the registry of trigger families, mechanism kinds,
  trap types, and puzzle archetypes that the generator draws from.

## Functions, by role

- **Register a trigger family / mechanism kind / trap type / archetype** — the
  entries that populate the four dispatch tables. Adding a new kind means adding a
  table entry, never editing the runtime.
- **Build a puzzle** (the builder API) — assemble a valid puzzle definition from
  catalogue parts; this is what the generator and the hand-authored fixtures both
  call.
- **Advance the trigger watchers** — per-tick, ask each active trigger whether its
  condition has turned true and, if so, emit its event.
- **Route a trigger event to its bindings** — look up and apply the bindings a
  fired trigger drives.
- **Apply a use-mode to a mechanism** — move a mechanism's state per a binding.
- **Evaluate the puzzle** — re-check solution and failure predicates after a state
  change; drive the state machine.
- **Fire the solution effect** — run the SOLVED consequence (open/reveal/disarm).
- **Fire a trap** — dispatch on trap type; run the FAILED consequence.
- **Audit equal-plausibility** — score solving vs red-herring bindings and report
  the spread against tolerance (the ruler Phase 6 measures with).
- **Emit an outcome** — publish the SOLVED/FAILED record onto the outcome bus.

## Files, and why (source lives in `src/`, planned by the issues)

> Actual filenames take the next indices from `.file-index-counter` at build
> time; source files follow the project's indexed-name + `.info.md` convention.
> Listed here by role so the datapath and the issues agree on the parts.

- **Puzzle & mechanism data model** — defines the at-rest and live structures
  above. The vocabulary every other file imports. (Issue 401.)
- **Trigger system + trigger-type dispatch table** — the three families and the
  watcher/route machinery. (Issue 402 and its sub-issues 402a/402b/402c.)
- **Mechanism activation + equal-plausibility auditor** — use-modes, binding
  tags, and the plausibility ruler. (Issue 403.)
- **Puzzle runtime (state machine + predicate evaluation)** — turns the pipeline
  over and drives `in-progress -> solved | failed`. (Issue 404.)
- **Trap system + trap-type dispatch table** — trap kinds, disarm-as-puzzle,
  enchantment backlash. (Issue 405.)
- **Puzzle archetypes + platforming integration** — the reusable composed puzzles
  the generator picks from. (Issue 406.)
- **Composition & outcome seam (builder API + outcome bus) + phase demo** — the
  surface Phase 6 composes through and Phases 5/6 read out of. (Issue 407.)

---

## The four dispatch tables (project convention: tables over if/else)

Phase 4 leans on the project's "dispatch table over branch ladder" rule in four
places, each a place the generator extends by adding rows:

1. **Trigger-type table** — magic-effect / physical / platforming -> how to watch
   and how to read an event's magnitude.
2. **Mechanism-kind table** — lever / plate / glyph / gate / ward -> its
   use-modes and how each moves its state.
3. **Trap-type table** — dart / drop / gas / seal / summon / backlash -> its
   effect payload and how it springs.
4. **Archetype table** — convergent-lever / lit-glyph-set / disarm-the-trap /
   break-the-enchantment / platforming-traversal -> how to build one and what its
   solution-set looks like.

Keeping these as tables is what makes Phase 6's job "pick rows and fill blanks"
instead of "write code," which is exactly the Phase 4 / Phase 6 line this
datapath is built to protect.
