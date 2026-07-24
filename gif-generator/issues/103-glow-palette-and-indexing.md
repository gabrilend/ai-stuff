# 103 — glow palette and indexing

## Current Behavior

Tone-mapped frames (from the light canvas work) end as 8-bit RGB with
nowhere to go; GIF needs palette indices.

## Intended Behavior

The purpose-built 256-color palette and the arithmetic that maps
tone-mapped pixels onto it.

- Index 0 is reserved: pure black, the untouched background.
- Each hue a scene declares gets a ramp from near-black through vivid
  toward white, gamma-spaced so the dark half — where glow falloffs
  band most visibly — gets more steps.
- A shared white-hot ramp near the top serves saturated cores of every
  hue.
- Ramp widths divide the 255 non-black slots among the declared hues;
  declaring more hues than can be seated is a hard error at scene-
  compile time (never a silent merge).
- Mapping is arithmetic — hue picks the ramp, brightness picks the
  step — not a nearest-neighbor search over the whole palette.
- A named-hue vocabulary ("ember", "violet", ...) lives here as data:
  hue angle plus saturation character, extendable without code.
- Tests: black maps to 0 and nothing else does; brightness
  monotonicity within a ramp; the seat-count error fires.

## Suggested Implementation Steps

1. The hue vocabulary table and the ramp builder.
2. The palette assembly (reserved black, hue ramps, white-hot ramp)
   producing the 256×3-byte table the encoder will embed.
3. The indexer from tone-mapped pixel to palette byte.
4. Tests as described.

## Related Documents

- docs/datapath-rendering.md (the purpose-built palette section)
- docs/datapath-gif-encoding.md (where the palette bytes land)
