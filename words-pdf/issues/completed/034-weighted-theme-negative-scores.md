# Issue 034: Weighted Theme Choice Favors Overused Themes When Scores Are Negative

## Current Behavior

`find_most_similar_theme_weighted` in `libs/fuzzy-computing.lua` scores
each theme as `raw_similarity * diversity_boost`, where
`diversity_boost = 1 / (1 + picks / 10)` shrinks as a theme is picked
more often.

That works for positive similarities: a heavily picked theme's score
shrinks toward 0 and a fresh theme can overtake it. For a negative
similarity the same multiplication moves the score *up*, toward 0. When
every theme scores below zero for a text, the most-picked theme gets the
smallest penalty-adjusted magnitude and wins. Example: raw scores -0.9
(picked 100 times) and -0.5 (never picked) weigh in at -0.08 and -0.5,
so the overused theme is chosen.

With nomic-embed-text most cosine similarities between a poem and a
theme description are positive, so this is rare in practice, but a
short or odd text can land below zero on every theme.

## Intended Behavior

The diversity weighting always makes a heavily picked theme *less*
likely to win, whatever the sign of its raw similarity.

**Decided:** the boost stays a multiplier for scores at or above zero
and becomes a divisor for scores below zero. Either way the score moves
*down* as a theme is picked more. Every positive score weighs exactly as
before.

Two other fixes were considered. Shifting scores into `[0, 1]` with
`(raw + 1) / 2` before weighting also fixes the sign. But it halves the
gaps between themes while the boost stays the same size. Cosine scores
from nomic-embed-text usually sit in a narrow positive band, so the
diversity push would get much stronger on almost every page of a real
book. The existing check "a few picks do not outweigh a clear lead"
fails under it: sea at 5 picks would lose to forest. Softmax would also
change every page and would need a temperature to tune. The sign-aware
rule fixes the bug without changing any result for positive scores.

## Suggested Implementation Steps

1. Shift similarities into a non-negative range before weighting, e.g.
   `weighted = ((raw + 1) / 2) * diversity_boost`, which keeps the order
   of unweighted results and makes the boost a penalty at every score.
2. Keep returning the raw similarity of the winner (callers log and
   threshold it).
3. Add a check to `tests/test-similarity.lua` with all-negative scores,
   and check that the existing ones still pass (the "few picks do not
   outweigh a clear lead" check depends on the exact formula).
4. Record the change in `docs/balance-updates.md`, since it changes which
   theme some pages get.

## Relevant Files

- `libs/fuzzy-computing.lua` (`find_most_similar_theme_weighted`)
- `tests/test-similarity.lua`

## What Happened

Built 2026-11-02.

- `find_most_similar_theme_weighted` in `libs/fuzzy-computing.lua`:
  `weighted = raw * boost` when `raw >= 0`, and `raw / boost` when
  `raw < 0`. The weighted score still rises steadily with `raw` (the two
  halves meet at 0), still falls with every pick for any nonzero score,
  and still reports the winner's raw similarity.
- `tests/test-similarity.lua` has five new checks: the issue's
  -0.9 / -0.5 example, a closer all-negative case, a negative score
  falling with every pick, unweighted order kept for negative scores,
  and a positive score beating any negative one however often it was
  picked. The first three fail on the old formula. The four existing
  weighting checks pass unchanged.

**Effect on a book: none today.** All three callers in
`compile-pdf-ai.lua` throw away a choice whose raw similarity is under
0.15 (pages) or 0.1 (poems) and use "neutral" instead. An all-negative
result never gets past that. When some scores are positive, a positive
one always wins. The fix protects any later caller that uses the chooser
without such a threshold.
