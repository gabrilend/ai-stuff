# 503 — Keeping a picture

## Current behavior

Nothing exists. Needs `203` (the extension's menu page) and `403` (the cache).
The exact shape of the request is open question 12 in `docs/008`.

## Intended behavior

**The reader can keep a picture they liked.** Pictures live in the cache, in
RAM by default (`403`); this issue is how one leaves the cache on purpose.

From the Extensions menu (the puzzle-piece button left of the hamburger menu),
the extension's entry opens a page listing the pictures shown recently —
picture, sentence, the quantity, the page it came from. Each has a **save**
action, which hands the PNG to Firefox's own downloads so the reader picks
where it goes. The sentence and quantity go into the file name.

The setting that moves the whole cache to disk instead (`403`'s disk mode) is
on the same page, next to the list, so both ways of keeping pictures are in one
place.

## Suggested implementation steps

1. The host gains a message listing recent cache entries and one returning a
   picture's bytes.
2. `src/extension/` — the recent-pictures page, reached from the Extensions
   menu, with save via the downloads interface (the manifest gains the
   downloads permission).
3. Test: save a picture, confirm the file opens and its name carries the
   quantity; switch the cache to disk mode from the page and confirm the host
   writes there.

## Related

`docs/005-datapath-the-picture.md` · `docs/008-open-questions.md` (12) · needs
`203`, `403` · blocks `504`
