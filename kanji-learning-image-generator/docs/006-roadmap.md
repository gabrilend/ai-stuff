# 006 — Roadmap

Three phases. They are not a schedule and they are not progress tracking — they
are three clusters of functionality that can be built and tested without each
other's help, arranged so that each one only needs the ones below it.

The issue numbers inside a phase are ordered the same way: the lower ones are
foundations and the higher ones stand on them. Reading a phase's issues from
first to last should explain how that third of the machine was built. Reading
them in the order they happened to be worked on would explain nothing.

## Phase 1 — The Ink

*Bytes into geometry into pixels. Nothing in this phase knows what a kanji means.*

Everything here is about turning two large XML files into a shape that can be
drawn, and having somewhere to draw it. It is the least surprising third of the
project and the one everything else stands on. It ends with a machine that can
put any character's strokes onto a surface and write that surface to disk, having
no opinion at all about what the character is for.

| | |
|---|---|
| `101` | The two archives — fetching them, decompressing them, and recording what was taken |
| `102` | Reading a shape out of XML — a scanner, the two readers, and the record they join into |
| `103` | The line the brush took — the SVG path language, and curves flattened into runs |
| `104` | A surface that holds grey — the raster canvas, its brush, its blur |
| `105` | A picture on the disk — a PNG encoder, which means a deflate encoder |
| `106` | Numbers a machine will read — ordered JSON |

## Phase 2 — The Meaning

*A record into a scene. Nothing in this phase knows what ComfyUI is.*

This is where the project stops being a drawing program. It decides what world a
character belongs to, which of its pieces are subjects and which are only sounds,
what object lies along each individual stroke, and it produces both the grayscale
field that carries the illusion and the sentence that describes the scene.

It is the third most likely to be wrong, and the most interesting to be wrong in.

| | |
|---|---|
| `201` | What a stroke is shaped like — measuring direction, length, curve, hook and place |
| `202` | The field the illusion rides on — strokes into a luminance map |
| `203` | What the pieces mean — the component lexicon, mostly derived rather than written |
| `204` | The place the meaning makes — biome, subjects, and a role for every stroke |
| `205` | The words the machine reads — a scene, written out as a prompt |
| `206` | Arrows that teach the order — the stroke-order layer |

## Phase 3 — The Machine

*A scene into a file somebody can run. Then all of them, then a way to look.*

| | |
|---|---|
| `301` | The shape of a ComfyUI graph — nodes, links, and the catalogue that knows their sockets |
| `302` | The workflow for one kanji — the actual pipeline, in both formats |
| `303` | The whole alphabet at once — every character, in parallel, selectable |
| `304` | A gallery you can page through — the set, at the size the illusion works at |
| `305` | The documentation as a website — all of this, cross-linked |
| `306` | The demos, and the thing that runs them |

`303` is the point of the project. Everything before it makes one recipe;
that one makes all of them, and makes them without a human choosing which.

## What is not in any phase

**Generating the images.** There is no diffusion model here and there will not
be one. `docs/001` says why, `docs/005` says what is emitted instead.

**Judging whether the illusion worked.** A person squints at a thumbnail. That
is the specification and it does not become an assertion by being written down
harder. `304` exists to make the squinting cheap, and `docs/007` holds the open
question about whether any of it can be measured.
