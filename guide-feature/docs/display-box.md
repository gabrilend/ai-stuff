# The display box

The display box is the size of the page, in characters: a width (columns) and
a height (rows). A watch might show 20x8, a terminal 80x24, a desktop window
120x40. Everything that writes to the page must fit inside the box, and the
language models are told its size before they write.

The owner's words: "we must also be able to limit the dimensions (in
characters, X/Y or width/height) of the display box, so that we can
dynamically adjust to various size screens. The LLM is provided this
knowledge, and if their output doesn't fit it is returned mechanically and run
again with a description of why. Like a compiler error."

## The parts of the box

    ┌──────────── width W ────────────┐
    │ fg-sora-1's share   (S rows)     │
    │ fg-sora-2's share   (S rows)     │  height H
    │ fg-sora-3's share   (S rows)     │
    │ fading rows         (F rows)     │
    └──────────────────────────────────┘

| Quantity | Type | How it is found |
|---|---|---|
| `W` box width | whole number of characters | from the box rule (below) |
| `H` box height | whole number of rows | from the box rule |
| `F` fading rows | whole number of rows | `floor(H × fading fraction)`; the fading fraction is a setting in the page keeper's input file |
| `S` a voice's share | whole number of rows | `floor((H − F) ÷ number of voices)` |

Every voice's frame must fit `W` columns by `S` rows. The fading rows hold the
highest-relevance thoughts that have dropped out of the newest frames, until
the box is full. A fading thought that does not get a row is still tracked and
still loses relevance; it is just out of sight, which is what the vision asks
for: "causing things to fall out of relevance and fade from the viewer's
sight".

A box where `S` would be less than 1, or `W` less than 8, is refused as an
error. A box that small cannot hold a sentence, and pretending it can would
hide the problem.

## Who decides the size: the box rule

The page keeper holds the box. Which size it holds is decided by the box
rule, a setting in its input file. Each rule is one entry in a table of rules,
looked up by name:

| Rule | Meaning |
|---|---|
| `fixed WxH` | Always this size. The simplest, and the one the first phases use. |
| `smallest-viewer` | Viewers say their size when they ask for the page (`docs/page-protocol.md`, the `box=` part of the request). The box is the smallest width and the smallest height among viewers heard from in the last few minutes, so the page fits every screen that is watching. |
| `named-viewer NAME` | The box follows one viewer, for example the watch, and other viewers draw the box inside whatever space they have. |

Which rule is the default is an open question (`docs/open-questions.md`).

## When the box changes

The page keeper publishes a new page with the new `box:` and `share:` header
lines (`docs/page-protocol.md`). The voices see the new share on their next
read and fit their next frame to it. Until then, a voice's current frame may
be taller or wider than the new share. The page keeper then lists only the
rows that fit, counts the hidden rows in the log and in the goodbye receipt,
and the page marks that voice as `over-box` so viewers can show it. Nothing
is cut silently. Whether this is the right behaviour is an open question.

## The fit check: like a compiler error

The same check runs in two places: in the thinker before a frame is sent, and
in the page keeper when a frame arrives. It is one piece of code shared by
both, and it reports problems the way a compiler does: one line per problem,
naming the line and the measure.

    frame does not fit the box 40x4:
      line 2: 47 characters, 7 over the width of 40
      line 5: the frame has 5 lines, 1 over the height of 4
    rewrite the whole frame so every line is at most 40 characters
    and there are at most 4 lines.

In the thinker, this text is given back to the language model, with the
frame it wrote, and the model is asked again. The number of tries is a
setting. When the tries run out, the thinker does not send a cut-down frame.
It logs the failure, counts it, keeps its previous frame on the page, and
starts over from a fresh read of the page. Every retry and every
give-up is counted in the thinker's goodbye receipt, so how well a model
respects the box can be measured.

In the page keeper, a failing frame is refused (`docs/datapath-frame-to-page.md`,
step 4).
