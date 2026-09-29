# readme-gallery

Films short, seamlessly looping GIFs of 3D shapes interacting by rule, in the
house look: a black ground and bright colour. Each film is one scene file of
plain data. The films make up the owner's personal library of animations, in
`/home/ritz/pictures/shape-gifs/`, and feed a gallery page on the neocities
site (neocities-modernization issue 10-042e). They were first meant for the
repository's README; the owner decided against that on 2026-09-26. The
tool's name is a leftover of that first purpose.

## Commands

    readme-gallery.lua [DIR] [scene ...] [--out=DIR] [--still] [--frames=N]
    render-all.sh [DIR] [--still]         every scene, four at a time (at most 4 processes)
    render-all.sh --library               every scene into the owner's library:
                                          /home/ritz/pictures/shape-gifs/, stills in stills/
    test-readme-gallery.sh [DIR]          the proofs (186 checks)

- `scene` is a name from `scenes/`, or a path to any `.lua` scene file. With
  no scene named, every scene is filmed.
- Films go to `/dev/shm/delta-version/readme-gallery-candidates/` by default.
  That folder is in RAM, not in the repository.
- `--still` also saves frame one of each film as a PNG.
- `--stills=DIR` saves those PNGs in their own folder, and implies
  `--still`.
- **The library.** Every film, approved or candidate, lives in
  `/home/ritz/pictures/shape-gifs/`, with a still of each in `stills/`.
  The owner keeps them all there and picks the front page's films from
  them. `render-all.sh --library` rebuilds the whole folder with the
  tool itself. The RAM candidates folder remains a scratch area.
  (The six approved films were once kept in the repository; now only
  their fingerprints are, in `tests/approved-films.lua`.)
- `--frames=N` shortens a film. The tests use it.
- `--jobs=N` splits a film's frames across N worker processes and
  gathers them in order. The result is byte-identical to one process,
  and a test checks this. A scene can ask for workers itself with
  `jobs = N`; the blob and liquid scenes do, since they are the slow
  ones. Workers are started with `--shard=k/N --shard-dir=`.
- A refusal prints one plain line and exits 1. Refusals include a
  fractional cycle count (which would leave a seam in the loop), an
  unknown shape, colour, motion or effect, and a morph on a shape that
  cannot morph.

## The parts

| File | Role | Knows about |
|------|------|-------------|
| `meshes.lua` | the shape cabinet | triangles only |
| `choreography.lua` | where each shape is at moment t, after reactions; where the camera is and what it looks at; the star field | scenes, not pixels |
| `raster.lua` | draws one moment through the view it is handed: depth buffer, lighting, glowing edges, 2x2 smoothing | shapes and a view, not scenes |
| `fluid.lua` | a liquid sloshing in an invisible tilting box, worked out ahead | drops, a box, gravity |
| `png.lua` | stills with uncompressed deflate blocks | bytes |
| `../../../gif-generator/src/004-gif.lua`, `002-palette.lua` | encoder and palette, borrowed unmodified | indices and colours |

### `meshes.build(name, params) → mesh`
`mesh = { verts = {{x,y,z}...}, faces = {{a,b,c}...}, superball = bool }`.
Faces are 1-based and wound outward, and this is checked when the mesh is
built.

| Shape | Parameters |
|-------|------------|
| `cube`, `tetrahedron`, `octahedron`, `icosahedron` | none |
| `torus` | `major`, `minor`, `rings`, `sides` |
| `star_prism` | `points`, `outer`, `inner`, `depth` |
| `superball` | `grid` |
| `cone` | `segments`, `radius`, `height` (point up) |
| `horn` | `ridges`, `twist`, `length`, `radius`, `rings` (along +x, twisted) |
| `terrain` | `size`, `grid`, `base`, `hills = {{x,z,height,radius}}`, `waves = {{amp,fx,fz,phase}}` (open ground sheet, world units) |

### `meshes.radius_toward(mesh, v) → r`
How far a solid with no dents reaches in unit direction v, scaled so its
farthest corner is at 1. Blending two solids' reaches morphs one into the
other (`morph_through`).

