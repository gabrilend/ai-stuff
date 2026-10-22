# 104 — Similarity as the angle between word counts

phase 1, the fit and the fade

## Current behavior

Nothing exists. The measure is designed in `docs/datapath-relevance.md`,
"Measuring the same thought, reworded".

## Intended behavior

A table of similarity measures, chosen by name in the page keeper's input
file. The first and only entry for now is `word-angle`:

- **word counts**: text (string) in, a table from word (lowercased string) to
  count (whole number) out. Words are runs of letters and digits. Everything
  else separates them.
- **similarity**: two word-count tables in, a decimal from 0 to 1 out, the
  cosine of the angle between them as arrows with one direction per word.
  Two empty tables are an error, because an empty thought cannot exist (102
  drops empty lines).

The table shape (name to a pair of functions: make a position, compare two
positions) is what lets a later measure, such as word embeddings, be added
without touching relevance (105).

## Suggested implementation steps

1. Word splitting with Lua patterns that treat UTF-8 letters as word
   characters (bytes 0x80 and above are part of words).
2. Cosine over the smaller table's words.
3. Tests: identical text gives 1; no shared words gives 0; word order does
   not matter; "the model is too big" against "the model is too small" is
   recorded as a known high score, so the measure's blind spot is written
   down in a test.

## Related documents

- `docs/datapath-relevance.md`

## Blocked by

None.

## Blocks

105.
