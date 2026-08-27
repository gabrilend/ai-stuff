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

---

## 2026-08-25 — the batch was taking the whole machine

**Symptom, reported from outside the program**: generating the full set drove
the processor to the top of its thermal range and held it there. Nothing was
going to break — a chip throttles itself long before damage and the limits it
reports carry that margin — but sustained heat is sustained wear, and the run
was also taking every core the machine had and leaving none for the person
using it.

**Cause.** `303` asked how many processors there were and started that many
workers. Fourteen of fourteen, flat out, for the length of the run.

| Knob | Was | Now | Why |
|---|---|---|---|
| `batch.share` | — (all of them) | 0.45 | A proportion, not a subtraction. Two cores free is a large concession on a four-core machine and almost none on a thirty-two core one, and it is the *share* held at full load that sets the temperature. |
| `batch.reserve` | — | 1 | And at least one core left alone regardless, so a small machine stays usable. |
| `batch.max_workers` | — | 6 | An outright ceiling. |
| `batch.nice` | — | 10 | Workers wait at the back of the queue. Does not cool anything; means a hot run never also makes the machine feel broken. |
| `heat.warm` | — | 58 | Above this the run starts pausing between characters. |
| `heat.hot` | — | 72 | By here the pauses are as long as they get. |
| `heat.rest_warm` / `rest_hot` | — | 0.06 / 0.55 s | The pause at each mark; proportional in between, because a flat pause treats one degree over as the same emergency as ten. |
| `heat.ceiling` | — | 2.5 | How much further the pause may grow if it is still climbing past the hot mark. |
| `heat.check_every` | — | 1 | Characters between readings. Two was too slow to catch a burst. |

**Measured, on the five hundred commonest characters:**

| | workers | peak | mean | wall clock |
|---|---|---|---|---|
| before | 14 | 86 °C | 74 °C | 34 s |
| after | 6 | 81 °C | 66 °C | 91 s |

Eight degrees off the mean for roughly two and a half times the wall clock. That
is a deliberate trade and it is the one that was asked for; anybody who wants
the old behaviour raises `share` and the two marks.

**What this is not.** A machine that does not report its temperature gets the
pauses turned off entirely, with a notice. Resting on a fixed schedule against a
temperature nobody measured is a slower run bought for nothing.

---

## 2026-08-26 — the first numbers that were measured rather than guessed

**Every dial in this file until now was a starting position set by argument.**
There was no way to do better: nothing had ever been generated. There is now, so
these were measured — one dial moved at a time, against the machine grader in
`src/046`, on the character for *tree*.

**The finding is that `control_strength` was less than half what it should be**,
and it was the only dial that mattered much.

| strength | released at | agreement |
|---|---|---|
| 0.85 *(as guessed)* | 0.72 | 0.349 |
| 1.20 | 0.72 | 0.574 |
| 1.20 | 0.95 | 0.594 |
| 1.55 | 1.00 | 0.623 |
| 1.90 | 1.00 | 0.663 |

For scale: a field compared against a *different character's* field scores about
0.39. So at the setting this project shipped with, the finished picture agreed
with its own character no better than with a random one — which is exactly what
looking at it showed. At 1.55 the tree grows a visible trunk with two diagonals
sweeping down and a crossbar, and it is unmistakably a photograph of a tree.

**It helps more on crowded characters, not less**, which was the opposite of the
worry. 語, at fourteen strokes: 0.457 at 0.85, and 0.720 at 1.55. More strokes
means more structure for the composition to follow.

| Knob | Was | Now | Why |
|---|---|---|---|
| `workflow.control_strength` | 0.85 | 1.55 | The table above. 1.90 scored higher still and is left as headroom rather than taken, because nothing has checked what it does to a thirty-stroke character. |
| `workflow.control_end` | 0.72 | 1.0 | Releasing it early was argued for on the grounds that the model should finish the scene unaided. Measured, holding it to the end is slightly better and does not stamp the character through the picture the way that argument feared. |

