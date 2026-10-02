# 701e — every film kept and rated

Part of 701. Depends on: 701a, 701b. Blocks: 701f, 701g.

## Current Behavior

The 34 films in `/home/ritz/pictures/shape-gifs/` carry no ratings. Six are
"approved", recorded only as SHA-256 values in the gallery's
`tests/approved-films.lua`. The 2D renders in `output/` are untracked and
unrated. The viewer shows films and cannot rate them.

The pattern exists elsewhere: `kanji-learning-image-generator` built the
skill's pool (`src/045-the-pool-that-remembers`, `046-two-ways-of-saying-it-is-good`,
`047-the-quality-dial`, `048-what-a-higher-tier-buys`), with cards beside each
artifact. Its cards use the `.info.md` suffix, which the skill warns collides
with the house's source companions.

## Intended Behavior

- **A card beside every film**: its fingerprint, the score that made it, the
  seed, its ratings appended one per line, never edited, and a short
  description of what moves in it (issue 064's per-film description fills
  this line).
- **Five tiers**, as the skill defines them. The six approved films start at
  five, by her earlier approval; the fingerprint test stays as well.
- **The viewer rates**: keys 1 to 5 append a rating to the card of the film
  on screen. The maker and the viewer share no code, as the skill asks.
- **A counting tool** reports how many films sit at each tier, so no document
  has to quote a number that goes stale.

## Suggested Implementation Steps

0. Read `kanji-learning-image-generator`'s pool first (`045` to `048`): it
   is the house's one built example, and she asked that this process learn
   from it while kanji stays separate (701, question 3). Note what to keep
   and what to do differently, starting with its `.info.md` card suffix.
1. Settle the card suffix (`.card`), and the card's fields.
2. Write cards for the 34, with the six at tier five.
3. Add the rating keys to the viewer, appending only.
4. Write the counting tool, and point the skill's pool section at it.

## Open Questions

1. Should 2D renders join the same pool and the same cards, or keep a pool
   of their own?
