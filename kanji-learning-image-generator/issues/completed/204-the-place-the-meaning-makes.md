# 204 — The place the meaning makes

## Current behavior

Done. `src/024-the-scene-grammar.lua` holds the seventeen worlds, the scoring,
the subject selection and the role assignment, and reports on itself two ways:

```
luajit src/024-the-scene-grammar.lua --chars 休語時川
luajit src/024-the-scene-grammar.lua --spread
```

**Two mistakes, and both put a character in the wrong world while producing a
picture that would have looked perfectly good.**

*The sound half was demoted and its insides were not.* The archive marks the
phonetic piece and says nothing about the pieces inside it — being a component of
a phonetic component is not a property anybody catalogues — but those inner
pieces are exactly as unrelated to the meaning, and they vote. 語 is a speech
radical beside a phonetic half that contains two mouths; the two mouths outvoted
the speech radical and the scene came out as a person alone in a room. 時 is a
sun beside a phonetic half containing earth, and the earth outvoted the sun into
a rice paddy.

*The outermost component was skipped.* It restates the character rather than
describing it, which is true for compounds and leaves atomic characters with no
component evidence at all. 一, 十, 大 and 車 scored nothing anywhere and were
reported as belonging to no world — and they are among the first characters
anybody learns.

**The tie-break is not the classical radical.** The archive gives that as a
catalogue *number*, and turning a number into a world would have needed a
two-hundred-row table restating what the decomposition already says better. Ties
go to the order the worlds are written in, which means nothing and is at least
the same on every run.

**Characters that match nothing are still reported and still refused.** Run
`--spread` for how many. That refusal is the ticket's central decision and it
holds: a default world would put an unknown share of the output into generic
landscapes with no relation to their characters, and every one of those pictures
would look fine.

## Intended behavior

**One record in, one scene out.** The scene is a table and contains no prose —
`docs/004` is the design and the no-prose rule is the part most likely to be
eroded, because it is always tempting to build a sentence here where the
information is. `205` builds sentences. This decides facts.

Four answers, in order, each narrowing the next:

**The biome**, by scoring rather than branching. Every biome has trigger words
and trigger components; meanings and components are looked up; highest score
wins; the primary meaning weighs more than later glosses; a semantic component
weighs more than a keyword; the classical radical breaks ties.

**A character that scores nothing is reported, not defaulted.** A silent default
biome would mean some unknown fraction of the output is a generic landscape
unrelated to its character, and every one of those images would look fine. This
is the most dangerous fallback available in this project and it is refused.

**The subjects**, being the non-phonetic components that the lexicon could gloss,
each with the bounding box of its own strokes so the prompt can say *in the left
third* rather than *on the left*.

**The two demotions** from `docs/004`, both to something specific:

- phonetic components (`kvg:phon`) are de-selected from subjecthood and
  re-selected as landscape — their strokes become ridgelines, paths, rock faces
- unglossable components are de-selected from subjecthood and re-selected as
  structure, and counted

**A role for every stroke**, from its measurement and the biome's vocabulary. The
same long vertical is a cedar trunk in a forest and a cataract in water.
Measurement is universal; vocabulary is per biome.

**Which strokes are named**, being the heaviest few. The count is a setting.

**Polarity**, from the biome.

### The biome table is the interesting artifact

It is a table of worlds, each with a name, its triggers, its palette, its light,
its Japanese register, its polarity, and its per-direction stroke vocabulary. It
is the most opinionated thing in this project and it should be readable straight
through as a list of worlds a kanji can be about.

Registers matter more than they look. *Forest* is not a world — a Hokkaido birch
stand, a Kyoto temple grove and a satoyama woodland edge are three worlds, and
naming which one is what the vision meant by cultural context being baked into
the imagery rather than added to it.

## Suggested implementation steps

1. **`src/024-the-scene-grammar.lua`** — the biome table, the scoring, the
   subject selection, the role assignment.

2. **Readings inform register.** A character with only *on* readings is usually
   abstract and borrowed; one with *kun* readings is usually concrete and native.
   That is a real signal about how literal the scene should be and it costs one
   lookup in a record that already has the readings.

3. **Test the reasoning, not the wording.** 木 must land in forest, 川 in water,
   山 in mountain, 火 in fire. 休 must produce two subjects and neither phonetic.
   A known phono-semantic compound must produce exactly one subject and one
   landscape component. None of those assertions mention a single English word of
   prompt, which is the point of the scene being a table.

4. **Report the biome distribution over the whole set.** If four thousand
   characters land in three biomes, the trigger lists are too thin, and that is
   invisible from any single character.

## Related

`docs/004` — the design. `201` — measurements. `203` — the lexicon.
