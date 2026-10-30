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

## What Happened

Built 2026-10-30 on top of 701d. `./test-shape-films` is 300 of 300 (22
new checks in `src/056-cards-test.lua`), and all 34 shape films still film
byte-identical; each now comes out with a card beside it.

- **Learned from the kanji pool first (step 0).** Kept: the film and its
  card are the whole store; nothing is deleted; ratings are appended and
  the last one counts; who rated is on every line; the film is written
  before its card; counts come from a tool, never a typed number. Done
  differently: the card suffix, no machine grader yet, no category
  folders (the library is one flat folder, so the kind is a field), and a
  film made again is marked on its card instead of renamed. The full note
  is in `src/055-cards.info.md`.
- **The card (step 1).** `NAME.gif.card`, so it can never be mistaken for
  a source file's `.info.md`. Fields: film, fingerprint, category, score,
  generator, seed, size, frames, made, about, then `ratings:` and one line
  per rating. `docs/card-format.md` is the page the maker and the viewer
  agree on. When a film is made again into different bytes, its card says
  so on a `refilmed` line with the new fingerprint; the ratings above stay
  as the record but no longer count. Made again into an approved film's
  bytes, the approval is carried again.
- **Cards for the 34 (step 2).** The film tool writes a card for every
  film it makes, and `./count-films --write` writes one for any film in a
  folder that has none, finding the score by the film's name. The six
  approved films start at `- 5 by person on 2026-09-23 (approved before
  there were cards)`, found by their fingerprint, whatever they are named;
  `tests/shape-films/approved-films.lua` and its test stay as they were.
  Her 34 at `/home/ritz/pictures/shape-gifs/` get their cards when she
  runs `./count-films --write` (or `./render-all-shapes --library`) on her
  machine; nothing here can reach that folder.
- **The viewer rates (step 3).** Keys 1 to 5, in both views, append a
  rating to the card of the film on screen, and the footer shows its
  tier. `viewer/rate.lua` reads and appends cards from the format page
  alone, sharing no code with the maker; a film with no card is refused
  with a pointer to `./count-films --write`. LÖVE isn't installed here, so
  the window itself is untested; `rate.lua`'s reading and appending are
  tested from the suite.
- **The counting tool (step 4).** `./count-films [FOLDER]` reports each
  kind's films at each tier, unrated, and waiting on a new rating after a
  refilm, plus films with no card and cards with no film. Pointing the
  studio skill's pool section at it is left to 701f, which writes the
  skill.

Open question 1, decided by default and easy to undo: 2D renders join the
same pool and the same cards. The runner writes a card for every score it
films, with category `strokes` or `two spaces`, and the counts keep each
kind apart. If she'd rather they had a pool of their own, it's the runner's
one `film_made` call and the folder it writes to.
