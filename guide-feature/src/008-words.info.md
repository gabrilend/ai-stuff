# 008-words — info

The word finder (issue 103): a canvas's words, which word covers each cell,
and the sentences they make. The change finder (104), the blit (106) and the
marks (201) all stand on it.

A **word** is a run of characters with no space in it
(`docs/datapath-blit.md`, "Words"). It is a record of `row`, `column` (of its
first character), `length` (in characters) and `text`. Words never wrap: one
that reaches the end of a row ends there. Columns and lengths are counted in
characters by `005-utf8.lua`.

A **sentence** is the words in reading order up to a word that ends one, or
up to an entirely empty row (`docs/canvas-format.md`). A word ends a sentence
when its last character is `.`, `!` or `?`, looking past closing quotes and
brackets (`"go."`, `(left!)`, `“yes?”`). A full stop inside a word (`3.14`)
doesn't end one, and a word ending in one always does, abbreviation or not
(`e.g.`). The last words of a canvas are a sentence even with no full stop.

| Name | Type | Meaning |
|---|---|---|
| `find(rows)` | function | the words, in reading order. A row that is not UTF-8 is refused |
| `owners(words, width, height)` | function | `owner[row][column]`: the number of the word on that cell, or nil. A word off the canvas is refused |
| `sentences(words, height)` | function | the sentences (lists of word numbers) and `sentence_of[word number]` |
| `ends_sentence(text)` | function | whether a word ends its sentence |
| `of_canvas(record)` | function | `{ words, owner, sentences, sentence_of }` for a canvas record (006) |
| `SENTENCE_ENDS`, `CLOSERS` | tables | the characters that end a sentence, and those looked past |

Tests: `009-test-words.lua`.
