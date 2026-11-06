# 008 — Standing inside a model

**Phase:** 0 — Tools
**Blocked by:** 004, 005
**Blocks:** 105
**Related documents:** docs/datapath-cad-viewer.md

## Current Behavior
Built. glTF carries stations and filling in asset.extras (written by
`src/005-gltf.lua`, read and checked there); the camera can stand at a point
facing another (`stand_at` in `src/009-the-orbit-camera.lua`); the viewer
steps through stations with `n`, returns outside with `o`, hazes the lit
look by the filling, and with `--stations` photographs every station and
measures coverage (`src/010-the-viewer.lua`); the receipt lists each part's
stations and the unseen count (`src/008-say-goodbye.lua`).

Found while building: the coverage first called two plainly visible parts
unseen, because the graphics card stores a colour a shade off from the
arithmetic (159 for 160). Colours are now matched within two shades. And
the picture filing tool (`scripts/file-screenshot`) now treats a picture
that differs from the last of its name by under 2% of a shade in any pixel
as already kept, since the card draws a pixel or two differently from run
to run.

## Intended Behavior
A model can carry **stations**: named places to stand inside it, each
{ name (string), eye {x,y,z}, look {x,y,z} (numbers, the point looked at) },
and a **filling**: { colour {r,g,b}, density (number, how quickly the view
thickens with distance) } for a model whose space is full of a liquid or
haze. Both travel inside the glTF file (asset.extras), so the model brings
its own viewpoints. In the viewer, `n` steps to the next station and `o`
back to circling from outside; `--stations` makes a screenshot take one
picture per station (per requested view).

Each station run also measures **coverage**: the parts view (every part
one flat, distinct colour) is drawn at every station and its pixels counted
per part, so the receipt says which parts each station shows, how much of
the picture each takes, and which parts no station shows at all. "Each
relevant feature is featured at least once across the whole set" becomes a
number a test can check, rather than something checked by eye.

## Suggested Implementation Steps
1. glTF: write and read asset.extras.stations and asset.extras.filling.
2. Camera: stand at an eye, look at a point (sets yaw, pitch, distance from
   the two points, so the orbit camera can carry on from there).
3. Viewer: stations on `n`/`o` and `--stations`; filling as distance haze in
   every view but parts; coverage from the parts view's pixels.
4. Tests: a station's camera sees its look point at the picture's centre;
   coverage of the crown sketch from outside names every part.
