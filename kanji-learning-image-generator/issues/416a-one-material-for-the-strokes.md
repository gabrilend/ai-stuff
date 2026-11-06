# 416a — One material for the strokes

## Current behavior

**Designed, not built.** Shown by printing what each route is told for 木, 文
and 才 on the far kitchen (2026-10-06):

- **The inside route's strokes are told about several different things.** The
  subjects sentence names the character's pieces and one object per stroke
  shape from the world's role list. For 木 in the forest that means "tree
  standing as an upright, tree lying as a level bar..."; but the forest's own
  role list also makes strokes into "a shaft of light" and "a small bird", so
  one character's strokes can be four kinds of thing at once.
- **The inside route's background contains the strokes' own material.** 木's
  background sentence says "between the trunks, wet bark". The second pass
  draws trunks inside the strokes, but the first pass has already drawn trunks
  everywhere else, so the strokes are camouflaged. This is the failure `416`'s
  open question describes (休's 亻 half lost among dark trunks).
- **The outside route is told about pieces that have nothing to do with the
  meaning.** 文 (writing) is told "(two crossed sticks:1.2) in the middle
  centre, a lid resting on top"; 才 (talent) is told "(a working hand:1.2),
  fingers". Those come from what the character is *drawn* with, and the owner
  saw them as backgrounds that did not relate to the character.

## Intended behavior

Asked for in these words:

> for the one where the strokes are excluded from image generation, the
> background should be a forest. For the one where the strokes comprise the
> image, the strokes should be like... treetrunks that grew into that shape,
> and the parts that are not strokes (but which logically would be tree)
> should be hidden by leaves or something. Pick one material or object or
> something to represent the strokes, and that can be the ONLY example of that
> object / material type in the image.

**Every world has one stroke material and one cover.**

- **The material** is what every stroke of a character in that world is made
  of: in the forest, living tree trunks grown into the shape. One material for
  all strokes, never a mix.
- **The material appears nowhere else in the picture.** The background pass is
  forbidden it (it goes into that pass's refusals), and any clause of the
  background sentence that mentions it is left out.
- **The cover** is what hides the places where the material would logically
  carry on past the strokes: in the forest, dense leaves. It is named in the
  background sentence, so the trunks seem to go *behind* something rather than
  stop in mid-air.

**The outside route is told the meaning's world only**: its setting, its light
and its palette. Not the pieces, and not the strokes. For 木 that is the
woodland.

**Every world must have both.** A world with no material or no cover is an
error naming the world, not a quiet return to the old sentence.

## Suggested implementation steps

1. **`024` BIOMES**: each world gains `material` — the phrase for what the
   strokes are made of, the words that recognise it in other clauses, and the
   cover phrase. All seventeen worlds at once. A test asserts that every world
   has all three.
2. **`025` PARTS**:
   - `subjects` (inside, strokes) becomes the material, weighted, plus the
     style. The pieces and the per-stroke role list are no longer said there.
   - `background` (inside, everywhere else) becomes "background", the world's
     clauses minus any that name the material, plus the cover, plus the style.
   - `outside` becomes the world and the style only.
   - The illusion route's `whole` is unchanged.
3. **`025.prompts`** returns a second refusal sentence, the background's: the
   ordinary refusals plus the material.
4. **`029.build_inside`**: the first pass (background over the whole frame)
   uses that second refusal sentence. The second pass (strokes) keeps the
   ordinary refusals.
5. **Tests in `035`**: for 木, the background sentence contains no trunk or
   bark, the background refusals do, the subjects sentence names trunks and
   nothing from the role list, and the outside sentence carries no subject.
6. **First run**: 木, 文, 才 on the far kitchen with Chroma, at most three
   pictures per turn, looked at by the owner.

## Open questions

- 才 (talent) lands in the person world: "a figure alone in a plain room". Is
  that the right world for *talent*, or should talent and ability have a world
  of their own?
- The forest material is trunks and the cover is leaves. What are the right
  material and cover for each of the other sixteen worlds? The first set is
  written by Claude and is a proposal, to be looked at world by world.

## Related

`416` — the two routes this changes. `024` — the worlds. `025` — the
sentences. `029` — the inside route's two passes.
