# 107 — Letters the archive already drew

## Current behavior

There is no lettering anywhere in this project, and one file refuses it in
writing. `src/026` draws its stroke numbers as seven-segment figures and says
why:

> WHY DIGITS ARE DRAWN AND NOT TYPED. There is no font machinery anywhere in
> this project, and adding one for ten shapes would be the largest dependency
> here by a wide margin.

That was right about ten shapes and it is wrong about a hundred, because it
assumed the shapes would have to come from outside. They do not.

**The stroke archive already contains the alphabet.** KanjiVG is a file of
characters drawn as ordered strokes, and the characters it draws are not only
kanji. Asked for the printable low range it answers for

```
  ! , . 0-9 : ; ? A-Z a-z
```

and asked for katakana it answers for all of it — the plain syllables, the small
ones, the voiced forms, and the long-vowel mark. Hiragana too. Every one of them
is what the kanji are: paths in the archive's 109-unit box, in writing order.

So the letters are already strokes, and this project has read strokes since
`102`, flattened their curves into runs of straight segments since `103`, and
laid a run onto a surface as a thick soft mark since `104`. A word is a row of
characters that all three of those handle without being told anything new.

What is genuinely missing is small and countable. Glosses in the meaning archive
use nine shapes the stroke archive does not draw. Counted over every English
gloss in it, most-used first:

| shape | roughly how often | what it is for |
|---|---|---|
| space | everywhere | between words |
| `(` `)` | ~650 each | the qualifier half of a gloss |
| `-` | ~330 | hyphenated senses |
| `'` | ~140 | possessives |
| `*` | ~19 | the archive's own marks |
| `"` | ~18 | quoted senses |
| `&` | ~17 | *and* |
| `/` | ~15 | alternatives |
| `%` | 2 | one gloss, twice |

Those counts are what a scan of the archive says today; the coverage mode
described below counts them again rather than trusting this table.

## Intended behavior

**A line of text, drawn by the machinery that draws kanji.**

`src/016a-letters-are-strokes-too.lua` — beside the canvas that draws them,
because that is what it is: ink, and nothing in it knows what a kanji means or
what a gloss is.

**Glyphs are read out of the stroke archive directly, not through the join.**
`019` joins the two archives on the character and keeps only ideographs; no
dictionary glosses the letter R, so a letter cannot survive that join and must
not be asked to. The alphabet asks `012` for the codepoints it wants and gets
back the same stroke entries every kanji is made of.

**The whole alphabet is about a hundred entries and it is cached like the
store.** A run that letters six thousand panels must not re-scan thirteen
megabytes of XML for the shape of an *e*. The cache belongs in the RAM tier
beside `019`'s, keyed by the same archive stamp, so a new archive release
invalidates it the way it invalidates everything else.

**Nine shapes are ours, and they are marked as ours.** Space draws nothing and
advances. Hyphen, slash, parenthesis, apostrophe, quote, asterisk and percent
are a handful of polylines each, written in the same 109-unit box the archive
uses so nothing downstream can tell where a glyph came from. `&` gets no shape:
it is replaced with the word *and* before drawing, because one ampersand costs
more polyline than the three letters it stands for and reads worse at thumbnail
size.

**A tenth shape is ours and is not a letter.** `~`, which the archive does not
carry at any codepoint, drawn as a wave rather than as the typographic tilde —
`208` runs it end to end as a border and a border made of dashes with gaps in it
is a dashed line, not a squiggle.

**Advance widths are measured, not assumed.** Every glyph sits in the same
109-unit box, and an *i* uses a tenth of its box while an *m* uses all of it.
Advancing by the box would set every word as if it were on graph paper. So each
glyph is flattened once, the extents of its ink are taken, and the advance is
that width plus a tracking constant — which also means a glyph whose ink turns
out to sit somewhere unexpected in its box is visible as a measurement rather
than as a mystery in a finished panel.

**Nothing is drawn before it can be measured.** A caller has to be able to ask
how wide a line will be without drawing it, because `208` centres text and
chooses a size that fits, and both of those are decisions made before there is
anywhere to put the ink.

**A missing shape is reported, never silently skipped.** A gloss containing a
character with no glyph must come back as a list of what could not be drawn.
Dropping it leaves a hole in a panel that a person will read as a typo in the
dictionary.

**It draws in colour with an outline, exactly as `026` does.** The two-pass
trick in the arrow layer — everything drawn once fat in the dark outline colour
and once thin in the bright one — is what makes yellow survive a bright sky, and
lettering that will be laid over a photograph needs it for the same reason.
`208` puts letters on a black panel where the outline does nothing, but the
capability belongs here rather than being rebuilt the first time anybody letters
a picture directly.

### What it offers

| | |
|---|---|
| the alphabet | every glyph the project can draw, read once and cached |
| a measurement | how wide a string is at a given size, before any ink |
| a line | one string, drawn onto a sheet at a point, in a colour, with its outline |
| a centred line | the same, centred in a box that is given rather than computed |
| what is missing | which characters of a string have no shape |
| a coverage count | how much of the meaning archive's gloss text this can actually draw |

### It must be legible at thumbnail size

The same constraint that resized every arrow in `206` applies here and will be
got wrong the same way if it is reasoned about at full size. The whole project
is specified at `field.thumbnail` — 96 pixels. A panel is read at that size
first and opened at full size second.

## Suggested implementation steps

1. **Find out what the archive actually contains before designing around it.**
   A mode that writes the entire alphabet as one picture — every glyph the
   archive gave, every glyph written here, at panel size and again at thumbnail
   size. The Latin letters in KanjiVG are drawn as handwriting rather than as
   type, and whether that reads as charming or as illegible is a thing to look
   at rather than to predict.

2. **The reader and the cache**, keyed by `019`'s archive stamp, in the RAM
   tier. Not in the repository: it is derived from a file that is not committed
   either.

3. **Measure every glyph once** when the alphabet is built, and keep the extents
   beside the strokes. Measuring at draw time re-flattens the same curves for
   every word on every panel.

4. **The nine shapes and the squiggle**, in one table, each commented with why
   it is written by hand instead of read.

5. **Sizes, tracking, outline width and colours go in `input/settings.lua`**,
   with everything else, and every turn of one goes in `docs/balance-updates.md`.

6. **Tests in `020-test-the-ink`**, which is where phase one's tests live. The
   ones worth writing are the ones that fail quietly otherwise: that a measured
   width matches the ink a drawn line actually leaves; that a string containing
   a shape nobody has is reported rather than drawn short; that the alphabet
   builds from a cold cache and from a warm one and produces identical pictures.

## Open questions

**Does the arrow layer's seven-segment figure survive?** Deferred deliberately:
build the alphabet with digits in it, draw the same character both ways, look at
the two at thumbnail size, and record the answer in `docs/balance-updates.md`.
The argument for the seven-segment figure is that it reads as part of a diagram
rather than as text, which is a real argument and not obviously wrong. Until
somebody has looked, both exist.

## Related

`012` — the stroke reader these glyphs come out of.
`015` — curves into runs, which is what makes a glyph drawable.
`016` — the surface and the brush that puts them down.
`026` — where the refusal is written, and the outline trick this borrows.
`207`, `208` — the first two things to use this.
