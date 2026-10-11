<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10,
     from the "glass and metal" description in notes/vision; reworked the
     same day for dials, 3D models, voxel effects and the far camera. The
     palette values live in code (the palette tokens issue); this file names
     the roles and the rules, not the numbers. -->

# Visual language: glass and metal

## No AI-generated artwork

Nothing on screen is AI-generated art. Everything is made by hand or by
formula: small 3D models, voxel effects computed from formulas, and the
dashboard's materials drawn by shaders.

## Dashboard materials

| Material | Used for | How it is drawn |
|---|---|---|
| **metal** | the dashboard body, bezels, the face dial windows are cut into | a base tone plus a brushed streak texture running *around* the circle (circular brushing, like a watch dial), and a soft highlight |
| **glass** | the seamless windows over dials | a tinted, slightly darker copy of what is beneath, shifted outward a few pixels toward the edge (refraction), a thin bright edge line, one curved highlight. Seamless: no visible frame between glass and metal, just the change of material |
| **paper-thin dial** | the disc under each window | a surface no thicker than paper, inscribed (not printed on top) with words or numbers; lit as if under glass, slightly darker than the face above it |
| **paint** | buttons only | flat, saturated, bright color with a pressed-in state; the only saturated color on the dashboard |

Metal and glass range from dark to bright: gunmetal, graphite, steel,
silver, polished chrome; smoked glass, grey glass, clear glass, frosted bright
glass. Lower, deeper parts are darker; upper, nearer parts are brighter. A
nested dial is darker than the dial it is seen through.

## Shapes

- Most elements are **circles** or **semi-circles**: the dashboard, its rings,
  buttons, dial windows (arc-shaped slots or round holes).
- Text on dials follows the arc it sits in.

## Motion

- **Lots of rotating displays.** The game turns the dials: they move with
  weight, coasting and settling at each inscription. Numbers roll like an
  odometer rather than jumping.
- The player never turns anything. Rotation is the game speaking.
- Nothing teleports. Everything that changes value rotates or slides there.

## The rule of buttons and dials

- Pressable means painted. A button is bright and colorful.
- A dial is never painted and never pressable. It is bare surface under
  glass, so it can never be mistaken for a button.

## The map: models and voxels

- **Units and buildings** are small, simple 3D models, low in polygons, with
  their owner's color on a few faces.
- **Effects** — auras, shield domes, couriers' sparks, magic — are clouds of
  very small voxels. Each voxel's position, size and color come from a
  formula (of time, of the effect's strength, of its seed), not from a
  hand-placed particle. Voxels not directly in view of an opponent are not
  drawn at all.
- **Seen from afar**, an effect keeps a minimum saturation and coverage so an
  aura still reads as a colored haze rather than vanishing into single
  pixels.
- **Merged stands** are drawn as a small dial (level and count) with a balance
  color and differential triangles.

## The far camera

The scene sits impossibly far from the camera, seen through a very long lens,
so the world looks almost flat and evenly scaled like a map while still being
a true 3D render (models keep their depth, light and shadow). Rendering
accurately at that distance means dealing with what distance does to
numbers: the scene is drawn relative to the camera's target rather than
the world origin, and depth is stored in a way that keeps precision across
the whole range (see the far-camera issue).

## Team colors

Each stand-in has one paint color (their buttons, couriers, the edge of their
quadrant, a few faces on their models). Foes have darker, desaturated
versions of their own colors so friend and foe never share a hue. Balance
colors (merged markers) use a separate scale from team colors, and are always
paired with differential triangles.

## Light by dials, depth by the hub camera (2026-10-10)

- **No light direction, no skybox.** Each material (metal, glaze, earth) has
  a light dial painted by formula: a round picture whose rim is a clock of
  the day — noon warm white at the top, dusk and dawn orange at the sides,
  night deep blue at the bottom — brighter toward the rim. A surface looks
  its light up through a window onto its dial, by which way it faces the
  viewer; the dial turns once a calendar day, so the hours pass over
  everything. Colours of one material are tints of its dial (issue 213).
- **Four views to compare** (issue 214): the far camera (nearly flat, like
  a map), the hub camera (just above the hub, looking out over one quadrant
  at a time — the valley of the reference pictures in assets/), and the
  slant view: the hub at the screen's bottom behind
  the console, the quadrant running up to the map's edge, far things the
  same size as near ones; the outer tiers stay pressed together, so near the
  top each step on screen covers more of the world, and when the chair turns
  the far ground sweeps past fastest. And the arch view, where the game
  starts: every tier ring a copy of the console's arch grown outward from
  it, a set span of angle foot to foot along each ring (450 degrees to
  start; past a full turn the same ground shows twice — "magic circles that
  had more than 360 degrees of rotation"); "a king in a castle walking
  along the battlements"; figures stand upright on their rings at one
  size. Under the hub camera far things fade
  into a haze that is also the sky.
- **The focus ring**: a tilt-shift blur, sharp at one distance from the hub
  and blurring nearer and farther — an arc on screen under the hub camera.
  It can be switched off; the owner noted many visible layers can carry the
  miniature look without it.
- Figures stand straight up on their ground ("neither leaning toward nor
  away"); leaning away from the hub is kept to compare.
- **The console's metal, seen across** (issue 302): brushed in streaks
  parallel to the arch, lit by the metal light dial like the world (warm at
  dusk, blue at night) over a faint panel lamp so it is always readable, a
  soft sky sheen toward its far edge, and one faint highlight that slides
  along the arch with the hour. No fixed glints.
- **The land as lit points** (issue 214): no ground texture — the land is
  a grid of points, each with a height, a facing and a colour, drawn as a
  flat circle facing the camera, shaded by direction round its centre —
  brightest on one side, darkest opposite, blended (the owner's drawing:
  assets/references/terrain-circle-sun-top-right.png).
  No light is worked out on a circle: it is only turned in the screen's
  plane — bright-pole-up where its slope faces the sun, dark-pole-up where
  it faces away — and so many overlap that each shows only its upper edge,
  painting the land; cliffs light and darken through the day. Circles are
  ordered by distance from the centre alone, nearest on top; wholly
  covered ones are never painted. Points are spaced evenly along
  every ring, so the land is denser in far rings. The painted map (rings,
  quadrants, sections) is a menu choice. The focus blur is off by default.
- **Sheen-points, two colours each, and water** (issue 214): every
  sheen-point records a sun-side and a shade-side colour, and its circle
  blends between them round its centre. A moving surface is moved only by
  turning its points: the lake's sheen-points live in the ceramic engine's
  shared memory and its workers turn them each step by passing waves and
  the sun, so ripples show as patches of shade-side colour drifting across.
