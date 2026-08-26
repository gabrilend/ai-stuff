# Phase 2 — The Meaning

**Goal.** A kanji record becomes a scene: a world, a cast taken from the
character's own etymology, an object lying along every stroke, and the grayscale
field that makes a picture secretly be a character. Nothing in this phase knows
what ComfyUI is.

This is where the project stops being a drawing program.

## Issues

| | | Status |
|---|---|---|
| `201` | What a stroke is shaped like | **completed** — every boundary measured off the archive, and the thing that measured them kept |
| `202` | The field the illusion rides on | **completed** — five steps in a fixed order, and a blur that answers to how crowded the character is |
| `203` | What the pieces mean | not started |
| `204` | The place the meaning makes | not started |
| `205` | The words the machine reads | not started |
| `206` | Arrows that teach the order | not started |

## Where the risk is

**Nothing here can be tested against the thing it is for.** The specification is
that a person squints at a thumbnail and sees the character, and no assertion in
this repository observes that. Every test in this phase checks that the machinery
did what it was told, and none of them check that what it was told was right.
`docs/007` Q1 is the standing question about whether that gap can be closed at
all.

**The dangerous fallback is the default biome**, and `204` refuses it. A
character that matches no biome, quietly given a generic landscape, produces an
image that looks fine and has nothing to do with its character — and nobody would
find it, because there is no symptom. This is the single most plausible way for
this project to be broadly wrong while appearing to work.

**The second is the unglossable component.** `203` counts them and `303` reports
them because a component that silently contributes nothing makes an image that is
quietly about less than it should be.

## What `201` turned up

**A claim that sounded like an engineering judgement and was an untested
assumption.** The plan stated that a hook cannot be seen by measurement, on the
reasoning that a hook barely moves a stroke's endpoint — which is true, and does
not imply the conclusion. A hook barely moves the endpoint and swings the
direction hard. The two populations turn out to be cleanly separated with
nothing in between.

The lesson is not about hooks. It is that every boundary in this phase is a
claim about a dataset, and the difference between a guessed boundary and a
measured one is invisible until somebody looks. So the thing that measured them
is a mode of the file it configures, not a script that was deleted afterwards.

## What `202` turned up

**Every test passed while the output was wrong**, which is the failure mode this
phase's note at the top predicts and it happened on the first character that
tested it. A twenty-nine-stroke character came out as a grey smudge: the strokes
had all been drawn, the range was on its band, nothing touched the border, and
the character was not there. All the machinery had done what it was told.

The fix was to make the blur depend on how crowded the character is rather than
being one number. The finding is that in this phase, *looking* is a test — and
it is the only one that checks the thing the project is actually for.
