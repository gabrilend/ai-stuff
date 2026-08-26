# 007 — Open questions

Every question this project has raised, closed and open together, in one place.
An open question is not decoration and not a closing section: it is work that has
not happened. A task holding one is in progress, whatever its issue file says.

Closed questions keep their answers here rather than being deleted, because the
reason a thing was decided is more useful than the decision.

---

## Open

### Q1 — Can "the illusion worked" be measured at all?

The specification is *a person squints at the thumbnail and sees the character*.
Nothing in this repository can check that, because this repository never sees a
generated image — it emits recipes.

There is a shape of an answer: downscale a generated image to thumbnail size,
blur it, and correlate it against the structure field. High correlation means the
finished picture's broad light and dark really did land on the strokes. It would
be cheap, and it would run wherever the images actually get made.

Two doubts. It measures agreement with the *field*, not legibility as a
*character* — a picture could correlate well and still be unreadable because the
strokes merged. And it says nothing about the other failure, the one where the
model painted the character on a wall and scored perfectly.

**Not started.** It needs generated images to test against, which needs a machine
with a GPU, which this is not.

### Q3 — Should a component's own picture be reused inside the characters that contain it?

木 gets an image. 休, 林, 森, 材, 村 all contain 木 and all get their own images,
each inventing its own tree.

If the tree in 木's image were the same tree every time, a learner would
accumulate a visual vocabulary — recognising *that cedar* in a new character
before reading anything. That is a much stronger teaching claim than this project
currently makes.

The machinery is not obviously there. It would mean either fixing the described
tree in words so tightly that the model reproduces it, which diffusion models
resist, or generating components first and using them as image inputs to the
characters that contain them, which is a second, harder pipeline. Worth deciding
before the vocabulary in `src/023` grows large enough that changing its shape is
expensive.

### Q4 — Is one image per character right, or should a character get several?

A kanji has several meanings, and 生 notoriously has a great many. One scene has
to pick, and picking the primary gloss means the other senses are unrepresented.

Generating one image per sense group is a small change to the batch driver and a
large change to what the deliverable is. It also multiplies the set size by an
unknown factor. Unasked and undecided.

### Q5 — How much of the stroke-order ramp survives the diffusion?

`docs/003` lays stroke one down darker than stroke six so the composition pulls
the eye along the writing order. Whether any of that ordering survives sampling
is unknown and is probably a small effect on top of a large one.

If it does not survive, the ramp is costing contrast for nothing and should be
turned off — it makes late strokes weaker, which makes them likelier to be lost.
Needs generated images to answer. Until then the knob defaults low.

### Q6 — Do the hand-written parts of the component lexicon belong to this project?

`docs/004` derives most component glosses from KANJIDIC2 and hand-writes the
rest. The hand-written part is a small dictionary of what shapes look like, and
it is the only place in the project asserting something no archive said.

It should probably be a data file rather than a table inside a source file, so
it can be corrected by somebody who knows kanji better than the person who wrote
it and does not know Lua. Not done, and the longer it waits the more entries have
to move.

---

## Closed

### Q2 — What happens to the characters KanjiVG draws and KANJIDIC2 does not gloss?

**Asked because the number looked alarming and turned out to be three numbers.**
Nearly three hundred characters were being dropped for having strokes and no
gloss, which sounded like a large hole in the output set.

Sorting them apart made it small. The overwhelming majority are **not kanji** —
the stroke archive also draws letters, digits, punctuation and both syllabaries,
and no kanji dictionary lists those. A further handful are in the **compatibility
block**, glossed elsewhere under another number. What is left, the actual gap, is
a few rare and archaic characters that nobody learning Japanese will meet.

So: nothing worth rescuing by hand, and the question is closed. `docs/002` has
the three categories and `src/019 --report` has the current counts.

Left behind by it is a smaller question that is genuinely unanswerable from what
is on disk: **which ordinary character does each compatibility character
duplicate?** Two derivations were tried and both were refuted by their own
checks — comparing the drawings (they differ on purpose; that is what the block
is *for*) and reading the archive's own element name (it names itself). The
pairing is in Unicode's character database, which would be a third dataset
fetched to resolve nine characters nobody is learning. Not worth it, so they are
excluded and named. If that judgement ever changes, the mapping is one file away.

### Why not derive strokes from a CJK font instead of KanjiVG?

**Because a font has no stroke order and no decomposition.** An outline of 休 is
one silhouette. It cannot say that the left half is 人, cannot say which mark was
made first, and cannot say that a hook is a hook. Both of the things that make
this project more than a filter — the etymology and the writing order — exist
only in KanjiVG. Closed at the outset; recorded because a font is the obvious
first idea and it is a dead end for a specific reason.

### Why is nothing here written in Python, given that ComfyUI is?

**Because nothing here talks to ComfyUI.** The output is JSON on disk. The
boundary is a file format, not a library call, so the language on this side is
free and the house preference applies. Were this project to submit jobs to a
running server it would still be an HTTP POST.

### Why emit both workflow formats rather than converting between them?

**Because the conversion needs facts neither format contains.** Going from API
format to UI format requires knowing every node's socket names and widget order,
and going the other way requires knowing which widgets are interface-only
(`docs/005`). Once that catalogue exists, emitting both from one description is
strictly less code than emitting one and converting. Closed while writing `301`.

### Why is the arrow layer composited in ComfyUI rather than here?

**Because the picture it goes on top of does not exist here.** Compositing on
this side would mean a second pass over the output directory of a machine this
project never sees. Three nodes in the workflow put it in the same file the
sampler writes.
