# 406 — Cuboids carried to color-coded sections

**Phase:** 4 — Factories and engineers
**Blocked by:** 109, 110
**Related documents:** docs/game-design.md (Hauling cuboids),
docs/core-terms.md (cuboid, section, hauling)
**Completed:** 2026-10-10

## Current Behavior

Built. The owner: "Small cubes that are made of rounded spheres that can be
picked up by the creatures and brought to color coded sections."

- **Cuboids**: 96 (from `input/`), each the unit sphere pushed toward a cube
  in the shader — every coordinate raised to 0.3, keeping its sign (a
  superellipsoid), with its exact surface facing — glazed like ceramic (a
  sharp glint, a broad sheen, a pale edge at a slant) in one of the four seat
  colors. Records: 12 floats each, front and back blocks (005).
- **Sections**: four color-coded patches, one in the middle of each
  quadrant, painted into the flat map (012); their places are data (007).
- **Hauling** (the unit box, 020): a seat's unit with no order fetches the
  nearest lying cuboid nobody else has claimed, walks to it, stops within
  reach and asks to pick it up; once it carries, it walks to the cuboid's
  section and asks to set it down. Foes do not haul; any order stops a unit
  hauling and it lets go.
- **Claims and carrying** (the cuboid box, 020): each step a lying cuboid is
  claimed by the lowest-numbered unit fetching it, and carried when that
  unit asks; a carried cuboid rides in front of its carrier's chest; a set-
  down cuboid is stacked in its section, nine to a layer; after 12 seconds
  it appears somewhere new, from the seed.
- **The holding pose** (018): while carrying, the arms bend forward and up
  to hold the cuboid — the same bend formula, fed a fixed pose.
- **Counts**: four small dials on the console, each inked in its section's
  color.

Measured: after 25 seconds, 15 cuboids delivered and 60 being carried, at
144 frames per second. Tests: of two units after one cuboid, the lower-
numbered carries it and the other goes back to looking; a carried cuboid
stays in front of its carrier; cuboids get delivered, and every delivered
cuboid rests inside its own color's section.

## Intended Behavior

As above (the issue's blueprint was built as written).

## Implementation Steps (as built)

1. `src/005-unit-records.lua`: unit group D (job, target, wants, carrying);
   the cuboid record and vertex format.
2. `src/007-seeding-the-units.lua`: `seed_cuboids`, `SECTIONS`,
   `CUBOID_SIZE`.
3. `src/020-ceramic-boxes.c`: `think`, `steer_toward`, `unit_chunk`;
   `cuboid_chunk`, `stack_slot`, the seeded reappearance.
4. `src/013-the-world-renderer.lua`: the cuboid shader and instance mesh.
5. `src/018-the-body-plan.lua`: `holds`, `HOLD_FORWARD`, `HOLD_LIFT`.
6. `src/014-the-dashboard.lua`, `src/016-the-game.lua`: the section dials and
   the counts.

## Decisions

- A cuboid that has just been lifted still sees its carrier as "fetching"
  (the carrier learns it carries only on the next step). An early version
  read that as letting go and dropped every cuboid the moment it was lifted;
  only "idle" (what an order makes a unit) now means letting go. A test
  covers the pickup.
- Claims go to the lowest-numbered unit so the result never depends on which
  worker finished first.
