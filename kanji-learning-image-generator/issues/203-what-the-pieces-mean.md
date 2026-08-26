# 203 — What the pieces mean

## Current behavior

A record says 休 contains 人 and 木. Nothing knows that those are a person and a
tree, or what a person and a tree look like.

## Intended behavior

**A component character in, a depictable thing out.**

`docs/004` establishes why this matters: the components are the etymology, and the
etymology is why the picture can be true rather than invented.

**Most of it is derived, not written.** A component is usually a kanji in its own
right, and its meanings are already in the record store. 木 is glossed *tree,
wood* by KANJIDIC2, and no human needs to type that here. The lexicon's first
move is always to look the component up in the store everything else uses.

**The written part is small and is exactly the part derivation cannot do.** Three
kinds of gap:

- **Components that are not standalone characters.** 亠, 冖, 廴, 辶 and their kind
  appear only inside other characters and have no dictionary entry to read.
- **Glosses that are true and unpaintable.** A component glossed *rule, law,
  measure* is correct and cannot be drawn. The written entry says what the shape
  depicts — a measuring rod — which is a different question from what it means.
- **Glosses that would mislead the scene.** A component whose primary gloss is a
  grammatical function rather than a thing.

Every written entry is marked as written, so the report can say how much of a
given character's imagery came from the dictionary and how much from us.

**A component with no gloss from either source is counted and named, never
skipped silently.** `docs/004` calls this a de-selection to *structure*: its
strokes become terrain rather than nothing. The count appears in every batch
report, and a component appearing often in that report is the next entry somebody
should write. That report is the maintenance mechanism for this file, and without
it the lexicon would only ever grow by accident.

**Each entry also carries a biome affinity**, because the component is the
strongest evidence there is for what world the character belongs to (`docs/004`
weighs it above a keyword). 水 says water, 火 says fire, 艹 says growing things,
宀 says a building, 彳 says a road.

## Suggested implementation steps

1. **`src/023-the-component-lexicon.lua`** — the derivation, the written table,
   the merge, and the counting.

2. **Written entries are a table of rows** — component, what it depicts, biome
   affinity, and a note on why it needed writing. The note is the thing that stops
   the table becoming folklore: a future reader can tell a real gloss from a guess.

3. **Cover the productive components first, and let the report choose the rest.**
   The traditional radicals in their combining forms are where the volume is.
   Beyond those, the batch report's frequency ordering says which one to write
   next, and that is a better ordering than anyone's intuition.

4. **Test that coverage is measured rather than assumed.** Run the lexicon over
   every component in the archive and report what fraction resolved, from which
   source. The test asserts the machinery works, not that coverage is high —
   coverage is a number that should be looked at, not a threshold that turns red.

## Open question

`docs/007` Q6 asks whether the written half belongs in a source file at all, or
should be a data file editable by somebody who knows kanji and not Lua. Unresolved,
and the answer gets more expensive the more rows are written.

## Related

`docs/004` — how the lexicon is used. `102` — the store it derives from.
