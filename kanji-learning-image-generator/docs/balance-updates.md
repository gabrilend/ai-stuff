# Balance updates

Append only. Every knob turned, with the number before, the number after, and
what was being chased. Not a changelog — a changelog says what changed, and this
says what it felt like and why somebody reached for the dial.

Issue files are for features. This is for turning knobs and pulling levers.

The knobs themselves live in `input/settings.lua`, which is read at startup by
everything (`docs/006`). Their meanings are in `docs/003` and `docs/005`.

---

## 2026-08-25 — the first settings, and what they were guessed from

Nothing has been generated yet, so every number below is a starting position
rather than a finding. They are written down now so the first person to change
one has something to compare against.

| Knob | Set to | Reasoning |
|---|---|---|
| `field.blur_radius` | 9 (at 768px) | The single most important dial (`docs/003`). Roughly one and a half stroke widths, which is enough to turn a line into a neighbourhood without letting adjacent strokes merge. Characters with many strokes are the ones that will break this first. |
| `field.stroke_width` | 6.5 (at 768px) | About 0.85% of the canvas. Wide enough to survive the blur, narrow enough that 20-stroke characters do not become a solid block. |
| `field.range_low` / `range_high` | 0.16 / 0.86 | The field is compressed into this band rather than running full black to full white, so the control net biases rather than dictates. Full range crushes the scene. |
| `field.order_ramp` | 0.12 | How much weaker the last stroke is than the first, carrying the writing order in the composition itself. Deliberately small: it costs contrast from exactly the strokes most likely to be lost, and whether any of it survives sampling is open question Q5. |
| `field.taper` | 0.18 | Fraction of each stroke's length over which the brush thins at either end. Matches a written stroke; also stops stroke ends reading as blunt objects. |
| `field.resolution` | 768 | Matches the native size of the SD 1.5-era control nets this targets. |
| `scene.named_strokes` | 5 | How many strokes get an object named in the prompt. More than about six and the sentence stops being something a text encoder can hold; fewer than three and the composition is unconstrained. |
| `workflow.control_strength` | 0.85 | Hard enough that the strokes land. This is the dial people will reach for first when the character does not appear. |
| `workflow.control_start` | 0.0 | Composition is decided in the earliest steps, so the field is present from the first one. |
| `workflow.control_end` | 0.72 | Released before the end so the model finishes the scene without the field in the way. Holding to 1.0 stamps the character through the picture. |
| `workflow.steps` | 24 | Ordinary. |
| `workflow.cfg` | 6.5 | Slightly below the usual 7-8. High guidance fights the control net, and when they fight the picture gets the worst of both. |
| `workflow.sampler` / `scheduler` | `dpmpp_2m` / `karras` | Ordinary and well-behaved for this kind of conditioning. |
| `arrows.head_length` | 13 (at 768px) | Large enough to read at thumbnail size, which is the size the rest of the image is designed for. |
| `arrows.number_size` | 19 (at 768px) | Same reasoning. Stroke numbers that vanish in the thumbnail defeat the layer. |

---

## 2026-08-25 — the blur stopped being one number

**Symptom.** Looking at the first six real fields at thumbnail size, five were
crisp and 鬱 — twenty-nine strokes — was a grey smudge with no character in it.
Thumbnail size is the *only* size this project is specified at, so that is a
failure and not a rough edge.

**Cause.** `field.blur_radius` was one number for every character. The blur has
one job with two edges: a stroke must stop being a line and become a
neighbourhood, without merging into the neighbourhood beside it. How much room
sits between those two edges depends entirely on how crowded the character is,
and characters run from one stroke to nearly thirty inside the same box. A
radius that turns a six-stroke character into a proper field welds a
twenty-nine-stroke one shut.

| Knob | Was | Now | Why |
|---|---|---|---|
| `field.blur_radius` | 9, flat | 9 **at eight strokes** | Same number, different meaning: it is now the radius for a character of `blur_reference` strokes rather than for all of them. |
| `field.blur_reference` | — | 8 | Where the radius above applies unchanged. Eight is near the middle of the distribution. |
| `field.blur_falloff` | — | 0.38 | How fast the radius shrinks as strokes are added. Strokes crowd roughly as the square root of how many there are in a fixed box, so the exponent belongs below a half. Set to 0 to go back to a flat radius. |
| `field.blur_minimum` | — | 3 | A floor. Below about three the softening stops doing its job and the strokes go back to being lines. |

Which gives, at the current settings: one stroke ≈ 20, three ≈ 13, six ≈ 10,
twelve ≈ 8, twenty-nine ≈ 5.5.

**What this is not.** Stroke count is a proxy for stroke *spacing*, not a
measurement of it. The honest measurement is the distance from each piece of ink
to the nearest ink belonging to a different stroke, and it costs a great deal
more while almost certainly moving the number by less than turning this dial
does. If a character ever comes out wrong in a way this cannot fix, that is the
thing to build.

---

## 2026-08-25 — the arrows were drawn for a page, not for a thumbnail

**Symptom.** The first stroke-order layers were correct and unreadable. Every
arrow pointed the right way, every number was the right number, and at the size
the rest of the image is designed for they were specks.

**Cause.** The sizes were picked against a full-size image on a screen. The
whole project is specified at thumbnail size — that is where the illusion works
and where a learner meets it — so the annotation has to be legible there too.

| Knob | Was | Now |
|---|---|---|
| `arrows.head_length` | 13 | 27 |
| `arrows.head_width` | 9 | 21 |
| `arrows.shaft_length` | 26 | 34 |
| `arrows.number_size` | 19 | 36 |
| `arrows.line_width` | 3.0 | 5.0 |
| `arrows.outline` | 2.4 | 3.4 |

**And a second thing, which was a bug wearing a knob's clothes.** Two arrows
were considered to be in each other's way if their *anchors* were closer than
about one shaft length. But an arrow carries a number beside it, and the number
is now the largest part of it — so two strokes beginning close together produced
two labels printed one on top of the other while the placement reported that it
had found room for both.

| Knob | Was | Now | Why |
|---|---|---|---|
| `arrows.clearance` | shaft × 1.15, in code | 66, in settings | Covers the arrow *and* its number. Being in code is what let it drift out of step with the sizes above. |
| `arrows.nudges` | 14, in code | 16, in settings | How many sideways attempts before an arrow gives up, keeps its number in place, and shortens itself instead. |

A twenty-nine-stroke character still has nowhere to put twenty-nine labels. One
of them gives up and is counted, which is the honest outcome.
