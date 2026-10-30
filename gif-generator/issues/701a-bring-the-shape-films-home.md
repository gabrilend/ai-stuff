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
7. Bring their issues too: `delta-version` issues 060 (the shape films) and
   062 (the viewer) move here with `git mv`, renamed into this project's
   numbering as completed or open phase 7 work as their state says, and every
   reference to them is updated. Issue 064 does not come: it went to
   `double-diaper-dungeon` as 10-007 (see 701, question 2).

## Open Questions

1. Do the scenes go under `input/` (beside the 2D scores, as things a person
   writes) or `assets/` (as fixed material)? — **Taken as `input/shapes/`**
   (2026-10-30), since a person writes them, as the scores are. The runner's
   `input/` listing reads only `.lua` files at the top, so the folder does
   not disturb it. Easy to move if she would rather have `assets/`.

## What Happened (2026-10-30)

Built on the branch `claude/701a-shape-films-home`, in one commit, every
file moved with `git mv`:

- `src/034-meshes.lua`, `035-choreography.lua`, `036-raster.lua`,
  `037-fluid.lua`, `038-png.lua`, `039-shape-films.lua` (the tool, once
  `readme-gallery.lua`); `040-gif-decode.lua` and `041-gif-decode-test.lua`
  (the viewer's reader); `042-choreography-test.lua` and
  `043-framing-test.lua`. Each has its `.info.md`; the counter reads 44.
- `input/shapes/` holds the 34 scenes and `parts/`; `tests/shape-films/`
  the test scenes, the six fingerprints and the independent walker.
- `viewer/` keeps `main.lua`, `conf.lua` and `decode-worker.lua` under
  those names, because LÖVE starts a folder by its `main.lua` and its
  threads by file name; this is the one place the numbered order could not
  reach. The decoder they load is `src/040`.
- `render-all-shapes`, `test-shape-films`, `view-gifs` and
  `test-gif-viewer` sit at the project root beside `run`.
- Issues 060 and 062 came across as 702 and 703, both still open as their
  state said. Every reference in the monorepo outside the transcripts now
  names the new homes; `delta-version/scripts/readme-gallery-and-gif-viewer-moved.md`
  says where they went.

The bar, measured in a fresh clone before and after:

| Check | Before (old homes) | After |
| --- | --- | --- |
| shape films (`test-shape-films`) | 186 passed, 0 failed | 186 passed, 0 failed, the same lines |
| the six approved films | byte-identical to their fingerprints | byte-identical to their fingerprints |
| every scene films (`render-all-shapes`, 2 frames each) | — | all 34 |
| viewer reader, her library folder | 14 passed, 1 failed (no library on that machine) | the same |
| viewer reader, the six approved films as the folder | — | 19 passed, 0 failed |
| viewer window | no display on that machine | the same |

**Still to see on her machine:** `./test-gif-viewer` with her library and a
display (the window check and the library check), and `./view-gifs` opening
as before. Until then this issue stays open.

