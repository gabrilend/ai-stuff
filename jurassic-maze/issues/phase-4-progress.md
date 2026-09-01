# Phase 4 — The Wandering

**All eight issues complete.** A crowd of little guys wanders, sets itself
errands and finishes them, stands about, notices each other, and the camera can
be told to go and find somebody more interesting.

| Issue | |
| --- | --- |
| [401](completed/401-a-step-from-surface-to-surface.md) | a step from surface to surface |
| [402](completed/402-smoothing-belongs-to-the-renderer.md) | smoothing belongs to the renderer |
| [403](completed/403-a-path-is-found-once-and-kept.md) | a path is found once and kept |
| [404](completed/404-an-idle-is-a-row-with-a-clock.md) | an idle is a row with a clock |
| [405](completed/405-the-meet-pass-pairs-bodies.md) | the meet pass pairs bodies |
| [406](completed/406-two-bodies-idling-together.md) | two bodies idling together |
| [407](completed/407-the-director-decides-what-is-worth-watching.md) | the director decides what is worth watching |
| [408](completed/408-the-panel-and-its-sliders.md) | the panel and its sliders |

`./run-maze --scene crowd` runs it. `p` opens the camera's settings, `tab` swaps
subject, `c` gives the camera back.

## The journey, and what it taught

### Density, not population

The shared idle — the thing this whole phase is pointed at — fired **six times a
minute** when it was first working, and it took a while to accept that nothing
was broken. Two hundred walkers in nine thousand floor cells is two percent
occupancy, and two of them are adjacent almost never.

The number in the table was a count. What it needed to be was a density.

**What it taught:** a feature that works and never happens is indistinguishable
from one that does not work, and the first instinct is to debug the feature.

### Two closures and a shadowed parameter

Three performance and correctness faults in this phase were all the same kind of
thing: something small, in a hot or a rarely-taken path, that nothing pointed at.

- The meet pass reached its buckets through a callback, which allocated a closure
  **per body per tick** — a quarter of a million a minute at seven hundred
  bodies, for a loop of four lines. Removing it made the pass four and a half
  times faster and it stopped being the most expensive one.
- Errands were being abandoned nineteen times in twenty, because the separation
  rule always displaced the higher id and a body pushed one cell sideways is no
  longer at the start of its path. Preferring to displace the body that is *not*
  going anywhere fixed it.
- `drawn_position` took a `Stone` parameter that shadowed the module's own, and
  every caller passed nil for it. It only ran for walking bodies, in the draw
  path, so it did not appear until the first screenshot of a scene containing
  any — and that screenshot was written off at the time as the window manager
  throttling a background window.

**What it taught:** the third one is the lesson. A screenshot that hangs is a
failure, and treating it as an environment problem cost two hours of it sitting
there being wrong.

### Every world has its own copy of every module

The viewer loaded its own `038-walking.lua` and called a function on it that the
*tick's* copy had been linked. Nothing was nil until the moment it was.

This is the same isolation that made a parameter sweep in phase three report
identical numbers for twelve different settings. The isolation is correct and it
is not going to change; what changed is that the failure now carries a message
saying exactly this, and the viewer takes its modules from `world.modules`.

**What it taught:** an invariant nobody can see is worth an error message that
explains itself, more than it is worth a comment.

### The test that made the whole camera design safe

Fifteen hundred ticks, the swap key pressed five hundred times, every panel
control driven through its whole range, the camera panned and zoomed throughout —
and a simulation checksum identical to a run where nobody looked.

It also asserts the quiet run never touched the camera stream **at all**, because
if it had, the simulation is reading it, which is the entire thing the separate
stream exists to prevent. That second assertion is the one that keeps the first
from being vacuous.

**What it taught:** the reason to give the camera its own stream was written down
in phase one, before there was a camera. Writing the test was ten minutes because
the design had already done the work.

## What is worth carrying into phase 5

- A duel is the same shape as a shared idle: a record referencing two bodies with
  their generations, holding a clock. This is the second instance; the third one,
  in phase six's games, is when generalising is worth doing rather than guessing.
- The director's verdict list has a hole at the top marked for "its duel ended".
  Fencing fills it and the camera needs no other change.
- Open question 1 is still open and now blocks nothing structural, because
  `disengage_seconds` is written as a knob: zero makes released fencers re-engage,
  which is the other reading of the sentence, and no rewrite either way.
