# Datapath — from particle snapshot to indexed frame

This document follows a frame snapshot (positions, life-fractions,
hues) into a rectangle of palette indices ready for the encoder.

## The light buffer

The canvas is a floating-point accumulation buffer — three floats
(red, green, blue light energy) per pixel, FFI-allocated once and
cleared to zero each frame. Zero is the black background; it costs
nothing and can never be contaminated, because nothing is ever drawn
*as* background.

Floats, not bytes, because glow is additive: twenty overlapping faint
particles must sum into one brilliant core without clipping at every
intermediate step. Clipping happens exactly once, at tone-mapping.

## Splatting a particle

Each particle stamps a small radial glow:

- The stamp is a square of a few pixels' radius around the particle's
  position. Within it, brightness falls off smoothly from center to rim
  (a squared-falloff bell — cheap, and indistinguishable from a
  Gaussian at this size).
- The particle's hue selects a color; its remaining-life fraction and
  bright-seed scale the intensity — young particles blaze, old ones
  ember out.
- The stamp *adds* into the light buffer. Order of particles is
  irrelevant; addition commutes, which is also what will make threaded
  rendering safe span-by-span later.

Sub-pixel positions are honored: the stamp's falloff is evaluated at
each pixel's true distance from the particle's fractional position, so
motion stays silky instead of snapping to the grid.

## Tone-mapping: light to color

Accumulated light can far exceed 1.0 where particles crowd. A soft-knee
curve (linear when dim, gentle shoulder into saturation) compresses
energy into displayable range, and *desaturates toward white* as energy
climbs — that is what makes a dense core read as "white-hot" while its
halo keeps the hue. Gamma is applied last so the dark end of each glow
uses the palette's dark entries well.

## The purpose-built palette

GIF allows 256 colors. We spend them deliberately:

- index 0: pure black, reserved for the untouched background.
- For each hue the scene declares: a ramp of steps from near-black
  through vivid to near-white, gamma-spaced so more steps live in the
  dark half, where banding would otherwise show in glow falloffs.
- A shared white-hot ramp at the top for saturated cores.

Ramp sizes divide the remaining 255 slots among declared hues. Mapping
a tone-mapped pixel to its palette index is then arithmetic — find the
hue's ramp, index by brightness — not a nearest-neighbor search over
256 candidates. A scene declaring more hues than the palette can seat
is a hard error at compile time, never a silent merge of look-alike
colors.

## The output

One byte per pixel: the palette index. This rectangle, plus the shared
palette built once per render, is everything the GIF encoder needs.

## Relevant pieces

- the light buffer (float RGB accumulation, cleared per frame)
- the splatter (radial stamp, additive, sub-pixel aware)
- the tone-mapper (soft knee, white-shift, gamma)
- the palette builder (per-hue gamma ramps, reserved black)
- the indexer (brightness-to-ramp arithmetic)
