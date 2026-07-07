# 707 — The Template-Configuration UI (data viewing / editing)

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 703 (edits templates), and *reads* 701 (resource kinds), 702
> (balances & ledger), 704 (projected throughput), 705 (stock policy). It has the
> most blockers of the simulation-facing issues because it is a window onto all
> of them.
> **Blocks:** 708 (the demo drives the UI or at least its projection functions).
> **Concern:** **data viewing / editing.** This is the ONE issue on the viewing
> side of the wall. It must not contain simulation logic.

The vision's "in-game UI that the user can use to modify templates, never
instantiations." This is where the player turns the knobs: edits request and
inventory templates, allocates workers across workshops, hires service staff, and
sets market stock policy — and *sees* the consequences projected back. Crucially,
it is kept on the far side of the separation-of-concerns wall: it **edits molds
and reads projections**; it never generates the data it shows.

## Current Behavior

None of this exists yet. There is no interface for editing templates, allocating
workers, hiring staff, or setting stock policy; the simulation (701–706), once
built, would be headless and unconfigurable by the player.

## Intended Behavior

A configuration interface with these panels, each a thin view/editor over a
simulation module — never a reimplementation of it:

- **Stockpile view** — read-only over 702: current balances (gold, gems, resource
  notes, trial logs), produced goods, and the ledger. Pure viewing.
- **Template editor** — edit request and inventory templates through 703's
  template CRUD and save-as-new. Edits the **mold only**; there is no control
  anywhere in this UI that reaches a stamped instance.
- **Worker-allocation editor** — set how many workshops and how many workers each
  (per building-type), and **preview projected throughput by calling 704's
  compute-a-workshop's-throughput function.** The number shown is the number the
  simulation uses — the UI must not re-derive it, or the preview could drift from
  reality. This is where the player *feels* the room-vs-throughput tradeoff: the
  preview should show how spreading workers thin trades total volume for
  per-worker efficiency.
- **Service-staff panel** — hire/release service staff (704c) and preview the
  resulting production-speed bonus, again via the simulation's own projection.
- **Market stock-policy editor** — edit each market's stock policy mold (705a).
  Editing the policy never edits the market's on-hand stock; the intake process
  reconciles.

The wall, stated as a rule this issue must honor:

- The UI **reads** through the simulation's query/projection functions and
  **edits** through the simulation's mold-editing functions (template CRUD, worker
  counts, staff counts, stock policy).
- The UI **never** computes an economic quantity itself, **never** advances a
  tick, and **never** touches a stamped instance. If the UI needs a number, it
  asks the module that owns that number.

## Suggested Implementation Steps

1. Build the read-only stockpile view first (lowest risk, proves the query seam).
2. Build the template editor over 703's CRUD, foregrounding the mold/instance
   boundary in the interface itself (there is simply no "edit this return's
   request" affordance).
3. Build the worker-allocation editor; wire its throughput preview to 704's
   compute-throughput. Add a visible before/after so the tradeoff is legible.
4. Build the service-staff panel and market stock-policy editor over 704c and
   705a.
5. Keep every panel a pure view/editor. If a panel finds itself wanting to
   compute something, that computation belongs in the simulation module and the
   panel should call it.
6. Write the `.info.md` describing each panel's read-seam and edit-seam, and a
   test (or scripted walkthrough) that edits a template and a worker allocation
   and confirms the change lands in the simulation model and the previewed number
   matches the simulation's own.

## Files (proposed, by role)

- an `economy/config-ui` module (the panels, each bound to a simulation
  read-seam and edit-seam) and its `.info.md`.
- a config-UI walkthrough test proving edits land in the model and previews match
  the simulation.

## Design notes worth keeping

- This issue is the concrete instance of the project rule "write data generation,
  and separately and abstracted away, write data viewing." The simulation (701–
  706) is the generator; this is the viewer/editor. The wall between them is the
  whole reason the economy stays debuggable — errors in *what the numbers are*
  live in 701–706; errors in *how they're shown or edited* live here, and never
  the twain shall hide in each other.
- Every previewed number is a call into the simulation, not a copy of its math.
  Comment this at each preview so no one later inlines a "quick" recomputation
  that then rots out of sync.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  "Separation of concerns: simulation vs configuration UI."
- Edits 703; reads 701, 702, 704, 705. Exercised by 708.
