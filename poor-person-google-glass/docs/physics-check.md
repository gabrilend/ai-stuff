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

## Second round (2026-10-10)

### Storing light somewhere else: a glowing screen
Mirrors cannot hold light, but some materials can. **Phosphorescent**
pigments (strontium aluminate, the stuff in glow-in-the-dark paint) absorb
light, hold the energy in trapped electrons, and give it back as a glow for
seconds to minutes. A laser drawn across such a screen leaves a glowing trace
— the "e-ink style" screen of the vision, and the photon store moved from the
cylinder to the panel. Violet and blue light charge these pigments well; green
charges them weakly. **Photochromic** materials (those in sunglasses that
darken outdoors) are the other kind: light changes their colour and it fades
back slowly.

### What keeps light in the centre
A moving fluid barely moves light, so a vortex will not hold the beam in line.
What does is **total internal reflection**: a core of higher refractive index
inside a cladding of lower index traps light that hits the wall at a shallow
angle, which is how an optical fibre works. The "rifle barrel" is the index
step, not the flow. (Light can itself be made to corkscrew — "optical vortex"
beams carry a twisting wavefront — but that is a property of the beam, and not
needed to keep it aligned.) Light turned aside by a closed slot is best
absorbed by a dark wall, where it becomes heat, rather than kept in the medium,
where it would scatter back into the picture.

### A liquid moved by levers
Index-matching liquids can be stirred and pushed, but a **bubble** is a large
index mismatch and shows up as a dark or bright speck: the volume must be
sealed and degassed. Duplicated motors spread load and give a diagnostic for
free: two motors doing the same job should draw the same current, so a
difference between them reports a fault.

### Green
The eye is most sensitive near 555 nm, so a green spot looks brightest for the
least power — the best colour for a low-power display. Pen-sized green
pointers of the past were mostly **DPSS** lasers: an infrared diode pumping a
crystal that doubles the frequency to green, and cheap ones leak invisible
infrared. Direct green laser diodes (about 520 nm) now exist and have no
infrared leak. Blue is not more powerful by nature; the eye sees it as dimmer
at the same power, so blue devices are run hotter, and blue light is more
damaging to the retina per watt.

### Segment displays
A 7-segment display (digits) or a 14- or 16-segment display (letters) needs
only one on/off control per segment, against a full grid's one per cell. Seven
to sixteen shutters is a much smaller machine than a slotted grid.

## Third round (2026-10-10)

### Glowing screen: set aside
Phosphorescent screens hold a picture but change too slowly — "not
responsive enough."

### Light sent back down the tube
A tube lined to reflect light backward, with a mirror at the back, gives light
that missed the panel another pass forward. Real displays do this: **light
recycling**, as in the reflective films behind a laptop's LCD that send
wrongly-angled light back to be reflected forward again. It raises the share of
light that reaches the screen; it does not hold light for long (each bounce
loses a little, and the loss is heat). If the back is the laser itself rather
than a mirror, light returning into a laser diode makes it flicker and hop
between wavelengths (**optical feedback**), and can damage it; lasers that
must tolerate returning light use an **optical isolator**, a one-way valve for
light. So the back is better a mirror, with the emitter entering from the side
or through a small hole.

### A vortex of light
Light can travel down a round pipe in a spiral that circles the axis without
crossing it — **skew rays** — and a beam can itself carry a corkscrew
wavefront (an **optical vortex**, with a dark centre like a ring). But light
does not push on light: two beams cross through each other unchanged. A spiral
of light around the centre would neither steady nor disturb the beam down the
middle; it would only reach the far end later, as stray light or heat.

### The 22-segment cell
A 2-wide by 4-tall box grid: 2 horizontal segments on top, then each of the 4
rows adds 3 verticals and 2 horizontals — 2 + 4 × (3 + 2) = 22. Two cells side
by side share their middle column of 4 verticals, so a pair is 22 + 22 − 4 = 40
segments; the 4 bits saved become metadata, so a pair fits in 44 bits.
Straight segments only: letters made of diagonals (K, M, N, V, W, X, Z) must be
approximated with steps and boxes. A tool that draws every character on the
grid would show which ones read.

## Fourth round (2026-10-10)

### Red and green
Red laser diodes are the smallest and cheapest made (they are in every
pointer). Red plus green mixes to yellow and amber, so two lasers give four
looks per segment: off, red, green, yellow.

### E-ink
E-ink holds its picture with no power and no light, and is read by daylight.
Black-and-white e-ink changes in a few tenths of a second at best; colour
e-ink takes seconds — about as slow as the glowing screen set aside earlier.

### Light along the side
Fibre made to leak light along its length ("side-glow" fibre) exists and is
sold for lighting: a line that glows softly when seen from the side. The
spiral of light around the centre could be let out this way, as faint coloured
streaks along the band.

### Distance at the edges
A picture thrown onto a curved panel already stretches toward the panel's
edges. Shaping the curve could make the far-from-centre parts look farther
away, as on a tilted map — part of the perspective done by the panel's shape
rather than by drawing.
