# Issue A13: Music From What the Pictures Show

**Phase:** A - Infrastructure Tools
**Type:** Tool (a see-in-3d step)
**Priority:** Medium
**Status:** Open — waiting on two model files on the machine nearby
**Dependencies:** A09 (the image server), A10 (keeping, the conversation), A12 (moving pictures)

---

## Why this exists

> now can we take the gifs and the images and the input images that show the
> in-engine simulations and use them as inputs to create ost songs in a variety
> of different tunes, depending on the various variables that are playing in the
> game state? or just... create some background music that we can be playing in
> the background.

> we should have at the start of the pipeline the screenshots and the images and
> the gifs and whatnot ... we can use image recognition to describe the visuals,
> then generate a music based on that

> we will have to generate multiple dimensions of these variables interacting
> with each other. Which, is kinda the benefit and joy of AI generated artwork,
> you can always get more, scaled to some dimension or another.

Decided with her: ACE-Step makes the music ("we will use our own system for
sound-effects later on"); the looking runs inside ComfyUI as part of the same
pipeline ("Can't we just run it in comfyUI?"); it runs "when we're working on
music", not on every kept picture.

## Current Behavior

Nothing makes music. The machine nearby (192.168.0.88, ComfyUI 0.22) has the
nodes for both halves — `TextGenerate`, which runs a language model and takes
an image, a batch of frames or audio as input, and ACE-Step's
`TextEncodeAceStepAudio`, `EmptyAceStepLatentAudio`, `SaveAudio` — but neither
model: its text encoders hold only a T5 file for Chroma, and no ACE-Step
checkpoint.

## Intended Behavior

`see-in-3d music` over a set of visuals and a set of dimensions:

1. **The visuals first.** Screenshots, kept pictures, development-history
   renders, moving pictures (a GIF sent as its frames).
2. **Looked at inside ComfyUI.** `TextGenerate` with a vision-language model
   describes each visual as music would need it: what is there, its mood, its
   light, its motion — and suggests instruments and a feel.
3. **Dimensions, multiplied.** The game's own variables, each with its
   values (time of day: noon, dusk, night; crowding: sparse, full; pace: calm,
   battle), are crossed with each other and with the visuals' descriptions.
   Every combination is a piece: the description chooses mood and instruments,
   the variables choose tempo, key and intensity. More pieces are always one
   more value away.
4. **ACE-Step makes each piece** from tags and (optionally) lyrics, a set
   length, one seed per combination so a piece can be made again.
5. **Kept like every see-in-3d output**, in the project's
   `mind/imagination-portraits/`, beside the visual it came from, with what
   made it, and written into the conversation where it was made; the story
   page plays it.

## Suggested Implementation Steps

1. On the machine nearby (by her, or with her leave): the ACE-Step checkpoint
   into `ComfyUI/models/checkpoints/`, and a vision-language model the
   `TextGenerate` node can load into `ComfyUI/models/text_encoders/`
   (Qwen2.5-VL 7B, the `qwen_image` loader type, is the likely one).
2. The looking workflow and the music workflow, built from the server's own
   node descriptions, tested as dry runs.
3. The dimensions file and the crossing.
4. Keeping audio (the keep step learns sound); the story page's audio player.
5. A real run on a handful of the development-history renders.

## Open Questions

1. Which variables, with which values, for centered-ui-design's first set?
2. Song length, and lyrics or none?
