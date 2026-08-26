# 004 — Datapath: the scene grammar

`docs/003` decided *where* the darkness goes. This decides *what the darkness is*.

The scene grammar takes one kanji record and answers four questions, in this
order, because each answer narrows the next:

1. **What world is this?** — the biome
2. **Who is in it?** — the subjects, taken from the character's own components
3. **What is each line?** — a role per stroke, taken from that stroke's geometry
4. **Which way round is the light?** — the polarity

Its output is a *scene*, a plain table. `src/025-the-words-the-machine-reads.lua`
turns a scene into a prompt. Nothing else turns a scene into anything, and the
scene never contains prose — that separation is what lets the wording be rewritten
without touching the reasoning, and the reasoning to be tested without reading
English.

## 1. The biome

A biome is a world with a fixed vocabulary: a palette, a light, a set of things
that are allowed to exist in it, and a Japanese register that tells the model
*which* forest — a Hokkaido birch stand, a Kyoto temple grove, a satoyama
woodland edge.

It is chosen by scoring, not by branching. Every biome carries a list of trigger
words and a list of trigger components; each meaning of the character and each of
its components is looked up, matches add to that biome's score, and the highest
score wins. Three things make the score worth more than a chain of tests:

- the **primary meaning weighs more** than the later glosses, because KANJIDIC2
  orders them and the first one is the sense the character is normally used in
- a **semantic component weighs more than a keyword**, because the component is
  what the character was actually built out of and the keyword is a translation
- **ties are broken by the order the worlds are written in**, which means nothing
  and is at least the same on every run. The plan said to break them with the
  classical radical; the archive gives that as a catalogue *number*, and turning
  a number into a world would have needed a two-hundred-row table restating what
  the component decomposition already says better

A character that scores nothing anywhere is not given a default quietly. It is
reported. A silent fallback biome would mean an unknown fraction of the output
set is a generic landscape with no relationship to its character, and that
fraction would never be discovered because the images would look fine.

## 2. The subjects, and the components that are demoted out of being one

The components come from KanjiVG's group tree (`docs/002`). Each one is a
character in its own right, and this is where the etymology does the work:

> 休 is 人 beside 木. So the picture is a person beside a tree, and no mnemonic
> had to be invented, because that is what the character *is*.

Each component is looked up in the **component lexicon**
(`src/023-the-component-lexicon.lua`), which answers *what does this piece look
like as a thing in a picture* — and separately, *what is it called*. A phrase
goes into a sentence; a name is what a learner is told the piece is. The names
are derived from the phrases rather than written a second time, because writing
both by hand is one chance per row for the two to disagree. The lexicon is mostly not written by hand: a
component is usually itself a kanji, so its glosses are already in KANJIDIC2 and
the lexicon reads them out of the same record store everything else uses. Hand
authorship is reserved for the pieces that need it — components that are not
standalone characters (亠, 冖, 廴), and components whose dictionary gloss is too
abstract to paint (an entry glossed *rule, law* has to be told that it looks like
a measuring rod).

Two demotions apply, and both are demotions to something specific rather than to
nothing:

### Which of two pictures this is

Everything in this section describes **one of two readings**, and which one runs
is a setting. The distinction did not exist when this document was written and
`notes/041` is why it does now.

| Reading | The half chosen for its sound | The question it answers |
|---|---|---|
| `semantic` | becomes landscape, as below | *what does this word mean?* |
| `mnemonic` (default) | is a named subject like any other | *what can I hang the meaning on?* |

The argument below is the argument for `semantic`, and it is correct. It is not
the argument for `mnemonic`, which is this: 時 is a **sun** over a **temple**,
and the mnemonic works *because* a temple has nothing to do with time. A picture
showing only the sun has quietly dropped the half of the character a learner has
to account for when they meet it on the page.

**The scoring is identical under both.** A sound half never votes on which world
a character belongs to, in either reading, because that was never about the
picture — it is about what the character is *about*, and a piece chosen for its
sound is not evidence of that.

**Phonetic components are de-selected from subjecthood and re-selected as
landscape.** KanjiVG marks them with `kvg:phon`. In a phono-semantic compound the
phonetic half is there for how the word sounds, and painting it as a subject puts
an object in the picture that has nothing to do with the meaning — the most
plausible-looking way this project can be wrong. Its strokes still need to be
something, so they become terrain: ridgelines, paths, rock faces, reflections.
Present in the composition, absent from the sentence.

**And so is everything inside it**, which the archive does not mark and which is
where this first went wrong. Being a component *of* a phonetic component is not
a property anybody catalogues, but those inner pieces are exactly as unrelated to
the meaning, and they vote. 語 — *word, speech, language* — is a speech radical
beside a phonetic half, and that phonetic half contains two mouths. Counted, the
two mouths outvoted the speech radical and the scene came out as a person alone
in a room. 時 — *time* — is a sun beside a phonetic half containing earth, and
the earth outvoted the sun into a rice paddy. Both pictures would have looked
perfectly good and been about the wrong thing.

