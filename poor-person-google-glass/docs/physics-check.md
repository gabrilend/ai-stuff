<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, to set each part of the design against known physics so the issues build on what will work and name what will not. -->
# Physics check

Each part of the design next to the physics it relies on, and the closest
thing that already exists.

## Light that gets seen
A dark-adapted eye notices a flash at about 5–10 photons arriving within
about a tenth of a second; a readable spot in daylight needs on the order of
billions of photons per second. Single photons are the unit; the release has
to carry very many of them.

## Storing light in the mirrored cylinder
Light can be kept bouncing between mirrors, but not for long. How long it
lasts is the round-trip time divided by the fraction lost per bounce. With a
cylinder about a centimetre across and the best mirrors made (losing about one
part in ten thousand per bounce), the light is gone in well under a
millionth of a second; ordinary silvered mirrors (losing a few parts in a
hundred) lose it in about a billionth. Two consequences:
- The store holds light for microseconds at most, so it smooths and shapes
  pulses rather than banking light between scenes.
- Everything the store does not release ends up as heat in its walls.
The real device with this shape is a laser cavity with **Q-switching**: the
cavity fills, then a fast switch opens and the stored light leaves as one
strong pulse. The rotating aperture is a mechanical Q-switch (early lasers
used a spinning mirror for exactly this).

## Tabs moving through a liquid
Where light crosses from glass into another material it bends and partly
reflects, by an amount set by the difference in refractive index. **Index-
matching** liquids and gels are made for this (they are used to join optical
fibres); with the filling matched to the glass, the boundary all but
vanishes. Tabs must also be matched, or opaque where closed.

## The mask
Overlapping slotted strips form a picture by multiplication: a point is lit
only if every strip over it is open there (logical AND). This is a mechanical
**spatial light modulator** — the same job a projector's LCD or
micromirror chip does, done with fewer, larger, slower parts.

## Throwing light outward
The light leaves the crown toward the world and the panel catches it. If the
panel is moved away or misses, the release goes on toward whatever is in
front — including other people's eyes. Visible lasers under about 1 milliwatt
(class 2) are considered safe for an accidental glance because people blink;
the crown's releases should stay under that, and should not fire when the
panel is not in place (see docs/open-questions.md).

## No camera, no eye tracking
The vision first said "only turn it on when the user is looking at that
spot", then settled it: "your inputs determine what gets shown." Gaze is not
measured. The wearer steers by dials, buttons, stick and cuff.

## Heat without fans
Small piezoelectric "micro-blowers" (a vibrating plate a few millimetres
across pushing air through a nozzle) are real air pumps with no fan blades.
Heat fins on the hair work by area: flaring them out increases the surface
giving heat to the air.
