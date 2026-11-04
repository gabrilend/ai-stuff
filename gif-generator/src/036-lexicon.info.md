# 036-lexicon — which words the studio knows

`unknown(prose, vocabulary)` → a list of `{ word, sentence }`, the words the
studio does not know, in order of first appearance, each with the sentence
it came from. `known_set(vocabulary)` → the set of known words.

Known: score vocabulary words (read from the palette, easing, emitter tables
and the shape words), a short plain-English list kept in this file, and
every word file's word and aliases. Words under three letters are known; a
simple inflection (-s, -es, -ed, -ing, -ly, -er, -est) of a known word is
known; an unknown word claims its own inflections, so "hands" and "hand"
start one session between them. Sentences end at `.`, `!`, `?` or a blank
line. `vocabulary` is what `034-words.load_all` returns.
