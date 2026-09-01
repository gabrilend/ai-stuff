# Not ours

`inspiration-maze.png` is a reference image. It is where this project came from
and it is the picture the renderer is trying to earn its way toward. It was not
made for this project and it is **not** licensed under the AGPL like everything
else here.

Treat it the way you would treat a photograph pinned above a desk: look at it,
measure things off it, argue with it. Do not ship it, do not put it in a
release, and do not assume that because it sits in this repository it carries
this repository's licence. It does not.

**Nothing in the program reads this directory.** That is deliberate. If a build
step ever needs a file from here, that is the moment to stop and work out
whether it is allowed to.

## What is measured off it

The picture is the source of these numbers, and they are recorded here rather
than in a document that would drift away from them:

| Read off the picture | Value | Where it went |
| --- | --- | --- |
| Corridor width | one cell | the whole grid follows from this |
| Wall height above its corridor | one layer | why a step of one is climbable and two is not |
| Staircase run | four to six cells | the generator's stair length range |
| Terraces stacked | roughly eight, base to summit | the default level count |
| Projection | a two-to-one isometric, viewed corner-on | `iso.lua`'s constants |
| Light | from the upper left; three face tones | the renderer's three-tone shading |

If any of those are re-measured and found wrong, change them here first and then
in the code, so that the picture and the program keep agreeing about what was
observed.
