# Phase 2 — The Meaning

**Goal.** A kanji record becomes a scene: a world, a cast taken from the
character's own etymology, an object lying along every stroke, and the grayscale
field that makes a picture secretly be a character. Nothing in this phase knows
what ComfyUI is.

This is where the project stops being a drawing program.

## Issues

| | | Status |
|---|---|---|
| `201` | What a stroke is shaped like | not started |
| `202` | The field the illusion rides on | not started |
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
