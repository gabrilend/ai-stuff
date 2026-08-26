# Phase 9 — The sprite studio

**Goal:** the art is generated, kept, judged, and the judging is watched.

**Status: in progress.** Seven of nine issues complete.

## The issues

| Issue | State | What it establishes |
| --- | --- | --- |
| [901 a sprite is an animated SVG](completed/901-a-sprite-is-an-animated-svg.md) | done | A picture that watches itself, and a reader that did not write it. |
| [902 the paintbrush is a closed set](completed/902-the-paintbrush-is-a-closed-set.md) | done | Twelve words, and nothing outside them. |
| [903 the pool keeps everything](completed/903-the-pool-keeps-everything.md) | done | Storage is cheap, judgment is expensive. |
| [904 two ways of rating](completed/904-two-ways-of-rating.md) | done | Both algorithms, both tested. |
| [905 the machine grader is a heuristic](completed/905-the-machine-grader-is-a-heuristic.md) | done | A proxy for taste, measured rather than trusted. |
| [906 the quality dial](completed/906-the-quality-dial.md) | done | Raising quality spends variety, and says so first. |
| [907 the anchor that stops drift](completed/907-the-anchor-that-stops-drift.md) | done | A loop tuned by a grader that is itself being tuned. |
| [908 the phase nine demo](908-the-phase-nine-demo.md) | not started | The capstone. |
| [909 a thing wears a sprite](909-a-thing-wears-a-sprite.md) | not started | Foundational, and discovered late. |

## What is built so far

| Source | What it is |
| --- | --- |
| `082-sprite` | Making, writing, and independently reading one animated SVG. |
| `083-test-sprite` | Three thousand round trips, and the grader's spread. |
| `084-calibrate` | Whether the five tiers are still five tiers. |
| `085-sprite-pool` | Every sprite ever made, and what anybody thought of it. |
| `087-studio` | The agreement rate, the anchor, and the dial that quotes its price. |

## Two more, from building the library

**Zero out of zero is not perfect.** A ratio over no observations is the single
most dangerous number this project could print — a hundred per cent agreement
with a person who has never rated anything. Nothing disagreed; nothing agreed
either. The agreement rate has three standings rather than two, and both the
unmeasurable and the too-thin cases have tests checking that no percentage
appears in the sentence.

**A correction must not destroy what it corrected.** The obvious storage is one
tier field that a person's rating overwrites. It works perfectly and it destroys,
every time somebody disagrees, exactly the pair the agreement rate is computed
from. Two fields, one effective.

## Three things this phase has already taught

**A vocabulary grows once and never shrinks.** The first sprites rendered as
piles of overlapping shapes rather than as creatures, and the obvious fix was
more shapes. The actual fix was mirroring the detail layers — a pair either side
of the middle reads as eyes, or arms, or a thing with a front. It cost no new
words. Reach for a rearrangement of the closed set before reaching to open it.

**A threshold on edit distance is meaningless without the length of the input.**
The suggester offered `bob` for an empty word, because three edits is the whole
of a three-letter word. The description parser from phase 8 had the identical
bug. Both now require the distance to be shorter than the word being corrected.

**Cut lines have a date on them.** The grader's five tiers were first separated
by four round numbers that looked reasonable; against real output they left tier
one empty and put ninety per cent into two tiers. A five-point scale that is
really a three-point scale is worse than a three-point scale, because the two
dead numbers look like information.

So `084-calibrate` was written as a program rather than a script — the numbers
are frozen and the distribution is not. It has already caught one drift: making
the detail layers mirrored moved every line by two points, and nothing else would
have said so.

## What that leaves open

Two new questions, both in [open questions](../docs/016-open-questions.md).

**Who runs the calibration, and when?** The tool exits non-zero when the tiers
have gone adrift, so finding out is solved; remembering to look is not.

**A tier is a ranking and the dial will read it as a verdict.** Because the cut
lines are percentiles, tier five means *in the best tenth of what this paintbrush
produces* — so improving the generator does not raise anybody's tiers. Make every
sprite better and the same ten per cent are still tier five. Worth resolving
before a tier is used to decide the generator has got better.
