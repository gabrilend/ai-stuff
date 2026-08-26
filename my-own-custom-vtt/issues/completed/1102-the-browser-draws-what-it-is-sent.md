# 1102 -- The browser draws what it is sent

**Phase:** 11, the second view and the documentation
**Blocked by:** [1101](1101-the-paintbrush-travels-as-numbers.md)
**Blocks:** [1107](1107-the-phase-eleven-demo.md)
**Documents:** [the dynamic picture](../../docs/012-the-dynamic-picture.md)

## Current behaviour

**Done.** `067-view.js` holds the layers per thing, replaced whole each update,
and assembles them: four shapes, three of which are two canvas calls each.

The view holds no opinion about what a goblin looks like. It holds an opinion
about how to draw a ring. That is why it is about a hundred lines.

Motion is driven from the frame clock rather than the beat, because a bob at
twenty beats a second is a stutter and a bob at sixty frames a second is a bob.
Each thing's phase is offset by its own index, so a room of goblins does not bob
in unison -- which reads as one object rather than several.

**What moves and what is simulated are different things.** The bob displaces
nothing, is sent nowhere, and is never asked about. Confusing the two would be
the beginning of a client that thinks it knows where a goblin is.

Which body is yours is drawn as a ring around the outside rather than as a tint,
so it does not argue with the sprite's own colours.

A thing wearing nothing gets the plain circle it always got, and that is
commented as being the correct picture of a thing whose appearance nobody has
decided rather than a fallback hiding an error.

## Intended behaviour

It assembles the layers it was sent, and it **moves**.

### It renders the paintbrush, it does not own it

Four shapes, three of which are drawn with two calls each. The view holds no
opinion about what a goblin looks like; it holds an opinion about how to draw a
ring.

That is why this is small. A view that had to know what a goblin looks like would
be a second generator.

### The motion is the point

The vision asked for art that behaves more like a video game and less like a
picture somebody moves tokens around on. A sprite that bobs, walks, flickers or
turns is that difference, and it costs one number per thing and a clock the view
already has for its animation frame.

The motions are driven from the view's own frame time rather than from the beat,
because a bob at twenty beats a second is a stutter and a bob at sixty frames a
second is a bob. **What moves and what is simulated are different things** — the
sprite's bob has no effect on anything and must not be mistaken for one.

### It still draws something when a thing wears nothing

A thing with no sprite is normal: a hand-built fixture has none, and a version 2
world file has none. It draws the circle it drew before, which is not a fallback
hiding an error — it is the correct picture of a thing whose appearance nobody
has decided.

## Suggested implementation steps

1. Hold the layers per thing, replaced whole each update.
2. Draw them in order, in the shape the paintbrush allows.
3. Drive motion from the frame clock, not the beat.
4. Keep the plain circle for a thing wearing nothing, and say why in a comment.
