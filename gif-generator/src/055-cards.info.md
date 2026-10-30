# 055-cards — a card beside every film

Every film the studio makes keeps a card beside it, `NAME.gif.card`
(issue 701e; the format is `docs/card-format.md`): its fingerprint, the
score or scene that made it (and the generator behind a generated scene),
its seed, size and frames, the day it was made, what moves in it (from the
score's own first comment paragraph), and its ratings on five tiers,
appended one per line and never edited. The last rating since the film was
last made counts. A film made again with new bytes gets a `refilmed` line,
and starts unrated; its old ratings stay above. The six approved films
start at five.

## Usable surface

- **film_made(film_path, card, approved) → card_path, how** — a film was
  just written: a new card (`new`), a `refilmed` line (`refilmed`), or
  nothing (`kept`). `039-shape-films.lua` and `026-render-main.lua` call it.
- **read(card_path) → card** — fields, `ratings` ({ tier, by, on }) and
  `refilmed` ({ on, fingerprint, after }).
- **tier_of(card) → tier, by** — the tier that counts, or nil.
- **current_fingerprint(card)**, **fingerprint(path)** (by `sha256sum`).
- **rate(card_path, tier, who, date, note)** — one rating, appended.
- **about(score_path)**, **what_made(dir, film_name)** — what a card says
  about where a film came from.
- **write_missing(dir, folder) → count** — a card beside every film with
  none.
- **counts(folder) → report**, **describe(report, folder) → text** — films
  at each tier by kind, films with no card, cards with no film; read from
  the cards alone.

CLI: `luajit src/055-cards.lua DIR --counts|--write [FOLDER]`, or the
root's `count-films [FOLDER] [--write]`.

## Learned from the kanji pool

The house's one built pool is `kanji-learning-image-generator/src/045` to
`048`. Kept from it: the pair of files is the whole store; nothing is
deleted; ratings are appended and the last counts; who rated is on every
line; the picture is written before its card; the counts are a utility,
never a number typed into a document. Done differently: the card ends in
`.card`, not `.info.md` (that is every source file's companion page here);
there is no machine grader yet (the burner's 809 waits the same way, until
one's agreement with her can be measured); there are no category folders,
because the library is one flat folder, so the kind is a field; and a film
made again is marked on its card rather than given a new name.
