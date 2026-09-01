# 080-the-front-desk

Decides which of the three front ends is being asked for, so that main.lua does
not have to.

Read this page rather than the source.

## What it is for

The engine insists on a file called `main.lua` at the root of the game directory,
and that file is a doorway rather than a room: the moment it starts choosing
between things, the project has a piece of program sitting outside its own reading
order. So the choosing happens here, where it is numbered and read in sequence
like everything else.

## The three, and what each is

| | |
| --- | --- |
| **the viewer** | builds a world and draws it — the generator, the validator, two baked meshes, seven locomotion rows, a director and a panel |
| **the client** | loads a scene, a picture and a datafile, and draws only the things that move |
| **the tracing table** | shows a picture somebody else made and lets a person draw the world onto it |

## The rule is the argument

`--play` names a scene file and belongs to the client. `--trace` or `--plan`
names a picture or a plan and belongs to the tracing table. Anything else is the
viewer.

Not `--scene`, which the viewer has meant "which creatures are in it" since phase
four. Two flags of one name in one program is a collision that shows up as the
wrong front end starting, with a parse error from a file that was never the file
being asked for — which is exactly what it did the first time this was written.

## The forwarders ask whether a callback exists

A front end that does not want one says so by not having it, rather than by being
asked whether it does. The client has no use for a resize and the tracing table
has no update worth the name.
