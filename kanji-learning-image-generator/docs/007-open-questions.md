# 007 — Open questions

Every question this project has raised, closed and open together, in one place.
An open question is not decoration and not a closing section: it is work that has
not happened. A task holding one is in progress, whatever its issue file says.

Closed questions keep their answers here rather than being deleted, because the
reason a thing was decided is more useful than the decision.

---

## Open

### Q1 — Can "the illusion worked" be measured at all? — **answered, partly**

Yes, well enough to be useful. `src/046` shrinks a finished picture to thumbnail
size, blurs it, and correlates it against the field that produced it. A field
against itself scores 1.00 and against a different character's about 0.39, and
that gap is what the five tiers divide up.

Both doubts below were right and neither turned out to be fatal, because the
machine's ratings are measured against a person's continuously — every rendering
they both rated is a free measurement of how often the machine agrees, and that
number is printed where it can be seen.

What remains open is not the measurement but the **anchor**: if a person's
ratings become rare, the apparatus converges on the grader's taste with nothing
raised anywhere. There is a floor and it is reported. Nobody has watched it over
a long run.

The original question and its two doubts, kept:



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
it and does not know Lua. **This got more pressing while it waited**: the table
is now well over a hundred and fifty rows, and every row added is a row that has
to move if the answer is yes.

### Q7 — Should the trigger lists keep growing until nothing is refused?

`204` refuses to invent a world for a character that matches nothing, and the
count of those fell from a hundred and twenty-three to thirty-five as the lists
were widened in response to real runs. Run `src/024 --spread` for where it
stands.

The remaining ones are mostly abstract or archaic — *merit*, *effort*,
*already*, *concave*. Two directions, and they are genuinely different:

Keep widening the lists until every character has a world. That means inventing
imagery for concepts that do not have any, and the invented ones will be
indistinguishable from the earned ones once they are in the file.

Or stop, and let the refusal stand as the honest answer for a character this
project has nothing to say about. That means a learning set with holes in it,
and the holes are in exactly the abstract characters a learner finds hardest.

Nobody has decided. The lists were widened opportunistically each time a real
run reported a gap, which is a policy by accident rather than by choice.

### Q8 — Is one world in three the right shape for the distribution?

About a third of the whole archive lands in the *person* world. That is not
obviously wrong — mouth, person, eye, hand and heart really are the commonest
radicals there are — but it means a third of the output will be figures in rooms.

The alternative is splitting that world into several: the body, the face, work,
the crowd. It would spread the output and it would also be the point at which
the world list stops being a list of places and starts being a taxonomy, which
is a different kind of thing to maintain.

### Q9 — Are the model and control net named in the settings the right ones? — **answered**

Yes, and by luck as much as judgement. This machine has an eleven-gigabyte
Pascal card, which suits the older generation of model the settings already
named; the newer generation would have been slow and tight on it. `404`
installs both and the pictures come out.

What was *not* right was the strength the control net is applied at, which was
set at less than half what it should be. See `docs/balance-updates.md`.



### Q10 — Is the heat trade set where a person would want it?

`307` made a run take under half the machine and rest when the processor climbs,
which cost roughly two and a half times the wall clock for eight degrees off the
mean. Those numbers were chosen against one processor on one afternoon.

A machine with better cooling is being slowed down for nothing; a laptop may
want more caution still. The knobs are all in `input/settings.lua` and none of
them has been tried anywhere else.

### Q15 — Which style suits which character, and can that be decided rather than guessed?

`412` made style a thing you can ask for, and the first four asked for it did
not agree. Against the photographic default, a Wimmelbild took 川 from 0.76 to
0.98 and 木 from 0.64 to 0.87 — and took 語 from 0.75 down to 0.52.

The pattern in four characters is not a finding, but there is a guess worth
testing: the two that gained have radicals that are **things you can stand in a
landscape** — posts in water, a tree in a wood. The one that lost is abstract,
and its scene was already a crowded desk, so a style whose whole instruction is
*crowd it with small objects* had nothing left to add and something to lose.

If that holds, style belongs on the **world** rather than on the run — water and
forest asking for a teeming picture while word stays photographic. Deciding it
needs more than four characters, and the pool now records which style made each
rendering, so the comparison is a query rather than an experiment.

### Q11 — Are the radical names the right ones?

`401` gives every piece a short name, and those names are **ours**. Most are
derived from the phrase already written for that piece; the rest are corrections
somebody typed.

The person this was built for is learning through a system that has its own
names for radicals, and a learner who meets *leader* here and something else
there has been given two things to remember instead of one. Matching an existing
system exactly would mean either taking its list — which belongs to somebody —
or reconstructing it, which is guessing at somebody's choices.

The names are marked as ours wherever they are shown, which is honest and is not
the same as being useful.

### Q12 — Can a phrase be animated?

`408` refuses, and says so. A word's record is *built* from its characters
rather than read from the store, and nothing reconstructs one from a companion
file — so the animation cannot find the strokes it needs.

The fix is small and nobody has done it: record the characters in the companion,
which is already there under `characters`, and rebuild.

### Q13 — Is there a second measurement, for the failure the first is blind to? — **now urgent, with evidence**

No longer hypothetical. Asked for a Wimmelbild, 時 came back with its right half
**drawn** — dark horizontal bars and an upright with a cross on top, standing
against the sky. They are not objects in a scene; they are strokes. And the
machine gave it **0.84**, its second-highest score of the run.

That is the failure being *rewarded*. It has to be, by construction: the grader
measures how closely the finished picture's light and dark match the field, and
nothing matches a field better than the character itself. The score is not
merely blind to this failure — it is maximised by it.

Two consequences, and the second is the uncomfortable one:

- **A high score is not automatically good**, and nothing in the pool says which
  high scores are which. A floor set at tier 5 selects for this failure.
- **Any future tuning against this grader will drift towards it.** The strength
  sweep in `docs/balance-updates.md` was measured against exactly this number.
  It gave a good answer, and it would have kept giving "better" answers past the
  point where the pictures stopped being pictures.

What would catch it: the difference between a stroke and an object is roughly
uniform width, hard edges, and no attachment to anything around it. A thing in a
scene casts a shadow, is occluded, and varies in thickness. That is a harder
measurement than the first, and it is the one that decides whether this project
is generating illustrations or diagrams.

Until it exists, **looking is the only defence**, and the phase demonstrations
exist for that reason.



The machine grader (`406`) measures whether the finished picture's light and
dark landed where the strokes are. It cannot see the other failure at all: a
model that satisfies *kanji* by painting one onto a wall in the scene scores
beautifully.

Something would have to notice **brush strokes rather than scenery** — high
contrast, hard edges, uniform stroke width, a shape sitting on a surface rather
than being made of one. That is a harder measurement than the first and it is
the one the negative prompt is defending against, so it is also the one nobody
would find out had failed.

### Q14 — What happens to old ratings when the paintbrush changes?

Every rendering records which version of the vocabulary it was made against,
which was the whole point of storing it. Nothing does anything with that yet.

When the vocabulary changes — a world renamed, a piece re-described — every
rating made before it describes a picture that would not be made the same way
now. They are not wrong, exactly. They are answers to a question that has since
been reworded, and there is no rule yet for what to do with them.

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
