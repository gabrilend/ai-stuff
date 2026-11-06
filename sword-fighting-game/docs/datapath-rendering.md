# Datapath: from records to pixels

How the view turns the battle's records into a picture. The view reads the
simulation and never writes to it.

```
022 shapes (vertex rows, pure data)  ──► 023 engine meshes, once at start
                                          + one shader: clay | brick | flat

per battle:  region + scenery stream ──► 025 scenery part list (once)
per frame:
   soldier records ──► 024 figure part lists (pose from u, swing, guard,
                       stamina, health, tripped, alive)
   darts ──► part list along each dart's arc
   tick events ──► view's own spark list (hits, parries), aged per frame
   camera:
     first person (026): eye = soldier, 0.32 m behind the shoulders,
                         90° across, eyes on the lock's chest
     third person (027): above and behind the contingent, slid and zoomed
   ──► sky gradient (2D) ──► 3D pass with depth: scenery, figures, marks
   ──► first person: depth cleared, own arms and sword drawn on top
   ──► 2D: edge glows (awareness, fatigue, wounds) or the command table
```

## A part

| Field | Type | Meaning |
| --- | --- | --- |
| shape | string | "blob", "box", "brick" or "cylinder" |
| model | 16 numbers | row-major matrix placing the unit shape in the world |
| sx, sy, sz | numbers | the shape's own scale, so normals are turned correctly |
| color | {r, g, b[, a]} | 0..1 |
| look | string | "clay", "brick" or "flat" |

World axes: x east, y up, z south, metres; a cell is 1.2 m. A figure's own
frame is x forward, y up, z right.
