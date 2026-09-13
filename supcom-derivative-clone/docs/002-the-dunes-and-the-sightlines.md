# 002 — The Dunes and the Sightlines

The ground is the game. This document describes what the ground is made of, how
it is raised, and how a sightline is read off it.

## The field is a heightfield

The field is a square grid of **cells**. Each cell has one number: its height.
That array is the whole map — there is no tile type, no terrain class, no
walkability flag. Everything the rules need to know about a place is derived
from the heights around it:

- **Water** is every cell whose height is below the field's water line. Frigates
  move on water and nothing else does. Tanks stop at its edge.
- **Slope** is the height difference between neighbouring cells, and it is what
  land movement pays for. A steep face is slow; a crest is a place you are seen.
- **Cover** is a sightline question, answered below, and is never stored.

The heightfield is **raised by a tool** from a seed and a small table of shape
parameters — the field's size, how tall the dunes are, how long their wavelength
is, how rough the surface is, where the water line sits. Two machines given the
same seed and the same parameters raise the same dunes to the last bit, which is
what lets two players hold the same field without sending it to each other.

There is no map editor and no hand-drawn map. **Never raise a field by hand; make
the tool that raises fields.** A field that was hand-tweaked cannot be
regenerated, and a field that cannot be regenerated is one that cannot be sent as
a seed.

## What a dune looks like

The vision asks for ground that looks like sand dunes. The tool raises them in
layers: a long, low swell that gives the field its large shapes; a shorter
ridge-and-trough pattern laid across it at an angle, which is what makes a dune
field read as dunes rather than hills; and a fine roughness so that no two
crests are identical. Each layer's amplitude and wavelength is a shape parameter.

The tool validates what it raised before anything uses it, and refuses rather
than repairs: the water must not cover the whole field, both teams' starting
ground must be above water and reachable from each other by land, and no cell
may hold an absent value. A refusal names what was wrong and where.

The tool can also print the field as text — a grid of characters graded by
height, with the water line marked — so the dunes can be looked at before
anything can draw them.

## The sightline

A sightline is the question **can this point see that point?** It is answered by
walking the straight segment between the two points across the heightfield and
checking that the segment never passes below the ground.

Both endpoints have a height above the ground: an **eye height** for the viewer
and a **profile height** for the thing being looked at. A tank's eye is low; an
enforcer's is high, which is the vision's remark that they are taller than tanks
and must be placed carefully — a tall unit sees over more crests and is seen over
more crests, and both of those are true at once. A plane's height is the ground
plus its flight altitude, which is why planes see almost everything and why the
only things that reliably see planes are anti-air guns looking up.

There is **no maximum sight distance.** The vision says every unit has infinite
range, and the sightline is what makes that a game instead of a firing squad:
range is unlimited, but the field is folded, and every fold is a wall.

<!-- toy: sightline -->

## What the sightline is used for

- **Targeting.** A unit may only fire at what it can see. The targeting pass in
  the tick asks the sightline question for each shooter against candidates, and
  a unit with nothing in sight fires at nothing.
- **Reports.** A scout plane sees the ground beneath it and reports what it sees
  to the cloud. What it cannot see, it does not report.
- **Claiming.** Territory is claimed by presence, and presence is a position, not
  a sightline; but defences are thorns, and thorns hurt what they can see.

## The cost of asking

The sightline walk is the most-asked question in the simulation, and it is asked
by every shooter against every candidate every tick. Two things keep it cheap:

- **A coarse pass first.** Before walking the segment, the tallest cell along it
  is compared against the segment's lowest point. If the segment's lowest point is
  above the tallest cell, the answer is yes without a walk. The tallest cell per
  region is precomputed when the field is raised and never changes.
- **The walk is a straight loop over integers.** Which cells a segment crosses is
  a line-drawing question, and a line drawn across a grid is the oldest fast loop
  in graphics.

Whether that is enough is a measurement, not an argument. The headless runner
reports how many sightline questions a tick asked and how long they took, and
the number is what decides whether the coarse pass needs a second level.

## The generated look

The vision wants the field's art to be generated — a tileset produced by an
image model rather than drawn — because the field is random every time and the
number of dune shapes it can take would exhaust any hand-drawn set. That is a
**viewing** concern: the heightfield is the data, the tileset is a view of it,
and nothing in the simulation reads a picture. The tileset pipeline is
[its own issue](015-roadmap.md) in the viewing phase, and its design is pending
until the viewer exists to consume it.

## Open questions this document carries

The [open questions](016-open-questions.md) page holds them under group C:
whether slope should slow movement or only decide sight; whether a sightline is
blocked by units as well as by ground; and how large the field is, which decides
how long a shot takes to land.

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[territory](005-territory-mass-and-energy.md) · [the views](010-the-views.md)
