# Datapath: how a thought fades

The vision says each frame must be treated as "100% valid and real, meaning
its future descriptions have to include it and the new stuff, or at least
what they deem important, causing things to fall out of relevance and fade
from the viewer's sight". This document is how the page keeper turns that
into a number on every thought.

## What the page keeper remembers about each thought

A list of thought records, held in the page keeper's memory:

| Field | Type | Meaning |
|---|---|---|
| number | whole number | The page keeper's own counter, unique for the run. Never shown to a voice. |
| voice | string | Who wrote it. |
| frame | whole number | The voice's frame number it was last seen in. |
| text | string | The words, exactly as the voice last wrote them. |
| word counts | table from word (string) to count (whole number) | The text lowercased and split on anything that is not a letter or digit. This is the thought's position in "word space". |
| relevance | number, 0 to 1 | 1 while it is in its voice's newest frame. Lower while fading. |
| carried | whole number | How many times a later frame has carried it forward. |
| first page, last page | whole numbers | The page numbers it was first and last listed on. |

## Measuring "the same thought, reworded"

Two thoughts are compared by the angle between their word counts, treated as
arrows in a space with one direction per word. The cosine of that angle is
1.0 for the same words in any order and 0.0 for no words in common:

    similarity(a, b) = Σ a[w]·b[w]  ÷  ( √Σ a[w]²  ·  √Σ b[w]² )

This is the "detecting waves in dataforms by measuring angles of similarity"
idea from the owner's notes, in its simplest form. It knows nothing about
meaning: "the model is too big" and "the model is too small" are near-twins
to it. That is a known limit, and the reason this measure is one entry in a
table of measures, so a better one (word embeddings, for example) can be added
beside it and chosen in the input file without changing the rest.

A thought counts as **carried forward** when its similarity to a thought in a
newer frame is at least the carry threshold, a setting in the input file.

## What happens when a frame arrives

When voice V's new frame arrives (after it passes its checks):

1. **Match.** Each thought in the new frame is compared with every thought
   record still on the page, from every voice. Its best match, if at or above
   the carry threshold, is carried forward: that old record is retired, and
   its `carried` count and `first page` pass on to the new thought. A voice can
   carry another voice's thought. When fg-sora-2 repeats what fg-sora-1 said,
   that is fg-sora-1's thought surviving in fg-sora-2's words.
2. **Fresh.** Every thought in the new frame gets relevance 1.
3. **Let go.** V's previous-frame thoughts that were not carried forward
   begin to fade: they keep their text, and their relevance drops for the
   first time.
4. **Fade.** Every fading thought that this frame did not carry forward
   loses relevance:

       relevance = relevance × decay

   `decay` is a setting between 0 and 1. A thought below the vanish level
   (another setting) is set to 0 and leaves the page.
5. **Lay out.** The page is built from the newest frames, then the fading
   thoughts by relevance, until the display box is full
   (`docs/display-box.md`).

So a fading thought loses relevance once per frame that goes by without it,
from any voice. With three voices writing, a thought nobody repeats lasts
about three times as many frames as with one voice.

## Why it runs on one thread

A page holds at most a few dozen thoughts, so one arriving frame means a few
hundred comparisons of short word lists. That takes microseconds. Spreading
it over threads would cost more in coordination than it saves. If the measure
becomes expensive (embeddings computed by a model), the comparisons become a
batch, and the batch goes to a thread pool or the GPU on kuvalu.

## The settings, and where their history is kept

carry threshold, decay, vanish level, fading fraction of the box. They live
in the page keeper's input file. Every change to them is appended to
`docs/balance-updates.md` with the reason, once there is a first change to
record.
