# 603 — Compositor render loop

## Current behavior

Surfaces exist and they know when they're dirty (601, 602) but
nothing yet copies their pixels into the screen framebuffers
that the display controllers scan out from.

## Intended behavior

A `compositor-tick` box fires once per display refresh — the
same 60Hz cadence the input poller uses (501) but driven off a
separate timer so the input poll and the composite pass can run
on different workers concurrently.

Each tick, the compositor:

1. For each of the two screens, walk the surface list (601)
   from back to front in z-order.
2. For each surface whose owning app is the foreground on that
   screen (604) AND whose damage bit is set (602), copy the
   pixel buffer into the screen's framebuffer at the surface's
   position. The copy respects the surface's width and height,
   bounded by the screen's edges.
3. Clear each composited surface's damage bit.
4. For each drawer overlay (606) currently open on that screen,
   composite the drawer on top of whatever the foreground put
   down. Drawers do not respect z-order with foreground
   surfaces; they sit unconditionally above.

The composite copy is straight memcpy of rows from the surface
buffer into the framebuffer's pixel offset. No alpha blending,
no scaling, no filtering — surfaces produce pixels in the
screen's native format and position. Phase 9 may revisit if
the modeller (phase 10) wants alpha blending for translucent
selection highlights.

The compositor runs on a single worker per tick — the per-frame
work is small and the contention overhead of splitting it
across workers exceeds the gain. Multiple workers run other
boxes concurrently with the compositor; only the compositor
itself is serialised per frame.

## Suggested implementation steps

1. `compositor_tick_box()` — the per-frame body.
2. `composite_surface_to_framebuffer()` — the per-surface copy.
3. The `compositor-tick` box in a statically embedded map that
   runs alongside `input-poll` from 501.

## Open questions

- *What shows where a surface was released or moved?* Nothing is copied
  there any more, so the old pixels would stay on the screen.
- *Is a surface copied only when its own bit is set?* Two surfaces of one
  owner may overlap (601). Copying only the one behind would cover the
  one in front.
- *How is "single worker per tick" kept?* A timer that fires while a
  frame is still running would start a second frame on another core.
- *How does the timer reach the map?* `program_argument_every` (501) is
  in an unmerged pull request (#214).
- *Where does the drawer step (4) and the foreground filter (604) go?*
- *Does anything start the compositor at boot?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn. The first was chosen by Claude
when asked, and is open for Ritz like the rest.

1. *A background colour, owned by the system:* `COMPOSITOR_BACKGROUND`
   (the palette's paper colour), a constant so it can become wallpaper
   later. A release, a move and a resize each record the rectangle the
   surface left (`surface_expose`); the next frame paints the background
   there first. Each screen keeps one rectangle around everything
   uncovered since the last frame, never a list that can fill: painting a
   little more than was uncovered is never wrong.
2. *No.* Back to front, a surface is copied when it is marked, or when
   anything painted or copied before it this frame overlaps it. So the
   one in front of a copied surface is copied again and still shows in
   front, and whatever was under a surface that left is copied back over
   the background.
3. *A loop, as the input frame's:* the frame number rides a wire back to
   the one `composite` station, so a frame needs the tick and the last
   frame's number, and only one number exists.
4. *An engine timer aimed straight at the station behind the argument
   door* (its port 0), so this does not depend on #214. It can switch to
   `program_argument_every` once that is merged.
5. *In those issues.* This one leaves the foreground filter and the
   drawers out; 604 and 606 add them to `compositor_screen`.
6. *Not yet*, as with the input frame (501): `compositor_start` is linked
   into the kernel, and the device's framebuffers (111a–111d) are still
   open.

A whole frame's decisions come from one look at the surface table
(`surface_gather`, under 601's lock): every surface's place, pixels and
damage bit (taken, as 602 says), and the uncovered rectangle. Anything
that changes during the copy is there for the next frame. The pixels
read are safe because the compositor runs inside a box's run, and a
released buffer is retired, not freed, until every run that might hold
it has ended.

## What happened

Built on the twin as answered above:

- `src/system/107-compositor.c` and `.h`: `compositor_screen`,
  `compositor_frame`, `compositor_start`, `compositor_stop`, and the
  background constant.
- `src/boxes/108-compositor.c`: the `composite` box.
- `src/maps/compositor.map`: the box, its loop and its door.
- `src/system/104-surfaces.c` and `.h`: `surface_expose` and
  `surface_gather`, and the rectangle a release, move or resize leaves.

`twin/tests/109-test-compositor.c` (24 checks):

- A new surface is copied exactly where it stands, and nothing else
  changes.
- A frame with nothing marked copies and presents nothing.
- An unmarked write shows nothing until it is marked.
- Marking the surface behind copies the one in front again.
- A move, a shrink and a release paint the background where the surface
  was and copy back what was under it.
- A surface in the corner lands exactly there.
- With the map on its own timer: frames come at 60 Hz, one at a time.
  A thread drawing and marking 3 000 times ends with its last drawing
  on the screen, and the next frame waits on the loop after a stop.

Without the overlap rule, two of those checks fail. A full-screen copy
takes about 0.1 ms per frame on the laptop.

## Related documents

- `docs/005-display-and-compositor.md`.

## Blocked by

601, 602.

## Blocks

604, 606, every later phase 6 issue.
