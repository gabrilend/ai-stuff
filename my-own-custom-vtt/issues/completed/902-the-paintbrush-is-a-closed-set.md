# 902 -- The paintbrush is a closed set

**Phase:** 9, the sprite studio
**Blocked by:** [901](901-a-sprite-is-an-animated-svg.md)
**Blocks:** [903](903-the-pool-keeps-everything.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

**Done.** Twelve words: four shapes, three palette slots, five motions. One table
per kind, read forwards for names and backwards for words, plus a flat list that
both the documentation and the edit-distance suggester come from.

An unknown word returns the COUNT for its kind, which is not a legal value, so a
caller that stores one without checking gets a loud failure rather than a sprite
that quietly became a circle. There is no "and otherwise".

The vocabulary was extracted rather than invented: four shapes because those are
what the encoder draws, three slots because that is what a layer can tint from,
five motions because those are what the file can declare. When the sprites needed
to read as creatures rather than as piles, the answer was mirrored detail pairs —
which cost no new words — rather than adding shapes. A vocabulary grows once and
never shrinks.

`sprite_nearest_word` offers the word probably meant, under two conditions: at
most three edits, **and** fewer edits than the length of the word being corrected.
The second was missing at first and the test caught it — an empty word was being
offered `bob`, because three edits is the whole of a three-letter word. The
identical bug lived in the description parser's suggester and was fixed the same
way.

## Intended behaviour

**The paintbrush**: the closed set of legal moves this project offers. Two halves
that must not drift apart.

**The document half** — every word a sprite description may speak, and what each
means. A contract, readable by a person.

**The executable half** — the table of permitted constructors, which the wall
checks against.

### Closed is the whole point

A paintbrush is defined by what it refuses. Handed a long reference describing an
API, anything generating descriptions will invent plausible neighbouring calls
that do not exist — confidently and in good style. This is true of a person
working fast and much truer of a language model.

**Prefer a closed allowlist over a complete reference, and prefer it hardest
exactly when the temptation to document everything is strongest.**

### It is extracted, not designed

The renderer decides what a layer can be, which animation states it can drive,
which palette slots it can tint. The paintbrush is **read out of the renderer**,
not invented beside it — adding words the project does not have is how a
paintbrush stops describing its project.

### The wall

Same discipline as the description language in
[801](completed/801-a-description-is-validated-first.md): every error names the
entry and the field, carries the nearest legal word, all errors reported at once,
and nothing quietly filled in.

The vocabulary being small is what makes edit distance meaningful.

## Suggested implementation steps

1. Derive the vocabulary from what the renderer can actually draw.
2. One table, from which both the wall and the documentation come.
3. Report every fault at once, with suggestions.
4. Write the companion `.info.md`, listing the vocabulary — that listing is the
   contract.
5. Test that a word the renderer cannot draw is refused rather than ignored.
