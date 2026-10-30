# The card beside every film

Every film the studio makes keeps a card beside it: `NAME.gif` and
`NAME.gif.card`, two files in the same folder, and that is the whole store
(issue 701e). There is no database and no index. Copy the pair anywhere and
the card comes with the film. Nothing is deleted: not a film, not a card,
not a low rating.

The film tool (`src/039-shape-films.lua`) and the runner
(`src/026-render-main.lua`) write a card when they make a film. The viewer
appends ratings to it. They share no code: this page is what they agree on.

## A card

    film: breathing-solid.gif
    fingerprint: 3fb7c585864e2ebd7d4066fb27b60ab9febff4e9a43ddeb818210cd3bbb462e9
    category: shapes
    score: input/shapes/breathing-solid.lua
    seed: none
    size: 320
    frames: 96
    made: 2026-10-30
    about: one shape breathes between a cube and an octahedron, ...
    ratings:
    - 5 by person on 2026-09-23 (approved before there were cards)
    - 4 by person on 2026-11-02

- **film**: the film's file name.
- **fingerprint**: the SHA-256 of the film's bytes when the card was written.
- **category**: `shapes` (a shape scene), `strokes` (a score of strokes
  alone) or `two spaces` (a score with both). Quality is talked about by
  kind, so counts are kept by kind.
- **score**: the file that made it, from the project folder.
- **generator**: for a generated scene, the program that wrote it.
- **seed**: a score's seed; `none` for a shape scene, which draws the same
  every time.
- **size**, **frames**: the picture's width and height, and its frame count.
- **made**: the day the card was written.
- **about**: what moves in it, from the first paragraph of comments at the
  top of its score.
- **ratings:** then one line per rating, appended, never edited.

Fields are `name: value`, one per line, in this order; a field with nothing
to say is left out.

## Ratings

    - TIER by WHO on YYYY-MM-DD
    - TIER by WHO on YYYY-MM-DD (a note)

Five tiers, the house's one scale:

| Tier | Meaning |
|------|---------|
| 5 | reach for it first |
| 4 | use freely |
| 3 | fine among others |
| 2 | kept but not reached for |
| 1 | the record of what missed |

`WHO` is `person` for now. A machine grader joins only once its agreement
with her is measured, and its ratings will say `by machine`, so the two
can always be told apart. The last rating counts; the ones before it stay,
as the history.

The six films approved on 2026-09-23 start at five, by that approval
(`tests/shape-films/approved-films.lua` keeps their fingerprints too).

## A film made again

When a film is made again and its bytes differ, it is a different film. Its
card gains a line, and only ratings after it count for the new film:

    - refilmed on 2026-11-02: fingerprint <sha256> (ratings above are for the film before)

If the new bytes are an approved film's, the approval follows on the next
line. Made again with the same bytes, the card is left as it is.

## Tools

- `count-films [FOLDER]` (or `luajit src/055-cards.lua DIR --counts FOLDER`):
  how many films sit at each tier, by kind, read from the cards alone.
- `count-films [FOLDER] --write`: first, a card beside every film that has
  none, from the score of the same name.
- `view-gifs`: keys 1 to 5 rate the gif on screen.
