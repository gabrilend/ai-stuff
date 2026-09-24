# Issue W05d: Clean-Room Loop — Describe, Build, Check

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** High (the default route for every replacement)
**Dependencies:** W05a (scorer), W03 (renders models from fixed cameras)

---

## Current Behavior

W05's routes (search, and generate from a render of the original) produce
assets whose lineage is `derived`: whoever made them saw the original. No
route produces an asset made by someone who never saw it.

## Intended Behavior

The owner (2026-09-23): "that may be worth it in all cases. I worry about
things like scaling, so it might need to be an iterative process before a
viable model is produced. So we'll need tests like 'is approximately as large'
and if not, then it scales it up, takes pictures, presents those to the
creation system and says 'fix the imbalances with the new scale' or similar."

Three roles, each a separate session (or process) with separate access:

| Role | Sees the original? | Produces |
|------|--------------------|----------|
| **Describer** | yes | a **specification**: words (what it is, its parts, its mood, colours by name) plus functional measurements |
| **Builder** | **never**: no access to the client folder, the reader library or any original render | the replacement, made from the specification only (text → concept image → image-to-3D → mesh, or text → sound, etc.) |
| **Checker** | yes | numbers and named measurement failures only, never pictures of the original |

The specification's measurements are the facts gameplay depends on, not the
look:

| Measurement | Type | Why the game needs it |
|-------------|------|-----------------------|
| height, width, depth | float, yards | fits doors, selection circles, camera framing |
| footprint radius | float, yards | collision and selection |
| attachment heights (overhead, chest, hands, origin) | float, yards from the ground | health bars, spell effects, weapons |
| animation list with durations and key moments | list of (name, ms, hit point ms) | gameplay timing (e.g. when an attack lands) |
| sound length and loudness | ms, dB | timing and mixing |

### The fitting loop (the owner's scaling idea)

```
 spec ──▶ builder makes candidate
              │
              ▼
        checker measures the candidate (and only the candidate) ──▶ within tolerance? ──yes──▶ scorer (W05a gate) ──▶ keep
              │ no
              ▼
        scale the candidate so its height matches the spec
              │
        render the *scaled candidate* from the fixed camera ring
              │
        builder gets: those renders + the failed measurements in words
        ("width is 30% over spec after scaling to height; arms are now thin
         relative to the body — fix the imbalances at the new scale")
              │
              └──▶ builder makes the next candidate (back to the top)
```

Each round is kept (content-addressed, with its measurements), so the loop's
history shows the asset converging. A round limit stops runaway loops and
reports the closest candidate.

### Why the loop never uses similarity as its guide

Two things are true at once: the loop pulls the candidate toward the
original's **measurements**, and the project wants the candidate to be
**unlike** the original. If the builder were told its similarity score and
asked to raise it, or shown the original to compare against, the loop would
steer toward the original and would be a copying machine. So:

- The loop's feedback is **functional measurements only** (size, footprint,
  attachment heights, timing).
- The similarity score (W05a) is a **gate** at the end ("is it distinct
  enough?"), never a direction. A candidate that fails the gate is rebuilt from
  the specification with a new seed or style, not nudged.
- The checker never sends the builder an image of the original, and the
  builder's transcript is checked for that (below).

### Evidence for the transcripts

- The builder runs without the client folder and without `libwreaders.so`
  (enforced by the process, not by instructions).
- An automatic check scans each builder transcript for forbidden material:
  Blizzard model paths, image hashes of original renders, file names from the
  client folder. A hit marks the asset `derived`, whatever else happened.
- The provenance record names the describer, builder and checker transcripts
  (paths and line ranges).

## Suggested Implementation Steps

1. Specification format (a Lua table: words + the measurement table above) and a describer tool that measures the original automatically and leaves the words to the describer.
2. Builder sandbox: a separate process with no access to the client folder; its inputs are the specification and the fitting renders.
3. Checker: measure candidate against the specification; produce the failed-measurement text.
4. The fitting loop with a round limit and per-round storage.
5. Transcript scanner for forbidden material.
6. Tests: a spec for a simple object (a crate) converges within the round limit; a builder transcript seeded with a forbidden path is flagged; a candidate that matches the original's silhouette closely fails the W05a gate even though every measurement passes.

## Acceptance Criteria

- [ ] One doodad and one creature made end to end through the loop with lineage `independent`
- [ ] The loop's per-round history is visible in the gallery
- [ ] The transcript scanner flags a planted violation
- [ ] The builder process cannot open the client folder

## Open Questions

1. **Skeletons.** A clean-room builder can't reuse Blizzard's skeletons (W05b), because that makes the result `derived`. It could build its own skeleton from the specification's functional measurements (bone count, joint positions, attachment heights), then the animations come from a clean-room source too. Accept that animated units take longer to reach `independent`, with W05b's borrowed skeletons as the stopgap?
2. **Tolerance.** How close is "approximately as large": ±10% on height and footprint as a first guess?
3. Is a separate Claude session enough of a separation, or should the builder use a different model or tool chain altogether?

## Related Documents

- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`, `W05a-similarity-to-original-score.md`, `W05b-borrowed-skeleton-and-animation-sets.md`
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/012-asset-replacement-and-provenance.md` (Clean-room by default)
