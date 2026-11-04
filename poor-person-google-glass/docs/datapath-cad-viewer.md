<!-- Made by Claude (Opus 5.5), 2026-10-10, for phase 0 (issues 001-006), as the datapath for the CAD viewer; updated whenever an issue changes it. -->
# Datapath: the CAD viewer

From a model file on disk to a lit, turnable picture. Reading and drawing
are kept apart: everything left of the shape record knows file formats and
nothing about windows; everything right of it knows windows and nothing
about file formats.

```
input/viewer-settings.lua → checked settings (window size, field of view, colours)

model file (path, string)
  → its ending picks a reader (dispatch table)
      .stl        text or binary, told apart by size      up axis z
      .obj (+.mtl) lines; parts by o/g and material      up axis y
      .gltf/.glb  JSON → nodes → meshes → accessors      up axis y
                  → buffers (base64 inside, or .bin beside)
  → shape record: parts, each { name, colour {r,g,b},
        positions: 9 numbers per triangle, normals: same length }
        + bounds, triangle count, degenerate count
  → stood upright (a z-up file is turned a quarter about x)
  → copied once into the graphics card, one mesh per part
  → every frame: orbit camera (target, yaw, pitch, distance)
        → view and projection matrices (turned upside down, because a
          canvas stores its rows the other way up from the screen)
        → drawn into an off-screen canvas in the current view:
          lit | edges | parts | depth | normals | annotated
        → the canvas shown in the window, the panel of figures over it

a model may carry, in its glTF's asset.extras (issue 008):
  stations  { name, eye {x,y,z}, look {x,y,z}, fov (degrees, optional) }
            → the model opens at the first; n steps through them, o goes
            back outside; the camera stands at the eye facing the look,
            through the station's own lens if it has one
  glow      a material with an emissive colour → its part is drawn as
            light (its own colour, brightened, little haze), lit looks only
  filling   { colour, density } → the lit look hazes toward the colour
            with distance (a liquid or haze filling the model)

--stations → at every station: the parts view drawn and its pixels counted
             per part (coverage), then the requested views saved;
             tmp/shared-memory/coverage-FILE.txt holds the table, and the
             receipt says how many stations show each part and which parts
             none does

joint records (issue 010, docs/joints.md), when the model has them:
  input/joints/MODEL.lua + output/joints/MODEL.results.lua (written by
  ./joints, only read here) → each joint's state: empty, waiting, pass,
  fail, gone → a coloured mark at the joint with its two parts' names
  (j shows them in any view; the joints view always does)

the model stands on an upright pillar (the camera's target), like an
artifact on a plinth:
  left-drag  → turn around the pillar (yaw only)
  right-drag → tilt the view (pitch only)
  wheel      → nearer or further
  the mouse resting near an edge → the pillar slides across the floor,
             level: sideways, away (top edge), nearer (bottom edge)

mouse, keys → the handlers → camera or display toggles
scripted run options (--drag, --tilt, --mouse, --key, --wheel,
--screenshot, --views)
  → the same handlers; real input is then ignored and counted
--screenshot → each requested view drawn into the canvas and saved from it
               (never read from the screen, which may be covered by
               another window) → tmp/shared-memory/screenshot-FILE-VIEW.png

--record turn|walk → frames numbered, each camera set by its number (a turn
             on the plinth, or a walk holding at each station then gliding
             to the next), drawn lit, halved, written raw to
             tmp/shared-memory/frames/NAME/ → src/031 (one worker per
             processor, joined in frame order) → a GIF (src/030: median-cut
             colours, LZW) → scripts/render-gallery gathers stills and GIFs
             of every model into output/gallery/ with an index page

on closing → output/goodbye: file, format, triangles, parts, frames,
             seconds, ignored input, and per picture: view, share of
             pure-black pixels (a picture not drawn reads back black),
             camera (size, yaw, pitch, distance, target)
after the window closes, view-cad → scripts/file-screenshot:
             each new picture into development-history/NNN-NAME.png with
             notes (what made it, what changed since the last picture);
             a picture the same as one already filed (identical bytes, or
             the last of its name with no pixel more than 2% different) is
             not filed again
```

Test models are never drawn by hand: `scripts/make-test-shapes` writes the
formula-made cube and crown sketch in every format into
`tmp/shared-memory/shapes/`. For current figures (bytes, read times, how far
corners move on a round trip) run `issues/completed/demos/phase-0-demo` or
just its table: `luajit issues/completed/demos/phase-0-compare.lua`.
