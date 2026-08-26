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
| `203` | What the pieces mean | **completed** — a rule for refusing glosses about writing, and a queue that says what to write next |
| `204` | The place the meaning makes | **completed** — seventeen worlds, and two ways of being confidently wrong that the spread report caught |
| `205` | The words the machine reads | **completed** — clauses ranked for dropping and placed for reading, which are not the same order |
| `206` | Arrows that teach the order | **completed** — one arrow per stroke, pointing the way the stroke leaves, legible at the size that matters |

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

## What `203` turned up

**The expected difficulty was coverage and the real one was quality.** Almost
every piece of every character has a dictionary entry. The commonest pieces have
the least useful ones, because a piece that appears in two thousand characters is
a structural radical and dictionaries describe those by catalogue position — a
radical number, a kana name, a stroke count. All true, none of it paintable.

That is a rule and not a list, so the long tail is handled and the failures are
reported rather than guessed at.

## What `204` turned up

**Both bugs produced good-looking pictures about the wrong subject**, which is
the failure this phase's note names at the top as the dangerous one.

Demoting the half of a character chosen for its sound is not enough — the pieces
*inside* that half have to go with it, and nothing in the archive marks them.
And skipping the outermost component, which merely restates a compound, silently
starves every atomic character of all its evidence.

Neither would have been visible one character at a time. Both were obvious the
moment the whole set was tabulated by world, which is why the distribution report
is a mode of the file rather than something somebody might run.
