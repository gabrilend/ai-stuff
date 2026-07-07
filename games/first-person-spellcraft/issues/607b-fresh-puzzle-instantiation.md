# 607b — Fresh puzzle instantiation from Phase-4 primitives

**Phase:** 6 (AI Dungeon Master & Learning)
**Parent:** [607](607-lair-generator.md)
**Depends on:** 607a (the lair spec to realize), Phase 4 (the live primitives).
**Blocks:** 608 (the loop / demo attempts a live lair).

## Current Behavior

None of this exists yet. A lair spec from 607a is only a plan — a list of
references. Nothing turns those references into the live mechanisms, triggers,
and traps a party can actually touch, so the party has nothing to attempt.

## Intended Behavior

The **make-it-real** half of generation. Given a validated lair spec, it
**instantiates** each puzzle spec into live Phase-4 objects — **fresh, for this
visit only** ("newly created each time a group of adventurers wanders on"):

- The **mechanism** that provides the solution.
- Its **multiple triggers**, including the equal-seeming **red-herring** triggers
  Phase 4 provides — the DM keeps the decoys "suitably equal in likely" so the
  solution is not obvious.
- The **solution path** the puzzle spec named.
- The **trap that fires on failure** — wired so that failing the puzzle triggers
  it, and, where the spec says so, so that **disarming the trap is itself the
  puzzle** (both shapes exist in Phase 4).

The four **combats** are instantiated from their specs the same way. Nothing here
is persisted between visits: instantiation always starts from the spec, so
re-entering a "cleared" lair yields a brand-new one.

Prefer erroring over improvising: if a spec references a primitive that will not
instantiate, that is an error to surface, not a gap to paper over.

## Suggested Implementation Steps

1. Write **instantiate-puzzle**: turn one puzzle spec into a live Phase-4
   mechanism + triggers (real + red-herring) + solution + trap-on-failure.
2. Wire the **trap-on-failure** connection, including the "disarming is the
   puzzle" variant, using Phase-4's trap interface.
3. Write **instantiate-combat**: turn one combat spec into a live encounter.
4. Write **instantiate-lair**: run the above across the whole spec, producing a
   live, attemptable lair; ensure no state leaks between visits.
5. Companion `*.info.md` describing the instantiate functions.
6. Tests: each puzzle instantiates with at least one real trigger and at least
   one equal-seeming red-herring; failing a puzzle fires its trap; a
   disarm-is-the-puzzle spec wires correctly; re-instantiating the same spec
   yields an independent lair (no shared state); a bad primitive reference errors.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) —
  "instantiate fresh puzzles" and "wire the trap-on-failure."
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md)
  *(Phase 4)* — mechanisms, triggers, red-herrings, and traps realized here.
