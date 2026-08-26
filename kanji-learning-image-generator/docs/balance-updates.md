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
