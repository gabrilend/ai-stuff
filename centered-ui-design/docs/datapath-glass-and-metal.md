<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10;
     reworked the same day for the dial component, 3D models and voxel
     effects. Updated by phase 2 issues. -->

# Datapath: dashboard parts, models and voxels to pixels

## Data

| Structure | Fields |
|---|---|
| palette token | `name` (string, e.g. `metal-3`, `glass-1`, `paint-seat-2`), `r`, `g`, `b`, `a` (numbers 0–1) |
| dial | `window_shape` (arc slot or round hole), `center_x`, `center_y`, `radius` (numbers, pixels), `window_start_angle`, `window_end_angle` (numbers, radians), `inscriptions` (list of strings around the disc), `angle` (number, radians, current), `target_angle` (number, radians, where the game wants it), `angular_velocity` (number), `nested` (another dial seen through this one's surface, or the word `none`) |
| button | `shape` (circle, half-circle, arc segment), position and radii (numbers), `paint` (token name), `verb` (string, the order kind), `state` (resting, hovered, pressed, de-selected) |
| model | `mesh` (vertex list: positions, normals, colors as numbers), `place` (on the sphere), `facing` (number, radians), `owner_color` (token name) |
| voxel effect | `formula` (name of a function of time, strength, seed → voxel positions, sizes, colors), `strength` (number), `seed` (integer), `place`, `visible_to_opponent` (boolean, from the simulation's sight check) |

## Steps

```
 snapshot ─▶ map layer:
     models ─▶ placed through the sphere projection ─▶ 3D scene, camera
               impossibly far away (long lens), drawn relative to its target
     voxel effects (only those visible to an opponent) ─▶ formula ─▶ instanced
               tiny cubes ─▶ minimum saturation and coverage when far
     merged stands ─▶ small dial + balance color + triangles
 ─▶ dashboard layer, back to front:
     nested dials (deepest first) ─▶ dials ─▶ metal face with window cut-outs
     ─▶ glass over each window (refraction of what is beneath) ─▶ painted buttons
```

Dial motion is physical: each dial turns toward its target angle with
friction and settles at an inscription. The player never sets a target;
only the snapshot does.

This is pure viewing code: it reads snapshot numbers and never changes the
world.
