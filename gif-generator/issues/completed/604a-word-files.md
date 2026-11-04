# 604a — word files

Part of 604. Depends on: nothing. Blocks: 604b, 604c, 604d.

## Status: completed

## Current Behavior

Built as described below. `src/034-words.lua` loads and checks word files
(`load_all`, `load_one`, `check`, and `--check WORD` as a command);
`src/022-score.lua` offers `pattern{}` and `score.shapes()` (the shape
constructors, shared with word files), and `score.read(path, vocabulary)`
takes the loaded words as a second argument; the runner (`026`) and the
stats utility (`030`) load the words once per run. `words/ring.lua` (a
pattern: a whole circle as two half-arcs, odd tenths kept in tenths) and
`words/slowly.lua` (plain) are the worked examples. `docs/score-format.md`
has a Patterns section. `src/035-words-test.lua`: 17 checks passing; every
older test still passes.

Before this, a score could only use the closed vocabulary, with no way to
name a recurring shape once and reuse it.

## Intended Behavior

**One file per word**, in `words/`, named for the word: `words/spiral.lua`.
A word file returns a table:

| field | type | meaning |
|-------|------|---------|
| `word` | string | the word, lower case, matching the file name |
| `aliases` | list of strings | other spellings and forms that mean the same (`spirals`, `spiralling`) |
| `kind` | string | `"pattern"` (draws something) or `"plain"` (understood; nothing new to draw) |
| `meaning` | string | one or two sentences: what the word draws, or how to read it in the score's terms |
| `fields` | table, patterns only | each extra field the pattern takes, with a one-line description |
| `expand` | function, patterns only | `expand(call)` → a list of stroke tables in the ordinary vocabulary |
| `example` | string, patterns only | one `pattern{...}` call that renders |

A word file is **pure**: it is loaded in a sandbox offering only `math`,
`string`, `table`, `ipairs`, `pairs`, `type`, `tostring`, `tonumber`,
`error`, and the score constructors (`arc`, `line`, `point`, `fill`,
`tip`). It cannot read files, run commands or keep state.

**`pattern{ name = "spiral", at = 0.0, lasts = 3.0, color = "ember", ... }`**
becomes part of the score vocabulary. The reader loads the named word file
and replaces the call with the strokes `expand` returns, each marked with a
comment naming the pattern; the wall then checks those strokes like any
others. So the pipeline still only ever sees ordinary strokes, and a
pattern that expands into something illegal is refused by the same wall
with the same teaching. An unknown pattern name is refused with the nearest
known word.

Word files are named for their word, not numbered: they are looked up by
name, and their order means nothing. (An exception to the numbered reading
order, as `input/` scores are.)

## Suggested Implementation Steps

1. `src/034-words.lua`: list `words/`, load each file in the sandbox,
   check the contract (every field present and the right type, file name
   equals `word`), and return the word table and an alias index. Refusals
   name the file and the field.
2. In `src/022-score.lua`: add `pattern` to the sandbox; expand through the
   word table; carry the pattern name as a comment.
3. `src/035-words-test.lua`: a good pattern expands and compiles; a plain
   word loads; a bad file (missing field, wrong name, a call to `io`) is
   refused with its name; an unknown pattern name teaches the nearest.
4. `docs/score-format.md`: the `pattern` call and the word-file contract.
5. Seed `words/` with two examples written by hand, so the contract has a
   worked case: a pattern (`ring`, a full circle) and a plain word (`slowly`).
