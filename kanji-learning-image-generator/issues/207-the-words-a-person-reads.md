# 207 — The words a person reads

## Current behavior

`src/025-the-words-the-machine-reads.lua` turns a record into the sentence a
diffusion model was trained to answer. That sentence is written for a machine
and it reads like it: a scene, a biome, a list of subjects, a negative list, all
of it aimed at getting a picture made.

Nothing in this project writes the other sentence — **the one a person reads to
find out what the character means.** The gallery prints a gloss in HTML beside
the picture, but that is a page rather than an artifact, and it exists only for
as long as somebody keeps the folder it points into.

## Intended behavior

`src/025a-the-words-a-person-reads.lua`, beside `025`, because they are the same
act pointed at different readers: a record in, words out, no pixels anywhere in
either. This one produces a **caption** — a table of lines with a rank on each,
which `208` draws and which anything else could print.

**What a caption holds, in the order it is read:**

| line | what it says | where it comes from |
|---|---|---|
| the headline | the primary gloss — *rest*, *tree* | `meanings[1]` from the meaning archive |
| the support | the next two glosses | `meanings[2]`, `meanings[3]` |
| the reading | how it is said, in katakana | `readings_on`, or `readings_kun` converted |
| the pieces | every component and what it means | `023`'s lexicon over `record.components` |

**The reading is katakana, and that is a choice rather than a convenience.**
The archive gives on-readings in katakana and kun-readings in hiragana, and the
convention behind that split is a Japanese one about where a reading came from.
This is a study card made in English for somebody learning from English, and it
shows the reading in the script Japanese itself reserves for words arriving from
somewhere else. Where a character has an on-reading, that reading is already
katakana and is used as it stands. Where it has none — about one entry in
fourteen — its kun-reading is converted, which is a fixed offset in the
codepoint table between the two kana blocks and not a transliteration.

**A converted reading must not pretend to be a native one.** Kun-readings in
the archive carry a dot where the character's part of the word ends and the
trailing kana begin, and a leading dash on the ones that are suffixes. Those
marks survive the conversion unchanged, so a reading that came from the hiragana
column still says so on the panel. Flattening both columns into unmarked
katakana would erase a distinction the dictionary carries, and this project's
rule is that everything on a card comes out of an archive and says which one.

**The pieces are the reason the panel exists at all.** `docs/001` says the
bridge this project builds is that the shape is the picture of the word, and the
bridge is only visible when the pieces are named: 休 is a person beside a tree,
and that is the archive's claim about the character rather than ours. So each
component gets a line — the piece as it is written, and the name `023` gives it,
which is the same name `024` used to decide what the picture is of. **The panel
and the picture must agree, because they are made from the same lookup.** A
panel that named its pieces from a second source would be a second scene
grammar, and the day the two disagreed the panel would be lying about the
picture beside it.

**A piece with no name is shown as a piece with no name.** `023.look_up`
returns nothing for a component it cannot picture, and `docs/004` already turns
those strokes into structure rather than into a subject. The panel does the
matching honest thing: the piece is drawn and the name is left blank, and the
count of unnamed pieces goes into the card. A component quietly dropped from a
panel is a character that appears to have fewer parts than it has.

**How many pieces fit is decided by the panel, not here.** This produces every
piece it can name, ranked, and `208` takes what fits and says how many it left
out — the same shape as `206`, where an arrow that cannot find room gives up,
keeps its number, and is counted.

**A long gloss is a real case and is not truncated silently.** Some glosses in
the archive are whole clauses. The headline names a size ladder rather than one
size: it steps down until it fits, then wraps to a second line, then — only then
— is cut at a word boundary, and a cut is recorded in the caption so the card
can say it happened.

**A phrase is captioned too.** `019a` builds a record for a whole word, whose
meaning had to be supplied because the archives gloss characters and not words.
So a phrase's headline is the supplied meaning, its pieces are its characters
each carrying its own primary gloss, and its reading is each character's reading
in order — which is wrong for a phrase whose reading is irregular, and is
therefore marked as assembled rather than as read out of an archive.

### What it offers

| | |
|---|---|
| a caption for a character | the four kinds of line, ranked, with what was cut recorded |
| a caption for a phrase | the same shape, from a supplied meaning and its characters |
| one reading, in katakana | on-reading if there is one, converted kun-reading if not |
| what could not be said | unnamed pieces, cut glosses, assembled readings |

## Suggested implementation steps

1. **The reading first, because it is the part with a rule in it.** On-reading
   preferred, kun-reading converted by the block offset when there is none, the
   dot and dash kept, and the caption saying which column it came from. Test it
   against a character with both, one with only kun, and one with neither.

2. **The pieces through `023.look_up` and nothing else.** Same lookup, same
   order — written lexicon, then the piece's own dictionary entry, then the
   entry for the character the piece is a squeezed form of.

3. **The size ladder and the piece cap live in `input/settings.lua`**, because
   they are the numbers that will be wrong the first time and every change to
   them belongs in `docs/balance-updates.md`.

4. **Tests in `027-test-the-meaning`.** The ones that matter: that the panel's
   piece names are identical to the ones `024` put in the prompt for the same
   character; that a character with no on-reading still gets katakana; that a
   converted reading keeps its dot; that a gloss too long to fit reports the cut
   rather than arriving short.

## Open questions

**Whether the support glosses should be the next two, or the next two that
differ.** The archive frequently lists near-synonyms — a card reading *rest /
repose / resting* teaches once and takes three lines to do it.

**What a character with one gloss shows.** 生 has many; plenty have exactly one.
Blank lines, or a taller headline, or fewer lines and a shorter panel.

## Related

`025` — the same act, aimed at a machine.
`023`, `401` — where a piece's name comes from, and the ticket that gave every
piece one.
`019a` — the phrase record this must also caption.
`107` — the shapes these words get drawn with.
`208` — what draws them.
