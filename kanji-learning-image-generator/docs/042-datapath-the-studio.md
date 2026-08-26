# 042 — Datapath: the studio

Phases one to three make a recipe for every character. This is the machinery
that turns recipes into pictures, keeps every picture ever made, records how
good each one is, and lets a bad one be argued with.

`notes/041` is why it exists. This is its shape, written whole before any of it
is built, so that every interface between its parts gets settled while both
sides are still a sentence.

## The whole thing at once

```
  input/arguments/時.lua          a person's better argument, optional
        │
        ▼
  THE WALL                        every error named, located, and all at once
        │                         nothing quietly filled in
        ▼
  the scene                ◄──────  or, with no argument, the scene grammar
        │                           works it out as it always has (docs/004)
        ▼
  the recipe                      field, arrows, prompts, workflow  (docs/005)
        │
        ▼
  THE SUBMITTER                   posts it to a running ComfyUI and waits
        │                         the only part that talks to another machine
        ▼
  a rendering                     a PNG that machine drew
        │
        ├──────────────────────────────────────┐
        ▼                                      ▼
  THE MACHINE GRADER                    THE POOL
  squint at it and see if                <char>-<seed>.png
  the character is there                 <char>-<seed>.info.md
        │                                      ▲
        └──────────────────────────────────────┤
                                               │
  THE GALLERY  ──── a person clicks a tier ────┘
        │
        ▼
  THE DIAL                        per-world floor; says what raising it costs
        │
        ▼
  what gets shown, and what gets elaborated
```

## What an artifact is here

**A rendering: one PNG a diffusion model drew, from one recipe, at one seed.**

Not the recipe. The recipe is deterministic and reproducible from the character
alone — it is a *description*, and descriptions are not the thing being judged.
What varies, and therefore what needs judging, is what came back.

This means **the studio spans two machines** and the seam is an HTTP request.
Everything up to the submitter runs anywhere; the submitter needs a ComfyUI with
a graphics card behind it. Both halves live in this repository because both are
this project's, but only one of them can run without the other machine existing.

## The paintbrush, and why this project needs one

The closed set of things a description of a scene may say.

It exists for one sentence in `notes/041`: *supply them with better arguments as
we please*. A picture that missed has to be arguable with, and an argument is a
description somebody writes by hand. The paintbrush is the vocabulary that
description may speak, and it is **closed** — a short list of legal words with
nowhere for a plausible-sounding invention to go.

It is not designed. It is **extracted** from what this project already has:

| Word | Legal values | Comes from |
|---|---|---|
| `world` | one of the seventeen | `src/024` |
| `subjects` | pieces this character actually contains, each with a phrase | `src/023`, checked against the record |
| `strokes` | a phrase per stroke number this character actually has | `src/021` |
| `light`, `palette`, `register` | free text, replacing the world's own | `src/024` |
| `polarity` | `dark_ink` or `light_ink` | `docs/003` |
| `note` | free text, for a person, never used | — |

Everything in that table already existed as a field on a scene. The paintbrush
is that shape, published as a contract and enforced at a wall.

**The language is the parser.** An argument is a Lua file returning a table, so
syntax errors arrive with line numbers for free and there is no parser to write
or to debug. The wall checks vocabulary, not syntax.

**The wall names every error, locates it, offers the nearest legal word, and
reports all of them in one pass.** The vocabulary is small and closed, so the
nearest legal word is computable and is almost certainly what was meant. A
malformed field is an error; an absent optional field takes its documented
default, and that default is published in the paintbrush contract — a default
that exists only in code would be a fallback, and a fallback is a warning, and a
warning is an error.

## The pool is the filesystem

No database, no index, no schema. Every rendering is two files with the same
stem that travel together:

```
pool/sky/06642-時-0f3a91.png        what came back
pool/sky/06642-時-0f3a91.info.md    everything true about it
```

The companion holds: what it is; its category; the character; the description
that produced it, or the path to the argument that overrode it; the seed; the
paintbrush version; the canvas it answered; an **append-only** list of ratings,
each with a tier, who gave it, and when; and a list of elaborations.

Three things fall out of that and each is the reason for it:

- **Ratings survive their own history.** A tier is never overwritten; a new
  entry is appended and the last one wins. So a machine's guess stays visible
  underneath the correction a person later made, which is what makes the
  agreement rate computable at all.
- **Queries never open a picture.** *Which forest ones are tier 4 or better* is
  answered by reading small text files, not by decoding images.