### `meshes.terrain_height(params, x, z) → y`
The ground's height at a point, from the same numbers the terrain mesh is
built from. This is how things rest on the ground that is drawn.

### `meshes.reshape(vertex, p) → x, y, z`
Pushes a sphere vertex onto the p-norm ball:
- p ≈ 1 gives an octahedron;
- p = 2 gives a sphere;
- a large p gives a cube.

This is how a superball morphs.

### `choreography.load(scene, hues, meshes) → scene`
Validates the scene and builds its meshes. `hues` maps each colour name to
`{r,g,b}`.

### `choreography.pose(scene, t) → items`
`t` runs from 0 up to, but not including, 1. Each item has these fields:

| Field | Type |
|-------|------|
| `mesh` | table (a mesh, above) |
| `position` | {x,y,z} |
| `rotation` | 3×3 rows |
| `scale` | number |
| `stretch` | {x,y,z} |
| `rgb` | {r,g,b}, 0 to 1 |
| `style` | "solid", "glow" or "wire" |
| `shatter` | number, 0 to 1 |
| `glow` | number, 0 to 1 |
| `morph_p` | number, or nil for a shape that doesn't morph |
| `shard_rgbs` | list of {r,g,b} |
| `shard_distance` | number |

### `choreography.camera(scene, t) → { eye, target, roll } | nil`
nil means a still camera, which the rasteriser draws with its original
arithmetic. The approved films depend on that path byte for byte.

### `choreography.strokes(scene, t) → { { points = {{x,y,z}...}, rgb, rgbs? }... }`
Wind strokes and the track's striped rails, as polylines for the painter.
`rgbs` gives each segment its own colour.

### `choreography.beams(scene, t, placed) → polylines`
Beams worked out afresh each frame between two tagged shapes in `placed`.
They are pinned exactly to both ends.

### `choreography.streaks(scene, t) → polylines (with `heading`)`
Speed streaks laid in the world around the eye, along the direction the
camera is moving at that instant. They are recomputed every frame, so they
pour from the heading's vanishing point and swing round at once when the
ride swerves. They need a moving camera.

### `choreography.track_frame(track, s) → centre, along, side, up, twist`
The track at s: the rails' directions there, and the corkscrew angle.

### `choreography.part_position(scene, tag, t) → {x,y,z}`
Where a tagged shape or carried part is at t. Anchors use it, and so do
the tests.

### `choreography.stars(scene, t) → { {x, y, rgb, brightness}... }`
Under a moving camera the sky slides against the camera's heading and
pitch. One full turn of heading slides it exactly one frame-width, so the
loop stays seamless.

### `raster.draw_blobs(canvas, items, lights)`
Soft round bodies (items with `blob`) are drawn by marching a ray per pixel
to the smooth-union surface of their group, testing only the blobs the ray
passes near. There are no outlines. Each light's slant on the surface is
cut into the blob's `bands` (`raster.band_level(slant, bands)`), so
brightness comes in stacked levels that sweep as the light moves. Blobs
use the same depth buffer as the solids.

### `fluid.simulate(spec, frames) → { frames = {[0..frames-1] = {{x,y,z}...}}, start, seam }`
The liquid, frame by frame, in the box's own frame. The loop is closed by
settling, choosing the best-matching start, and blending the first
`blend` frames; the file's head explains the method.

### `fluid.tilt_matrix(tilt, t)` — the box's turn at loop moment t.

### `choreography.lights(scene, t, placed) → { { position, rgb }... }`
Point lights riding tagged shapes or parts, such as a lamp on a turning
arm, or standing at fixed `at` positions.

### `raster.new(size, camera, meshes)` / `set_view(canvas, view)` / `clear` / `draw_stars` / `draw_item` / `draw_stroke` / `project_point(canvas, x, y, z) → fx, fy, depth` / `finish(canvas, index_of) → uint8 indices`
`set_view` builds forward, right and up directions from the eye and
target, keeping up near the world's up, then turns them by the roll. A
shape with any corner nearer the lens than 0.3 units is skipped whole,
because a fly-through passes right by things.

## Scene file

