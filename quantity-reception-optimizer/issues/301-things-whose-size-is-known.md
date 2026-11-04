# 301 — Things whose size is known

## Current behavior

Nothing exists. Needs `101` for the dimension vocabulary.

## Intended behavior

**The reference catalogue: a data file of objects whose size, weight, force or
volume is known, each with where that number came from.** Fields are in
`docs/004-datapath-the-analogy.md`: name, kind, dimension, SI value, a phrase
for asking an image generator to draw one, and a source — plus two fields the
picture layout (`401`) needs: `packing` (string, `grid` for boxes and
vehicles, `hex` for round or piled things) and `footprint_aspect` (number,
width ÷ height of the object as seen in the picture).

Bare numbers (dimension `count`) have no catalogue candidates; the language
model names the object (`303`).

And a function that, given a quantity record, returns every candidate: each
object of the same dimension, with the count — the quantity's SI value divided
by the object's — already computed. **The count is the host's work, never the
language model's.**

**Coverage before cleverness.** Every dimension in the lexicon has objects in
at least four kinds, spread across scales from small (a paperclip, a coin) to
enormous (a container ship, a football pitch), so that any quantity a page is
likely to hold has some object it comes out between 1 and 30 of. The vision's
own examples are in it: a horse pulling a cart (force), sacks of flour (mass).

**Drawable counts.** Every object in the picture is drawn individually, so the
count is exact — 11.2 sacks is eleven sacks and a fifth of one sticking off the
frame's edge (`401`). A candidate whose count is below 1 or above the most
objects one picture can hold is still returned but marked as not drawable;
`303` offers only drawable ones. The upper bound is one setting in the settings
file, shared with the layout in `401`, which is where it is enforced and where
its value is tuned.

## Suggested implementation steps

1. `assets/` — the catalogue, a Lua table file, one entry per object, each with
   its source in a comment as well as in the field.
2. `src/` — the catalogue module: load; check every entry's dimension exists in
   the lexicon and its value is positive; the candidates function.
3. A coverage report: for each dimension, the range of SI values for which at
   least one drawable candidate exists, and any gaps. The phase demo reads it.
4. Tests: the vision's examples (99 N, 15 lb of flour, 1234 kg, 15 m²) each get
   drawable candidates in at least three kinds.

## Related

`docs/004-datapath-the-analogy.md` · needs `101` · blocks `302`, `303`
