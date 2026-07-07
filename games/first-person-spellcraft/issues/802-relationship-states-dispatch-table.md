# 802 — Relationship states as a dispatch table (+ transitions)

> Phase 8. The three ways a province can stand toward you, and the only
> sanctioned ways it moves between them. Both are dispatch tables — never
> if-ladders. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 2).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 801 (a province to hold a state key).
- **Blocks:** 803 (yields dispatch on state), 805 (the clear-and-control loop
  drives transitions), 807 (the union counts hostile provinces).
- **Kind:** state model.

## Current Behavior
None of this exists yet. A province record (801) carries a relationship-state
key, but nothing gives that key meaning and nothing governs how it changes. A
province could be set to any string, and there are no rules about what a
`hostile` province *is* versus an `allied` one.

## Intended Behavior
Three relationship states exist, each an entry in a **relationship-state dispatch
table keyed by the state name**. The vision names all three:

> be peaceful, and they are on your side… be unkind, and they are challenges to
> train up on. leave unclaimed, and monsters return…

| state key           | meaning                                    |
| ------------------- | ------------------------------------------ |
| `allied` (peaceful) | on your side; provides "one thing or another" |
| `hostile`           | a challenge to train up on                 |
| `unclaimed`         | monsters return (804)                       |

Each state-table entry answers the same shared questions with its own values /
functions: a display label; whether it **yields passively**; whether it
**presents a challenge**; whether **monsters can return**; an `on_enter` and an
`on_exit` hook; and its **allowed transitions**. Because every state answers the
same questions, adding a fourth state later is adding one table row, not editing
a switch in five places.

A **second dispatch table keyed by `(from_state, to_state)`** is the *only*
sanctioned way a province changes relationship. Attempting a transition looks it
up; a missing entry means the move is illegal and the attempt fails loudly (no
silent fallback — a rejected transition is a real signal, per project policy).
The sanctioned moves are:

- `unclaimed → allied` (cleared peacefully),
- `unclaimed → hostile` (subjugated unkindly),
- `allied → hostile` (you turned on an ally),
- `hostile → allied` (you made peace),
- `allied → unclaimed` and `hostile → unclaimed` (abandoned; 804 takes over).

Each transition, when it fires, runs the old state's `on_exit` then the new
state's `on_enter`, so bookkeeping (e.g. starting/stopping the reversion timer,
adjusting the unkindness tally) lives with the states, not scattered in callers.

## Suggested Implementation Steps
1. Write a **relationship-states** module. Define the state dispatch table with
   one entry per state; give every entry the same key set so the shape is
   uniform. Prefer describing each state in plain fields + small functions.
2. Define the **transition table** keyed by an ordered `(from, to)` pair. Store
   the effect of each legal move (which hooks to run, any ledger note to write).
3. Write **describe-state** (return a state's entry) and **attempt-transition**
   (validate against the transition table, run `on_exit`/`on_enter`, write the
   new key into the province record). A rejected transition returns an explicit
   failure the caller must handle.
4. Have `on_enter`/`on_exit` hooks touch only the province they are given —
   starting the reversion timer on entering `unclaimed`, clearing it on leaving,
   and appending to the kindness ledger on entering `hostile` via subjugation.
5. Keep the **unkindness accounting hook** here but let 807 own the tally object;
   the state hook just notifies it. Wire it as an injected callback so this
   module does not hard-depend on the union module.
6. Write the companion `*.info.md`.
7. Test: assert every illegal `(from,to)` is rejected and every legal one flips
   the key and runs both hooks exactly once. Tests are cheap; make several.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Uses the province record from 801; feeds the yield dispatch in 803; is driven
  by the expedition resolver in 805; notifies the union tally in 807.
