# Parity may be pessimism

I wrote in `docs/004-architecture.md` that "parity is not pessimism — it
keeps the divergence grid honest." That sentence is half-true and I want
to flag the other half before phase 2 makes it obvious.

The other half: parity can hide an aesthetic mismatch. The DS is *a*
shape — fixed-point math, no shaders, fake-tilt-shift via layered
sprite backdrops, hard memory budgets, no threads. A faithful native
rendering of that shape is a *port of the DS to native*, which is not
the same thing as a native game that happens to share a source tree
with a DS game.

The divergence grid (`docs/005-divergence-grid.md`) measures *technique*
divergence: "how do we solve problem X on each target?" It does not
measure *feel* divergence: "what is it like to play this?" Two
techniques can score "yes both ship something they call tilt-shift" in
row D1 while producing experiences that are obviously not the same
game to anyone holding both devices.

## The specific prediction

At the phase 2 capstone demo, when the NDS and native screenshots are
placed side by side per `issues/110-phase-1-demo.md` (extended into
phase 2), I expect:

- The native build, observing the DS triangle and texture budgets, will
  look like a 256×384 emulator window with a faintly modern-looking
  sprite filter. Not bad. Not memorable. Faintly embarrassing in the
  way "fan port" is faintly embarrassing.
- The DS build, with its faked tilt-shift, will read *correctly* — the
  faked technique is appropriate to the device, and the device's
  resolution and color depth do the heavy lifting of the aesthetic.

The asymmetry is the prediction. The native build, hobbled by parity,
will be the weaker artifact. The DS build, expressing its constraints
honestly, will be the stronger one.

## What I would do instead

If the prediction holds at phase 2, I would change the parity rule from
"both targets honor DS budgets" to "the trunk honors DS budgets; the
native build is free to exceed them where the divergence is *aesthetic*
and tracked in the grid." A new column on the grid — "is this
divergence asked to preserve feel, or to preserve correctness?" — would
help me see which rows can legitimately diverge in scope, not just in
technique.

The cost of relaxing the rule: harder to keep gameplay deterministic
across targets if rendering can run different effects. The benefit: the
native build gets to be the native game.

## What I would not change

The fixed-point-in-gameplay rule. That one I believe in. Determinism
and parity *of gameplay state* are the things that make multi-target
worth it — and floats break that without any aesthetic compensation.
Aesthetic parity (the rule under question here) is a different rule
than computational parity.

## If I am wrong

If at phase 2 the native build looks the same kind of good as the DS
build — if the parity discipline produces two screenshots that read
as the same game on different screens — then the rule was right, the
grid is sufficient, and this note becomes an artifact of an excess of
caution. That outcome is fine. I want to have predicted specifically
enough that the prediction is checkable.

Filed 2026-05-13.
