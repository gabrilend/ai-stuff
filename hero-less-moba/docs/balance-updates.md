# Balance Updates

Append-only. Every knob turned and lever pulled, newest at the bottom, each with
the reason it was turned. Small tuning does not get an issue file; it gets a line
here.

Feature changes and design changes are **not** balance updates. If a rule
changed, that is an issue file. If a number changed, that is a line here.

Format:

    ## YYYY-MM-DD — what changed
    Old → new. Why. What was observed that prompted it.

---

## 2026-08-24 — nothing yet

No numbers have been chosen. The catalogue tables under `assets/` do not exist.
The candidates waiting to be picked are listed in Group B of
[open questions](020-open-questions.md), and the first entry in this ledger
should be the initial values with a note on where they came from.

## 2026-08-24 — the first spawn timings, as estimates

Nothing → the numbers below. These are the author's first estimates, written down
so that the timing tests have something to move away from rather than something
to invent. **None of them has been observed yet.** They are the shape of the
rhythm, not chosen values.

    normal wave interval      every 10-15 seconds
    normal wave size          5-6 bodies per lane
    surge stream interval     every 0.5 seconds
    surge stream size         one body per lane, all lanes on one shared timer

The ratio is what matters more than either number: a surge puts bodies on the
ground roughly twenty to thirty times as often as a wave does, one at a time
instead of six at a time. If the timing tests move one of these, they should move
the other and keep the ratio in view, because the surge's whole feel is that the
lull between waves disappears.

Related open questions: B1 (wave interval and size), B2 (surge length and stream
rate against the wave rate).

## 2026-08-26 — the first numbers that actually run

Estimates → catalogue tables. The four files under `assets/` now exist, so for the
first time these are values a program reads rather than a shape written down. They
were chosen to make a match *observable*, not to make it good: the point was to get
a frontline on screen so that everything in Group B has something to move away
from.

Where each cluster is anchored, following the discipline Group B asks for:

    the wave is the clock       -- one wave per lane per team, every 620 ticks
    a wave unit is the strength -- melee is 1x and everything else is a ratio
    the captain is 2.5x / 1.5x  -- health and damage, per the design
    the library is 1.5 towers   -- stored as a ratio, never as a figure
    a tick is 1/30 of a second  -- so a cooldown of 22 ticks is about 0.7s

What was observed, from the headless runner:

- **The stalemate is real and reproduces.** Twenty-two minutes, both teams between
  milestones three and four in every lane, neither base threatened. That is the
  vision's problem statement and it is now a thing that happens on a machine.
- **A melee body kills another in roughly six seconds** one-to-one, which is slow
  enough that a rank holds and fast enough that a wave resolves before the next one
  arrives. That number is what the wave interval was then chosen against.
- **The chest fills much faster than expected** — around a hundred and ninety draws
  per team over a full match, because nearly every wave in a stalemate is eventually
  wiped and nearly every wipe pays. Raised as **G4** rather than tuned here, because
  the match is only that long because the surge and the challenge are not built, and
  the number should be re-measured against a match shape that can actually end.
- **A stacked lane wins outright.** Everything one team drew, shovelled into the
  centre, reached the enemy library while the enemy's depth there collapsed to zero.
  Recorded against **B11**, which is the question the whole project exists to answer.

Two numbers that are not balance and are noted so nobody tunes them by accident:

    milestone 4 is at fraction 0.50   -- it must be the lane's bend; the builder
                                         places every other milestone relative to it
    command radius > tower range      -- getting inside has to be reachable ground
                                         rather than a spot under maximum fire

Related open questions: B1, B4, B5, B11, G4.

## 2026-08-26 — the camera's three constants

Nothing → the numbers below. Not simulation balance, but they are knobs with
reasons and they belong in the same ledger rather than in a comment nobody finds.

    wheel factor        1.18 per notch, multiplicative
    ease rate           14.0, as an exponential time constant
    zoom ceiling        9.0 screen pixels per pace

**Multiplicative, not additive**, because a notch should be the same *proportional*
change at every scale — an additive step crawls when zoomed in and jumps when zoomed
out, which is the same complaint from both ends.

**The ceiling is not a preference.** It is set by the requirement that a soldier's
upgrade badges be readable off the body, which is how an opponent learns your
arrangement at all. If the badges get smaller, this number goes up.

**The floor is not a number**, it is the whole-map framing, computed from the map's
own bounds — so changing the field size reframes the view with no second edit.
