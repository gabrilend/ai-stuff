# 089-build-the-image — info

Recipe plus board description in; a flashable image out, along with the manifest saying what went into it and a number anyone can reproduce from the same inputs. Issue 502.

This is what turns a description of a seed and a description of a computer into the actual bytes you put on a card. It never emits only the image -- always the image, what it is made of, and its identity, because an image on its own is a pile of bytes nobody can account for.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `089-build-the-image.lua` and run the sweep again.*

## Invocation

```
luajit 089-build-the-image.lua --recipe FILE --board NAME [--model FILE]
[--to FILE] [--dir ROOT]
```

## What it offers

| | What it is |
|---|---|
| `M.build(options)` | Returns { image, manifest, identity, layout } or nil and why. |
| `M.check_the_seam(built, expectations)` | The seam between this and the engine, checked by the build rather than discovered at first light. |
| `M.write(built, to)` | Three files, never only the image. |

### In more detail

**`M.build(options)`**

options: recipe, board, model_bytes, sizes (a memory budget module),
         shapes, format, blob_report_geometry

Returns { image, manifest, identity, layout } or nil and why.

**`M.check_the_seam(built, expectations)`**

The seam between this and the engine, checked by the build rather than
discovered at first light.

`expectations` is what the engine believes about where things are -- taken
from the engine's own layout description rather than written again here,
because two copies of an agreement are two things that can drift.

## The seam this exists to keep closed

The builder decides where things go and the engine decides where to look (102). If they disagree the machine fails at the earliest possible moment with the least possible information. So the agreement is checked BY THE BUILD: the offsets this lays down are read back out of the built image and compared against what the engine's own layout description says, before anything is written anywhere.

## The model is a parameter

Which model an image carries is the operator's choice at build time, not a decision baked into this project (101). This is also where a model too large for the board is refused, with the three numbers said out loud rather than left for first light to discover.

## Reproducible in the plain sense

same inputs, same output bytes. No timestamps and no build paths leak in, which is the usual reason this fails.

## Where it sits

**Belongs to** `502`.

**Checked by** `090-test-the-image`.

