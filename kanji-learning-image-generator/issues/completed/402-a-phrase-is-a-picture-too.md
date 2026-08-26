# 402 — A phrase is a picture too

## Current behavior

Done. `src/019a-a-phrase-is-a-record-too.lua`, and everything downstream takes a
word without being told anything changed:

```
luajit src/030-make-one-kanji.lua --phrase 時間=time,an hour
luajit src/031-make-them-all.lua --phrases
```

**The trick is that a single character is one cell.** Saying that in one place —
rather than checking everywhere whether a record is a word — is what lets the
field, the arrows, the scene grammar and the workflow treat a word and a
character as the same kind of thing. Nothing downstream branches on it.

**Component depths are pushed down by one for a word**, because the whole phrase
is now the outermost thing and each character is a piece of it. Without that,
two characters' outermost groups would both claim to be the whole record.

**Subjects are named in reading order.** They were sorted by size, which for a
word named the second character's pieces before the first's and described the
phrase backwards.

**The picture is as wide as the phrase and the workflow says so**, rounded to
what these models work in. A phrase more than about two and a half times as wide
as it is tall is well outside anything a diffusion model has been trained on, so
the run says that rather than refusing — a long word is a legitimate thing to
ask for and the result is worth looking at even if it is bad.

**A vocabulary list lives in `input/phrases.lua`**, which is the point: one word
on a command line is a demonstration, and a chapter's worth is a study set.

One bug worth keeping: a phrase list with a syntax error in it was being treated
exactly like no phrase list at all, so a typo reported as *nothing to do*, with
no error anywhere. A file that is present and will not load is now a different
thing from a file that is absent. The record store is keyed by character, the
field is built from one character's strokes, the scene has one character's
components, and the workflow saves one character's picture.

## Intended behavior

**A word or phrase gets one picture, and that picture is the whole phrase.**

From `notes/041`: *images for kanji or sets of characters that comprise a phrase
or word*. A learner is not trying to hold 時 and 間 separately — they are trying
to hold 時間, *time*, and that is one thing.

**The strokes of every character in the phrase, laid out side by side, are the
composition.** Two characters means two boxes across the frame, each holding one
character at the same scale it would have alone. Three means three. The frame
grows wider rather than each character shrinking, because a phrase that squeezes
its characters to fit is a phrase whose characters stop being legible at the one
size this whole project is specified at.

**The scene is the phrase's meaning, and the cast is every piece of every
character.** 時間 is a sun, a temple, a gate and a sun again — and the scene is
whatever *time* means, not what 時 means followed by what 間 means.

**The arrows number continuously across the phrase.** Stroke one of the second
character is not stroke one; it is stroke ten, because that is the order a hand
writes the phrase in and the writing order is the viewing order.

**A phrase needs its own meaning, and the archives do not have one.** KANJIDIC2
glosses characters, not words. Three ways a phrase can get a meaning and they
should all work:

- given outright by whoever asked for it — `--phrase 時間=time,an hour`
- read from a list of phrases in `input/`, which is where a course's vocabulary
  would go
- fetched from a word dictionary, which is a fourth archive and a decision
  `docs/007` should hold rather than this ticket

**Selection grows a phrase selector.** Everything that takes `--chars` should
take `--phrases`, and a set may hold both — a rendering knows which it is.

## Suggested implementation steps

1. **A phrase record**, built from the character records it contains: the
   strokes of each with an offset, the components of each, the meanings given
   rather than looked up. The same shape as a kanji record wherever it can be,
   so that everything downstream keeps working on it unchanged.

2. **The field places each character in its own box.** `022` maps one
   109-unit box onto a square canvas; this maps N of them onto a canvas N times
   as wide. The blur must be computed from the crowding of a *single* character
   rather than from the phrase's total stroke count, or every phrase will be
   softened as though it were one impossibly dense character.

3. **The workflow's picture stops being square.** `EmptyLatentImage` takes a
   width and a height and they are already settings; a two-character phrase is
   twice as wide. Diffusion models have opinions about aspect ratios and a
   very long phrase will hit them — the run should say so rather than silently
   producing something the model was never trained on.

4. **Test that a phrase's strokes are the concatenation of its characters',
   in order, with the numbering continuous.** That is the property everything
   else rests on and it is one assertion.

## Related

`notes/041` — why. `019` — the store this extends. `022`, `026`, `029`.
