<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Every question met while turning the vision into documents. Each is to
     be asked and worked through with the owner, one by one. When answered,
     write the answer into the design documents and move it to Answered with
     the date; do not delete it. -->

# Open questions

Each waiting question names the interpretation the documents currently
assume, so the design can move forward while the question waits — but the
assumption is a guess until answered.

## Answered

- **Platform?** LÖVE2D + LuaJIT. (2026-10-10)
- **Who plays at first?** Hot-seat with AI foes; networked play later.
  (2026-10-10)
- **How does time flow?** Real time, with orders in transit. (2026-10-10)
- **Where are you on the map?** Your base is the hub; each team member has a
  quadrant; the map is not to scale. (2026-10-10)
- **What does the rotating rim select?** Nothing — the player never controls
  dials; they are information only. Orders are: click the stand on the map,
  then click the order button on the dashboard, alternating, always exactly
  once each. No menus, no right-click: you tell someone to build, you tell
  someone to attack. (2026-10-10)
- **What is written on the dial?** The month and the day of the week, among
  other things. The player sees only a cut-out: a seamless glass window over
  a paper-thin disc. The dial is a generic component used throughout.
  (2026-10-10)
- **The architecture?** Soramech: consensual coroutines — stations that run
  when every input has arrived. (2026-10-10)
- **The two kinds of zoom?** Answered with merging: units always can merge
  into an average-level and count pair, colored by the balance of the threat
  they contest, with triangles for colorblind players. (2026-10-10)
- **Does the calendar set vote cadence?** Yes, among other things.
  (2026-10-10)
- **Distant forces move faster?** Yes: equal time per tier. The circle is a
  distortion of a grid on a sphere — inside, outside, or both; the inside is
  the underworld (w7). (2026-10-10)
- **Art?** No AI-generated art. Small 3D models and tiny formula-driven voxel
  effects. The scene impossibly far from the camera, rendered accurately.
  (2026-10-10)
- **Enhancements?** Yes — "yes yes yes yes yes yes yes yes yes": the City of
  Heroes system by way of Symbeline. A held enhancement waits in the tray
  until its power is owned, then slots in and strengthens it. (2026-10-10)

## Waiting

1. **Orders that need a second party.** With map-then-dashboard and exactly
   one click each, "attack" or "follow" or "build a factory" has no click
   left for *whom* or *where*. Assumed: every verb is relative (advance
   toward the front, attack the nearest enemy in reach, build where the
   engineer stands, follow the nearest friend). Or: does the next map click
   (which would otherwise name a new stand) supply the target when the verb
   needs one?
2. **Who sets the view's reach and fold**, now that the player never
   controls dials? Assumed: the game sets it from the state of the fronts
   (the furthest active front always fits on screen). Or is it itself an
   order — telling a scout or cartographer?
3. **How deep do heroes adventure**, without a depth dial? Assumed: the
   adventure verb sends a hero one tier deeper each time it is given. Or a
   set of verbs (shallow, deep, deepest)?
4. (Answered — moved to Answered above, 2026-10-10.)
5. **The sphere's other side.** Is the far pole the foes' hub (so pushing
   outward ends at their center), or open wilderness? How do forces pass
   between the surface and the underworld — gates at certain tiers, or
   anywhere?
6. **Voxels "hidden when not directly in view of an opponent."** Assumed:
   fog of war — an effect is drawn for a player only when that player has
   sight of it. Or the reverse: an effect is drawn only while an enemy is
   looking at it?
7. **Soramech's route into this project.** Write the pattern in Lua (stations
   as tables, LÖVE threads and channels), or build minimal-soramech's C
   engine and drive it from LuaJIT's FFI?
8. **What else does the calendar pace**, besides votes? Income, foe
   reinforcements, level-up windows, hero returns?
9. **Clicking a merged marker** — names its strongest stand, or the whole
   merge as one stand for that order?
10. **Who is the foe in each direction?** Assumed: one opposing player (AI at
    first) per direction, with one outpost per tier. With a team of 4, are
    there exactly 4 foes? Are foes teams with a hub of their own?
11. **Is the game won?** What ends a game: reaching a set tier, losing the
    hub, a time limit, or never?
12. **What is a stand made of?** Assumed: units gathered at the end of a
    factory's path. Can stands merge or split (each would be an order)?
13. **Seats not being played in hot-seat** — assumed: they keep running their
    last orders, and a helper AI handles only defense.
14. **The voting categories** — assumed: production, upgrades, heroes,
    reserve.
15. **Can couriers be intercepted?** Assumed: no.
16. **"The round table rotates, so no-one is ever unawares"** — assumed: the
    view rotates on switching seats so that seat's quadrant faces up. Or does
    it turn on its own over time?
17. **Engineers** — from a factory, or from the hub?
18. **HTML documentation pages** with the feedback inbox, as the house rules
    describe — wanted now, or after phase 1?
19. **A framerate cap of 0.** Built as "no cap" (the game runs as fast as it
    can: 377 frames per second measured). Or should 0 mean "stop"?
20. **Measured time or fixed steps?** Every motion is scaled by the real time
    since the last step, as asked. Because positions are 32-bit floats, a run
    at 240 frames per second ends a hair (about 2e-5 of a tier per second)
    away from one at 20. Exact replays and network play (issue 102) want the
    simulation to step in fixed slices — several per frame when frames are
    slow — while the view scales by measured time. Is that split wanted?
21. **Soramech's route, revisited.** The renderer uses the Lua route (stations
    on the main thread, LÖVE channels as the pool). It reaches 240 frames per
    second with 192 units, each unit one task per frame. Keep it, or move to
    the C engine through FFI when unit counts grow?
22. **The arch's band as "the display of the map".** Built as glass over the
    world (the map seen through a gold-edged lens). Or did you mean a
    separate drawn map along the band — a minimap?
23. **Allies' arches in a round world.** The M is drawn as a straight row
    (you see your arch and your neighbours' feet). In the round world, are
    the arches meant to stand in a ring around the hub, one facing each
    quadrant?
