# 102 — light canvas and tone-mapping

## Current Behavior

Complete. The light canvas lives as the project's first indexed source
file (with the index ritual documented at its head, per the skeleton
issue). Energy accumulates in flat float triples, row-major, y
downward; the only write is additive deposit; out-of-bounds deposits
and degenerate sizes are hard errors. Tone-mapping does white-shift,
soft knee, then gamma, into a reused mapped plane. Ten assertions
prove the datapath's promises, including luminance monotonicity and
hue-keeps-when-dim / bleaches-when-blazing.

## Intended Behavior

The project's first source module: a floating-point light canvas.

- Allocated once per render via LuaJIT FFI: three floats (red, green,
  blue light energy) per pixel, width and height from the scene.
- Cleared to zero (true black) at the start of each frame.
- Accepts additive deposits: "add this much energy of this color at
  this pixel." Addition is the only write operation — order-independent
  by design, which later makes threaded splatting safe.
- Tone-mapping pass converts accumulated energy to 8-bit color: linear
  when dim, soft shoulder into saturation, desaturating toward white as
  energy climbs (dense cores read white-hot), gamma applied last so
  dark glow falloffs get tonal room.
- A test renders known deposits and asserts on the mapped bytes:
  zero stays exactly black, energies sum, the shoulder never exceeds
  255, monotonicity holds (more energy never gets darker).

## Suggested Implementation Steps

1. The canvas record: dimensions, the FFI float array, clear and
   additive-deposit operations.
2. The tone-mapper: knee curve, white-shift, gamma; constants
   documented where they live (they are aesthetic knobs — future
   tuning belongs in docs/balance-updates.md).
3. Tests as described; runnable standalone under luajit.

## Related Documents

- docs/datapath-rendering.md (the light buffer and tone-mapping
  sections are the specification)
