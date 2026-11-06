# 102 — Finding a quantity in a sentence

## Current behavior

Nothing exists. Depends on `101` for the unit lookup.

## Intended behavior

**Given a paragraph's text and the character range of the word under the
pointer, return the one quantity record that word belongs to, or the answer "no
quantity here".** The record's fields are in `docs/003-datapath-the-quantity.md`.

The reader may be pointing at the number (`1234`), at the unit (`kg`), or at a
word that contains both (`15m2`). All three find the same record. So the
scanner starts at the pointer's word and looks outward in both directions, a
few words at most, for a number next to a unit.

**Numbers as people write them:**

- thousands separators: `1,234`, `1 234`, `1.234`. When the page's declared
  language settles which mark is the decimal point, it is used. When it does
  not (no declared language, or `1.234` where either reading is possible), the
  record carries **both readings** with `ambiguous = true`, and the language
  model picks one from the paragraph (`303`) — the owner's answer to open
  question 7 in `docs/008`
- decimals: `1234.5`, `1234,5`
- signs and approximations: `-40 °C`, `~15 kg`, `about 15 kg` (the word
  "about" is not part of the quantity, but is noted as `approximate = true`)
- ranges: `10–15 kg`, `10-15 kg`, `10 to 15 kg` → `value` and `value_high`
- scale words: `1.2 million tonnes`, `3 thousand km`
- unit before number: `$`-style is out of scope; currency is not a physical
  quantity

**A bare number is a quantity too.** `1234` with no unit within reach is read
with the dimension `count`: the model chooses what to draw that many of (`303`).
A number followed by an unknown word (`55 crocodiles`) is also a `count`, and
the unknown word is kept as `counted_noun` — the page already said what is
being counted, so the model is told to draw that. Unknown words are also
written to the log, so the lexicon can grow from real misses.

Numbers that are not amounts are not quantities: years (`in 1998`), page and
section numbers, phone numbers, dates, version strings. These are recognised by
shape and context and answered "no quantity here".

## Suggested implementation steps

1. `src/` — the number reader: from a starting character, read one number in
   any of the forms above and report where it ended. A dispatch table keyed by
   the next character decides which form is being read.
2. `src/` — the quantity finder: from the pointer's word, try number-then-unit
   at each nearby position, using the lexicon's longest-match lookup from `101`.
3. A file of test sentences, each with the pointer's word marked and the
   expected record (or "none") beside it. Every form listed above has at least
   one sentence. Real sentences gathered from the web are preferred to invented
   ones; `103`'s capture page produces them.
4. A miss counter: across the test file, how many quantities were found, how
   many missed, how many found wrongly. The phase demo reads it.

## Related

`docs/003-datapath-the-quantity.md` · needs `101` · blocks `106`, `303`
