# 010-changes — info

The change finder (issue 104): what a voice changed, measured against its
base, the version it started from. Never against the shared canvas as it is
now, which this file never sees (the owner's choice,
`docs/datapath-blit.md`, step 1). The fit check (105) takes its counts from
here and the blit (106) its words, so the two cannot disagree about what
changed.

## The lists

Words are compared by place: row, column and text.

| List | What |
|---|---|
| `kept` | the same text at the same row and column in both. Each entry has `base` and `voice`, its number in each list |
| `written` | in the voice's canvas, not identically in the base: new, different or moved |
| `removed` | in the base, not identically in the voice's canvas, and its cells there all spaces: erased |
| `overwritten` | in the base, not kept, and its cells in the voice's canvas not all spaces: a written word covers some of it. Not a change of its own; what happens to it on the shared canvas is the blit's collision rule |

Each word is a word record from 008 with `number`, its place in its own
canvas's word list. A cell past the end of a row counts as a space, since
rows may be written without trailing spaces.

## The counts

- `words_changed`: written plus removed.
- `sentences_rewritten`: sentences of the base in which no word was kept.
  An erased sentence counts, and so does a replaced one; a sentence with one
  word kept doesn't.

A moved word is written at its new place, and its old place is overwritten or
removed. So adding a space early in a row moves, and counts, every word after
it. That is the document's rule, and it is the right advice to give a voice:
writing over a word in place changes less than pushing a row along.

| Name | Type | Meaning |
|---|---|---|
| `find(base, voice)` | function | canvas records (006) or lists of rows, the same number of rows each; returns the lists and counts above |

Tests: `011-test-changes.lua`.
