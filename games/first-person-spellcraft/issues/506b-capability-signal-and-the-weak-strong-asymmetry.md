# 506b — Capability Signal & the Weak/Strong Asymmetry

> The wire that carries "this adventurer proved that-potentialed" out of Phase 5.
> Every puzzle attempt resolves into a small success-or-failure record that is
> written into the NCP's memory *and* published upward for Phase 6 to read. It is
> the measurement half of the weak-solver work.
>
> Second half of the weak-solver work (paired with 506a). Depends on 506a (the
> attempt), 502 (writes the outcome into memory), 501 (the stat that carried it).
> NCP = New Character Person; see
> [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. The weak solver (506a) will produce attempts, but nothing
turns an attempt's outcome into a durable record or hands it to the Dungeon Master,
so no one can learn from what an adventurer proved.

## Intended Behavior

When a puzzle attempt (506a) resolves through Phase 4 into an outcome
(solved / trap-triggered / gave-up), a **capability signal** is emitted:

- **Success or failure**, the stat that carried the attempt (501), and enough
  context (which puzzle, roughly how hard) for a consumer to interpret it.
- **Two destinations, one event.** The signal is (1) **appended to the NCP's
  memory store** (502) — so this adventurer now "remembers" the outcome and its
  persona (504) and future attempts (506a) can draw on it — and (2) **published
  upward for Phase 6** — the Dungeon Master reads it to update how potentialed the
  adventurer is (*"each time they conquer it, the AI remembers they are that
  potentialed"*).

The **weak/strong asymmetry** is the point of the whole signal, and this issue is
where it is made legible for Phase 6:

- The lair was built by a **powerful** generator (Phase 6); the puzzle was solved
  (or not) by a **deliberately weak** solver (506a). The DM cannot read the weak
  solver's mind — it can only read *this signal*. The gap between what the strong
  builder made and what the weak solver managed is precisely how the DM estimates
  difficulty and re-conceives what a "level" means.
- So the signal must carry what the DM needs to close that loop: the outcome, the
  carrying stat's level, and a difficulty reference — but **not** leak the solver's
  internal knobs (that would collapse the asymmetry into a direct readout).

Keep emission a thin, pure step: attempt-outcome in, signal out, plus the two
deliveries. Phase 6 owns what it *does* with the signal; Phase 5 only owns
producing an honest one.

## Suggested Implementation Steps

1. Define the **capability signal** structure: outcome (success | failure | give-up),
   carrying stat + its level at attempt time, a puzzle/difficulty reference, and a
   timestamp/run id. Keep it small and plain — it is a message, not a model.
2. Write the **emit operation**: from a resolved attempt (506a) build the signal,
   then perform both deliveries — append to memory (502) and publish to the Phase-6
   consumer seam. Make the publish seam a clean, documented boundary (a sink Phase 6
   subscribes to) so Phase 5 does not depend on Phase 6's internals.
3. Guard the asymmetry: deliberately exclude the solver's internal competence knobs
   from the signal. Comment this exclusion loudly — a future editor "helpfully"
   adding them would break the DM's difficulty estimation.
4. Test the round trip: run an attempt, assert a signal is both written to memory
   and delivered to a stub consumer, and that success and failure are
   distinguishable and stat-attributed.
5. Test the loop's intent: feed a stub DM consumer a stream of signals and confirm
   it can distinguish a stronger adventurer (more successes at higher difficulty)
   from a weaker one — proving the signal carries enough to "estimate how
   intellectual the characters are."
6. Write the file's `.info.md`: the emit operation and the consumer-seam contract,
   inputs/outputs as black boxes (Phase 6 reads this).

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Capability
  signal" structure and the "→ Phase 6" seam (weak-vs-strong asymmetry).
- [strategems](../strategems/README) — "remember the demonstrated, re-estimate the
  meaning."
- Pairs with: weak solver (506a). Writes to: memory store (502). Read by: Phase 6
  Dungeon Master. Stat source: data model (501).
