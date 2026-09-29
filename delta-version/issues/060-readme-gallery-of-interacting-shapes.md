# Issue 060: A Library of Interacting Shapes (first meant for the front page)

**Status**: In progress (all 34 films kept in the owner's library; README section dropped by the owner; four open questions below)
**Priority**: Low
**Created**: 2026-09-23
**Type**: New tool (`scripts/readme-gallery/`)
**Related**: neocities-modernization issue 10-042e (a gallery page of these
films on the neocities site); `058-front-page-rewrites-its-own-figures.md`
(the front page these were first meant for); `gif-generator` (whose GIF
encoder and glow palette this reuses, as libraries, unmodified)

---

## Current Behavior

**Built (2026-09-23 to 2026-09-26).** The tool is in `scripts/readme-gallery/`.
All of the steps below are in place, and `test-readme-gallery.sh` passes
186 of 186 checks.

**Where the films are now (2026-09-26).** The owner: "I changed my mind,
let's not put any in the Readme." Every film -- 34 of them, with a still of
each -- lives in `/home/ritz/pictures/shape-gifs/`, filmed there by
`render-all.sh --library`. They will also appear on a neocities gallery page
(neocities-modernization 10-042e). The README section is dropped. The six
approved copies that sat, never committed, in
`delta-version/assets/readme-gallery/` were removed; their SHA-256
fingerprints stay in `tests/approved-films.lua`, and the test re-films each
and compares.

**The first six were approved** ("wow all of them can you make more?").
They were first filmed into the repository with `--out=`; the library
copies are byte-identical to them.

| Approved scene | What it shows |
|----------------|---------------|
| orbit-kiss | Five solids circle a golden star and borrow each other's colours when they pass |
| shatter-bloom | A swinging cube bursts an icosahedron into rainbow shards, which reassemble |
| breathing-solid | A cube breathes through a sphere into an octahedron while moons swell and take its tint |
| star-ring-torus | A torus threads a ring of spinning stars, each flaring as it passes |
| reef-school | A shoal of fish swims nose-first past coral, taking the coral's colour |
| rainbow-stack | A rainbow column of cubes sways apart and presses together, smearing colours at each touch |

**Seven second-round candidates** await the owner's explicit pick in
`/dev/shm/delta-version/readme-gallery-candidates/`. They draw on the
owner's imagery: stars, rainbows, unicorns, sea creatures, flowers,
outfits and fruit.

| Candidate | What it shows |
|-----------|---------------|
| jellyfish-drift | Two jellyfish (a breathing dome, a hem ring, rippling crystal tentacles) drift through gold stars that flare as they pass |
| flower-open | Eight hinged petals open and fold shut twice a loop around a swelling gold heart, with three bees circling |
| fruit-burst | Five fruits on a carousel, each with a leaf, fall open in turn into facets of their own colour and close whole |
| rainbow-arch | Seven bands of tumbling cubes rise out of one white cloud, cross the arch and sink into the other |
| shell-spiral | A logarithmic whorl of tetrahedra turns with a swelling wave, and a pearl tints each chamber it passes |
| unicorn-horn | A twisted gold horn flies nose-first through a violet ring, trailing a rainbow tail of cubes, and stars swell as it passes |
| twirling-dress | A rose skirt flares and gathers as it spins under a bodice and a floating hat, with ribbons of gems circling the hem |

Each film renders in about a second in its own process. They range from
0.3 to 1.2 MB; fruit-burst and rainbow-arch are the largest, because their
many small moving pieces compress poorly.

**The second round added vocabulary without adding code to any scene:**
- the `arc` motion, with a size envelope that hides the jump back to the
  start;
- `lag`, `offset` and `sway` on any motion, which make tails, tentacles
  and shared paths possible;
- `orient`, and `rock` with a resting `center`;
- `pivot`, which lets a petal hinge at one end;
- `pulse` on chosen axes;
- `burst`, a shatter on a timer, and `shards = "own"`;
- the `cone` and `horn` meshes;
- the white `cloud` colour, which uses the palette's existing white ramp.

Refactoring for this left all six approved films byte-identical.

**Third round: a moving camera.** The owner loved the seven ("yay yay again!
again! more gifs please") and asked for more with a moving camera. A camera
may now carry a `motion` (orbit, dolly, crane, spiral, or fly with
`target = "ahead"`), a look-at `target`, and a `roll`, either rocking or
whole turns. All of it is scene data, bound by the same whole-cycle rule.

The stage manager works out the path, and the painter only receives each
frame's view: eye, target and roll. A camera without `motion` keeps the
painter's original still-camera arithmetic, untouched. The six approved
films and the seven second-round candidates all re-film byte-identical,
and the test suite now checks the approved six on every run. Under a
moving camera the sky slides with the heading, and a shape the lens passes
through is skipped whole.

A house rule for these scenes: the shapes move less (smaller swings, fewer
cycles), so the camera's motion is the one the eye follows.

| Camera candidate | Camera | What it shows |
|------------------|--------|---------------|
| coral-garden-orbit | orbit | Circles a coral garden of swaying spires, a turning brain coral, a starfish and an anemone, with fish idling round |
| rainbow-tunnel | dolly + roll | Drifts down a tunnel of rainbow rings streaming toward the lens while the horizon turns once |
| shell-staircase | crane | Rises up a spiral staircase of shells around a slender spire toward a gold star, then sinks |
| fruit-bowl-spiral | spiral | Sweeps in low and pulls up high round a bowl of gently bobbing fruit and grapes |
| jellyfish-flythrough | fly, looking ahead | Flies a figure of eight past ten breathing jellyfish and scattered stars |
| dress-mannequin-orbit | orbit + roll | Walks round the twirling outfit, now almost still |
| butterfly-weave | fly | Weaves round five flapping butterflies over a meadow of three flowers |

A new motion was needed for the tunnel: `conveyor`, which runs straight
along and back unseen, growing and shrinking at its ends. One fix came up
as well. The camera scenes were first composed too close, where
staircases and fly-throughs read as scatter, and they were pulled back
after checking them by eye.

**Fourth round: surfaces, characters, wind and spells.** The owner's
response was "I love this engine so much". They asked for one fix and four
new scenes.

**The fix.** The owner found jellyfish-flythrough "too fast, the models are
often out of frame". Changes:
- The camera now flies a gentle ellipse once in 12 seconds, down from a
  figure of eight twice as fast.
- It looks at a point further along its own path (fly `lead`), which turns
  the lens into the bend.
- Sixteen jellyfish line the path just to either side.
- The scene promises at least two bells in view in every frame. The new
  framing check confirms it: the worst frame has 2, the average is 3.4.

**The new scenes:**

| Candidate | What it shows |
|-----------|---------------|
| hill-to-the-stars | Balls roll up a hill, turning exactly as far as they roll; at the top each becomes a star and rockets up trailing sparks, then reappears at the foot |
| windmills-in-the-dark | Windmills on barely-lit land; wind as pale travelling sine-wave strokes; stars ride among them at two-thirds the strokes' frequency |
| wizard-rings | A wizard built from primitives casts rings from a star-tipped wand; the rings widen and narrow as they fly to a crystal, which flares |
| wizard-missiles | The same wizard sends purple darts on precomputed curved paths that converge on a target, each with a wake of sparks |

**The vocabulary this round added**, all as scene data:
- a `terrain` mesh and a scene `ground`, shared by drawing and resting,
  through `meshes.terrain_height`;
- `keyframes` routes that rest on the ground, and `on_ground`;
- rolling contact, `roll`;
- `becomes`, which turns one shape into another mid-route;
- `trail`, which fades when its leader rests;
- `parts`, which carry shapes in a parent's frame to any depth, so a
  character is assembled from primitives, with shared parts in
  `scenes/parts/`;
- the `wave` and `bezier` motions;
- wind `strokes`, drawn as polylines;
- `dim`;
- a scene `framing` promise, with its own check.

The drawing side learned to draw strokes and to project a single point.
Open sheets, meaning the ground, are cut face by face at the lens instead
of being dropped whole.

All six approved films and all earlier candidates re-film byte-identical,
except the jellyfish fly-through, which was changed on purpose.

Two bugs were found by eye and fixed:
- A part's size compounds with its carrier's, so windmill sails hung
  from the small hub came out a tenth of their size. They now hang from
  the windmill itself.
- A trail copy's mesh parameters used `a and nil or b`, which in Lua always
  yields `b`.

**Fifth round: fixes asked for in the owner's words, and four new scenes.**

| Change | What was asked, and what was done |
|--------|-----------------------------------|
| jellyfish-flythrough | "ensure we don't pass through any jellyfish, and they should be evenly distributed around the viewer ... an almost 8 shape ... bend toward the middle, then bend toward the out, then curve around". The camera flies the new `lobed` loop, which pinches in twice and never crosses itself. Sixteen jellyfish alternate inside and outside the loop, above and below the lens. `clearance` is checked: the closest pass leaves 0.48 to spare. Framing: at least 2 in view, average 3.9. |
| wizard-rings, wizard-missiles | "the circles and the magic missiles should be emanated from the tip of the wand. Right now they are emanating from a fixed location." Rings and darts now start from `{ part = "wand-star" }`, resolved to the tip at each launch moment. A test checks every launch. |
| hill-to-the-stars | "make the gap between each ball ... slightly greater". There are four balls, a quarter of a loop apart, and a shorter pause at the summit. A `spacing` check confirms the closest two ever come is 1.13, against a required 0.82. |
| dress-mannequin-orbit | "has one arm... It should have two arms." Two arms, one at each shoulder, hang from a spine that turns with the bodice. |
| butterfly-weave | "should be zoomed out a bit." The fly loop is wider and higher. |
| wizard-beam (new) | Three strands writhe between the wand's star and a drifting crystal. They are recomputed every frame and pinned to both ends, which a test checks. |
| twin-reef (new) | Two shoals dive together. Half of each passes through the other and curves home; the other half bursts at the middle once the passers are clear, reforms and returns. Each fish follows a precomputed closed `spline`, with `shatter_keys` for the bursts. Equal halves and the burst timing are tested. |
| candy-coaster (new) | The camera rides a closed `track` with candy-striped rails, gold ties and a one-turn corkscrew. Trackside stars rush past, and `streaks` stream from the vanishing point. |
| breathing-moons (new) | A copy of breathing-solid, with the approved original untouched. The centre becomes each moon's solid in turn with `morph_through`, holding each true shape before flowing into the next. |

The drawing side learned four things: morphing vertices through solids,
per-segment stripe colours, camera-space streaks, and skipping segments
flung far off-frame. Every approved film and every earlier candidate
re-films byte-identical.

Small fixes along the way:
- A scene whose shapes come only from its track is no longer refused as
  empty.
- Shapes unfolded from one written shape now share a `family`, so
  `spacing` does not count a ball and the star it becomes as a crowd.

**Sixth round: the library, four fixes, and a wood to fly through.**

**The library.** The owner said: "I want all of them. But idk which ones I
want to be in the readme yet. Let's keep them all at
/home/ritz/pictures/shape-gifs/". `render-all.sh --library` films every
scene into that folder with the tool itself, putting stills in `stills/`
through the new `--stills=` option. The folder holds 29 films (23 MB) and
29 stills (8.7 MB). The six approved films there match the repository's
byte for byte.

| Change | What was asked, and what was done |
|--------|-----------------------------------|
| candy-coaster | "the corkscrew is much too tight ... increase the lateral movement such that the radius of the screw shape increases" and "make the gray streaks come from the orientation of motion". The corkscrew now swings the track round an axis 1.6 to its side (`twist.radius`) over a longer stretch. Streaks are laid along the camera's current heading, recomputed every frame, so they pour from wherever the ride is going. |
| dress-mannequin-orbit | "I meant the part that's orbiting now, it should calm down like the other side and those should be the arms. I like what you've built now though." My reading: the built arms stay, and the orbiting gem ribbons stop orbiting. They become beading along the two sleeves, carried by the arms, so they move only as calmly as the arms sway. The owner may mean something else; it is recorded here to be corrected. |
| hill-to-the-stars | "double the increase you just made". The gap went from 1.2 s to 1.5 s last round; doubling that increase gives 1.8 s. Each ball's trip keeps its speed, and the loop grows to 7.2 s, so the extra time falls between balls. Spacing at its closest is now 1.84. |
| wizard-rings, wizard-missiles | "should move their wands slowly, like the wizard-beam, and the origin of their respective spells should be the tip of the wand at the position it's at when the particular effect is first created." Each now makes two gestures a loop, as wizard-beam does. The launch-from-tip test still checks every launch. |
| canopy-flythrough (new) | The camera swoops on a pinched loop among 20 trees, with trunks down to hill-to-the-stars ground and crowns at varied heights. Stars bob up and down, turning about the upright axis; the tool's up is y, where the owner's is z. Clearance is checked against crowns, leaves, trunks (as upright columns) and stars, with 0.56 to spare at the closest. At least 2 crowns are in view in every frame, 4.0 on average. |

**Seventh round: soft blobs, point lights, a liquid, and a new home.**

The owner asked for "some that have rounded shapes without wireframes but
with brightness levels on a 'per blob' fashion generated according to the
rotation of a point light machinery", and "one with a simple fluid
simulation inside of an invisible container? No need for a wireframe on
it, just use it for the physics of it."

- **Blobs** (`blob = { group, bands, soft }`) are drawn by ray marching to
  the smooth-union surface of their group, with no outlines. Each light's
  slant is cut into whole `bands`, so brightness comes in stacked levels.
- **Point lights** (`scene.lights`) ride tagged parts, such as a lamp on a
  turning arm, so the light machinery's rotation is the light's motion.
- **The liquid** (`fluid.lua`, `scene.fluid`) is 180 drops pushing and
  dragging on each other in an invisible box that rocks. It is worked out
  ahead and posed as blobs.
- **Frame-level workers** (`--jobs=N`, or a scene's `jobs`) split a heavy
  film across processes, byte-identical to one process.

| Scene | What it shows |
|-------|---------------|
| blob-lava-lamp | Seven wax blobs rise, sink, merge and part in an invisible column; a lamp on a turning arm sweeps their bands round |
| blob-necklace | Twelve rainbow beads round a lamp spinning at the ring's heart; neighbours drift together and melt |
| blob-jellyfish | A jellyfish of blobs: a breathing melted bell and four rippling tentacles, each melting only along itself |
| blob-berries-two-lights | A bunch of berries under a rose lamp and an ice lamp circling opposite ways; the two sets of bands sweep past each other |
| fluid-slosh | A liquid sloshes in a rocking box nobody sees, heaping against one wall then the other, lit in bands by a circling lamp |

Found along the way:
- A tentacle melting into the bell read as one lump, and was slow to
  draw. Each tentacle now melts only along itself.
- Coloured lamps multiply the colour they fall on, so dark violet
  berries went nearly black. The berries are now warm colours.
- The darkest band was raised to 0.3 so the dark sides still read on
  black.

**A second test file checks the seamless-loop promise directly.**
`tests/choreography-test.lua` poses every scene at the first moment and
one full loop later, and requires them to agree. It also checks that each
new word does what it says.

Lessons that shaped the design:
- **The key light sits in camera space.** A light fixed high in the world
  went dark whenever the camera looked down. The ambient level is set high
  because the palette's ramps lean dark, and a half-lit gold face read as
  olive.
- **The superball is a subdivided cube pushed onto a sphere.** A
  latitude/longitude sphere pinched at its poles and made the cube end of
  the morph lumpy.
- **Glowing edges are decided each frame.** A superball's creases vanish
  as its faces flatten into a cube.
- **A stack of rings reads as a soft-serve cone, not a jellyfish.** The
  bell became a flattened, breathing dome with a single hem ring.
- **Shards need faces large enough to read as slices.** A finely
  subdivided fruit burst into a net and made a 1.3 MB file. A coarser
  grid gives segments.

Nothing is in the README yet. Placing the approved films on the front
page belongs to the README work, not to this tool.

**Before this issue** — the root README had no pictures. It says nothing about how the house
interfaces look, even though they share one look: a black ground with
saturated, bright marks — yellow stars, rainbows, sea blues and corals,
flower pinks, fruit colours.

The gif generator makes animations, but its outputs belong to that
project: particle simulations described in prose. There is no way to
produce animations of solid shapes, and nothing that shows geometry
moving and reacting to other geometry.

## Intended Behavior

A small tool renders short, seamlessly looping GIFs of 3D shapes that
interact with each other by rule, for the owner's personal library of
animations (`/home/ritz/pictures/shape-gifs/`) and a gallery page on the
neocities site (neocities-modernization 10-042e). The repository's README
was the first destination; by the owner's choice (2026-09-26) it no longer
is. Each animation is one scene file of plain data, so a new animation is a
new file, not new code.

    readme-gallery.lua [DIR] [scene ...] [--out=DIR] [--still]

- **Scenes** are Lua files that return a table. They list:
  - the camera;
  - the instances: a mesh, a hue, a motion, a spin, and the size and
    shape changes each one goes through;
  - the reactions: what an instance does when another comes near. It
    might swell, borrow the other's colour, or shatter into rainbow
    shards and then reassemble.
- **Every motion is periodic over the loop.** Orbits, spins and breaths
  complete a whole number of cycles, so the last frame leads into the
  first with no seam. This is enforced at load time: a fractional cycle
  count is refused.
- **Generation is kept apart from viewing.** The choreographer turns a
  scene and a moment in time into a list of placed, coloured triangles
  and knows nothing about pixels. The rasteriser turns that list into
  palette indices and knows nothing about scenes. The encoder turns
  indices into GIF bytes.
- **The same scene always gives the same bytes.** Nothing random goes
  unseeded.
- **Films live in the owner's library**, `/home/ritz/pictures/shape-gifs/`,
  filmed there by the tool (`render-all.sh --library`), never into the
  repository. A RAM folder (`/dev/shm/delta-version/readme-gallery-candidates/`)
  is the scratch area for looking at work in progress.
- **At most four processes at once** (the owner, 2026-09-26: "use up to 4
  threads"): render-all films four scenes at a time, one process each, and
  a single film splits across at most four workers.
- **Optionally, one still of each scene is saved as a PNG**, so the
  candidates can be looked at without an animation viewer.

## Suggested Implementation Steps

1. **Meshes** (`meshes.lua`): a dispatch table of generators — cube,
   tetrahedron, octahedron, icosahedron, torus, star prism, and a
   "superball" sphere that can be pushed toward a cube or an
   octahedron. Every triangle is wound so its normal points outward,
   and this is checked when the mesh is built.
2. **Choreography** (`choreography.lua`): motion, spin and scale
   vocabularies as dispatch tables, plus a reaction layer. For each
   instance and each reaction, a closeness value between 0 and 1 is
   measured to the nearest instance carrying the named tag, and an
   effect from the effect table is applied at that strength. Scenes
   are validated on load, and unknown words are refused along with the
   list of legal ones.
3. **Rasteriser** (`raster.lua`):
   - perspective projection;
   - a depth buffer;
   - flat Lambert shading;
   - glowing edges for the wire style;
   - a seeded, twinkling star field.
   Each face is coloured once through the gif generator's palette
   indexer, not once per pixel.
4. **Encoder**: reuse `gif-generator/src/004-gif.lua` and
   `002-palette.lua` through `dofile`. No second encoder is written.
5. **PNG still** (`png.lua`): stored (uncompressed) deflate blocks with
   CRC and Adler checksums, enough for a viewer to open. No
   compression library is needed.
6. **Runner** (`readme-gallery.lua`): renders the named scenes, or all
   of them. The companion shell script `render-all.sh` renders every
   scene in its own process, all at once, so rendering uses every
   core.
7. **Scenes**: five or six candidates, each showing a different kind of
   interaction.
8. **Test** (`test-readme-gallery.sh`) checks that:
   - a tiny scene renders into a valid GIF: the signature, the loop
     extension, the frame count read back from the file, and the
     trailer;
   - two renders of the same scene are byte-identical;
   - a scene with a fractional cycle count, an unknown mesh or an
     unknown hue is refused.
9. **Companion `.info.md`** for the tool.

## Answered questions

- **Were the first six candidates approved?** Yes, all six (2026-09-23):
  "wow all of them can you make more?". The seven second-round
  candidates are that "more".
- **Can the camera move?** Yes. The owner asked for it in the third
  round, on the condition that the shapes move less to compensate.
- **Is breathing-moons' slight saw-tooth on its sharpest edges acceptable?**
  Yes. The owner said "it's acceptable to me" (sixth round).
- **Where do all the films live?** In `/home/ritz/pictures/shape-gifs/`,
  all of them, stills in `stills/`. Which ones go in the README is
  still to be decided (sixth round).
- **Should the fly-through keep its subjects in frame?** Yes, the owner
  said it was "too fast, the models are often out of frame". It now makes
  a checked `framing` promise.
- **Do any films go in the README?** No. The owner: "I changed my mind,
  let's not put any in the Readme." (2026-09-26.) They live in the library
  and go to a neocities gallery page.
- **How many processes may the tool use?** Up to four (the owner,
  2026-09-26: "use up to 4 threads").
- **Where did approved gifs first live?** In `delta-version/assets/readme-gallery/`,
  beside the tool's own project, not at the repository root. The tool
  writes them there with `--out=`, so the tool remains the thing that
  makes them.

## Open questions

- **The liquid's loop: how is a simulation made to loop?** A simulation
  never repeats itself exactly, so fluid-slosh closes its loop in three
  moves:
  1. The box rocks exactly periodically, and the liquid is run for three
     loops so the sloshing settles into nearly repeating.
  2. Of the next loop's frames, the one that best matches itself one loop
     later becomes the film's first frame. In fluid-slosh the match is
     0.32 per drop, about ten ordinary frame-steps.
  3. Over the film's first 10 frames, each drop glides from where it will
     be one loop on toward where it actually is.

  The join step then equals an ordinary step (0.034 against 0.032), so
  nothing jumps. The trade is that for those 10 frames (0.4 s) the drops'
  paths are blended rather than simulated, which a close eye might see as
  the liquid briefly moving a little too smoothly. Alternatives: a longer
  blend (smoother, less true); several loops long with a better match
  (bigger file); or a liquid pinned to the box's motion (exact, but no
  longer free). Is the blend the right trade?

- **Did the gem beading on the sleeves match what was meant by the dress's
  "arms"?** The owner's note was "I meant the part that's orbiting now, it
  should calm down like the other side and those should be the arms". My
  reading was that the orbiting gems should stop and become the arms'
  beading, keeping the arms already built. If the gems were meant to be
  arms on their own, as two calm arcs of gems in place of the built
  sleeves, that is a small change to the scene.

- **Magic missiles: exact loops or true momentum?** Each dart flies a
  curve worked out in advance (`bezier`), not one steered frame by frame
  toward the target with momentum. The reason is that a steered flight
  depends on every frame before it, so the last frame of the film never
  exactly meets the first, and the loop would show a seam. A precomputed
  curve is identical at the loop's end and start by construction, and
  respawning at the wand is hidden by the dart growing out of nothing.
  The cost is that the swing is designed rather than simulated. Is that
  the right trade? One alternative: simulate the steering for one loop,
  then blend the last stretch of each path into its start.

- Should the rendered size and loop length be fixed across the gallery,
  so the section reads as one set, or chosen per scene?
- Frame-level parallelism, meaning several worker threads inside one
  scene, would need the gif generator's worker-thread pipeline. Is
  rendering each scene in its own process enough, given that the
  gallery is always rendered as a batch?
