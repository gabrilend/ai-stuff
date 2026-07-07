# 603 — Challenge-modality dispatch: shadows, storm, pounding

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** nothing (a self-contained data table). Read by 606 (tuning picks
a modality) and 607 (generation applies it).
**Blocks:** 606, 607.

## Current Behavior

None of this exists yet. The vision says the DM "attempts to overcome them
through shadows, storm, or pounding," but there is no representation of those
three ways of leaning on a party, and no way to pick one for a given lair.

## Intended Behavior

A **dispatch table of challenge modalities**, one row per modality, never an
if/else or switch chain (per project policy, and because a fourth modality
should be a new row, not new branches). The three seed modalities:

- **shadows** — stealth and darkness: low light, hiding, avoidance, perception
  and stealth-leaning stats.
- **storm** — environment and chaos: moving hazards, shifting rooms, timing,
  reflex- and adaptability-leaning stats.
- **pounding** — brute force: durability checks, raw power, sustained pressure,
  strength- and endurance-leaning stats.

Each row carries: the modality's name, the **stats it leans on**, and its
**generation strategy** — the guidance the DM feeds the inference seam so a lair
built "through" that modality feels like that modality. The chooser is a
function that, given a party-capability estimate, **selects a modality** (biased
toward where the party is weak, so the DM presses the soft spot) and returns its
descriptor. The stats-per-modality mapping is the hinge that lets issue 606 tune
the chosen modality to per-stat difficulty.

## Suggested Implementation Steps

1. Define the **challenge-modality descriptor** structure: name, leaned-on
   stats, generation strategy.
2. Build the **modality dispatch table** with the three seed rows
   (shadows / storm / pounding). Keep the strategy text data, not code.
3. Write the **choose-a-modality** function: given a capability estimate, pick a
   modality (default policy: press the party's weakest relevant stat), returning
   its descriptor. Keep the selection policy swappable so "press the weakness"
   vs. "reward the strength" is a one-line change.
4. Expose a **list-modalities** accessor for the statistics utility and the demo.
5. Companion `*.info.md` describing the descriptor and the chooser.
6. Tests: all three rows are reachable; the chooser is deterministic given an
   estimate; adding a fourth row requires no change to the chooser or its
   callers; each modality names at least one leaned-on stat.

## Meta

- **Why a dispatch table:** modalities are the clearest place in the phase where
  "refer to behavior by index, not by branch" pays off — and it keeps the door
  open for a fourth way the vision has not named yet.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — "Data
  structures" (challenge-modality descriptor) and stage B.
- Issue 606 (difficulty tuning) consumes the chosen modality; issue 607 (lair
  generation) applies its strategy.
