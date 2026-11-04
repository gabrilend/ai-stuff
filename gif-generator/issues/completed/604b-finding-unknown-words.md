# 604b — finding unknown words

Part of 604. Depends on: 604a. Blocks: 604c.

## Status: completed

## Current Behavior

Built as described below, in `src/036-lexicon.lua`, with one addition
found while testing it on the vision's own paragraph (five unknown words:
hands, oriented, inward, reversed, hand): **an unknown word claims its own
inflections**, so "hands" and "hand" start one session between them, in
either order. `src/037-lexicon-test.lua`: 9 checks passing.

Before this, nothing decided whether a word in a person's prose meant
anything to the studio.

## Intended Behavior

`src/036-lexicon.lua`: `unknown(prose, words)` returns the unrecognized
words in the order they first appear, each with the sentence it came from.

A word is **known** when it is any of:

- a score vocabulary word (hue names, fades, easings, shape kinds, clock
  words, field names), read from the same tables the wall uses;
- a plain English word from the house list (`src/036-lexicon.lua` holds it:
  articles, pronouns, prepositions, common verbs and adverbs, numbers and
  number words, colours that are not hues);
- a `word` or alias in any word file.

Words are lower-cased; punctuation and numbers are stripped; words shorter
than three letters are known. A simple plural or `-ing`/`-ed`/`-ly` form of
a known word is known (spirals → spiral), so one concept spawns one session.

## Suggested Implementation Steps

1. The plain-English list, and the vocabulary words taken from the score
   and compiler tables.
2. Tokenising, sentence capture, the suffix rule.
3. `src/037-lexicon-test.lua`: the vision's own paragraph yields a short,
   sensible list; a word with a file is known; its alias is known; a
   plural is known; order and sentences are kept.
