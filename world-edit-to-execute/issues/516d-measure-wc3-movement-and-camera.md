# Issue 516d: Measure WC3 Movement and Camera Numbers on a Real Install

**Phase:** 5
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 516 (locomotion and fort demo)

---

## Current Behavior

`src/runtime/locomotion.lua` and `src/render/fort_demo.c` move and view
things the way WC3 does, but several of their numbers are stand-ins,
chosen to look right, not measured:

| Number | Stand-in | Where |
|--------|----------|-------|
| Turn speed per 1.0 of turn rate (`umvr`) | 10 rad/s | `locomotion.TURN_SCALE` |
| Propulsion window (`uprw`), and whether it is the full angle or half | 60 degrees, half-angle | `UNIT_TYPES.*.propwin` |
| Archer attack point, backswing, cooldown | 0.4 s, 0.3 s, 1.5 s | `UNIT_TYPES.archer` |
| Facing needed before an attack | within 20 degrees | `face_tolerance` |
| Arrow speed, arc | 900, 0.15 | `missile_speed`, `missile_arc` |
| How range is measured (centre to centre? minus collision sizes?) | ground distance, centre to centre | `loco.distance` |
| Camera pan speed; zoom limits; whether FOV 70 is vertical | 1400 units/s; 700-4200; vertical | `fort_demo.c` |

The data the 16 test maps carry agrees with the ranges in use (turn rates
0.1-1.0, speeds 200-350; see the 516 session notes) but only a running
game gives the rules.

Two readings of the stored data are also open: 21 map units store
`uprw` = 1, which is either a 1 degree window or the value in radians
(about 57 degrees, close to the usual 60). Which it is decides how the
field is read.

## Intended Behavior

Each stand-in replaced by a measured value, with the measurement noted
beside it.

## Suggested Implementation Steps

These run on the owner's install (`wc3-installs/`), in a test map made in
the World Editor: one archer and a timer that logs. The JASS below has
not been run; treat it as a sketch.

1. **Turn speed and propulsion window.** Place an archer facing east (0),
   order it to move to a point far to the west, and log its facing and
   position every 0.01 s until it has turned about:

   ```jass
   globals
       unit udg_probe = null
       real udg_t = 0
   endglobals

   function ProbeTick takes nothing returns nothing
       set udg_t = udg_t + 0.01
       call BJDebugMsg(R2S(udg_t) + " " + R2S(GetUnitFacing(udg_probe)) + " " + R2S(GetUnitX(udg_probe)))
   endfunction

   function ProbeStart takes nothing returns nothing
       set udg_probe = CreateUnit(Player(0), 'earc', 0, 0, 0)
       call IssuePointOrder(udg_probe, "move", -2000, 0)
       call TimerStart(CreateTimer(), 0.01, true, function ProbeTick)
   endfunction
   ```

   Turn speed is the facing's change per second while X stays put. The
   propulsion window is 180 minus the facing at the first tick where X
   changes. Repeat with `SetUnitTurnSpeed(udg_probe, r)` for r = 0.1, 0.3,
   0.6, 1.0 to see whether turn speed is proportional to the field.
2. **Attack timing.** Log each time the archer's target takes damage
   (a damage event) against the time its attack order was given; the first
   gap is facing + attack point, later ones the cooldown.
3. **Range.** Walk a target toward a held archer one step at a time;
   note the distance between the two (`GetUnitX/Y`) when the first attack
   starts, for targets of different collision sizes.
4. **Camera.** Hold the right arrow key and log
   `GetCameraTargetPositionX()` every 0.05 s; its rate is the pan speed.
   Zoom in and out fully and log `GetCameraField(CAMERA_FIELD_TARGET_DISTANCE)`.
5. Put each result into `locomotion.lua` / `fort_demo.c`, drop its
   STAND-IN label, and adjust the tests in `test_fort_scene.lua` that
   quote the numbers.

## Acceptance Criteria

- [ ] Turn speed per turn rate measured; `TURN_SCALE` set from it
- [ ] Propulsion window measured, and the reading of stored `uprw` values settled
- [ ] Archer attack timing and the facing tolerance measured
- [ ] How attack range is measured settled
- [ ] Camera pan speed and zoom limits measured

## Notes

Footage of play could stand in for steps 1 and 4 (count frames while a
unit turns about, or while the view pans a known distance), but the logging
map is more exact and needs no video.

## Note (2026-09-29, issue 517)

The camera numbers now live in `src/render/scene_viewer.c` (renamed from
`fort_demo.c`), and its zoom-out limit is 9000 so a whole map region fits
on screen; WC3's own limit is still to be measured.
