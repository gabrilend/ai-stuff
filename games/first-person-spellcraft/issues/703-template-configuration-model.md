# 703 — Template-Configuration Model (templates, never instantiations)

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 701 (requests are priced in resource types).
> **Blocks:** 706 (the return loop stamps instances from these molds), 707 (the
> UI edits these molds).
> **Concern:** data generation / data model (simulation). The *editing UI* is a
> separate issue (707); this issue is the model the UI edits through.

The heart of the phase, and the settlement half of the project-wide strategem
**"configure the template, never the instantiation."** The player edits *molds* —
what a returning character of a given kind may request, and what it is handed for
free. The world stamps *copies* from those molds at return-time. This issue owns
the molds and the stamping; it owns no UI and no return orchestration.

## Current Behavior

None of this exists yet. There is no representation of a request template, an
inventory template, or the act of deriving a concrete request from a template.
The vision's "in-game UI that the user can use to modify templates, never
instantiations. When the character returns, they can request new things, as you
define" has nothing behind it.

## Intended Behavior

Two kinds of **mold**, held keyed by character-kind:

- **Request template** — what a returning character-kind *may ask for*, and what
  each ask costs in scarce resources (gems, resource notes, trial logs — priced
  per 701). Example in plain terms: "on return, this kind may request a ritual
  if it brought gems, and always re-ups on mana."
- **Inventory template** — what the character is *handed for free from the
  stockpile* on return ("here, have a health potion. There's extra at the
  stockpile.").

And two kinds of **stamped copy**, which this module knows how to *produce* but
which live only for one return:

- **Request instance** — the concrete list of asks, derived from a request
  template plus *this* character's brought-back treasure. (A template may say
  "may request a ritual if gems ≥ N"; the instance either contains the ritual
  ask or it doesn't, decided from what was actually carried.)
- **Loadout instance** — the concrete set of free grants, derived from the
  inventory template against what the stockpile can currently cover.

The module's surface:

- **Template CRUD** — create, read, update, and list templates. Editing is
  always of a mold.
- **Save-a-template-as-a-new-template** — mirrors Phase 5's "save patterns as
  new patterns, but summarized." Lets the player fork a mold without disturbing
  the original.
- **Stamp an instance from a template** — the *only sanctioned way an instance
  ever comes to exist.* Called by the return loop (706). Takes a template and a
  character's brought-back treasure; returns a request instance (and/or loadout
  instance). Pure: same inputs, same stamped copy.

The invariant that must hold across the whole phase: **no entrypoint anywhere
lets a stamped instance be edited.** If an instance is wrong, the mold was
wrong. Fix the mold; the next stamp is right. This is what keeps settlement
behavior coherent, exactly as saving summarized character patterns keeps a
companion coherent.

## Suggested Implementation Steps

1. Define the request-template and inventory-template records (fields: the
   allowed asks, their conditions on brought-back treasure, their resource
   costs, the free grants). Key both by character-kind.
2. Implement template CRUD and save-as-new-template.
3. Implement the stamp operation: evaluate each template ask's condition against
   the brought-back treasure, emit the request/loadout instance. Keep it pure and
   free of stockpile/market side effects (those belong to 706/705).
4. Make instances deliberately *un-editable*: expose no setter for a stamped
   copy. Document why in a comment at the seam.
5. Write the `.info.md` (each entrypoint as a black box, emphasizing the
   template-vs-instance boundary) and a test proving: editing a template does
   not touch already-stamped instances, and two stamps of the same template with
   the same treasure are identical.

## Files (proposed, by role)

- an `economy/templates` module (the mold records + CRUD + save-as-new + the
  stamp operation) and its `.info.md`.
- a template test proving the mold/copy boundary holds.

## Design notes worth keeping

- **Templates never instantiations** is not a style choice here; it is the
  coherence guarantee. Put a comment at the stamp seam explaining that the two
  branches — "edit a mold" vs "stamp a copy" — must stay separate, and what goes
  wrong if a copy becomes directly editable (drift, incoherent behavior).
- The condition-on-brought-back-treasure is where gold's abundance matters: good
  templates gate their prized asks on gems / resource notes / trial logs, not on
  gold, so the glut resource doesn't trivialize the request.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  "The central principle: templates, never instantiations."
- [strategems](../strategems/README) — "Configure templates, never
  instantiations" (the shared pattern with Phase 5's inventory UI).
- 701 (pricing), 706 (calls stamp), 707 (edits the molds).
