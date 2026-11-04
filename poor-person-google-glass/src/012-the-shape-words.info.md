<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 012-the-shape-words

The describing language's whole vocabulary as Lua tables (issue 007a). docs/shape-words.md is the contract; 017 tests that the two hold the same words.

| Offers | What it is |
|---|---|
| `KINDS` | kind name → { solid (string: box/cylinder/cone/sphere/ring), along, across, deep (numbers, default extents), thin (which extent "thick" means), links ("round", "all" or nil) } |
| `KIND_ALIASES` | other word → kind name |
| `COLOURS`, `DEFAULT_COLOURS` | colour word → {r,g,b}; the order unnamed parts take colours in |
| `EXTENT_WORDS` | size word → "along"/"across"/"deep"/"thin"/"all" |
| `COMPARATIVES`, `DEGREES` | comparative → { extent, +1 or -1 }; degree word → factor (none = 1.5) |
| `RATIOS` | ratio word → number |
| `PLACES`, `DIRECTIONS`, `ALIGNING`, `PROPORTIONS` | phrase → place / axis ("x","y","z") / true / how |
| `JOINING_WORDS`, `GRAMMAR_WORDS`, `DROPPED_WORDS` | sets of words |
| `PHRASES_WITH_ARTICLES`, `PHRASES` | multi-word phrases joined into one word before reading |
| `all_words()` | every legal single word, as a set |
| `kind_of(word)` | a kind word or alias → kind name, or nil |
