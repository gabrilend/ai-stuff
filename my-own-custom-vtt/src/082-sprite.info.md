# 082-sprite

A word and a number become a small animated picture, and the picture can be read
back into the word and the number.

Three jobs, kept apart on purpose.

| Job | What it does |
| --- | --- |
| making | `category` + `seed` → `struct sprite`. Pure arithmetic. No clock, no file, no ambient randomness. |
| writing | `struct sprite` → SVG text. String-writing and nothing else. |
| reading | SVG text → `struct sprite`, written as though it had never seen the writer. |

## The paintbrush

Twelve words. That is the whole vocabulary, and the shortness is the feature.

| Kind | Words |
| --- | --- |
| shape | `circle` `rect` `triangle` `ring` |
| slot | `primary` `secondary` `accent` |
| motion | `still` `bob` `walk` `flicker` `turn` |

A word outside this list is refused. There is no "and otherwise a circle" — the
lookups return the count for their kind, which is not a legal value, so a caller
that stores one without checking gets a loud failure rather than a sprite that
quietly became something else.

Handed a long reference, anything generating descriptions invents plausible
neighbouring words — `ellipse`, `hexagon`, `tertiary`, `idle` — confidently and
in good style. A twelve-word allowlist has nowhere for the analogy to go.

`sprite_nearest_word` offers the word that was probably meant. Two conditions,
and the second is the one that is easy to leave out: at most three edits, **and**
fewer edits than the length of the word being corrected. Without the second, an
empty word gets offered `bob`, because three edits is the whole of a three-letter
word. That bug was found by a test and the same fix went into `076-describe`,
which had it too.

## What is in a sprite

| Field | Type | Meaning |
| --- | --- | --- |
| `category` | 32 bytes of text | What it is a picture of. Folded into the stream names, so two categories with one seed draw differently. |
| `seed` | `uint64_t` | The other half of the description. |
| `layers` | up to 6 × `struct sprite_layer` | Drawn in order, so the order is the layering. |
| `layer_count` | `uint8_t` | 2 to 6. |
| `palette` | 3 × `uint32_t` | Packed `0xRRGGBB`, one per slot. |
| `motion` | `uint8_t` | What the whole sprite does. |

A layer is five bytes: `shape`, `slot`, `offset_x`, `offset_y`, `radius`. The
offsets and the radius are hundredths of the viewbox measured from the middle,
which is why they fit in a byte — a sprite is described in its own units and the
renderer decides how big a metre is.

The first layer is fixed as the body: centred, large, primary, and **solid** — a
ring is never a body. Centred and large is what stops the generator producing a
sprite made entirely of small dots near one edge, which is technically a sprite
and visibly nothing. Solid is because a hollow outline with the detail floating
inside it reads as a diagram rather than as a thing standing somewhere.

## Half of them are mirrored

Detail layers come in matching pairs either side of the middle, in about half of
all sprites. A pair reads as eyes, or arms, or wheels — as a thing with a front.
The same shapes scattered freely read as a pile.

This was the single cheapest change that made the output look like creatures, and
it cost **no new words in the paintbrush**, which is exactly why it was preferred
to adding shapes. A vocabulary grows once and never shrinks.

Symmetry is drawn from the stream rather than decided by category, because
whether a goblin is bilateral and a torch is not depends on what a category
*means*, and categories are the ruleset's to name. See open question 10.4.

It also feeds the grader without a new component: a mirrored pair sums to zero
drift, so a symmetric sprite scores perfectly on balance for free.

## The stream registry is not an argument, and that is the point

Everything else in this project draws randomness from a session-owned named
stream. A sprite must not, because a stream carries a **position** — a sprite
drawn from one would depend on how many sprites were drawn before it, and then
"goblin, seed 7" would mean one picture on Tuesday and a different picture on
Wednesday. Every rating anybody had written down would be pointing at a picture
that no longer exists.

So `sprite_make` builds its own registry from the seed alone and names three
streams after the category. The named-stream discipline is kept; the position is
discarded.

## The two lowest bits of blue carry the slot

The reader recovers which palette slot a layer draws from by matching the layer's
fill colour against the palette. If two slots ever held the same colour that match
would be ambiguous, and it would fail on some seeds and not others — the worst
way for anything to fail.

So after the palette is built, the slot number is written into the two lowest bits
of the blue channel. Three parts in two hundred and fifty-five: invisible to a
person, decisive to a reader.

