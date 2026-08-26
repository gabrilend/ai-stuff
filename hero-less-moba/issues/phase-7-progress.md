# Phase 7 Progress — Watching It Happen

**The goal:** the real viewer. Everything so far has been readable through a
terminal and a report; this is where it becomes a thing you look at and touch.
Plus the documentation as browsable HTML — the same generator-and-view separation
applied to the project's own prose.

**Ends with:** a human playing a full match against the phase-8 bot with a mouse.

| Issue | | Status |
| --- | --- | --- |
| 701 | The window and the two snapshots | not started |
| 702 | The map draws itself | not started |
| 703 | The chest panel and the drag | not started |
| 704 | Locks, objections, and refusals are loud | not started |
| 705 | The sign-posts are clickable in the world | not started |
| 706 | The documentation becomes HTML | not started |
| 707 | The way in | not started |

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
- Issue 706 has no blockers and could be done at any time. Doing it early would
  make every other phase easier to read.

**Still open:** what the setting looks like. Nothing has been drawn.

**Demo:** not yet built.
