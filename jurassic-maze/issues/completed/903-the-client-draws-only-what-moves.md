# 903 — The Client Draws Only What Moves

| | |
| --- | --- |
| Phase | 9 — The Client |
| Blocked by | 901, 902 |
| Blocks | — |
| Reads | `src/075-the-sprite-baker.info.md`, `src/067-sightlines.info.md` |
| Open questions | two, at the bottom |

## Current behavior

The viewer is the whole program. It builds a maze, validates it, bakes meshes,
runs seven locomotion rows, follows a director, draws a panel, and has an opinion
about dinosaurs. To watch a ball roll down a hill it does all of that first.

## Intended behavior

A second front end that knows about **a picture, a geometry, and spheres**, and
nothing else at all.

It loads a scene. It builds the collision model from the scene's height field. It
runs the bouncing row. Every frame it draws the picture, then a sprite for each
body at the pixel the scene's five numbers say it belongs at.

**No stone is drawn, ever.** Not a polygon of it. The mountain in the picture was
drawn once, by something else, possibly by somebody's hand, and the client has no
opinion about what it looks like.

### Occlusion without a depth buffer

A body behind a rock has to not be drawn, and the client has a photograph rather
than a scene graph — so it cannot sort anything behind anything.

It does not need to. The geometry says exactly what is visible: cast the ray from
the body toward the camera and ask whether any column stands over it. That is the
same march the sightline survey uses, one ray per body per frame, and it is
**exact** rather than an approximation of a depth test. A body the geometry says
is hidden is not drawn.

This is also why a scene that descends toward the camera is worth having: on one
that never rises, no ray is ever blocked and the check costs nothing but confirms
it.

## Suggested implementation steps

1. Draw the picture and nothing else first, and pan around it. If the picture is
   in the wrong place, everything after this is measuring against a lie.
2. Then one body, at the spawn point, with the simulation stopped. It should sit
   on the ground in the picture. That single frame is the whole of the interface
   being right or wrong.
3. Then the crowd, and only then the occlusion check, so that a body vanishing is
   known to be the check rather than the projection.
4. Keep the client's key handling to what a client needs — pan, zoom, pause,
   step. Every knob the viewer has is a knob this does not have to grow.

## Related documents and tools

- [901](901-a-scene-is-a-picture-and-a-datafile.md) — what it loads
- [902](902-the-exporter-draws-the-world-once.md) — what makes one
- `src/073-bouncing.info.md` — the only locomotion row it runs

## Open questions

**One. Where do the creature numbers come from?** The scene carries geometry, not
gravity. A radius, a restitution and a rest time are properties of a ball rather
than of a mountain, so today they come from the creature table, which means the
client needs one file the scene does not describe. Whether that is right, or
whether a scene should carry the population it expects, is open question one of
[901](901-a-scene-is-a-picture-and-a-datafile.md) from the other side.

**Two. What happens when the picture and the geometry disagree?** Nothing checks
it and nothing can: a photograph has no opinion. A ball rolling visibly through a
painted wall is the symptom, and the only defence is that both files were written
by the same run — which stops being true the moment somebody supplies their own
picture, which is the whole point of the format. Not answered.