```lua
return {
    name = "shatter-bloom", size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 7.5, fov = 44, tilt = 0.3 },
    stars  = { count = 90, seed = 23, hues = { "gold", "rose", "ice" } },
    instances = {
        { tag = "bloom", mesh = "icosahedron", hue = "rose", scale = 1.35,
          spin = { axis = { 0.3, 1, 0.2 }, turns = 1 },
          reacts = { { to = "hammer", within = 2.6, effect = "shatter", amount = 1.1 } } },
        { tag = "hammer", mesh = "cube", hue = "gold", scale = 0.38,
          motion = { kind = "swing", from = { -3.6, 0.35, 0.6 }, to = { 3.6, -0.35, 0.6 }, cycles = 1 },
          spin = { axis = { 1, 1, 0.2 }, turns = 4 } },
    },
}
```

- **Motions:**
  - `fixed { at }`
  - `orbit { radius, cycles, phase, tilt, yaw, center, bob }`
  - `swing { from, to, cycles, phase }`
  - `lissajous { size, freq, shift, phase, center }`
  - `arc { radius, center, cycles, phase, from_angle, to_angle, depth }`: one
    way over an upright arch, shrinking to nothing at each foot so the
    jump back to the start is never seen
  - `conveyor { from, to, cycles, phase }`: straight from `from` to `to`,
    growing out of nothing at the start and shrinking away at the end
  - `keyframes { points = {{u,x,z[,y]}...}, sizes = {{u,s}...}, cycles, phase, lift }`:
    a route through named moments. A point without a y rests on the
    scene's `ground` (plus `lift`); sizes of 0 hide the jump back to the
    start
  - `wave { from, to, amplitude, waves, cycles, phase, up }`: along a line,
    rippling in a sine wave (a star riding the wind)
  - `bezier { points = {start, pull, pull, end}, cycles, phase }`: a curved
    flight worked out in advance, growing at its start and vanishing at its
    end
  - `spline { points = {{x,y,z}...}, cycles, phase, sizes }`: round a smooth
    closed curve through the points, with no stops at them
  - anchors: in `conveyor`/`wave` `from`/`to` or in `bezier`/`spline`
    `points`, a point may be `{ part = tag, plus = {x,y,z} }`. It is
    resolved to where that carried part is at the moment the shape sets
    off, so a spell leaves the wand's tip as the wand stood.
  - on any motion: `on_ground = true` (height is measured from the ground there), `lag` (follow the same path this fraction of a loop
    behind), `offset {x,y,z}`, and `sway { {vector, cycles, phase}, ... }`
    (waves added on top)
- **Per shape:** `spin { axis, turns, phase }`,
  `pulse { amount, cycles, phase }`, `morph { cycles, phase, cube, octa }`
  (superball only), `face_motion` (the shape points nose-first along its
  path), `stretch`, `style`.
  - `pulse` may take `axes {x,y,z}` to stretch only those axes.
  - `orient { axis, angle }` is a standing turn; `rock { axis, center,
    amount, cycles, phase }` swings back and forth about `center`.
    Turns compose as nose-first, then orient, then spin, then rock.
  - `pivot {x,y,z}` moves the shape off its middle before turning, so it
    hinges at one end (a petal).
  - `roll = { radius }`: rolling contact. The shape turns by the distance
    it has rolled this cycle divided by its radius. Needs a route motion.
  - `becomes = { at, over, mesh, hue, scale, ..., trail }`: at point `at` of
    its route the shape shrinks away and a new one grows in its place,
    riding on. Shorthand, unfolded on load into two shapes.
  - `trail = { count, spacing, shrink, mesh, hues, dim, full_speed }`:
    smaller copies following the same route a little behind in time. They
    fade when the leader rests, so a pause leaves no pile of sparks.
    Shorthand, unfolded on load.
  - `parts = { { mesh, hue, offset, scale, stretch, pivot, orient, spin,
    rock, pulse, dim, parts }... }`: shapes carried in this shape's frame,
    to any depth (an arm carries a wand, which carries a star). A part's
    size is measured against its carrier's. A shape with parts and no mesh
    is a hidden spine. Parts neither travel nor react.
  - `dim` (0 to 1) darkens a shape's colour: land barely lit.
  - `blob = { group, bands, soft }`, with a hue and no mesh: a soft round
    body of radius `scale`. It melts into the other blobs of its `group`
    where they come within `soft`, and is lit in `bands` whole levels
    (at least 2). No outline.
  - `shatter_keys = {{u, amount}...}`: a shatter timed at points of the
    route (needs a route motion).
  - `morph_through = { shapes, hues, cycles, hold, phase }` (superball
    only): becomes each solid in turn (cube, tetrahedron, octahedron,
    icosahedron), holding each true for `hold` of its share, with its
    colour following.
  - `burst { amount, cycles, phase, power }` shatters on a timer rather
    than a reaction; `shards = "own"` keeps the shards in the shape's
    colour instead of a rainbow.
