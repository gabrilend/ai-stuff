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
