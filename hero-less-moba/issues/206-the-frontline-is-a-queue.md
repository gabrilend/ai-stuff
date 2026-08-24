# 206 — The Frontline Is a Queue

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 203 |
| Blocks | 404, 602 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [the map and its milestones](../docs/002-the-map-and-its-milestones.md) |
| Open questions | B11 — does the frontline move at all; how wide the center is |

## Current behavior

Soldiers walk into and through each other. Two waves meeting produce a smear of
overlapping bodies with no discernible front.

## Intended behavior

Soldiers do not overlap and do not push each other. A soldier in the **closing**
state that would end its move inside the personal space of a friendly soldier
ahead of it **stops short** instead.

The result is a queue of **ranks**. The front rank fights; the ranks behind stack
along the lane and step forward as the front rank dies.

### Ranks are N abreast, and N differs by lane

**Each lane carries a width**, and the **center lane's is greater** — permanently,
as topography. A soldier stopping short looks for a free position in the front
rank at the point where the fighting is; if that rank is full to the lane's
width, it stops behind and forms the next one.

`width` comes from the lane record, so the same code produces a narrow side lane
and a wider middle with no special case. Why the center is wider, and what it
means that the middle is where numbers matter most, is in
[the map and its milestones](../docs/002-the-map-and-its-milestones.md).

### Why this is not cosmetic

1. **A wave reads as a wave** rather than a smear — the difference between a
   player being able to see what is happening in a lane and not.
2. **A lane upgrade becomes legible.** A stronger front rank visibly holds its
   ground while the enemy's queue backs up. Without the queue, extra strength
   shows up only as bodies vanishing slightly faster, which nobody can see.
3. **The stalemate becomes visible**, which is what the phase-2 demo is for. The
   vision's problem statement — units meeting in the middle and "barely moving
   the frontlines at all" — is only a problem statement if you can watch it
   happen.

Deliberately **not** included: pushing, flowing around, or any collision
resolution that moves a body which did not choose to move. A soldier either
advances into free space or waits. Anything more is a physics problem, and a
physics problem with a thousand bodies is a frame-rate problem wearing a costume.

## Suggested implementation steps

1. Add a personal-space radius to the unit catalogue. Heroes and monsters have
   larger ones, which is most of what makes them read as big.
2. In the move pass, before committing a step, check the front rank at the
   fighting point — available from the milestone buckets built in issue 204 — and
   either take a free position in it or stop behind.
3. Read `width` per lane rather than assuming single file.
4. **Process each lane front-to-back**, so the soldier ahead has already moved
   before the one behind checks the space in front of it. Otherwise the queue
   advances one body per tick and looks like a traffic jam. Comment this; it is
   exactly the kind of thing someone parallelises and breaks.
5. That ordering constrains thread-pool slicing to **whole lanes**, not arbitrary
   index ranges. Six lanes-worth of work is still six independent slices. Note it
   in issue 209.
6. Write a test: twenty soldiers into one lane against a wall of enemies, assert
   they form ranks with no two closer than the personal-space radius.
7. Write a test that a wide lane fits more abreast than a narrow one.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md) — lane
  width
- The phase-2 demo, which shows the stalemate this makes visible

## Still open

**Does the frontline actually move once upgrades exist?** This issue makes the
stalemate visible; nothing yet proves the replacement layers unstick it. Issue
804 answers it.

**How wide is the center relative to the sides?** A balance value, and a
consequential one — it is the dial that sets how much a body-count advantage is
worth.
