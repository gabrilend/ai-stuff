# 416 — Inside and outside

## Current behavior

**Both routes are built and run on the far kitchen (`415`). Outside works.
Inside works on half of one character, and has been tried on only one.**

- **One recipe per route**, chosen by the kitchen's `workflow.routes`; the local
  kitchen keeps `{ "illusion" }` and writes exactly what it always did. The
  workflow builder is a table of routes (`029.ROUTES`: `build_illusion`,
  `build_inside`, `build_outside`) sharing one sampler box, one seed and one
  save. The illusion route refuses a kitchen with no control net.
- **The sentence is split by kind, not rewritten.** Every clause of the prompt
  is a subject, an object along a stroke, the world, or the style, and a route
  takes a set of kinds (`025.PARTS`: `whole`, `subjects`, `background`,
  `outside`). The background sentence begins with the word *background*. All
  parts carry the style, so the routes share it by construction.
- **Masks come from the same strokes as the field** (`022.mask`, hard-edged,
  thresholded at half; `022.ink`, the strokes painted on paper). `030` writes
  `mask.png` (wide, for things to fit along), `ink.png` and `ink-mask.png`
  (brush weight), and `tone.png` (below), and uploads them all.
- **Outside**: the inked canvas, everything off the strokes redrawn from noise
  under the outside sentence, then the ink pasted back exactly. On 休 the
  forest grew around the character and the character arrived as painted.
- **Inside**, after two designs that failed (both kept as comments in
  `029.build_inside`): the background is drawn first under the background
  sentence; the strokes are laid into it as one flat tone, dark or light by the
  world's polarity; then only the strokes are redrawn, under the subjects
  sentence held to the mask, at strength `routes.inside_denoise`. That strength
  has a cliff — at 0.55 the tone stays a flat cut-out, by 0.74 the character is
  gone — and at 0.62 with the dark tone the 木 half of 休 became **one person
  standing with arms and legs along its strokes**, while the 亻 half was lost
  among dark trunks. The sweep is in `docs/balance-updates.md`.
- **The outside route is never graded by the machine** (`046.grades`); the
  dial, the calibration and the agreement numbers skip it because it carries
  no machine rating. A person may rate it.
- **The pool** names each rendering by route and kitchen (`045.stem`), so the
  two pictures of a character are two files.
- **Tested** in `035` under *inside and outside*.

**Still to do before this is complete:** step 7 below — a dozen characters
across several worlds, both routes, looked at by a person. One character in one
world is not a finding, and the inside route's numbers came from exactly that.

### What it replaced

There was one route from a scene to a picture: the **illusion route**. The
character's strokes become a grey field (`202`), a control net pushes the whole
picture towards that field's light and dark (`302`), and the hope is that the
character emerges out of the scenery when you squint.

It needs a control net, and the far kitchen (`415`) has none.

It also has a known way to fail that its own grader rewards (`docs/007`, Q13):
asked for a crowded picture, the model drew the strokes outright, and the
grader scored that second-best of its run, because nothing matches the field
better than the character itself.

The Wimmelbild style was removed on 2026-10-04 (see `412`). It was the style
that produced that failure, and the owner asked for something better in its
place. This is that.

## Intended behavior

Asked for in these words:

> We can just paint the Kanji over the image and say "you can't generate images
> in here" and then it'd fill the entire remaining space superbly.
>
> or, alternatively, the opposite, which is where you try and only put subjects
> where the lines would be (the layer is made transparent and invisible) and
> everywhere else should be noted as "background" specifically. Two approaches,
> inside and out, we should always do both. They should share style.

**Two routes, both run for every character, sharing one style and one seed.**
Both draw the line between strokes and not-strokes with a mask instead of a
control net — the stroke layer from `202`, thresholded, so it is the same shape
in both.

### Outside — the character is the wall

The character is painted onto the canvas as ink, and the mask over it says *do
not generate here*. The model fills everything else, and the strokes are kept
exactly as painted. The scene grows around the character: things lean on it,
shelter under it, grow up to its edges.

The character is legible by construction, so the picture's job changes: it is
no longer *find the character*, it is *the character with a world around it
that says what it means*.

