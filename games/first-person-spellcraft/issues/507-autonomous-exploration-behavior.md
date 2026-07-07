# 507 — Autonomous Exploration Behavior

> The moment the game "plays itself." An NCP walks a lair on its own — through the
> square rooms, into the four combats, up to each puzzle where it calls the weak
> solver — and carries treasure home. This issue adds the *decisions*; Phase 1
> already owns the *walking*.
>
> Depends on 501 (the instance it drives), 506 (the solver it invokes at puzzles),
> and Phases 1 (movement/rooms), 3 (spells it casts), 4 (puzzles/combats). NCP =
> New Character Person; see [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. An NCP instance (501) can be placed in a room, has a
persona (504) and a weak solver (506), but nothing decides where it goes or what it
does — it would stand still.

## Intended Behavior

An **autonomous exploration driver** that, each tick when no player is at the wheel
(508), steps a single NCP through a lair:

- **Navigate the rooms.** Choose the next room and move the body through the
  Phase-1 square-room world and its collisions, using the engine's existing
  movement — the driver decides *where*, the engine handles *how*. A lair holds the
  vision's fixed shape: "three-ish puzzles and four combats exact," and exploration
  is the loop that visits them.
- **Engage the combats.** On meeting one of the four combats, fight — casting
  Phase-3 spells, aimed by the AI (the aim *source* is the driver; the aim *path*
  is the same one the player uses in 508 — "aim once, aim everywhere").
- **Approach the puzzles.** On reaching a puzzle, hand it to the weak solver
  (506a); the attempt resolves through Phase 4 (solution, red-herring, or trap),
  and the capability signal fires (506b).
- **Gather treasure.** Route found gold, gems, resource notes, and trial logs into
  the instance's live inventory (501) — the payload Phase 7 reads on return.
- **Prompt the voice.** At the natural beats (room entry, pre-puzzle, post-combat,
  return), notify the companion (504) so it can guide — exploration *acts*, the
  companion *reads*; keep them separated.

The driver is a small decision loop, not a mind — deliberately simple, leaning on
the weak solver for the hard thinking and the persona for the talking. Its
outermost result is a completed (or abandoned) run whose inventory and memory the
rest of the game consumes.

## Suggested Implementation Steps

1. Define the **exploration state** for one run: which room, which combats/puzzles
   remain, current objective. Keep it plain and inspectable.
2. Write the **step operation** driven each tick: a dispatch table keyed by the
   current situation (in-transit | in-combat | at-puzzle | done) rather than a
   chain of if/else, each entry a small handler. Comment each handler with what its
   path leads to.
3. **Navigate:** pick the next room over the Phase-1 room graph and issue movement
   through the engine; do not re-implement movement or collision. Leave a comment
   at the seam naming which Phase-1 function owns the walking.
4. **Combat handler:** engage the Phase-4 combat by casting Phase-3 spells through
   the shared aim path, with the driver as the aim source. Keep the aim routing
   identical to the player-takeover path (508) so the two never diverge.
5. **Puzzle handler:** invoke the weak solver (506a), let Phase 4 resolve the
   trigger, and let the capability signal (506b) fire. The driver only *hands off*;
   it does not judge the puzzle.
6. **Treasure handler:** deposit found loot into the live inventory (501).
7. **Voice beats:** call the companion's utter (504) at the defined situations;
   route its lines to the same view sink, keeping generation and display separate.
8. Test a full dry run: a stubbed lair with the fixed puzzle/combat counts, driven
   start to finish, asserting the NCP visits every combat and puzzle, accrues loot,
   emits signals, and ends in `done`.
9. Write the file's `.info.md`: the step operation and run lifecycle, as black boxes.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Autonomous
  exploration" and the Phase 1/3/4 seams.
- [strategems](../strategems/README) — "aim once, aim everywhere."
- Drives: data model (501). Invokes: weak solver (506), companion (504). Yielded to
  by: player takeover (508). Consumes: Phases 1, 3, 4. Feeds: Phase 7 (return).
