# 607a — The lair spec and the fixed ~3-puzzle / 4-combat ratio

**Phase:** 6 (AI Dungeon Master & Learning)
**Parent:** [607](607-lair-generator.md)
**Depends on:** 601 (inference seam), 603 (modality), 606 (difficulty target).
**Blocks:** 607b.

## Current Behavior

None of this exists yet. There is no structured description of a lair and no
composition step that asks the strong model for one. Nothing enforces the
vision's fixed count of puzzles and combats.

## Intended Behavior

The **shape-deciding** half of generation. Two pieces:

- **The lair spec structure** — a small room layout holding a list of **puzzle
  specs** and a list of **combat specs**, each tagged with the modality and the
  stat(s) it leans on. A **puzzle spec** names, by reference into Phase-4
  primitives, a mechanism, its multiple triggers (including red-herrings), the
  solution, and the trap-on-failure. A **combat spec** names foes, arrangement,
  and leaned-on stats. (The specs are references/plans; 607b makes them live.)

- **The composition step** — builds a **generation request** from the difficulty
  target + modality + Phase-4 primitive pool, submits it through the inference
  seam (issue 601) using the **strong** model handle, and validates the response
  into a lair spec. Validation **enforces the one fixed ratio**: **exactly 4
  combats**, and puzzles at **three-ish** (a small allowed band around three —
  the statistics utility reports the exact band; the vision says "three-ish
  puzzles and four combats exact"). A response that violates the ratio, or fails
  to reference valid primitives, **errors** — no silent trimming or padding, no
  canned fallback lair (a fallback is a warning; warnings are errors).

## Suggested Implementation Steps

1. Define the **lair spec**, **puzzle spec**, and **combat spec** structures as
   plans referencing Phase-4 primitives.
2. Write the **build-generation-request** step from difficulty target + modality
   + primitive pool.
3. Write the **compose-lair** step: submit via the seam with the strong handle,
   receive a response.
4. Write the **ratio validator**: assert exactly 4 combats and puzzles within the
   three-ish band; assert every referenced primitive exists; error otherwise.
5. Companion `*.info.md` describing compose-lair and the spec structures.
6. Tests: a valid generation produces exactly 4 combats and an in-band puzzle
   count; a response with 3 or 5 combats errors; a puzzle referencing a
   nonexistent primitive errors; the strong handle (not the weak one) is used.

## Meta

- **The fixed ratio is the only hardcoded count in the phase.** Everything else
  defers to the statistics utility. This is deliberate — it is the one number the
  vision states as law.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — stage C.
- Issue 601 (seam), 606 (target), 603 (modality) supply the inputs; 607b makes
  the specs live.
