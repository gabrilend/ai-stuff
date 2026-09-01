# Phase 2 — The Eye

**All six issues complete.** The same maze can be looked at in a window, read in
a terminal, and measured with no window at all.

| Issue | |
| --- | --- |
| [201](completed/201-world-to-screen-and-back.md) | world to screen, and back |
| [202](completed/202-the-renderer-is-one-linear-sweep.md) | the renderer is one linear sweep |
| [203](completed/203-three-tones-and-a-mottle.md) | three tones and a mottle |
| [204](completed/204-pan-zoom-and-the-pointer.md) | pan, zoom, and the pointer |
| [205](completed/205-a-terminal-viewer-so-we-are-not-blind.md) | a terminal viewer so we are not blind |
| [206](completed/206-headless-and-the-report.md) | headless, and the report |

`./run-phase-demo 2` shows all three. `./run-maze --help` lists the flags.

## The journey, and what it taught

### The renderer was correct and the picture was wrong

The first working renderer drew every face, in the right place, in the right
order, in the right colour — and the maze read as **a field of separate cubes**
rather than as corridors between walls.

Nothing was wrong with the geometry. Every face was being outlined on all four
sides, including the side between two cells of one long wall whose tops are the
same continuous slab of stone. Those lines cut the wall into a row of blocks, and
the eye believed them.

A side is now inset only where it is a real edge: a top face's side only where
the neighbour's floor is not at exactly this layer, a wall face's vertical side
only where the neighbour's exposed run does not match.

**What it taught:** the second and third findings of phase one were also about a
picture no number could check. Screenshots are a test, and by this phase that was
no longer a surprise — the `--screenshot`, `--zoom` and `--at` flags exist so
that a frame can be compared against the same frame from before a change, which
is impossible if the camera is somewhere different.

### One sweep order was not enough

The projection has a property that was enjoyed rather early: the correct
back-to-front draw order is `for y ascending, for x ascending`, which is exactly
the column array's own memory order. It is why the index is `x + y * width`.

It stopped being sufficient the moment bodies existed. The stone is baked into
one static mesh, a mesh drawn in one call is drawn all at once, and a ball drawn
afterwards sits on top of every wall in the maze including the ones in front of
it.

So there are two orders now, both correct: memory order for the pure sweep, and
band by band — cells sharing one value of `x + y`, which cannot occlude each
other — for the mesh, with each band's index range recorded so bodies can be
drawn between them.

**What it taught:** a property that is elegant and true can still be the wrong
one to build on. The memory-order claim survives, and it is no longer
load-bearing, because there is no per-frame sweep at all any more.

### Baking the stone was not an optimisation

It was written that way from the start on the grounds that the stone does not
change. What that bought, which was not the reason, is that panning and zooming a
hundred thousand polygons costs two numbers — and the frame rate stays at a
hundred and forty with three hundred bodies moving.

The store's `version` counter exists, is never bumped, and is there so that the
first thing to change the stone in phase seven cannot forget that the mesh
depends on it.

## What is worth carrying into phase 3

- The headless runner is the point of this phase, not the window. Every finding
  in phase 3 that was *not* about a picture came out of a number it printed.
- `--screenshot` with `--zoom` and `--at` is how a rendering change gets
  compared against itself. Use it before and after, not after.
