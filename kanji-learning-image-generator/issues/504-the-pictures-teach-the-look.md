# 504 — The pictures teach the look

## Current behavior

There are no photographs of any museum in the project. A museum (`501`) is
described in words and the model's own sense of the place does the rest.

The far kitchen (`415`) has the core nodes for conditioning on a picture
(`CLIPVisionLoader`, `CLIPVisionEncode`, `StyleModelLoader`, `StyleModelApply`)
and no models for them. Nothing is installed there without its owner's consent.

**Waiting**, on two things: a collection of photographs worth using, and a
conditioning model on a kitchen whose owner agreed to it.

## Intended behavior

**A museum's own photographs condition the picture**, so "in the manner of"
means the colour, light and materials of those rooms rather than the model's
guess.

**The look is taken from the photographs; the shape is not.** A photograph is a
whole room with its own composition. So the photographs go in through an
image-prompt route (a CLIP-vision encoding applied as conditioning), never
through the masks of `416` or a control net — those belong to the character.
Their strength is a knob with a measured ceiling, above which the character is
lost.

**The photographs live beside the museum record**, `input/museums/<name>/`,
with one line per photograph saying which hall and what kind of view it is, so
a skeleton-hall scene is conditioned on a skeleton-hall photograph.

**The photographs used are recorded in the pool** by filename and a hash of
their bytes.

**A museum with photographs and a kitchen that cannot read them is refused**,
never silently run on words.

## Suggested implementation steps

1. **The conditioning route**, decided by checkpoint: an IP-Adapter for the SDXL
   model (Juggernaut XL), or Redux through the core `StyleModelApply` for the
   Flux-family one (Chroma). Its models added to `415`'s inventory so an absence
   is named before posting.
2. **The museum record grows a photographs folder**; the reader from `501`
   lists them and refuses one without a description line.
3. **Upload** through `415`, nodes added in `029` through `028`.
4. **Strength sweep**, looked at by a person — the machine grader alone is not
   trusted on this (`docs/007`, Q13).
5. **Tests in `035`**: missing model refused by name; the pool record carries
   each photograph's hash.

## Open questions

- Where will the photographs come from, and are they ours to feed a model?

## Related

`501` — the record the photographs join. `415` — the kitchen and its inventory.
`416` — the masks the photographs must stay out of.
