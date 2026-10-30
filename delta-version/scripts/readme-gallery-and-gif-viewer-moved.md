# readme-gallery and gif-viewer have moved

Both tools that lived here now live in `gif-generator`, brought there with
their history by its issue 701a (2026-10-30), so the 2D scores and the 3D
shape films share one studio.

| Was here | Now |
| --- | --- |
| `readme-gallery/readme-gallery.lua` | `gif-generator/src/039-shape-films.lua` |
| `readme-gallery/{meshes,choreography,raster,fluid,png}.lua` | `gif-generator/src/034` to `038` |
| `readme-gallery/scenes/` | `gif-generator/input/shapes/` |
| `readme-gallery/tests/` | `gif-generator/tests/shape-films/`, and `src/042`, `src/043` |
| `readme-gallery/render-all.sh`, `test-readme-gallery.sh` | `gif-generator/render-all-shapes`, `test-shape-films` |
| `gif-viewer/` (the LÖVE window) | `gif-generator/viewer/` |
| `gif-viewer/gif-decode.lua`, `gif-decode-test.lua` | `gif-generator/src/040`, `041` |
| `gif-viewer/view-gifs`, `test-gif-viewer.sh` | `gif-generator/view-gifs`, `test-gif-viewer` |

Their issues went too: delta-version 060 is gif-generator 702, and 062 is
703. Issue 064 stays here, marked as moved to `double-diaper-dungeon`.
