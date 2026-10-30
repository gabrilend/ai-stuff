# 035-choreography — the stage manager

Where every shape of a shape-film scene is at moment t, after its reactions;
where the camera is and what it looks at; the stars, strokes, beams, streaks
and lights. Knows scenes, not pixels. Refuses a broken scene on load.

## Usable surface

- **load(scene, hues, meshes, fluid) → scene** — checks and prepares a scene.
- **pose(scene, t) → items** — every placed shape at moment t.
- **camera(scene, t) → { eye, target, roll } | nil**
- **strokes / beams / streaks / stars / lights (scene, t, ...)** — the
  other things drawn at moment t.
- **track_frame(track, s)**, **part_position(scene, tag, t)** — helpers
  the tests and scenes lean on.

Every word of the scene vocabulary, and each function's fields, is written
out in `039-shape-films.info.md` ("The parts", "Scene file", "Scene-level
words", "The camera").
