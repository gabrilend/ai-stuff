# 006 — Filters and the Weave

The datapath of everything drawn between the painting and the cage. A **filter**
is a way of looking at the city; the map can wear several at once, and the rule
that lets it wear more than three without turning to mud is that they weave
rather than stack.

The words *layer* and *overlay* are not used. They suggest something laid on top,
and the interesting cases here are the ones that pass through each other.

## What a filter is

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | what you are asking about — fire hazard, shade, what you know of the guilds |
| `colour` | three numbers | what its lines are drawn in |
| `angle` | number, degrees | which direction its lines run. **Adjustable by hand at any time.** |
| `mode` | one of three | where it sits relative to the other filters — see below |
| `parameters` | list of named controls | anything this filter alone needs |
| `reading` | **(person, place)** → a number from 0 to 1, **or nothing** | the answer |

The reading's spacing is what carries the value: **tighter lines mean more**.

## The reading takes a person, and that is the whole of character switching

A filter does not read a place. It reads a place **for somebody**.

That one extra parameter is what makes it possible to select any house in the
city, play as whoever lives there, and have the map **repaint entirely** —
hatching rearranged, blank ground moved, a different city legible. Nothing else
is needed for it, because nothing in the design ever assumed a particular
observer; the map was always somebody's model, and this only makes explicit whose.

What it buys is the ability to look at another person's ignorance. A servant in
the eastern mansions has a blank harbour. A bargeman has a bright river and a
dark walled quarter. See [what this game is](001-what-this-game-is.md).

It also means a person's knowledge will come out **shaped like their quadrant** —
dense where they actually go, blank across the divide nobody crosses — which
draws the city's social horizon on the map without anything being built to draw
it. See [the places of the city](003-the-places-of-the-city.md).

## Nothing is the most important value

A filter is allowed to answer *nothing at all*, and that is different from
answering zero. Zero means this person knows the fire hazard here is low. Nothing
means **they have no idea**, and it draws as bare painting.

This is why the design needs no separate confidence channel, no fog-of-war
system, no greyed-out unknown state. Look at the city under the guilds filter and
the hatched parts are their knowledge, the bare parts their blindness, and the
picture is beautiful exactly where they are ignorant.

For filters about hidden things, "nothing" is not even a special case: a person's
knowledge **is** the set of events they hold, so a blank block is simply a block
where they hold none. See
[events and what people know](009-events-and-what-people-know.md).

## The three modes

Each filter sits in one of three places:

| Mode | Behaviour |
| --- | --- |
| **behind-always** | painted flat, beneath everything else, in the order added |
| **interwoven** | joins the weave with every other interwoven filter |
| **top-always** | painted flat, over everything else |

The two *always* modes do not weave with anything, including each other — they
are simply painted. Only the interwoven set weaves, and it weaves as a whole.

## The weave

Weaving is a property of the **crossings**, not of either thread, so the
interwoven set cannot be drawn by looping over filters and drawing each in turn.
They resolve together, in one pass.

The rule is the one real basket weave uses. Number the lines in each filter's
hatching. Where a pixel falls inside a stroke of more than one filter at once,
sum the line indices of every filter crossing there and take it modulo how many
are crossing; that picks which one is on top at that spot.

With two filters, line *i* of one crossing line *j* of the other puts the first
on top when *i + j* is even and the second when it is odd — so the two hatchings
pass over and under each other down the whole block, and neither one dominates.

This is what buys "any number of filters at once." Flat stacking goes to mud at
three, because whatever is underneath is simply buried. Weaving degrades
gracefully, because every filter gets an equal share of the crossings and none is
ever wholly hidden.

## The hatching is attached to the ground

Two properties are wanted at once and they pull against each other.

The pattern must not **swim** — if the lines are computed in screen coordinates,
they slide across the painting as you drag the map, and the city moves while the
hatching stands still. So the line index for a pixel is computed from its
position **in painting coordinates**: project onto the axis perpendicular to the
filter's angle, divide by the spacing, take the whole number. Locked to the
ground, so panning carries the pattern with the city.

The pattern must also stay **legible** — spacing fixed in painting pixels would
be five times denser on screen at the city view than at native zoom, collapsing
into solid fill. So the spacing used is the spacing you want *on screen* for that
block's value, divided by the current zoom.

The consequence, stated honestly: the pattern is perfectly locked during panning
and breathes slightly during zooming. That is the right way round, since panning
is constant and zooming is occasional.

## Every block carries a default filter

A block has a `default_filter` field naming the filter that switches on when the
block is selected — overridable per place, from the interface.

This is the strongest idea in the design. It means **each place teaches you how
to look at it**. Select the tannery row and it opens under trade. Select the
terraced gardens and it opens under shade. Select a block where something is
wrong and it opens under whatever is wrong there. You are not choosing one lens
and sweeping the city with it; the city hands you a lens per place, and
overruling it is itself a small act of insight.

How you change it from the interface is undecided. See
[open questions](012-open-questions.md).

## The render order

Every frame, over the painting:

1. **behind-always** filters, painted flat in order
2. **the interwoven set**, resolved together in one pass by the weave rule
3. **top-always** filters, painted flat in order
4. the cage — see [the fence network](004-the-fence-network.md)
5. the glow — see [the map surface](002-the-map-surface.md)

All of steps 1 to 3 read the block-identity buffer described in
[the map surface](002-the-map-surface.md): for each pixel, look up which block it
belongs to, look up that block's reading in each active filter, evaluate the line
patterns, resolve the weave, paint.

## What the colour rule costs here

[The rule about colour](001-what-this-game-is.md) says colour never carries a
fact the words don't also carry, and filters are where that bites hardest. A
filter is identified to the eye by its colour *and* by its hatch angle, and in
the tome its chip must also carry its name. Three redundant channels for one
identity, deliberately.

A filter whose meaning is only findable by recognising a colour is a filter
somebody cannot use.

## Related documents

- [What this game is](001-what-this-game-is.md) — the model-not-camera idea, the colour rule
- [The map surface](002-the-map-surface.md) — the identity buffer these read
- [The tome](007-the-tome.md) — where filters are controlled
- [Open questions](012-open-questions.md)
