---
name: gif-studio
description: >
  Make looping animated GIFs with the gif-generator studio: glowing 2D
  strokes of light in screen space, 3D shapes in world space, or both on one
  canvas. Use when asked to make, render, film or rate a gif, a shape film,
  a score or a scene; to view or count the films; or when the studio's wall
  refuses a score. Every example in this file is a score or scene the
  studio's tests render, so it cannot drift from the studio.
audience: any LLM agent working on gabrilend's machine, or in the ai-stuff repository
---

# The gif studio

One project makes every picture: `gif-generator`, at
`/mnt/mtwo/programming/ai-stuff/gif-generator` (below, the project). It
holds two painters and one canvas:

- **the 2D painter** paints strokes of glowing particles in screen space,
  in pixels, from a **score**;
- **the 3D painter** draws shapes in world space, in world units, from a
  **shape scene**;
- **a score may speak both**: shapes in a world, and strokes painted onto
  panes of glass in front of the camera, behind it, or standing in the
  world. Light adds: a painted pane brightens what is behind it.

Both are closed languages. A score or scene declares and never computes,
and a wall checks every word before anything is drawn. One encoder, one
palette and one reader serve both (`src/004-gif.lua`, `src/002-palette.lua`,
`src/040-gif-decode.lua`). Every film gets a card beside it, and a person
rates films on five tiers.

The contracts are the law; this file is the tour:

| What | Where |
|------|-------|
| every 2D word, and the second space | `docs/score-format.md` |
| every 3D word (printed from the wall's own lists) | `docs/shape-format.md` |
| the card beside every film | `docs/card-format.md` |
| the 2D wall | `src/024-compile.lua` |
| the 3D wall and its word lists | `src/049-shape-wall.lua`, `src/048-shape-words.lua` |

Read the contract for the words you use before writing. Never write a word
from memory of an older version.

## Screen space: a score of strokes

A score lives in `input/NAME.lua`: one `canvas{}`, then `stroke{}` calls in
playing order. Positions are pixels from the top-left, y downward. Times
are seconds in tenths. Clock faces name directions (12 is up).

```lua score
-- sweep: one ember stroke sweeps three quarters of a circle, and a
-- gold spark waits where it ends.
canvas{ size = 128, fps = 25, length = 2.0, seed = 7 }

stroke{ name = "sweep", at = 0.0, lasts = 1.6,
        color = "ember", fade = "in-out", ease = "smoothstep",
        shape = arc{ center = { 64, 64 }, radius = 40,
                     from = "12 o'clock", to = "9 o'clock",
                     turn = "clockwise" },
        emit = { rate = 400, speed = 18, aim = 0.6, drag = 2.5, life = 0.8 } }

stroke{ at = 1.0, lasts = 1.0, color = "gold", fade = "flash",
        shape = point{ at = tip("sweep") } }
```

The shapes are `arc`, `line`, `point` and `fill`. `tip("name")` borrows
where a named stroke ends. The seed fixes the particles: the same score
and seed make the same bytes on any machine.

## World space: a shape scene

A shape scene lives in `input/shapes/NAME.lua` and returns one table.
Positions are world units around the origin: x right, y up, z toward a
still camera. The loop is time: every cycle and turn is a whole number, so
the last frame leads into the first with no seam.

```lua scene
-- two-moons: a violet icosahedron circles a gold cube that turns in
-- place; the cube glows when the moon passes close.
return {
    name = "two-moons",
    size = 128, frames = 24, delay_cs = 4,
    camera = { distance = 7, fov = 44, tilt = 0.3 },
    instances = {
        { tag = "home", mesh = "cube", hue = "gold", scale = 0.6, style = "solid",
          motion = { kind = "fixed" }, spin = { axis = { 0, 1, 0 }, turns = 1 },
          reacts = { { to = "moon", within = 2.2, effect = "glow", amount = 0.8 } } },
        { tag = "moon", mesh = "icosahedron", hue = "violet", scale = 0.4, style = "glow",
          motion = { kind = "orbit", radius = 2.2, cycles = 1 } },
    },
}
```

A scene file is read in an empty sandbox: no `math`, no `dofile`. A scene
that has to compute (a ring placed with sines, a part reused) is a small
program in `input/shapes/generators/`, and `./make-shapes` writes the plain
scene from it. Edit the generator, never the scene it wrote.

## Both on one canvas

A score speaks the 3D words through four more calls: `camera{}` and
`world{}` at most once, `shape{}` for each shape (the words of one scene
`instances` entry), and `pane{}` for each pane of glass. A stroke names its
pane with `pane = "name"`; a stroke that names none is on `front`, the pane
over the whole frame. `tip("tag")` naming a shape is where that shape
appears in the picture each frame, so a stroke on a camera pane follows it.

```lua score
-- following: a violet shape circles a glass sign with a gold arc on
-- it, passing in front of the sign and behind it; a jade spark on the
-- front pane follows the shape wherever it appears.
canvas{ size = 128, fps = 25, length = 2.0, seed = 5, background = "sky" }

camera{ distance = 7.5, fov = 44, tilt = 0.25 }

world{ stars = { count = 40, seed = 3, hues = { "ice", "violet" } } }

shape{ tag = "wanderer", mesh = "icosahedron", hue = "violet", scale = 0.5,
       style = "glow", motion = { kind = "orbit", radius = 2.4, cycles = 1 } }

pane{ name = "sign", at = { 0, 0.2, -0.6 }, facing = { 0, 0, 1 },
      size = { 3, 3 }, pixels = 96 }

stroke{ pane = "sign", at = 0.0, lasts = 2.0, color = "gold", fade = "in-out",
        shape = arc{ center = { 48, 48 }, radius = 34,
                     from = 12, to = 11, turn = "clockwise" },
        emit = { rate = 400, speed = 8, aim = 0.4, drag = 2.5, life = 1.2 } }

stroke{ at = 0.0, lasts = 2.0, color = "jade", fade = "in-out",
        shape = point{ at = tip("wanderer") },
        emit = { rate = 250, speed = 14, drag = 3.0, life = 0.5 } }
```

A pane's `place` is `"front"` (over everything), `"back"` (behind every
shape) or `"world"` (the default: standing at `at`, looking along `facing`,
`size` wide and high in world units, `pixels` across). A shape in front of
a world pane hides its light; a shape behind it shows through. A world
pane and a fill's corners cannot follow a shape.