- **Nothing can be separated from its meaning.** Copy the pair anywhere and the
  tier, the seed and the origin come with it.

**Nothing is ever deleted.** A low tier is the record of what missed and by how
much. Storage is cheap and judgement is expensive.

**Which is why the pool is on the disk and not in the RAM tier**, where every
other thing this project writes at runtime goes. That exception is the whole of
`410`: it was in the RAM tier, the machine restarted, and every rating anybody
had given vanished without a word — leaving a pool that looked exactly like one
nobody had filled yet.

The same reasoning goes one level further. A picture is large and can be made
again, because the same description and the same seed produce the same bytes. A
companion is a few hundred bytes holding somebody's opinion, and no seed
regenerates an opinion. So the companions are in the record and the pictures are
not, and a clone arrives holding every judgement ever made and none of the
pictures — which is a supported state, and the report says so and gives the
command that makes them again.

**Counts come from a utility, never from a number written into a document.**

## The category is the world

Quality is never discussed globally — it is always *these* that are looking bad,
and the unit somebody says that about here is the world. *The forest ones are
all the same tree.* So the category is the world's name, the pool is arranged by
it, and the floor is set per-world.

A second axis crosses it: a rendering is of a **character** or of a **phrase**.

## Two graders, and the machine one closes an old question

**A person's grader is the gallery.** It already shows every rendering at
thumbnail size; a tier is five buttons under each one. It is a *viewer* and it
reads finished files only — it never reaches back into the machinery that made
them, because a grader with access to the generator's internals is grading the
intent rather than the result, and the result is all anybody else will see.

**The machine's grader squints.** `docs/007` Q1 asked whether *the illusion
worked* could be measured at all, and answered: shrink the rendering to
thumbnail size, blur it, and correlate it against the structure field that
produced it. That was left open because it needed generated images to test
against. The submitter produces exactly those.

It measures agreement with the *field*, which is not the same as legibility as a
character, and it says nothing about the other failure — a model that painted
the character on a wall and scored beautifully. Both limits are real, both are
written down, and a grader that is wrong in known ways beats no grader at all,
because it can be measured against a person's ratings.

**Which grader runs is a dispatch key, not a branch**, and both write the same
field. Everything is machine-rated on arrival so that floors work from the first
day; a person corrects whatever they feel like, and their rating wins and is
marked as theirs.

**The floor that stops it drifting**: a guaranteed fraction of renderings gets a
person's rating, and the agreement rate is reported where it can be seen. Let a
person's ratings become rare and the whole apparatus converges smoothly on the
grader's taste rather than theirs, with nothing raised anywhere.

## The dial

Per world, set at run time, never a build-time constant.

Raising a floor costs variety and **the system says so before it happens**:
*raising forest from 3 to 4 leaves 31 to draw from instead of 214, so expect
them to start resembling each other.* The trade has to be visible at the moment
of choosing rather than discovered afterwards in the output.

A second dial is provenance: *tier 4 or better* and *tier 4 or better as judged
by a person* are different requests and the second is smaller and more
trustworthy.

Re-rating is offered with its own cost attached and declining is free. A studio
that nags is a studio nobody opens.

## What a higher tier buys

**A stroke-order animation.** One frame per stroke, the character being written
over the picture that hides it. It is the most useful thing a study tool can own
and it is expensive enough to be worth reserving for renderings somebody already
said were good.

The encoder is ours, as the PNG one is: GIF89a is frozen, it is a few hundred
lines, and a borrowed encoder converts our errors into somebody else's silence.
The compression is the same family of trick as the one already written for PNG.

**Elaboration extends, never regenerates.** Same description, same seed, one
parameter differing. If elaboration re-rolled, what came back would be a
different picture wearing the old one's tier, and after a few rounds every tier
in the pool would describe something that no longer exists.

**Promotion creates work.** Moving a rendering from 3 to 5 means it now deserves
an animation it does not have, so a re-rate emits a work order and the queue of
outstanding elaboration is a thing that can be counted and worked through. The
rating system is the generator's task queue.

**Demotion never destroys.** It stops further investment; it does not remove
what was already made.

## The wall between making and looking

The submitter writes into the pool. The gallery reads the pool. They share no
code and never will. When the gallery shows something wrong, *is the file wrong
or is the display wrong* is answered by opening the file in any other program,
and the answer is definitive. Share one line between them and that question
becomes unanswerable forever.
