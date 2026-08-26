# The sprite studio

[The dynamic picture](012-the-dynamic-picture.md) says the view is told *what a
thing is*, not what it looks like this frame, and leaves open where the
appearances come from. This document answers that: they come from a studio that
generates them, keeps every one it has ever made, and gets better because
somebody said what they liked.

## What it emits

**One animated SVG per sprite.** Self-contained, vector, text.

Four things follow from that choice and each of them is load-bearing:

- **It is not a .png**, which is the requirement from
  [the vision](../notes/vision) stated as a file format.
- **It is watchable as it stands.** Open it in a browser and the goblin walks.
  This matters more than it sounds: a rater who is shown a still frame of an
  animation is rating an illustration, not an animation, and a project about
  motion cannot be judged by somebody blind to motion.
- **It is text**, so it diffs, and so the encoder is string-writing rather than a
  compression format. Nothing is borrowed to produce it.
- **The renderer can use it directly** -- scale it, tint it, recolour a layer,
  compose it -- because vector parts survive being transformed and a raster sprite
  does not.

## The paintbrush and the canvas

**The paintbrush** is the closed set of moves a sprite description may use: the
layer names the renderer understands, the animation states it will drive
(`idle`, `walk`, `turn`, `open`, `flicker`), the palette slots it can tint, the
anchor points it attaches things to. It is *extracted* from the renderer, not
invented -- if the renderer cannot drive a state, that state is not a word.

It is closed on purpose. Handed a complete reference, anything generating
descriptions will invent plausible neighbouring words that do not exist, and do it
confidently and in good style. A short allowlist has nowhere for the analogy to
go.

**The canvas** is the brief for one sprite: what it is, what category it belongs
to, what it needs to read as at a glance.

Between them sits **a wall, not a net**. Every error names the entry, the field,
and what was wrong; carries the nearest legal word, since the vocabulary is small
enough that edit distance means something; and all errors are reported in one
pass, because stopping at the first turns fixing a description into one guess per
run. Nothing is quietly filled in. A documented default for an *absent optional*
field is vocabulary; a default that exists only in code is a fallback, and a
fallback is a warning, and a warning is an error.

## The pool

Every sprite ever generated, kept. Nothing is ever deleted -- a low tier is not
waste, it is the record of what missed and by how much, and a pool that has been
pruned cannot answer any later question about why the output drifted.

Each entry holds the sprite, the description that produced it, the paintbrush and
canvas it came from, its **category**, its **tier**, and **who set that tier and
when**.

Category is the unit quality gets discussed in, because quality is never discussed
globally. Nobody says "the sprites are bad"; they say *the goblins* are bad. Here
the categories are the `kind` families a ruleset declares -- goblins, doors,
drinking vessels, flames.

Five tiers, one scale, written by people and machines alike: 5 reach for it first,
4 use freely, 3 fine among others, 2 kept but not reached for, 1 the record of
what missed.

## Two ways of rating, and they are different machines

Both are built. Both are tested. Which one a project is running is a setting, and
switching costs nothing because they write the same field.

### Algorithm A -- rate on arrival, correct on inspection

The machine rates **everything**, the moment it is generated. A person rates a
little, whenever they feel like it. Both write the same field, the person's rating
wins, and it is marked as a person's.

This exists because of an arithmetic problem: if everything generated is kept and
only a little is ever looked at, the pool is overwhelmingly unrated, and a floor
of "tier 4 or better" would exclude nearly the whole library. Machine-rating on
ingest means every artifact has a tier, so floors work from the first day.

It pays a second time. Wherever both a machine tier and a person's tier exist for
one sprite, that is a free measurement of **how often the machine agrees with
you** -- continuously, as a by-product of ordinary use, with no evaluation exercise
ever being run. A machine grader nobody has measured is not a grader, it is a
rumour.

Its shape: **large pool, thin judgment, measured**.

### Algorithm B -- judge the pool, then curate in play

A person passes over the whole library once and assigns every sprite a tier. From
then on, **the rating happens during play**: mid-session, the moment somebody
looks at a goblin and thinks *that one is wrong*, they change its tier right
there, at the table, and carry on.

Curating with their mind. Rating the ones they come across, if they want.

Its shape: **small pool, complete judgment, contextual**.

