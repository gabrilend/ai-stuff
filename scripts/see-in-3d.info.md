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
| `see-in-3d gallery EXAMPLES-DIR [--out=DIR]` | every example folder (`scene.lua`, `note.txt`, `picture.png`) rendered at once and laid out as one page of drawing sheets, picture beside views; `stages.txt` gives words under each stage. Default out: `scripts/tmp/shared-memory/see-in-3d/gallery/`. Note format: `libs/see-in-3d-gallery.lua`'s header. |

Defaults: screenshots and briefs use `scripts/tmp/shared-memory/see-in-3d/`;
views 480 pixels square; one worker process per view. The same scene always
gives the same bytes.

The words a scene may use: `see-in-3d-paintbrush.md`. Libraries:
`libs/see-in-3d-paintbrush.lua`, `libs/see-in-3d-render.lua`,
`libs/png-writer.lua`, `libs/see-in-3d-gallery.lua`. Examples:
`see-in-3d-examples/`. Tests: `test-see-in-3d.sh`.
