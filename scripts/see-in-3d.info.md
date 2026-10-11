# see-in-3d — info

Turns a picture into an object seen from four sides (issue A08). A model (or
a person) looks at a screenshot, writes a short scene file saying what the
picture is in space, and renders it: front, right, top and angle on one
sheet. Wrong-looking views mean the reading of the picture was wrong.

| Step | Does |
|---|---|
| `see-in-3d shot --desktop [OUT.png]` | the X screen, by ImageMagick's `import` |
| `see-in-3d shot PAGE-OR-URL [OUT.png]` | a page, by headless Firefox with a throwaway profile in RAM |
| `see-in-3d brief SHOT.png` | where to write the scene, what to run next, and the whole paintbrush |
| `see-in-3d render SCENE.lua [--size=N] [--workers=N]` | the wall first (all problems, nearest words, nothing drawn on refusal); then `SCENE.png` (2×2 sheet), `SCENE-{front,right,top,angle}.png`, `SCENE.obj` beside the scene |
| `see-in-3d imagine SCENE.lua [--view=…] [--mode=depth\|render] [--server=URL] [--checkpoint=…] [--prompt=…]` | one view imagined as a picture by a Stable Diffusion server; asks the server what it holds first (issue A09) |
| `see-in-3d animate --from=P --to=P [--middle=P] --prompt="the mechanism" [--frames=8] [--delay=12] [--bounce]` | a looping GIF between pictures: in-between frames blended and lightly repainted by the image server, GIF written by gif-generator's encoder (issue A12) |
| `see-in-3d choose [PROJECT]` | a page of the project's kept pictures with beginning / middle / end buttons that writes the animate command to copy |
| `see-in-3d imagine-all EXAMPLES-DIR [imagine options]` | every gallery example imagined and kept in its folder |
| (every render, imagine, animate) | kept in the project's `mind/imagination-portraits/`, with a `see-in-3d: kept PATH \| CAPTION` line the conversation exporter turns into a picture in the transcript (issue A10); `--project=DIR` names the project, `--no-keep` only for regenerations |
| `see-in-3d gallery EXAMPLES-DIR [--out=DIR]` | every example folder (`scene.lua`, `note.txt`, `picture.png`) rendered at once and laid out as one page of drawing sheets, picture beside views; `stages.txt` gives words under each stage. Default out: `scripts/tmp/shared-memory/see-in-3d/gallery/`. Note format: `libs/see-in-3d-gallery.lua`'s header. |

Defaults: screenshots and briefs use `scripts/tmp/shared-memory/see-in-3d/`;
views 480 pixels square; one worker process per view. The same scene always
gives the same bytes.

The words a scene may use: `see-in-3d-paintbrush.md`. Libraries:
`libs/see-in-3d-paintbrush.lua`, `libs/see-in-3d-render.lua`,
`libs/png-writer.lua`, `libs/see-in-3d-gallery.lua`. Examples:
`see-in-3d-examples/`. Tests: `test-see-in-3d.sh`.