**Components with no usable gloss are de-selected from subjecthood and re-selected
as structure**, and they are *counted*. A lexicon that silently omits a fifth of
the components produces a set of images that are quietly about less than they
should be. The count is printed by every batch run, and a component that turns up
often enough in that report has earned an entry in the hand-written half of the
lexicon.

**The outermost component counts, and it is the character itself.** Skipping it
looks right — restating the whole character is not evidence about the whole
character — and it left every *atomic* character with no component evidence at
all. 一, 十, 大, 車 and a hundred like them scored nothing anywhere and were
reported as belonging to no world, and those are the first characters anybody
learns. For a compound the outermost element is almost never in a world's list of
pieces, so counting it costs nothing there.

A component's **place in the frame** comes from the bounding box of its own
strokes, not from its `kvg:position` label. The label says *left*; the box says
*the left third, upper half*, which is what a prompt can actually use.

## 3. The role of each stroke

`src/021-the-shape-of-a-stroke.lua` measures a stroke and returns:

| Measurement | Meaning |
|---|---|
| `direction` | horizontal, vertical, falling-left, falling-right, rising |
| `length` | end-to-end, as a fraction of the canvas |
| `travel` | arc length; `travel / length` well above 1 means it curves |
| `hooked` | whether it ends in a flick — measured as a sharp turn over the last fifth |
| `place` | which ninth of the frame the stroke's midpoint is in |
| `weight` | how much of the character's total ink this stroke is |

**Hookedness was going to be read out of the archive's label and is measured
instead**, and the reason the plan said otherwise is worth keeping. A hook is a
small flick at the end of a stroke; it barely moves the endpoint, barely changes
the arc length, and is invisible to every other statistic in that table — so the
plan concluded that geometry could not see it and the archive's own stroke
classification had to be consulted.

The conclusion did not follow from the premise. A hook barely moves the endpoint
and *sharply changes the direction*, and direction is the easiest thing here to
measure. Run `luajit src/021-the-shape-of-a-stroke.lua --calibrate`: every class
the archive labels as hooked averages a turn upward of seventy-five degrees over
its last fifth, and every class it does not labels under twenty-six. There is no
overlap. The measurement is used because it agrees with the label everywhere and
also works on the strokes the archive left unlabelled or labelled ambiguously.

The biome then supplies an object for that measurement. In a forest, a long
vertical is a cedar trunk; a long low horizontal is a fallen log; a falling-right
diagonal is a shaft of light through the canopy; a dot is a bird. In water, the
same long vertical is a cataract and the same dot is a stone breaking the surface.
The measurement is universal; the vocabulary is per biome.

**Not every subject is named either.** A crowded character can have six
nameable pieces, and naming all of them spends the sentence before the world is
mentioned. They are sorted largest-first so what survives the cut is what
dominates the picture.

**Not every stroke is named in the prompt.** A twenty-stroke character listed
stroke by stroke produces a sentence no diffusion model can hold. Only the
structural strokes are named — the ones carrying the most ink, which are the ones
that decide the composition. The rest are in the field and are left to be whatever
the scene puts there. How many get named is a knob, and it is in
`docs/balance-updates.md`.

## 4. Polarity

The biome decides whether ink is dark or light (`docs/003`). A forest against the
sky wants dark strokes; lanterns in a night street want light ones. This is one
field on the biome, and it flips the structure field and nothing else.

## The negative prompt is where this project is defended

The failure this design invites is a model that satisfies "kanji" by **painting
the kanji**. A brushed character on a wall, a banner, a carved sign — technically
present, completely useless, and the image will look good enough that it passes
a careless glance.

So the negative prompt names that failure explicitly and permanently: text,
letters, lettering, watermark, signature, calligraphy, brush strokes, ink wash,
chinese characters, japanese characters, kanji, writing, logo, border, frame.
Those terms are not tuning parameters and they do not vary per character. If the
character appears in the output, it must have appeared because the trees stood
that way.

## Worked example

`休` — *rest*, grade 1, six strokes.

- **Components:** 人 (left, semantic, glossed *person*), 木 (right, semantic,
  glossed *tree, wood*). Neither is phonetic; both become subjects.
- **Biome:** *tree* and *wood* trigger forest; the component 木 triggers it again
  and weighs more than a keyword. Forest wins comfortably.
- **Subjects:** a traveller in the left third; a cedar in the right two-thirds.
- **Structural strokes:** stroke 2 is a long vertical in the left third — the
  traveller's standing line. Stroke 4 is a long vertical, right of centre — the
  trunk. Stroke 3 is a long horizontal — a low branch across the frame.
- **Polarity:** forest is dark-ink; trunks against a bright sky.
- **Prompt, assembled:** a traveller resting against a cedar at the edge of a
  satoyama woodland, low sun behind the trunks, a long branch reaching across the
  frame, quiet, photographic — and none of the negative list.

The learner sees a person leaning on a tree. The person is the two left strokes
and the tree is the four right ones, and *rest* is what happens when you put those
two together, which is exactly the fact the character has been carrying for three
thousand years and that a flashcard throws away.