- **Reactions:** `{ to = tag, within = distance, effect, amount }`. The
  effects are `swell`, `bleed_hue`, `shatter` and `glow`. Each is measured
  against the nearest shape carrying that tag, as it stood before any
  reactions were applied.
- **Colours:** `rose ember gold jade teal ice violet`, the gif generator's
  hue vocabulary. Every film declares all seven in the same order, so the
  palette is shared across the gallery. `cloud` is white: it needs no ramp,
  because the palette sends anything this unsaturated to its white ramp.

## Scene-level words

- `ground = { same numbers as a terrain }`: what `keyframes` and
  `on_ground` rest on. Put a `terrain` shape with the same numbers in the
  scene to see it.
- `strokes = { { from, to, amplitude, waves, drift, phase, hue, dim, up, segments }... }`:
  thin lines of light bent into a travelling sine wave that tapers at the
  ends. `drift` counts whole travels per loop.
- `framing = { tag, at_least, margin }`: a promise that in every frame at
  least that many shapes carrying the tag have their centre in the picture.
  `tests/framing-test.lua` checks it.
- `beams = { { from = tag, to = tag, amplitude, waves, writhe, strands, hues, dim, segments }... }`:
  lines of light always joining two moving things, bending and writhing.
- `track = { points, gauge, twist = { from, to, turns, radius }, rails = { hues, stripes,
  samples, thickness, dim }, ties = { count, hues, dim, width, thickness },
  along = { { tag, count, mesh, hues, scale, side, up, spin, style }... } }`:
  a closed smooth ride with a corkscrew. With `twist.radius`, the track
  swings out round an axis that far to its side, a wide helix, and
  rejoins itself. Its rails are striped strokes, its
  ties and trackside shapes are laid along it on load, and a `ride` camera
  rides it.
- `streaks = { count, seed, cycles, far, near, length, inner, outer, hue, dim }`:
  speed lines rushing past from the way the camera is heading.
- `clearance = { { tag, radius, column }... }`: a promise that the lens
  never comes within `radius` of those shapes. With `column = true`, the
  shape is treated as an upright post, such as a trunk, and the distance
  is measured level to its upright line.
- `spacing = { tags, at_least }`: a promise that no two of those shapes
  (from different families) come closer than that.
- `lights = { { tag or at, hue, strength }... }`: point lights for blobs.
  With `tag`, the light shines from that shape or part, so the lamp's
  motion is the light's motion.
- `fluid = { count, seed, radius, box, tilt = { axis, amount, cycles },
  gravity, stiffness, drag, substeps, time_scale, warmup, blend, hues,
  bands, soft, blob_size, center }`: a liquid in an invisible tilting box.
  It is posed as blob drops tagged `drop`, and the box itself is never
  drawn.
- Shared parts, such as the wizard, live in `scenes/parts/`. The runner does
  not list that folder. A scene loads a parts file relative to its own path.

## The camera

Without `motion`, the camera is still: `camera = { distance, fov, tilt }`.
With one, it moves:

```lua
camera = { fov = 46,
           motion = { kind = "orbit", radius = 3.7, height = 1.3, cycles = 1,
                      target = { 0, -0.4, 0 }, bob = { amount = 0.35, cycles = 2 } },
           roll = { amount = 0.07, cycles = 2 } }       -- or roll = { turns = 1 }
```

