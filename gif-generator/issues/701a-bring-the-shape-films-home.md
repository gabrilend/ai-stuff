# 701a — bring the shape films home

Part of 701. Depends on: nothing. Blocks: 701b, 701c, 701e.

## Current Behavior

The shape-film tool lives at `delta-version/scripts/readme-gallery/`
(`readme-gallery.lua`, `choreography.lua`, `meshes.lua`, `raster.lua`,
`fluid.lua`, `png.lua`, `render-all.sh`, `scenes/` with 34 scene files,
`tests/`, `test-readme-gallery.sh`, `readme-gallery.info.md`). The viewer
lives at `delta-version/scripts/gif-viewer/` (`main.lua`, `conf.lua`,
`decode-worker.lua`, `gif-decode.lua`, `gif-decode-test.lua`,
`test-gif-viewer.sh`, `view-gifs`, `gif-viewer.info.md`). Neither follows
this project's numbered-file reading order.

Paths that name the old homes, all of which must change together:

- `readme-gallery.lua:34`, `:48` (the climb into this project's `src/`),
  `:49` (its RAM output folder)
- `render-all.sh:17-18`
- `gif-viewer/view-gifs:14-15`, `gif-viewer/main.lua:23`
- `gif-viewer/gif-decode-test.lua:18`, `:23`, `:176`
- `delta-version` issues 060, 062, 064 and its README, wherever they name the
  folders

## Intended Behavior

Both tools live in this project, as numbered source files in the one reading
order (`.file-index-counter`, claimed through the project's own tool, never
by hand), with their `.info.md` companions. The 34 scenes live under
`input/` or `assets/`, beside the 2D scores. The library folder
`/home/ritz/pictures/shape-gifs/` stays where it is: it is hers, and the
render command keeps writing to it.

Nothing about what is drawn changes in this step. **The proof is the six
approved fingerprints**: re-filming the six approved scenes after the move
gives byte-identical files, and every test that passed before passes after.

## Suggested Implementation Steps

1. Run both tools' tests in their old homes and record the counts (gallery
   186 checks, viewer 19) and the six fingerprints, as the bar to meet.
2. Move with `git mv`, in one commit, so the history follows each file and
   both the old and new paths are tracked (the house rule for moving
   directories).
3. Renumber into the reading order through the project's indexing tool, and
   write the companions.
4. Retarget every path above. Then grep the whole monorepo for
   `readme-gallery` and `gif-viewer` and fix every straggler, including
   issues and docs.
5. Re-run both test suites and re-film the six; compare against step 1.
6. Leave a short note in `delta-version/scripts/` saying where they went.

## Open Questions

1. Do the scenes go under `input/` (beside the 2D scores, as things a person
   writes) or `assets/` (as fixed material)?
