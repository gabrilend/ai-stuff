# 047-the-renderer

Draws the world. Reads snapshots, writes nothing.

## The brief

**A glance should answer "which lane am I losing" with no number anywhere on the
screen.** Everything else here is subordinate to it.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(world, camera_module)` | | — Builds the disc image, the sprite batches, the fonts. |
| `draw(world, camera, previous, newest, blend)` | | — One frame, under the camera's transform. |
| `COLOUR` | *(table)* | The palette, so the panel matches. |

The camera **module** is handed in rather than reached for, so the renderer asks the
camera its questions through the camera's own functions instead of reading fields off
the record and re-deriving answers the camera already knows.

## The look

Nobody remembers why. An ancient automated war nobody alive started: the bases still
spawn soldiers because the machinery that spawns soldiers still works, the towers still
shoot because that is what towers do. The libraries hold the records of why the war
began and nobody has read them.

So: cold ground, faint worn paths, and two colours of light that clearly are not on the
same side. Team 1 is warm, team 2 is cold — the fastest distinction the eye makes, and
the one the whole read depends on. The bodies are the only things that look alive, and
they are not really.

## What is drawn, in order

1. **Connectors** — the ground the jungle used to occupy. Thinner and duller than a
   lane, because that is what it is.
2. **Lane ground**, at each lane's real width. The centre is visibly wider, and that is
   topography rather than decoration — a player should be able to see it before anybody
   explains it.
3. **Push bars** — each team's reach, growing toward each other from opposite ends. The
   primary read made explicit.
4. **Milestone marks**, drawn across the lane, so a player can read a lane the way the
   simulation does.
5. **Stone** — command radius, body, health bar, and a badge per slotted upgrade.
6. **Libraries**, last and brightest.
7. **Bodies**, batched.
8. **Body detail**, only above a zoom threshold.

## Detail arrives with zoom, and never an event

Three thresholds on `zoom_fraction`, in order: health bars, then upgrade badges, then
the mark saying which lane paid for a body. All three are things you look at when you
have a moment, never things you must see to stay informed.

**A soldier's upgrades must be readable off the body.** That is not a nicety — it is
the only way an opponent learns your arrangement at all. You know roughly *what* they
hold because the deck is shared; you learn *where they put it* by looking at what walks
at you. Leaning in has to answer that, or the fog stops being made of walking and
starts being made of the interface not telling you.

## The sprite batch

One batch per team, because a batch can only be drawn in one colour at a time and team
colour is the distinction the whole screen turns on.

This is the one place in the viewer where the drawing has to be fast, and it is fast
for the same reason the simulation is: hundreds to thousands of near-identical things,
handed over all at once rather than one at a time.

The disc is **generated** rather than loaded from a file — four lines of arithmetic
against an asset that would have to be kept in step with the code that assumes its
size.

Bodies outside the visible rectangle are skipped. At the rest framing that rejects
nothing and costs four comparisons per body; at close zoom it rejects almost
everything, which is exactly when the frame has the least room to spare.

## Interpolation

Between the two most recent frames, clamped to [0, 1] rather than trusted to arrive
there. A body absent from the previous frame was just born and is drawn where it is,
rather than sliding in from wherever the slot's last occupant died.

## Two drawing details worth knowing

**Rubble stays.** A felled tower is drawn as an empty outline rather than erased,
because "there used to be a tower here" is information — erasing it would make a lost
lane read as a lane that never had stone in it.

**The command radius is drawn for both teams.** It is the one piece of information in
this game both sides can see, and it is drawn that way deliberately: the attacker and
the defender have to reason about the same circle at the same moment.

**A connector is drawn once per edge, not twice** — but "once" is subtle. Only drawing
toward the higher node id looks right and is wrong, because a connector's two end edges
join it to a *junction*, and junctions are built first and hold lower ids. Both ends
went undrawn and the connectors floated in the middle of the map, joined to nothing.
The rule is "draw it unless the other end is a connector that will draw it itself."
