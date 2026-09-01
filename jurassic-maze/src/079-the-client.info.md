# 079-the-client

A picture, a geometry, and spheres. It draws no stone at all.

Read this page rather than the source, and read
[903](../issues/completed/903-the-client-draws-only-what-moves.md) before either.

## What it is for

Not one polygon of the world. The mountain in the picture was drawn once by
something else — possibly by somebody's hand — and this has no opinion about what
it looks like. What it has is a height field to collide against and five numbers
that say where a world position lands in the image.

The viewer beside it builds a maze, validates it, bakes two meshes, runs seven
locomotion rows, follows a director and has an opinion about dinosaurs. To watch
a ball roll down a hill it does all of that first. This does none of it.

Run it with `./run-client`.

## Exports

The engine's callbacks — `load`, `update`, `draw`, `keypressed`, `wheelmoved`,
`mousepressed`, `mousereleased`, `mousemoved`, `resize` — reached through
[080-the-front-desk](080-the-front-desk.lua), which picks it when the arguments
carry `--play`.

## Occlusion without a depth buffer

A body behind a rock has to not be drawn, and there is nothing to sort it behind:
the world is a photograph.

It does not need sorting. The geometry says exactly what is visible — cast the
ray from the body toward the camera and ask whether any column stands over it.
One ray per body per frame, the same march the sightline survey uses, and it is
**exact** rather than an approximation of a depth test. A body the geometry says
is hidden is not drawn, and `h` shows them in red instead, which is how you tell
a hidden body from a missing one.

This is also why a world that descends toward the camera is worth having: on one
that never rises, no ray is ever blocked.

## Three things it does not assume

**The picture is read with plain Lua io** and handed to the engine as bytes. The
engine's own loader resolves a name inside its sandbox, rooted at the game
directory, so it cannot open a scene sitting anywhere else — and a scene that has
to live inside the program is not a scene somebody else can hand you.

**The line of sight comes from the scene's projection**, not from this project's.
A client that assumed its own constants would be right only for pictures this
project drew, which is the opposite of the point.

**The step is fixed** at a sixtieth, with the leftover carried between frames.
The speed cap that stops a sphere passing through a face is a distance per tick,
so a step that grows when the machine is busy is a step in which balls leave the
world.

## What it still needs that a scene does not carry

A radius, a gravity and a restitution are properties of a ball rather than of a
mountain, so they come from the creature table — one file the scene does not
describe. Whether that is right is open question one of
[903](../issues/completed/903-the-client-draws-only-what-moves.md).