This is the file format reaching back and constraining the generator. That is
uncomfortable and correct: a picture that cannot be read is not a picture this
project has.

## The reader is independent on purpose

It shares no code with the writer, and it recovers each field from the **drawing**
rather than from a restatement of the struct.

| Recovered | From |
| --- | --- |
| shape | the element name — and a `circle` with `fill="none"` is a ring, which is what a person looking at it would notice too |
| slot | matching the fill against the palette |
| offset and radius | the geometry, run backwards: a rect's corner and width, a triangle's base midpoint and half-width |
| motion | what the animation actually does — translate along y is a bob, along x is a walk, opacity is a flicker, rotate is a turn |

Nothing in the file says "this layer uses the accent". If the writer put the wrong
colour on a layer, the reader notices; a label would have agreed with the mistake.

Two independent readers is proof; one is an opinion.

## Still is the absence of an animation

A still sprite carries no animation element whatsoever, and the reader recovers
`still` from finding none. That asymmetry has its own test: it is the one case
where the file says something by not saying anything.

## The machine grader

`sprite_machine_tier` returns 1 to 5. It is a **heuristic** and is called one in
every place it appears, because the whole apparatus around it exists to measure
how far the machine's taste has drifted from a person's, and a grader that is
really a complexity metric will drift somewhere nobody predicted.

Five components, a hundred points:

| Component | Out of | What it likes |
| --- | --- | --- |
| layers | 24 | four; one is a blob and six is a pile |
| motion | 20 | anything but still — this is the project's opinion, stated as one |
| palette | 30 | secondary near the primary, accent far from it |
| size | 14 | a body filling about a third of the box |
| balance | 12 | the detail sitting near the middle |

`sprite_machine_score` exposes the raw total, and `sprite_machine_reasoning`
writes the breakdown as a sentence so a demo can show which component made the
call rather than announcing a number.

## The cut lines are measured, not chosen

The first four cut lines were round numbers that looked reasonable. Against the
generator's real output they put ninety per cent of every sprite into two tiers
and left tier one entirely empty — a five-point scale that was really a
three-point scale, which is worse than a three-point scale because the two dead
numbers look like information.

`084-calibrate` histogrammed the pool and the four numbers became the tenth,
thirtieth, seventieth and ninetieth percentiles of what it found. Run it for the
current figures rather than trusting any number written in prose.

**It has already earned its keep once.** Making the detail layers mirrored moved
every one of the four lines by two points. The tool said so; nothing else would
have, and the tiers would have drifted from 10/20/40/20/10 to 6/18/37/23/16 with
no error anywhere.

**That makes a tier a ranking, not a verdict.** Tier five means "in the best tenth
of what this paintbrush produces", not "good". That is the right meaning for the
quality dial, whose job is to hand back the better ones, and it is worth being
clear-eyed that it is not the other meaning.

## Functions

| Function | Takes | Gives |
| --- | --- | --- |
| `sprite_make` | a sprite to fill, a category, a seed | nothing; the sprite is filled |
| `sprite_to_svg` | a sprite, a buffer, its capacity | bytes written, or 0 — a buffer too small is refused rather than half-filled, because half an SVG is not a smaller picture but an unopenable file |
| `sprite_from_svg` | a sprite to fill, SVG text | 1 when it read, 0 when it could not |
| `shape_name` `slot_name` `motion_name` | a value | the word, or a bracketed complaint when out of range |
| `shape_from_word` `slot_from_word` `motion_from_word` | a word | the value, or the COUNT for that kind when unknown |
| `sprite_vocabulary` | a place to put the count | the twelve words, flat |
| `sprite_nearest_word` | a word | the nearest legal one, or nothing |
| `sprite_machine_tier` | a sprite | 1 to 5 |
| `sprite_machine_score` | a sprite | 0 to 100 |
| `sprite_machine_cut` | a tier | the lowest score that still counts as it |
| `sprite_machine_reasoning` | a sprite, a buffer, its capacity | the buffer, filled with the breakdown |

## Related

- [083-test-sprite](083-test-sprite.c) — the round trip, three thousand sprites
- [084-calibrate](084-calibrate.info.md) — whether the tiers are still five tiers
- [the sprite studio](../docs/017-the-sprite-studio.md)
- issues [901](../issues/completed/901-a-sprite-is-an-animated-svg.md),
  [902](../issues/completed/902-the-paintbrush-is-a-closed-set.md),
  [905](../issues/completed/905-the-machine-grader-is-a-heuristic.md)
