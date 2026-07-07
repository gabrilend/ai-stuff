# Datapath — Spell System (Phase 3)

> How a spell travels from a written-down idea to a flash of light in a room.
> This document traces the **data flow**, names the structures and functions by
> the role they play (not by their eventual code names), and marks the two seams
> where Phase 3 touches its neighbors: it draws **aim** in from Phase 2, and it
> hands **magic effects** out to Phase 4.
>
> Companion reading: the Phase 3 entry in
> [vision-overview.md](vision-overview.md#phase-3--spell-system) and
> [roadmap.md](roadmap.md#phase-3--spell-system). The vision lines this phase
> answers to are, in [notes/vision](../notes/vision): "make the spell list be
> dominions spells" (~90), "there are many ways to cast spells of each level in
> each path ... there are more than one ways to do each of them" (~111-113), and
> "apply certain magic effects to certain puzzles ... create a mechanism that
> provides the solution" (~118-119).

---

## The one-line flow

```
  spell TEMPLATE  →  CAST REQUEST  →  casting-method DISPATCH  →  effect RESOLUTION  →  world APPLICATION  →  effect RENDERING
   (definition)      (+ aim from       (one route per            (cast → effect        (monsters +           (viewing;
                      Phase 2)          method: gesture,          events)               mechanisms)           separate module)
                                        charge, two-hand)
```

Read left to right, it is: *what a spell is* → *someone wants to cast it* → *how
they cast it* → *what it does* → *who it happens to* → *what you see*. The middle
five arrows are all **data generation**. The last arrow, rendering, is **data
viewing**, and is kept in a separate module on purpose (see "The generation /
viewing wall" below).

---

## Stage 1 — Spell template (the definition)

A spell is a **template, never an instantiation** — the same discipline the
vision applies to NPC inventories and settlement workers ("modify templates.
never instantiations", vision ~50). The spell list is a table of molds; casting
stamps out short-lived copies of effects, but the mold itself is read-only data.

**Structures, by role**
- *Spell template* — one spell. Carries: its magic **path**, its **level**, a
  reference to the **effect** it produces, and the set of **casting methods**
  that can invoke it (one-or-more; the "more than one way to do each" rule).
- *Spell book / spell registry* — the whole table of spell templates, keyed so a
  cast request can name a spell and find its mold.

**Functions, by role**
- *Look up a spell by name/id* — the registry's read path.
- *List spells for a path and level* — feeds later UI, the NCP's chooser, and the
  count validator.

Defined by issue **301** (path & level taxonomy — the vocabulary) and issue
**302** (the template struct and the registry that holds them).

---

## Stage 2 — Cast request (someone wants to cast)

Nothing above knows *who* is casting or *where they are pointing*. The **cast
request** is the small packet that carries that intent into the system. It is the
one structure that flows all the way from "a caster decided to act" down to "an
effect resolves."

**Structure, by role**
- *Cast request* — references a spell template, names the **caster** (player or
  NCP — the system does not care which), names the **chosen casting method**, and
  — only if the spell needs aiming — carries an **aim/intent** value.

**The Phase 2 seam (aim comes IN here).** Phase 3 does not read mice, brains, or
ceiling headsets. It asks Phase 2's input-abstraction layer for a single thing:
an **aim/intent** — a direction (and whatever origin/steadiness Phase 2 chooses
to attach). The same seam serves the player and an NCP identically ("anything
that needs aiming, the user can aim, when they're playing as an NCP", vision
~112-113); the *source* of the motion changes, the *routing* does not — this is
the "Aim once, aim everywhere" strategem from
[strategems/](../strategems/README). Phase 3 owns the *shape of the request it
needs*; Phase 2 owns *how the aim is produced*.

Defined by issue **303** (the cast-request struct and the aim/intent seam).

---

## Stage 3 — Casting-method dispatch (how it is cast)

"There are more than one ways to do each of them." A spell can be invoked by a
**gesture-cast**, a **charge-and-release**, a **two-hand-combination** (which
ties naturally to Phase 2's two hands), and more added over time. Rather than a
switch statement over method names, methods live in a **dispatch table** keyed by
method — data-and-functions indexed by key, the project's standing preference and
a natural fit here.

**Structures, by role**
- *Method dispatch table* — maps a method key to that method's handler and its
  static traits (does it need aim? does it charge over time? how many hands?).
- *Method handler* — the per-method route that turns a cast request into a
  *resolved cast* (validates the method is legal for the spell, applies
  method-specific behavior such as charge timing, and confirms an aim is present
  when the method needs one).

**Functions, by role**
- *Dispatch a cast request* — look the method up, run its handler, produce a
  resolved cast (or a clear refusal).
- *Register a casting method* — how new methods join the table without editing a
  central switch.

Defined by issue **304** (umbrella), split into **304a** (the method contract and
the dispatch registry — the stable part) and **304b** (the initial concrete
method set — the growing part).

---

## Stage 4 — Effect resolution (what it does)

A **resolved cast** now knows the spell, the caster, and the aim. Resolution
turns it into **effect events** — the neutral, world-agnostic description of what
should happen: "deal N fire damage along this ray", "emit magic-effect FIRE at
this point", "raise a wall here". Effect *kinds* are themselves a **dispatch
table** keyed by effect kind, so a new effect is a new table entry, not a new
branch.

**Structures, by role**
- *Effect event* — one neutral thing-that-happens: its kind, its magnitude/
  parameters, and its target region (a point, a ray from the aim, an area).
- *Effect-kind dispatch table* — maps an effect kind to the resolver that expands
  it into effect events.

**Functions, by role**
- *Resolve a cast into effect events* — the generation core. Pure: it reads the
  resolved cast and the world's queryable state, and returns effect events. It
  does **not** mutate the world and does **not** draw anything.

Defined by issue **305a**. This stage is deliberately a closed box: give it a
resolved cast, get back a list of effect events, with no side effects — so the
whole spell verb can be tested without a running world or renderer.

---

## Stage 5 — World application (who it happens to)

Effect events are applied to the world. Two destinations matter, and they are the
two ways a spell "means something":

1. **The Phase 1 world / monsters** — damage a zombie, move a wall, light a room.
   Applied through whatever query/mutate handles Phase 1 exposes.
2. **The Phase 4 magic-effect seam** — a spell can *trigger a mechanism* ("apply
   certain magic effects to certain puzzles", vision ~118). Phase 3 does not know
   what a puzzle is. It **publishes** magic-effects (a FIRE effect landed here, a
   WATER effect there); Phase 4 mechanisms **subscribe** to that seam and decide
   whether they were triggered. This is the outward seam, the mirror of the aim
   seam on the input side.

**Structures, by role**
- *Magic-effect emission* — a published fact: kind, location/region, magnitude,
  source caster. The unit Phase 4 subscribes to.
- *World-application handler table* — a dispatch table keyed by effect kind that
  routes each effect event to the right world/monster mutation and/or magic-
  effect emission.

**Functions, by role**
- *Apply effect events to the world* — walks the events, routes each via the
  handler table, mutates Phase 1 state and/or emits magic-effects.
- *Subscribe to magic-effects* / *emit a magic-effect* — the seam Phase 4 hooks.

Defined by issue **305b**. The seam is intentionally narrow and neutral so that
Phase 4 puzzles, and nothing else, own the meaning of "this effect solves this."

---

## Stage 6 — Effect rendering (what you see)

Rendering is **data viewing**, and lives behind a wall from everything above.
Given the same effect events (or a viewing-friendly echo of them), the renderer
draws the flash, the beam, the impact — through the Phase 1 renderer. It reads;
it never resolves. You can run the game with rendering stubbed and every effect
still *happens*; you can replay recorded effect events into the renderer with no
caster present and every effect still *shows*.

**Structures, by role**
- *Effect-view descriptor* — a viewing-only record of an effect event: what to
  draw, where, for how long.
- *View dispatch table* — keyed by effect kind, maps each to its draw routine.

**Functions, by role**
- *Render effect views for this frame* — the viewing core, called from the Phase
  1 game loop's draw pass.

Defined by issue **306**.

---

## The generation / viewing wall

The single most important boundary in this phase: **defining/resolving spells
(Stages 1–5) never draws, and rendering spells (Stage 6) never resolves.** They
communicate only through effect events. This is the project's separation-of-
concerns discipline made concrete, and it is why resolution can be unit-tested
headlessly and why the renderer can be swapped (screen, log, the far-future
pico-8-style output) without touching spell meaning.

---

## Where each stage lives (stage → issue)

| Stage | Datapath role | Issue |
|-------|---------------|-------|
| 1 | Path & level taxonomy (vocabulary) | **301** |
| 1 | Spell template + registry | **302** |
| 2 | Cast request + Phase 2 aim seam | **303** |
| 3 | Casting-method contract & registry | **304a** |
| 3 | Initial concrete method set | **304b** |
| 4 | Effect resolution core (generation) | **305a** |
| 5 | World application + Phase 4 magic-effect seam | **305b** |
| 6 | Effect rendering (viewing) | **306** |
| — | Phase demo tying it all together | **307** |

---

## A note on counts

Per project discipline, this document does **not** hardcode how many paths, how
many levels, or how many spells or casting methods exist — those numbers rot. The
taxonomy issue (**301**) specifies a **count validator / statistics utility**;
run it for current figures. The vision fixes only the qualitative shape ("the
spell list be dominions spells", "more than one way to do each"); the exact
tallies are the validator's job to report.
