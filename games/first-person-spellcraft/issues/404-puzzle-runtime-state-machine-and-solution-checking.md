# 404 — Puzzle Runtime: State Machine & Solution Checking

> Phase 4 — Stages 3 and 4 of the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md). This is the
> loop that turns the pipeline over: advance watchers, route events, re-check the
> predicates, and drive the puzzle through `in-progress -> solved | failed`.

## Meta

- **Phase:** 4
- **Blocked by:** 401 (structures), 402 (trigger events), 403 (activation).
- **Blocks:** 405 (runtime calls the trap on failure), 407 (runtime emits
  outcomes onto the bus).

## Current Behavior

None of this exists yet. Triggers can fire and mechanisms can move (once 402/403
land), but nothing checks whether the puzzle is solved or failed, and there is no
state machine tying a tick together.

## Intended Behavior

A per-tick runtime advances one live puzzle instance:

1. **Advance the trigger watchers** (call 402's watcher pass) to collect this
   tick's edge-triggered events.
2. **Route each event** through 403 to move mechanism states.
3. **Evaluate the puzzle**: re-run the solution-set predicate and the failure
   predicate(s) over the current mechanism states and budgets.
4. **Drive the state machine**:
   - solution predicate true -> `solved`; fire the mechanism's **solution effect**
     (open the door, reveal the path, mark a trap `disarmed`).
   - a failure predicate true -> `failed`; hand off to the **trap** (issue 405).
     Note: firing a trap is **not** automatically terminal — the state machine
     decides whether a sprung trap ends the puzzle or merely raises its cost and
     leaves it `in-progress`. Own that decision here, explicitly, with a comment
     on each branch explaining what it brings.
   - neither -> stay `in-progress`, spend from the attempt/time budget as
     configured.
5. On any terminal transition (and on notable non-terminal ones), assemble an
   **outcome record** (issue 407 publishes it).

The runtime is the **state producer**; keep viewing/consuming (the demo's
rendering, the solver's reading) abstracted away behind the outcome edge, per the
project's generate-then-view separation. A puzzle instance must be advanceable in
isolation, so many can run in one lair without interfering.

The state machine, as a **dispatch table keyed by current node**, maps each node
to its allowed transitions and the guard that fires them — not an if/else ladder
over states.

## Suggested Implementation Steps

1. Create the runtime source file (indexed name + `.info.md`), importing 401-403.
2. Implement the **predicate evaluator** over the data-driven solution-set and
   failure clauses defined in 401 (mechanism-state equality, lit-counts, budget
   exhaustion, trap-sprung).
3. Build the **state-machine dispatch table** (`in-progress` / `solved` /
   `failed`) with per-node guarded transitions; comment each branch with what the
   path means for the player.
4. Implement the **tick function**: watchers -> route -> evaluate -> transition,
   operating on a single live instance.
5. Implement **fire-solution-effect** (the SOLVED consequence) and the **hand-off
   to the trap** (the FAILED consequence; the trap's behaviour is 405).
6. Assemble the **outcome record** at terminal transitions (fields from 401;
   emitting is 407) — which puzzle, archetype, verdict, triggers tried, which were
   solving, which red herrings taken, time and cost spent.
7. Tests, driving 401's hand-authored fixtures with test-double trigger sources:
   a solving sequence reaches `solved` and fires the solution effect exactly once;
   an `arms-trap` red herring reaches `failed` and hands off to a stub trap;
   budget exhaustion fails a stalled puzzle; two instances of one definition
   advance independently.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stages
  3-4 and the state-machine description.
- Downstream: [405](405-trap-system-and-trap-type-dispatch.md) (failure hand-off),
  [407](407-composition-and-outcome-seam-for-the-dungeon-master.md) (outcome bus).
