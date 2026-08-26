# 413 — The picture grows a panel

## Current behavior

The pool holds two files per rendering: the picture the model drew, and a
companion describing it. `input/settings.lua` says why the picture is untouched,
and it was learned the hard way:

> OFF, and this was learned the hard way. With it on, what lands in the pool is
> a picture with arrows already in it -- so the machine grader squints at arrows
> as well as scenery, and the stroke-order animation draws arrows on top of
> arrows and every frame looks the same.

`208` makes a panel. This ticket is about where it is allowed to appear, and the
answer follows from that paragraph rather than from taste.

## Intended behavior

**The pool keeps what the model drew. Still.** A panel is never written into a
pooled picture, for the reason the arrows are not: the machine grader shrinks a
picture and correlates it against the field, and a picture with a black panel
stuck to it correlates against nothing. The panel is a per-character file in the
character's folder, and the pool refers to it.

**Both graders see the picture alone, and that is the rule that matters most
here.** `046` is a machine that squints and a person who clicks, and the
agreement between them is the only anchor this project has. A person grading a
card with the answer printed under it is not grading whether the illusion
worked — they are reading a word and looking at a picture that has been labelled
for them. So the pool gallery shows pictures, exactly as it does now, and the
panel is on what *leaves* the pool.

**A card is an elaboration, and it is owed to the ones somebody liked.** `408`
established the shape: a tier is not only a filter, it is a budget, and a
picture at or above the floor earns work the others do not get. A stroke-order
animation is one such earning. A joined card is another, and a much cheaper one.
`405.elaborate` already records a rendering having earned an extra file, and
`048.owed` already answers which pictures deserve work they have not had —
cards join that queue rather than getting a second mechanism.

**The burn-in switch is the export, and it is off in the pool by definition.**
`panel.burn_in` in `input/settings.lua` decides whether the picture program's
run writes cards as it goes or leaves them to be made later. Either way the
card is a third file and the two the pool is built on are unchanged.

**The gallery reveals rather than shows.** A card in the pool gallery is a
picture; the meaning is under it and appears when it is asked for. That is the
flashcard, and it is also the honest order: squint at the thumbnail, decide what
you think it is, then look. A page that shows both at once cannot be used to
learn from, only to check.

**The animation stays 768 square.** `048`'s frames are the character being
written over the picture, and a panel repeated identically through twenty-nine
frames is twenty-nine copies of the same lettering in a file format that was
never going to be given a reason to compress it well. A card that animates is a
different artifact and can be asked for separately.

**A phrase gets a card the same way a character does.** `402` made a phrase one
record with one continuous stroke order, and `207` captions it; nothing here
needs to know the difference.

### Where each thing lives

| | |
|---|---|
| the picture | `pool/<world>/<stem>.png` — untouched, as now |
| the companion | `pool/<world>/<stem>.info.md` — as now, plus the card it earned |
| the panel | one per character, in the character's folder beside its field |
| the card | picture and panel joined, written when earned or when asked for |

## Suggested implementation steps

1. **Panels for the set**, before any card exists. `031` already walks every
   character; a panel per character is one more file per folder and is
   generatable on this machine with no picture program running.

2. **Cards through the queue that already exists.** `048.owed` reports what
   deserves work; a rendering at or above the floor with no card is owed one.
   The mode that does the work writes the joined image and records it through
   `405.elaborate`, which is how the animation records itself.

3. **`panel.burn_in` in `input/settings.lua`**, off by default, and the reason
   for the default written beside it the way `composite_arrows` has its reason
   written beside it.

4. **The reveal in `032`.** The pool gallery gains a way to see the meaning
   without the meaning being on the page by default. It still cannot write to
   the pool — that wall stays exactly where it is.

5. **Tests in `035-test-the-machine`**: that a pooled picture is byte-identical
   before and after cards are made for it; that a card is exactly as tall as its
   two parts; that a rendering below the floor is not given one; that a
   character whose panel has not been drawn yet produces a clear refusal rather
   than a card with a blank half.

## Open questions

**Whether a card should carry the arrows as well.** Picture, arrows and panel
joined is the whole study material in one file — and it is also the picture at
its least legible, with the illusion competing against twelve yellow arrows and
a paragraph.

**Whether the reveal belongs in the pool gallery at all**, or whether learning
from these wants a page of its own that never shows a tier, never shows a seed,
and never offers a rating — because `032`'s pool page is a grader's instrument
and a learner is not grading.

## Related

`405` — the two files a rendering is, and the note that records a third.
`408` — a tier as a budget, and the queue this joins.
`406` — the two graders whose view of a picture this must not change.
`032` — the gallery that reveals.
`208` — what makes the panel.
`docs/042` — the studio this is part of.
