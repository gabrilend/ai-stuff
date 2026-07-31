# balance updates

Append-only. Knobs turned and levers pulled — the small numbers that get moved
by feel rather than by design. Every entry says **what moved, from what, to
what, and why**. Nothing here needs an issue file; issue files are for what the
software *is*, and this is for where its dials happen to be sitting.

Documentation does not carry these numbers. Documentation points here, so that a
value changed at eleven at night does not leave four documents lying.

---

## Format

    ### YYYY-MM-DD — short reason
    - `where` — name: old → new. Why.

---

### 2026-07-31 — the file exists before anything can be tuned

No values yet. The dials that will land here first, once phase 5 draws anything:

- **the whisp** — arm count range, points per arm, arm length, wander
  frequencies, spin rate, velocity stretch factor
- **the gate on each arm** — where along the arm the wander is allowed to begin,
  and the amplitude past it. The gate position is not free: it belongs at a zero
  crossing of the wave, which ties it to the frequency. Moving one without the
  other puts a kink at the root. The doubling in the original drawing is an
  amplitude and lands here.
- **the hue range** — how far either side of pink a creature's colour may sit.
  Too narrow and every whisp is the same one; too wide and it stops reading as
  pink, which is the property the whole contrast rests on.
- **the trail** — sample interval, buffer length, taper curve, opacity falloff
- **the schemes** — every palette slot, four times over, plus each scheme's
  whisp contrast colour and the minimum contrast threshold the checker enforces
- **the witch camera** — spring stiffness and damping toward the target offset,
  offset height and distance, lean into turns and overshoot out of them, the
  idle drift, and how much it rises with speed. The three rigs it can be tuned
  toward are extremes of these numbers, not separate modes.
- **the waiting verb** — how long a thing takes, and how far you can drift
  before it cancels