Three things it has that A does not:

**Every rating is a person's**, so provenance is uniform. There is no agreement
rate to compute, because there is nothing to compare against -- which removes a
whole apparatus and also removes the safety measurement that apparatus provides.

**The judgment happens in context.** This is the real argument for it and it is
specifically a tabletop argument. A goblin sprite judged in a gallery is judged as
a picture. The same sprite judged mid-session is judged on *did that read as a
goblin at the moment I needed it to, at that size, in that light, next to those
other things.* That is a better question and it can only be asked while playing.

**The pool is bounded by patience.** The opening pass is the constraint: a library
is only as large as somebody will sit through. That is a real limit and it is also
the source of the quality -- everything in it has been looked at by a person.

### Which is which

| | A | B |
| --- | --- | --- |
| Pool size | Unbounded | Bounded by one person's attention |
| Coverage | Everything rated, mostly by machine | Everything rated, all by a person |
| When a person judges | Whenever they feel like it | Once at the start, then during play |
| What they are judging | A picture, in a gallery | A thing, in a session, in context |
| Machine-agreement measurement | Free and continuous | Does not exist |
| Fails by | The machine's taste quietly becoming yours | Running out of patience before the pool is big enough |

Neither is the better one. A is what you want for ten thousand generated
dandelions. B is what you want for the forty things that actually appear in your
campaign.

## The two dials

**The floor is per-category and set at run time.** You raise quality on *the
goblins*, because the goblins are what is bothering you. Not a global setting, not
a build-time constant.

**Raising it costs variety, and the system says so before it happens.** Moving a
category's floor from 3 to 4 reports how many sprites survive at each -- "31 to
draw from instead of 214, so expect them to start resembling each other" -- at the
moment of choosing, rather than being discovered afterwards in the output.

**The second dial is provenance.** "Tier 4 or better" and "tier 4 or better *as
judged by a person*" are different requests, and the second is smaller and more
trustworthy. Under algorithm B they are the same request, which is exactly what B
is for.

**Re-rating is offered, never forced.** The offer carries its own cost so the
answer can be informed, and "not now" costs nothing and is not asked again in the
same breath. A studio that nags is a studio nobody opens.

## Making and looking are separate programs

The studio writes sprites. The viewer reads sprites and collects tiers, and it
never reaches back into the machinery that made them -- it sees only the finished
file, exactly as a stranger would.

This is the [generate-then-view split](../strategems/patterns-that-keep-working)
again, at a fifth boundary, and here it has a specific job: a grader with access
to the generator's internals is grading the *intent* rather than the *result*, and
the result is the only thing anybody else will ever see.

Under algorithm B, the viewer is the running session itself. That has an
architectural consequence worth stating plainly: **the rating store has to be
reachable from a live game**, and the in-play re-rate travels the same socket as
every other command. It is not a world command -- it changes no thing and no wall
-- but it comes through
[the same door](010-commands-enter-through-one-door.md) and runs the same
gauntlet.

## Improving, bit by bit

A ladder whose bottom rung works immediately and whose every rung is the
prerequisite for the next:

1. **The pool, retrieved into the brief.** The best previous sprites for this
   category are shown before a new one is written. Improves from the first
   judgment; costs only storage.
2. **Per-category brief refinement**, tuned against accumulated ratings.
3. **A small adapter retrained periodically** on accumulated preference pairs.
4. **A full reinforcement loop** -- which needs a machine grader you already
   trust, and you calibrate that with the agreement data rungs 1 and 2 generate
   for free.

So the cheap thing and the prerequisite are the same thing. Build upward, never
skip.

**The anchor that stops it drifting:** under algorithm A, a guaranteed minimum
fraction of sprites gets a person's rating, and the agreement rate is reported
where it can be seen. Let a person's ratings become rare and the whole apparatus
converges smoothly on *the machine grader's* taste rather than yours, with no
error raised anywhere, and you find out months later by not liking the output.
Algorithm B has no such failure, and pays for that with a pool the size of one
person's patience.

## Read next

- [The dynamic picture](012-the-dynamic-picture.md) -- what consumes these.
- [Content is generated](013-content-is-generated.md) -- the same
  description-in-artifact-out spine, applied to maps instead.
- [Open questions](016-open-questions.md), section 10.