### Inside — the character is the scene

The stroke layer is never drawn. It is used only as a mask, invisible in the
finished picture. Inside the mask, the prompt names the **subjects** — the
objects the scene grammar (`204`, `411`) already chose for each stroke. Outside
it, the prompt says **background**, specifically and only: the world's setting,
empty of subjects. The character is there only because the subjects are where
the strokes were.

### What they share, and what they do not

| | outside | inside |
|---|---|---|
| style tail, seed, checkpoint, frame | same | same |
| strokes in the finished picture | painted, kept exactly | never drawn |
| mask | strokes protected, rest generated | strokes = subjects, rest = background |
| prompt | the whole scene | split: subjects inside, background outside |
| the four refusals (text, lettering, calligraphy, kanji) | still apply — the ink is ours, and the model must not add more | apply |
| machine grader (`406`) | **recorded but not counted** — correlation with the field is ~1 by construction and says nothing | counted as usual |

**The grader exclusion is the one rule here that matters most.** An outside
picture fed to the agreement statistics or the quality dial would sit at the top
of every ranking for the reason Q13 warns about, and the dial would learn to
prefer it.

**Minimal guidance.** Each route uses the fewest, densest words that state what
it needs, and leaves the rest to the model.

**The illusion route stays** for kitchens with a control net. These two are
added beside it, not over it; a run picks the routes its kitchen can serve, and
`415`'s inventory decides that.

**The pool records which route made a rendering**, as part of its name, so the
two pictures of one character are two files, not one replacing the other.

## Suggested implementation steps

1. **A stroke mask from the field** — `022` already makes the grey field; add a
   thresholded, slightly grown black-and-white version at the kitchen's frame
   size. Mask growth is a pixel number and scales with the frame (`414`).
2. **Outside workflow** in `029`, through the graph builder `028`: the inked
   canvas loaded, the inverted stroke mask applied as the inpaint mask
   (`InpaintModelConditioning` or `VAEEncodeForInpaint` + `SetLatentNoiseMask`),
   the full scene prompt, denoise 1.0 outside the mask.
3. **Inside workflow**: background first over the whole frame; the strokes laid
   in as a flat tone by polarity; the strokes alone redrawn under the subjects
   sentence at a strength below the cliff. (A single pass with each sentence
   held to its side of the mask, and a second pass redrawing the strokes from
   noise, were both tried and both lost the character.)
4. **`025` writes the split prompt** — the subject phrases on their own, and a
   background sentence that is the world with nobody in it. No new English goes
   anywhere but `025`.
5. **Both routes per character in `044`**, the route in the pool name (`045`),
   and the outside route marked as not graded in `046`'s statistics and `047`'s
   dial.
6. **Tests in `035`**: both workflows pass the socket catalogue; the outside
   canvas's stroke pixels equal the mask's; an outside rendering never enters
   the agreement numbers; one character gives two pool entries with one seed.
7. **First real run on the far kitchen** with Juggernaut XL, a dozen characters,
   both routes, looked at by a person before any number is trusted.

## Sub-issues

- `416a` — one material for the strokes: the inside route builds every stroke
  of one stuff that appears nowhere else, hidden past the strokes by a cover;
  the outside route is told the meaning's world only.

## Open questions

- The inside route's dark tone made the character into its subject but hid the
  strokes that fell on dark trunks; the light tone stays a cut-out. Should the
  background sentence be quieter (fewer trunks, more open ground) so dark
  strokes have something light to stand against — or should the tone be chosen
  by the first pass's actual brightness under each stroke instead of by the
  world's polarity? **Partly answered by the owner on 2026-10-06** (`416a`):
  the strokes' material is the only one of its kind, so the background has no
  trunks at all. Whether the tone should still follow polarity is open until
  `416a`'s first pictures are seen.

## Related

`202` — the field the mask is cut from. `204`/`411` — the subjects that go
inside. `412` — styles, and the removed Wimmelbild. `415` — the kitchen these can
run on. `406`/`047` — the grader and dial the outside route must stay out of.
`docs/007` Q13 — why.
