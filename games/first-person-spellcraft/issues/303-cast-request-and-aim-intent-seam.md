# 303 — Cast request & the Phase 2 aim/intent seam

> Phase 3 · Spell System · the packet that carries intent inward, and the seam
> that draws aim from Phase 2. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 2. Depends
> on: [302](302-spell-template-data-model.md) (a spell to reference) and Phase 2
> (the input-abstraction layer that produces aim).

## Current Behavior

None of this exists yet. Spell templates (302) sit in the book, but there is no
way to say "*this* caster wants to cast *this* spell, *this* way, pointed *there*."
There is likewise no agreed shape for the aim value Phase 2 will hand across.
Phase 2 is defining an input-abstraction layer (its roadmap deliverable); Phase 3
needs to name the one thing it wants from it without reaching into its internals.

## Intended Behavior

A **cast request** is the small packet that flows from "a caster decided to act"
all the way to effect resolution. It references:
- the **spell template** (by id, from the 302 registry),
- the **caster** — an opaque handle; the system deliberately does **not** care
  whether it is the player or an NCP ("anything that needs aiming, the user can
  aim, when they're playing as an NCP", notes/vision ~112-113),
- the **chosen casting method** (a method key that must be among the template's
  legal methods and present in the 304a dispatch table),
- an **aim/intent**, present **only** if the spell/method needs aiming.

**The Phase 2 seam (this is where aim comes IN).** Phase 3 must not read mice,
brains, or the ceiling headset. It consumes a single neutral value from Phase 2's
input-abstraction layer: an **aim/intent** — at minimum a direction, plus
whatever origin and steadiness Phase 2 chooses to attach. This issue's job is to
**pin down the shape Phase 3 needs** (the fields it will read) and to depend on
Phase 2 to fill it — for player and NCP identically. This is the "Aim once, aim
everywhere" strategem ([strategems/](../strategems/README)): the *source* of the
motion differs, the *routing* does not.

A spell that needs aim but is handed a cast request with no aim is **refused with
a clear error**, never defaulted to a straight-ahead guess — a missing aim is a
real upstream error to surface, not to paper over.

## Suggested Implementation Steps

1. Define the cast-request structure as plain data (spell id, caster handle,
   method key, optional aim/intent).
2. Define the **aim/intent shape Phase 3 reads** — the minimal field set
   (direction; optional origin/steadiness) — and document it as the contract owed
   by Phase 2's input layer. Reference Phase 2's datapath rather than duplicating
   its internals.
3. Provide a constructor by role: *build a cast request* — given a caster, a
   spell id, a method key, and (optionally) an aim, assemble a validated packet
   (spell exists, method is legal for the spell). Refuse malformed requests.
4. Provide a *does this cast need aim?* query (reads the template + method traits
   from 304a) so callers know whether to fetch aim before building the request.
5. Write a **stub aim source** used only for headless tests — a fixed direction
   standing in for Phase 2 — clearly marked as test scaffolding, so Stages 3–5
   can be exercised before Phase 2 is wired in. Track it for removal/permanence
   in this issue; it should not survive into shipping paths.
6. Add a `.info.md` for the cast-request module.

## Data Structures / Functions / Files (by role)

- *Cast request* — spell id, caster handle, method key, optional aim/intent.
- *Aim/intent (consumed)* — direction (+ optional origin/steadiness); owned in
  shape here, owned in production by Phase 2.
- *Cast-request builder* — validating constructor.
- *Needs-aim query* — reads template + method traits.
- *Stub aim source* — test-only scaffolding, marked for later removal.
- Files: a cast-request module under `src/` + `.info.md`; the stub aim source as
  a clearly-named test helper.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 2.
- [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md) — Phase 2's
  input-abstraction layer, the aim producer (planned; owned by Phase 2).
- [strategems/](../strategems/README) — "Aim once, aim everywhere."
- Blocks: 304 (methods consume cast requests), 305a (resolution reads the aim).
