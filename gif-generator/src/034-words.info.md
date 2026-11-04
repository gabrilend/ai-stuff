# 034-words — the word files

One file per word in `words/`, saying what the word means to the studio:
a **pattern** expands into ordinary strokes; a **plain** word is understood
and draws nothing new. The contract is in `docs/score-format.md`
(*Patterns*). Word files load in a sandbox (math, string, table, ipairs,
pairs, type, tostring, tonumber, error, and the shape constructors).

## Usable surface

- **load_all(dir) → vocabulary** — every word file in `dir/words/`.
  `vocabulary.entries` (word → entry), `.patterns` (word or alias → entry,
  patterns only), `.forms` (word or alias → word), `.nearest(name)` (the
  closest pattern word). Any file breaking the contract stops the load,
  with every problem of every file listed.
- **load_one(dir, name) → entry | nil, problems** — one file.
- **check(dir, name) → true | false, problems** — the contract, and for a
  pattern its `example` expanded and put through the compiler's wall.

As a command: `luajit src/034-words.lua --check WORD [DIR]` prints `ok` or
every problem; exit 0 or 1. Word sessions (604c) run it on their own file.

The score reader takes the vocabulary as its second argument
(`score.read(path, vocabulary)`); the runner and the stats utility load it
once per run.
