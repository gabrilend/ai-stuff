# 075-the-sprite-baker

Bakes a lit sphere and its shadow into pixels, with no engine anywhere near it.

Read this page rather than the source, and read
[805b](../issues/completed/805b-a-ball-is-a-baked-sprite.md) before either.

## What it is for

There is no art in this project and there is not going to be any. A sphere lit
from a fixed direction is a closed-form calculation — for every pixel inside the
disc the surface normal follows from the offset alone, and the brightness follows
from the normal — so **the sprite is a function rather than a file**. That is the
difference between an asset somebody has to maintain and a number somebody can
change.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `ball(radius)` | pixels from centre to silhouette | width, height, and a string of RGBA bytes |
| `shadow(radius)` | | the same, for the mark under a body |
| `BAKE_RADIUS` | | how large the viewer bakes them |
| `LIGHT` | | the light direction, so a test can check the shading against it |

## Nothing here knows what a texture is

It produces bytes. The viewer hands them to the engine — four lines in
`042-the-renderer.lua` — and the test reads them directly.

That split is the whole reason there is a test for what a ball looks like. A
picture is the one kind of output nobody writes a test for, on the grounds that
you can just look at it; you can, and only at the moment you happen to look.
`tests/076-the-sprite-baker.lua` asserts the things that would be true of any
correct lit sphere and are the ones a change is likely to break: round, empty in
the corners, a soft edge rather than a stepped one, brighter on the side the
light is on, and symmetric about the light's own axis.

## The sprite is a shading mask, not a coloured ball

All three colour channels carry the same brightness and the alpha carries
coverage. The draw sets the creature's colour and the multiply does the rest, so
**one sprite serves every kind and every team** — a team colour changing is a
number rather than a sheet to rebake.

The consequence is that the ambient term has to be low. The only thing that can
carry roundness is the range between the darkest pixel and the brightest; raise
the ambient and every ball flattens into a disc of flat colour with a ring around
it, which is exactly what the vector circle it replaced looked like.

## Coverage is supersampled, and that is the point of baking at all

Each pixel's alpha is the fraction of it that falls inside the disc, measured over
a four-by-four grid inside the pixel. A ball is **six pixels across at scale one**,
and at six pixels a polygon approximation of a circle is a plus sign with corners.
It is paid for once instead of sixty times a second.

The edge pixels average their brightness over the samples that landed *on the
sphere*, not over all sixteen. Dividing by the full count darkens every edge pixel
toward black, which reads as a dirty outline rather than a soft edge.

## Three terms make the shading, and the third is the one that matters

A diffuse term from the angle between the normal and the light. A tight specular
highlight, raised to a high power so it is a spot rather than a smear. And a
**darkening near the silhouette**, where the surface has turned away from the
viewer — which is what says *sphere*. Diffuse alone makes a disc with a gradient
on it.

## The shadow is dense in the middle, not fading from the centre

A falloff beginning at the centre was tried and is nearly invisible: almost all of
a disc's area is in its outer half, so a shadow that fades from the middle outward
is faint everywhere and the ball goes back to looking as though it hovers. It is
at full strength across the inner two thirds and soft over the outer third.

It is baked round and squashed to the two-to-one ratio by the draw, because that
ratio belongs to the projection — a shadow baked oval would have to be rebaked the
day the projection changes.

Not a nicety either. There is no perspective in this projection to say how far
away the ground is, so a mark on the ground is the **only** cue that a thing is on
a surface rather than hanging above it.
