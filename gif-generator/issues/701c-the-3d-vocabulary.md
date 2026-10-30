# 701c — the 3D vocabulary

Part of 701. Depends on: 701a. Blocks: 701d.

## Current Behavior

A shape scene is a Lua table returned by an ordinary Lua file: meshes,
about ten motion kinds, spin, pulse, morph, parts, blobs, trails, reactions,
ground, strokes, beams, a track, streaks, lights, fluid, framing and
clearance promises, and a camera with seven motions (`src/039-shape-films.info.md`,
from "Scene file" to "Tests"). It runs as real code: `input/shapes/blob-lava-lamp.lua` builds
its blobs with a loop and `math.cos`, and `input/shapes/wizard-beam.lua` loads a
part with `dofile`. A mistake stops the run at the first one found.

The 2D score is the opposite on every point: a sandbox where loops, math and
file reads do not exist, every word from closed tables, and a wall
(`src/024-compile.lua`) that reports every error in one pass, each with the
nearest legal word.

## Intended Behavior

The 3D words become a closed vocabulary with the 2D score's discipline:

- **Closed tables** for every word, the same tables the documentation is
  generated from, so the two cannot drift.
- **A sandbox**: a 3D scene is data, not a program.
- **The wall**: every error at once, each with the nearest legal word.
- **A generator step** for scenes that today use loops (a ring of blobs, a
  part reused): a small, separate, allowed program that writes the plain
  scene, kept beside it, so the scene itself stays data and the generation
  stays visible.
- **World space** stated in one place: units around an origin, y upward, the
  camera's eye, target, roll and field of view.

The 34 existing scenes are ported; the six approved films re-film
byte-identical.

## Suggested Implementation Steps

1. List every word the scenes use today, from `choreography.lua` and the
   scenes themselves, into vocabulary tables.
2. Write the 3D wall beside the 2D one, sharing its nearest-word machinery.
3. Run every scene through the wall; for each one that is not plain data,
   write its generator and check the generated scene is identical to what
   the old file produced.
4. Document the vocabulary from the tables, as `docs/score-format.md` is.
5. Prove: six fingerprints unchanged, every scene passes the wall, and a
   deliberately misspelled scene gets every error and every suggestion.

## What Happened

Built in stages on the branch `claude/701c-the-3d-vocabulary`.

### Stage A, 2026-10-30: scenes are data

- `src/045-scene-file.lua` reads a scene in an empty sandbox (no `math`,
  no `ipairs`, no `dofile`) and refuses a scene that reaches for anything,
  naming the way out: a generator. It also writes a scene table as
  canonical text, numbers written so they read back as the same double.
- `src/046-make-shapes.lua` and `./make-shapes` run every program in
  `input/shapes/generators/` and write what each returns as the plain
  scene beside the others, under a line saying where it came from.
  `./make-shapes --check` writes nothing and fails on any generated scene
  that is stale or missing. It never overwrites a hand-written scene.
- The 25 scenes that computed (loops, `math`, `dofile` of a part) moved
  to `input/shapes/generators/`, with `parts/` under it. The 9 that were
  already plain stay where they were. Every film, the gallery, the
  choreography test and the framing test read scenes through the sandbox.
- Proof: all 34 full-length films re-film byte-identical to the films
  made before the change (sha256 of every one), the six approved
  fingerprints included, two of them (`rainbow-stack`, `reef-school`)
  now from generated scenes. `./test-shape-films` is 196 of 196, with
  three new checks: every generated scene matches its generator, and a
  scene that computes is refused with the generator named and films
  nothing.

Still to come: the closed tables and the wall (steps 1, 2 and 4), then
folding choreography's own first-error refusals into the wall.
