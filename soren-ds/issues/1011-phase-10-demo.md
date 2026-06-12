# 1011 — Phase 10 demo

## Current behavior

Issues 1001 through 1010 produce the modeller. Phase 10 needs a
demo that exercises every piece and proves the platform hosts
this complex app cleanly.

## Intended behavior

A single-device interactive demo at
`issues/completed/demos/phase-10/run.sh` walks the user through:

### 1. Build a pyramid

The user opens the modeller, places five vertices to form a
square base with an apex (four base vertices at (0,0,0),
(4,0,0), (4,0,4), (0,0,4) and an apex at (2,3,2)). They form
four triangular faces (apex + each pair of adjacent base
vertices) and one square base face.

The script samples the perspective view at known pixel
coordinates and asserts the rendered pyramid matches the
expected silhouette.

### 2. Color the faces

The user picks five colors from the radial menu and applies
each to one face. The script samples the rendered colors and
asserts each face's pixel color matches.

### 3. Save the model

The user saves the pyramid as `/models/pyramid/` through the
drawer. The script reads the directory and asserts the
`meta.json` and box files are present and well-formed.

### 4. Build a cube

The user builds a second model — a cube with eight vertices and
six quad faces. Saves it as `/models/cube/`.

### 5. Merge

The user opens the pyramid model, then opens the merge sub-flow
and picks the cube as the auxiliary. Anchors the pyramid's apex
to the center of the cube's top face. Picks "drop interior".
Commits.

The merged model has the pyramid sitting on top of the cube,
sharing the anchor vertex, with the cube's top face dropped
(it was interior to the combined shape). The script asserts the
expected vertex and face counts after the merge.

### 6. Save and reload

The user saves the merged model as `/models/cube-with-spike/`.
Closes the modeller (909 path). Reopens it. Loads the merged
model. The script asserts the loaded geometry matches the
saved state and that the launch apps' heartbeats continued
throughout — the modeller is a guest on the platform, not a
disruptor.

## What the demo proves

- The vertex grid, face formation, color and roughness
  selection all work as a system.
- The save/load round trip preserves models bit-perfectly.
- Encapsulation correctly flattens the auxiliary model into
  the working set during merge.
- The interior-detail policy correctly identifies and culls
  hidden geometry.
- The modeller as a user-authored complex app runs cleanly
  under the MMU protection model from phase 9.
- The platform's vision — an app the architects didn't build,
  living comfortably above everything they did — is real.

## Suggested implementation steps

1. The script's interactive narrative with developer prompts.
2. The pyramid and cube authoring instructions.
3. Per-step pixel sampling and structural assertions.
4. The cleanup pass that resets the model files between runs.

## Related documents

- `docs/002-roadmap.md` — phase 10 demo description.
- `docs/010-modeller.md`.

## Blocked by

All of 1001 through 1010.

## Closes

Phase 10.
