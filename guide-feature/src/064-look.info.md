# 064-look — info

The look tool (issue 503): the pieces of the project nearest a model's
words, a few close ones (focused) or a wide spread (broad), with their
source text. The turn (055, its `looker`) answers every look call with it.

    luajit src/064-look.lua --project FOLDER --url EMBEDDER-URL [--timeout S] \
        [--count-url CHAT-URL] [--focus 0..1|focused|broad] WORDS...

| Function | Meaning |
|---|---|
| `answer(opts)` | the answer the model reads, and `{ refused, why, chosen, pieces, shown, left_out, count, nearest, farthest, tokens, seconds }`. opts: `project` (the clone's project folder), `commit` (the clone's, in full), `embedder` (an endpoint), `words`, `focus` (0 to 1), `name` (the focus as the model wrote it), `values` (`input/look`), `count_tokens`; `embed` and `model_name` as seams |
| `find(opts)` | the pieces chosen, without their text, or `{ refused, why }` |
| `ranks(n, focus, values)` | the ranks chosen out of n, 1 the nearest |
| `score(found, query)` | every piece's similarity in one pass; the piece numbers ranked |
| `source(project, piece, cache)` | a piece's lines from the clone's file |
| `label(piece)`, `describe(info)` | the piece's label; the log line |
| `read_settings(root)`, `focus_of(word, values)` | `input/look`, checked; a focus word as a number |
| `REFUSED`, `NOTHING` | why a look has nothing to show, by kind, as the model reads it |

Choosing: `nearest` pieces at focus 1, `spread` at 0, a straight line
between, evenly spaced from rank 1 to `(1 - focus) ^ curve` of the way to
the last rank. Filled nearest first to `budget` tokens; a piece that does
not fit is left out and counted. Refused, never answered from other files:
no clone, no index, an index at another commit or by another rule or
model, vectors of another length, no embedder, no names in the words.

Settings: `input/look`: `focused`, `broad` (decimals, 0 to 1), `nearest`,
`spread` (whole), `curve` (decimal above 0), `budget` (tokens).
