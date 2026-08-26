# 001 — What this makes

For each kanji, a **recipe for a picture**, and the picture is the kanji.

Not a picture with a kanji drawn on it. A landscape, or a room, or a figure by a
river, whose light and dark happen to fall in exactly the places the strokes of
that character fall. Up close it is a scene. Held at arm's length, or shrunk to a
thumbnail, or seen through half-closed eyes, it is 木, and the tree in it was
standing along the vertical stroke the whole time.

That is the trick this project industrialises, and the trick is not ours. There
is a known family of images where a spiral, or a face, or a word has been baked
into a photograph at low contrast, invisible at full size and unmistakable in the
thumbnail. The machinery that makes them is a diffusion model steered by a
grayscale picture that says *put darkness roughly here*. Give it a spiral and it
returns a photograph that is secretly a spiral. Give it the strokes of a kanji
and it returns a photograph that is secretly a kanji.

## Why this is a learning material and not a novelty

A learner meeting 休 is told two things that never touch: a shape, and the word
*rest*. The shape is four-plus-two lines and the word is a concept, and the only
bridge between them is repetition.

The bridge this project builds is that **the shape is the picture of the word**.
休 is a person beside a tree. Not by our invention — that is its etymology, and
the archive we read states it outright: the character contains 人 on the left and
木 on the right. So the image is a traveller resting against a trunk, and the
traveller *is* the left three strokes, and the trunk *is* the vertical one. There
is nothing to associate, because there are not two things any more.

And because the strokes are the composition, the order they are written in is a
path through the composition. The vision put it plainly:

> if the strokes are the structure, then the stroke order is the intended
> viewing order, as directed with arrows because it's a learning material.

So a second layer goes on top: numbered arrows, each one sitting at the start of
its stroke and pointing the way the brush went. The eye is walked through the
picture in the order the hand would write it.

## The four things a kanji is turned into

Every character that comes out of this system leaves four artifacts, and each one
is produced by a part of the machine that does nothing else.

| Artifact | What it is | Made by |
|---|---|---|
| the **structure field** | a grayscale image; the strokes as regions of darkness, softened until they are places rather than lines | `docs/003` |
| the **scene** | which components are subjects, which stroke carries which object, what biome it all sits in | `docs/004` |
| the **prompt** | the scene, written as the sentence a diffusion model was trained to answer | `docs/004` |
| the **workflow** | a ComfyUI node graph, in the two formats ComfyUI accepts, referring to the field and the prompt | `docs/005` |

The last of those is the deliverable. This project does not generate images — it
generates the thing you drop into ComfyUI to generate images, for every kanji at
once. That distinction is deliberate and it is the reason the whole set can be
produced on a machine with no GPU in it.

## What is refused

**No image generation happens here.** A diffusion model is thirty times the size
of this entire repository and needs hardware this does not assume. The output is
a recipe. Running it is a separate act on a separate machine, and the recipe is
written in the format that machine already reads.

**No character is drawn into the output image.** The negative prompt names
calligraphy, ink, text and lettering specifically, because the failure mode of
this idea is a model that paints the kanji onto a wall in the scene and calls it
done. The character must be assembled out of scenery or it has not worked.
`docs/004` says how that is enforced and `docs/007` records what remains unsure
about it.

**No meaning is invented.** Every gloss, every component decomposition, every
stroke order comes out of one of the two published archives in `docs/002`. Where
this project adds vocabulary — the words that turn *tree* into *a cedar with wet
bark, low sun behind it* — that vocabulary is in one file and is marked as ours.

## Where to read next

`docs/002` is where the data comes from. `docs/003` is the optical trick and the
only genuinely unusual piece of engineering here. `docs/004` is the part that
decides what the picture is *of*, and is the part most likely to be wrong in
interesting ways. `docs/006` is the order it all gets built in.
