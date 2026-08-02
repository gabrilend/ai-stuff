# Phase 2 — The hands

**Goal.** Thinking that can touch the machine. Memory, ports, storage, a console,
a status, and — the one that matters most — running code it has just written.

A machine that can think but not act has nothing to be instructed about, which is
why this comes before the words.

## Issues

| | | Status |
|---|---|---|
| `201` | The shape of a tool call | **completed** — the door and the catalogue as one object, a swappable grammar, every refusal a sentence, and a live exchange on the real engine, 27 of 27 |
| `201a` | Reading something too big to hold | **completed** — windows searched by the machine's own judgement, only the useful part crossing, summaries labelled as summaries, 19 of 19 |
| `202` | Say something | **completed** — a font drawn as pictures, letters on a real firmware framebuffer checked pixel for pixel, and the model given voices of its own, 13 of 13 |
| `203` | Touch memory | not started |
| `204` | Run what it wrote | not started |
| `205` | Touch the hardware | not started |
| `206` | Keep something | not started |
| `207` | Emit a status | not started |

## Where the risk is

`204`, and specifically its fourth step. Code written by a model will sometimes
loop forever, and without a way to regain control the first bad function ends the
machine.

The answer is the status emission: the assembler is ours, so it inserts one at
every loop back-edge, repetition pushes the magnitude away from fifty, and
crossing a threshold is where control gets taken. Cheap, and it reuses machinery
the design already has. What escapes it is code that did not come through our
assembler, which is what the single-stepping fallback is for.

`205` and `206` land together or not at all: the discipline that makes hardware
exploration survivable depends on writing a note first, and the note needs
storage.

## Demo

The machine narrating its own startup on screen — drawn straight into the
framebuffer the firmware handed it, with no driver underneath — then being asked
for something it has to write and run in order to answer.
