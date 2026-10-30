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

### Stage B, 2026-10-30: the closed tables and the wall

- `src/048-shape-words.lua` lists every word legal in each of 36 places
  (the scene, a shape, a spin, a track's ties, a fluid's tilt, ...), in
  each kind of shape motion and camera motion, and in each cabinet
  shape's proportions, with the kind of value it takes and one line of
  meaning. World space is stated there once. The names the runtime owns
  (hues, shapes, motion kinds, effects, solids) are not copied: the wall
  takes them from the modules, through `choreography.vocabulary()`,
  `meshes.names()` and the hue table, and refuses loudly if the motion
  kinds or shapes in the lists and in the code ever differ.
- `src/049-shape-wall.lua` walks a scene and reports every unknown word,
  hue, shape, style, motion, effect, solid and tag at once, each with
  where it is and the nearest legal word. `choreography.load` calls it
  first, so every film and every test that loads a scene is behind it.
- The nearest-word measure moved out of `024-compile.lua` into
  `src/047-nearest.lua`, which both walls share (the 2D tests are
  unchanged: score 12 of 12, compile 19 of 19).
- `docs/shape-format.md` is printed from the lists by
  `src/051-shape-docs.lua`; `--check` fails when it is stale.
- Words found in scenes but not in the old documentation are now listed:
  `jobs`, `flock` and `role` (labels the twin-reef test counts by),
  `shard_distance`, and each shape's proportions.
- One test scene changed: `tests/shape-films/tiny-third.lua` promised to
  frame a tag, `anything`, that nothing carried. The wall refused it, so
  it now names `ball` (still `at_least = 0`).
- Proof: all 34 scenes and the 4 tiny test scenes pass the wall;
  `tests/shape-films/misspelled.lua` gets all twelve of its mistakes in
  one pass, each with its nearest word, and films nothing;
  `./test-shape-films` is 222 of 222, the six approved fingerprints
  unchanged.

### Stage C, 2026-10-30: every rule at the wall

- Each word in the lists may carry its rules: needed, whole cycles (no
  seam), whole and at least N, 0 to 1, between 0 and 1, above 0, three
  numbers, at least or exactly N items, moments rising from 0 to below 1.
- The rules that tie one word to another moved into the wall too (a
  rolling, becoming or anchored shape needs a route motion; only a
  superball morphs, and its becoming and trail must be superballs; the
  ground, the track and a moving camera are there when something needs
  them; a light has a tag or a place; a roll counts cycles or turns),
  and are listed in words in `docs/shape-format.md`.
- `choreography.load` now only builds: its 68 first-error refusals are
  gone, along with the tables and helpers only they used. The one
  refusal left is a liquid with no simulator handed in, which is about
  the caller, not the scene.
- A misspelled needed word is reported once, as the misspelling, not
  again as a missing word.
- Proof: `tests/shape-films/broken-numbers.lua` (twelve broken rules,
  every word spelled right) gets all twelve in one pass and films
  nothing; every refusal the stage test (`042`) and the runner made
  before still refuses; all 34 scenes pass and re-film byte-identical;
  `./test-shape-films` is 240 of 240.

All five suggested steps are done. The issue stays open for a look on
her machine: the films there, and whether the wall's wording reads well.
