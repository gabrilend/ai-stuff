# Phase 7 Progress — Watching It Happen

**The goal:** the real viewer. Everything so far has been readable through a
terminal and a report; this is where it becomes a thing you look at and touch.
Plus the documentation as browsable HTML — the same generator-and-view separation
applied to the project's own prose.

**Ends with:** a human playing a full match against the phase-8 bot with a mouse.

| Issue | | Status |
| --- | --- | --- |
| 701 | The window and the two snapshots | built |
| 702 | The map draws itself | built |
| 703 | The chest panel and the drag | built |
| 704 | Locks, objections, and refusals are loud | refusals built, locks not |
| 705 | The sign-posts are clickable in the world | not started |
| 706 | The documentation becomes HTML | not started |
| 707 | The way in | not started |
| 708 | The camera is a lens you push into | built |

**Blocking:** nothing. D1 was the last decision in the project with a deadline
and it is made: **LÖVE**, because it is already LuaJIT — no FFI boundary between
viewer and simulation — and its sprite batcher is the only real performance
question here.

**Carry into the work:**

- **Whole map by default, zoom to inspect.** One rule, and it belongs in a
  comment above the camera code: **zoom reveals detail, it never reveals
  events.** Everything a player must react to is legible at the default view.
- **Keep the terminal viewer.** Two viewers means neither can quietly become part
  of the simulation.
- **There is no fog-of-war system to build.** Nothing is hidden deliberately —
  only something not to accidentally reveal. No enemy slot contents, transits,
  chest, or sign-post directions.
- **A soldier's upgrades must be readable off the body** at close zoom. That is
  the whole information design: you know *what* the enemy holds because the deck
  is shared, and you learn *where they put it* by looking at what walks at you.
- **The zoom is anchored to the cursor, not to the screen centre.** Issue 708
  exists because 701 said "a zoom scalar and a centre" and stopped there, which
  leaves the camera zooming about the middle of the display — a gesture that
  moves the thing you were looking at away from you. D7's ruling about the trip
  home applies just as hard to the trip out.
- Issue 706 has no blockers and could be done at any time. Doing it early would
  make every other phase easier to read.

**Still open:** what the setting looks like. Nothing has been drawn.

**Demo:** not yet built.

## Where the prototype got to

There is a window, and you can play in it.

**701 and 702 are standing.** A fixed tick under a free frame rate, two snapshots
with the blend clamped so the viewer is never ahead, and a map that draws its three
lanes at their real widths, its connectors, its milestone marks, its stone with
health and slotted badges, and both teams' command radii. Push depth is drawn as a
band growing along each lane from either end, so "which lane am I losing" is
answered by looking.

**708 is standing and is tested.** The wheel zooms to the cursor and the world point
under it does not move — asserted as a property with four hundred random anchors and
random scale changes, because every later camera feature is a chance to break it
silently. Home is instant, the floor is the whole map, the ceiling is set by 702's
requirement that badges be readable off a body, and the drawn scale eases in log
space while the anchor is re-honoured every frame so the point stays put *during* the
animation and not merely at its end.

**The second vision's gesture is in.** Picking a rune up pulls the camera back to
the whole map and lights up every place it could go — because the act of zooming out
is the act of asking where to put it — and dropping it returns the camera to whatever
was being watched, unless the player moved it themselves in the meantime. The base
towers deliberately stay dark, which teaches the library-slot rule without anybody
having to be refused first.

**The third vision's dots have shadows**, which is what says they are objects
standing on ground rather than marks on a surface.

**704 is half.** Refusals are loud and fade over several seconds. Locks and
objections are not built, because they need 402's instances.

**705, 706 and 707 are not started**, and 703 is a drag onto the world rather than
onto a panel target — which is what the second vision asks for and what the viewing
layer document does not.