`canvas{ background = ... }` is `"black"` (the default), a hue's dark glow,
or `"sky"`, the world's stars. A score of shapes may count `frames` in
place of `length`, so a shape film said as a score keeps its loop.

## When the wall refuses

The wall reads the whole score or scene, collects every mistake, and
refuses it once, naming each mistake's place and the nearest legal word:

```lua refused
canvas{ size = 128, fps = 25, length = 2.0, seed = 3 }
shape{ tag = "moon", mesh = "icosahedron", hue = "violt",
       motion = { kind = "orbit", radius = 2, cycles = 1 } }
stroke{ at = 0.0, lasts = 1.55, color = "amber", fade = "in-out",
        shape = arc{ center = { 64, 64 }, radius = 40, from = 12, to = 6 } }
```

```text
the score fails its wall (4 errors):
  stroke #1: lasts must be positive seconds spoken in tenths — got 1.55
  stroke #1: no hue named 'amber' — nearest legal: ember
  stroke #1: an arc needs turn = "clockwise" or "counterclockwise" — nearest to 'nil': clockwise
  shape #1 (moon).hue: no hue 'violt' -- nearest legal: violet
```

What to do:

1. Read every line. Each is one mistake; fix them all before trying again.
2. Take the suggested word when it is what you meant. When it is not, look
   the word up in the contract.
3. Never work around the wall: no computing in a score, no editing the
   word lists to let a word through, no rendering through a side door. A
   word the language lacks is a request to her, filed as an issue.

## Rendering

```bash
cd /mnt/mtwo/programming/ai-stuff/gif-generator
./run NAME              # input/NAME.lua → output/NAME.gif
./run                   # every score in input/
luajit src/039-shape-films.lua . NAME --out=FOLDER   # one shape scene
./render-all-shapes     # every shape scene, four at a time, into RAM
./render-all-shapes --library   # every shape scene into her library
```

- A score lands in `output/NAME.gif`, with `output/NAME.report` (frames,
  bytes, palette seats lit, seconds per stage) and its card.
- A shape film lands in RAM (`/dev/shm/gif-generator/shape-film-candidates/`) as a candidate
  unless `--out=` says where. `--jobs=N` splits one film across up to four
  processes, byte-identical to one. Her library is
  `/home/ritz/pictures/shape-gifs`; only `--library` films into it.
- Never more than four processes at once (her limit).
- `luajit src/030-stats.lua . NAME WORKERS` measures a stroke score on
  that many worker threads. A score with a second space films on one.

## Looking

```bash
./view-gifs                 # her library
./view-gifs FOLDER          # any folder of gifs
```

Left and right step through the films, `g` shows them all as a grid, `esc`
or `q` quits. Making and looking share no code: the viewer reads gifs with
the studio's reader and nothing else.

## Rating, and the pool

Every film keeps a card beside it, `NAME.gif.card`: its fingerprint, what
made it, its seed, what moves in it, and its ratings, one line each,
appended and never edited. The last rating counts. Nothing is deleted:
not a film, not a card, not a low rating.

| Tier | Meaning |
|------|---------|
| 5 | reach for it first |
| 4 | use freely |
| 3 | fine among others |
| 2 | kept but not reached for |
| 1 | the record of what missed |

- **She rates in the viewer**: keys 1 to 5 append a rating to the film on
  screen.
- **The counts come from a tool**, never from a number typed into a
  document:

  ```bash
  ./count-films                  # her library, by kind and tier
  ./count-films FOLDER --write   # first, a card for every film without one
  ```

- A film made again with new bytes says so on its card; its old ratings
  stay as the record and stop counting until it is rated again.
- The six approved films are also held by their fingerprints in
  `tests/shape-films/approved-films.lua`. A film is approved only on her
  word; never change a fingerprint to make a test pass.

## Rules of the house

- Scripts take the project folder as their first argument; with none they
  use the hard-coded path above.
- Source files are numbered from `.file-index-counter`, and each has a
  sibling `.info.md` describing its usable surface.
- `docs/shape-format.md` is printed: edit `src/048-shape-words.lua`, then
  run `luajit src/051-shape-docs.lua .`.
- `./test-shape-films` checks the whole studio, and every example in this
  file (`src/057-skill-examples-test.lua`).

## Building a studio of your own

This studio is the worked example of `canvas-and-paintbrush`, the general
recipe for building a studio that makes something else (sound, vector
pictures, tiles): a closed vocabulary, a wall, an encoder you own, maker
and viewer apart, every artifact kept and rated. Load that skill to build a
different studio; load this one to make pictures with this studio.