| Motion | Fields | What it does |
|--------|--------|--------------|
| `orbit` | `radius`, `height`, `cycles`, `phase`, `target`, `bob` | circles the target |
| `dolly` | `from`, `to`, `cycles`, `phase`, `target` | glides along a straight track and back |
| `crane` | `radius`, `low`, `high`, `cycles`, `turns`, `follow`, `target` | rises and sinks while circling; the target rises by `follow` |
| `spiral` | `near`, `far`, `low`, `high`, `cycles`, `turns`, `target` | circles while sweeping in low and out high |
| `lobed` | `radius`, `pinch`, `lobes`, `cycles`, `height`, `bob`, `center`, `target` or `"ahead"`, `lead` | a loop that pinches inward `lobes` times without crossing itself |
| `ride` | `cycles`, `height`, `lead` | rides the scene's `track`, rolling with its corkscrew |
| `fly` | `size`, `freq`, `shift`, `center`, `target` or `"ahead"`, `lead` | follows a knotted path; `"ahead"` looks along it, or with `lead` at where it will be that fraction of a loop later |

Every cycle, turn and frequency must be whole, and so must the roll's
cycles or turns. `"ahead"` is legal only when flying. Breaking either
rule is refused on load.

A house rule for camera scenes: the shapes move less (smaller swings,
fewer cycles), so the camera's motion is the one the eye follows.

## Tests

`test-readme-gallery.sh` films `tests/tiny.lua` into RAM. `tests/gif-facts.lua`,
a block-walker that shares no code with the encoder, confirms:
- the GIF89a signature, the size, the loop-forever block, the frame count
  and the trailer;
- that the still is a PNG;
- that `--frames=` works.

The test then refilms the scene and checks that the bytes are identical, and
checks that three broken scenes are refused and film nothing. `tests/tiny-new.lua`,
which carries every second-round word, gets the same treatment, including three
refusals of its own: half a rock, half an arch, and an unknown shard colour.

`tests/choreography-test.lua` asks the stage manager directly, with no pixels:
- for every scene, whether the moment one full loop in matches the first
  moment (the seamless-loop promise);
- whether each new word behaves as described (arc feet and crown, lag and
  offset, sway, rock, burst, own-colour shards, per-axis pulse);
- whether every face of the horn points outward.
- for every moving-camera scene, whether the eye, target and roll one
  loop in match the start; whether each camera motion, the conveyor and
  the roll behave as described; and whether four broken cameras are
  refused.

`test-readme-gallery.sh` also refuses two broken camera scenes. It then
films every approved scene again and requires each to match its recorded
fingerprint in `tests/approved-films.lua` byte for byte. It also checks
that a film split across workers matches one filmed alone, and that
`tests/tiny-fluid.lua` films to the same bytes twice.

`tests/tiny-third.lua` carries every fourth-round word and gets filmed,
read back and refused when its ground is removed. `tests/framing-test.lua`
walks every frame of every scene with a `framing` promise.
In the fifth round, `framing-test.lua` also checks `clearance` and `spacing`.
`choreography-test.lua` adds probes for each new word and checks the
owner's requests directly:
- rings and darts leave from the wand tip as it stood at every launch;
- beams are pinned to both ends in every frame;
- each twin-reef shoal has equal halves, and its bursts wait until the
  passers are more than a unit clear of the middle.

It also checks that seven more broken scenes are refused. The seventh
round adds probes for:
- blobs, and a light riding its turning arm;
- the band cutting;
- the blob surface: the depth at the middle pixel, and soft blobs
  melting into a bridge where hard ones leave a gap;
- the liquid: identical twice, inside the box, and with a join step no
  bigger than twice an ordinary one.

It also checks five more refusals.
`choreography-test.lua` probes each fourth-round word, and checks that seven
broken fourth-round scenes are refused:
- keyframe moments out of order;
- resting on a missing ground;
- rolling on a motion that is not a route;
- a part that travels on its own;
- a stroke drifting half a wave;
- a trail with no copies;
- a bezier with three points.
