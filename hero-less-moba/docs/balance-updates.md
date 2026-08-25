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