**And one dial turned out not to matter.** The band the field is compressed into
was moved from 0.16–0.86 to 0.02–1.00 with the strength held fixed: 0.617
against 0.623, which is noise. So it stays where `docs/003` argues it should be.
That test had to be run twice, because the first sweep moved the band and the
strength together and could not tell which had done the work.

**What none of this measures** is the failure the grader is blind to — a model
that satisfies *kanji* by painting one. Every picture above was looked at, and
none of them did it. That is not the same as knowing it will not happen at 1.55
on some other character.

---

## 2026-08-26 — the card was also the screen

**Symptom, reported from outside the program and in the plainest possible
terms**: the machine froze and had to be restarted.

**Cause.** Every picture loads a four-gigabyte model onto the graphics card, and
on this machine there is one graphics card and it is drawing the desktop.
Sweeping settings meant loading it over and over, back to back, with nothing
held back. A desktop with no graphics memory left does not run slowly; it stops.

`307` asked whether the *processor* was getting hot and answered it carefully.
Nobody asked the same question about the card — on the reasoning that generating
is the card's work rather than the processor's, so the processor's governor did
not apply. That reasoning is true and it answers the wrong question.

| Knob | Was | Now | Why |
|---|---|---|---|
| `kitchen.rest` | 1.0 | 1.0 | Unchanged: still right for a card of its own. |
| `kitchen.rest_on_the_display_card` | — | 6.0 | A second is courtesy on a spare card. On the one running somebody's desktop it is not enough, and the difference costs a few minutes across a set. |
| `kitchen.reserve_vram` | — | 1.5 | Gigabytes held back for the desktop, passed to the picture program as `--reserve-vram`. It takes everything it can get otherwise, which is right on a machine with a spare card and hostile on a machine with one. |
| `kitchen.least_free_vram` | — | 2.0 | A run will not submit below this. It waits first, since the picture program frees what it held between runs; still short after a minute, it stops and says how many it made. A run that wedged the display can tell nobody anything; one that stopped early can. |

**Whether the card is also the screen is asked, not assumed** — a card with a
desktop on it is never at zero before anything of ours has run. Same shape as
`307` reading a temperature rather than resting on a schedule.

**And the reserve is now in every command this project prints for starting the
picture program**, in the installer, the walkthrough and the message shown when
nothing is listening. A correct default nobody is told about is a default that
gets dropped the first time somebody types the command from memory.

## The frame stayed at 768, and now says why

Asked whether the pictures were failing for want of room, `414` made every
pixel-valued knob scale with the frame so the question could be asked honestly,
and then the answer came back **no**.

| Knob | Was | Now | Why |
|---|---|---|---|
| `field.reference` | — | 768 | The size every other pixel number below was measured at. Not a size the picture is drawn at — a unit for reading the rest of the file. |
| `field.resolution` | 768 | 768 | **Unchanged after measuring 1536 and finding it worse.** Kept as the value it always was, now for a reason instead of by default. |

Four characters, same seeds, same brief. At 768 they took 37 seconds each; at
1536, **290** — not four times the pixels for four times the cost but nearly
eight, since the card starts trading against its own memory. Eighty characters
would be six and a half hours.

**The scores split in both directions and neither was improvement.** 川 and 木
sat still. 時 fell from 0.84 to 0.63. 語 climbed from 0.52 to 0.83 — and 語 at
0.83 is a traced glyph on crowd texture, while 語 at 0.52 has the mouth radical
built from a wooden crate. The number went up because the picture stopped being
one.

The cause is not a knob. The picture is composed on a grid of cells standing for
eight-pixel squares, so 768 is 96 across and 1536 is 192, while the layers that
let one region know what the others are doing were trained around 64 and do not
reach further for a larger canvas. Past a point each region can only see its
neighbours, so it tiles a texture rather than composing a scene — and with no
scene left to bend, the only way to satisfy the structure field is to darken its
strokes directly.

**More room for the strokes remains the right instinct.** Pixels are the wrong
currency for it. What is left to try: fewer and fatter strokes in the field
itself, a second low-strength pass at the larger size over a picture composed at
the smaller one, or a checkpoint trained at 1024 to begin with.
