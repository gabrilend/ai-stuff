# 205 — The words the machine reads

## Current behavior

A scene is a table of facts. A diffusion model reads sentences.

## Intended behavior

**A scene in, two strings out** — what the picture is, and what it must not be.

This is the only file in the project that writes English, and keeping it the only
one is why `204` is forbidden from building sentences. Rewording the whole
project's output should mean editing one file, and testing the reasoning should
never mean reading prose.

### The positive prompt

Assembled in a fixed order, because a text encoder weighs the beginning of a
prompt more heavily than the end, and the order is therefore a statement about
what matters:

1. **the subjects**, with their places in the frame — the etymology, first
2. **the biome and its register** — which forest, not just forest
3. **the named strokes' objects** — the things that lie along the composition
4. **the light** — from the biome, and it is what carries the polarity visually
5. **a photographic tail** — the terms that keep the model out of illustration,
   because an illustration has flat regions and flat regions cannot hide a shape

A prompt does not simply concatenate everything the scene knows. A twenty-stroke
character with six components has more facts than a text encoder can hold, and a
prompt past that limit does not fail — it quietly ignores its own end, which
means the photographic tail falls off and nobody notices. The assembler tracks its
own length and drops from the middle, where the least structural stroke roles are,
rather than from the end.

### The negative prompt

**Fixed, permanent, and not a tuning parameter.** `docs/004` explains what it
defends against: a model satisfying the idea of a kanji by painting one. Text,
letters, lettering, watermark, signature, calligraphy, brush strokes, ink wash,
chinese characters, japanese characters, kanji, writing, logo, border, frame.

It is a constant in this file with a comment saying it is not to be tuned, and
that comment is the whole reason it is a constant instead of a setting.

## Suggested implementation steps

1. **`src/025-the-words-the-machine-reads.lua`**, taking a scene and settings.

2. **Emphasis with ComfyUI's weight syntax**, `(term:1.2)`, applied to the primary
   subject and nothing else. Weighting everything weights nothing, and a prompt
   full of parentheses is a prompt somebody has stopped reading.

3. **Length in tokens, estimated, not counted.** The real tokeniser is CLIP's and
   it is not here. Word count times a small factor is close enough to decide
   whether to drop a clause, and the estimate is documented as an estimate so
   nobody later reports a bug against it.

4. **Test that the negative list is present and complete in every prompt**, for
   every character in a sample. This is the assertion that stops somebody
   "cleaning up" the constant into a setting and then setting it to nothing.

## Related

`docs/004` — the scene and the defence. `204` — where scenes come from.
