# 022-the-structure-field — info

Builds the grey image that makes a picture secretly be a character.

For a general: a diffusion model can be handed a grey picture and told to make its finished image dark where that picture is dark. Hand it a spiral and it paints a photograph that is secretly a spiral. This hands it a kanji.

The whole trick is in how the strokes are prepared. Drawn hard-edged, the model satisfies the instruction the cheapest way available, which is to paint a black bar across the sky. Softened until they stop being lines and become *regions of darkness*, the same instruction can be satisfied by a tree standing there instead -- and then the character is made out of the scenery rather than drawn on top of it.

`docs/003` is the design. This is the five steps it names, in the order it names them, and the order is not negotiable: blurring before the weakening would smear each stroke's darkness into its neighbours before the weakening could tell them apart, and compressing before the blur would compress a range the blur then narrows again.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `022-the-structure-field.lua` and
run the sweep again.*

## Invocation

```
luajit src/022-the-structure-field.lua --chars 森休川 [--out DIR]
```

## What it offers

| | |
|---|---|
| `M.placement(settings)` | How the archive's box maps onto the picture. |
| `M.blur_for(count, settings)` | How far to soften a character with this many strokes. |
| `M.build(record, settings, options)` | One character's structure field. |
| `M.thumbnail(surface, settings)` | The same field at the size the illusion is supposed to work at. |
| `M.inspect(surface, measured, settings)` | What the field looks like from the outside, as numbers a test can assert on. |
| `M.edge_ink(surface)` | The most extreme value found anywhere on the outer border. |

### `M.placement(settings)`

How the archive's box maps onto the picture.

The margin is applied to the *box*, not to the character's own ink, and this is the one decision here that is easy to get backwards. Centring each character on its own extent would make 一 -- a single horizontal line -- fill the frame exactly as densely as 田 does. Every character would come out the same visual size, and a learner would lose the one signal they have for how much is in a character before they can read it.

### `M.blur_for(count, settings)`

How far to soften a character with this many strokes.

WHY THIS IS NOT ONE NUMBER. The blur has one job with two edges: a stroke must stop being a line and become a neighbourhood, without merging into the neighbourhood next to it. How much room there is between those two depends entirely on how crowded the character is -- and characters run from one stroke to nearly thirty in the same box.

Set flat, the radius that turns a six-stroke character into a proper field welds a twenty-nine-stroke one into a grey smudge that is unreadable at thumbnail size, which is the one size the whole project is specified at. The symptom is visible only by looking, which is what the phase demonstration is for.

Stroke count is a proxy for stroke spacing, not a measurement of it: strokes crowd together roughly as the square root of how many there are in a fixed box, so the exponent is somewhere below a half. The honest measurement would be the distance from each piece of ink to the nearest ink belonging to a different stroke, which costs a great deal more and would move the number by less than turning the dial does.

### `M.build(record, settings, options)`

One character's structure field.

options.polarity   "dark_ink" (default) or "light_ink" options.measured   the stroke measurements, if the caller already has them

Returns the canvas, and a table of what was done to it, which the run report and the card both quote.

### `M.thumbnail(surface, settings)`

The same field at the size the illusion is supposed to work at.

The specification of this whole project is that a person sees the character in the thumbnail and not at full size (`docs/003`). This is the same computation at a different size rather than a second implementation, so the thing being looked at is the thing that was made.

### `M.inspect(surface, measured, settings)`

What the field looks like from the outside, as numbers a test can assert on.

Per stroke: the average darkness of the pixels along that stroke's own line. That is how "did this stroke put ink anywhere" and "is the weakening actually monotonic along the writing order" get answered without looking at a picture.

### `M.edge_ink(surface)`

The most extreme value found anywhere on the outer border.

A character whose ink reaches the border has been scaled wrongly, and the illusion loses whatever fell off. Cheaper to ask than to look.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `027-test-the-meaning`.
