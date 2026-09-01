# 003 — The Places of the City

What the city is divided into, from the largest thing down to a single room's
worth of somebody's life. Six levels, one of them optional, and only two of them
drawn by hand.

## The chain

```
   group        the city, or one megastructure. Has no parent.
     │
   quadrant     four to a group. Absent beyond the wall.
     │
   district     a set of blocks. Boundary derived, never traced.
     │
   block        five to seven buildings around an intersection. Traced.
     │
   building     one stone structure. A rough zone, placed by hand.
     │
   house        an apartment inside it. No geometry at all.
```

You can select at four of these — building, block, district, quadrant — and which
one a click lands on is decided by how far in you are zoomed. See
[the map surface](002-the-map-surface.md).

## The chain is ragged, and that is not a hole

Land beyond the wall has **no quadrant**. Not an empty quadrant, not a null one —
the level does not exist there, because **the wall is what makes a quadrant**.

So a place's containment is a **list of the levels it actually has**, walked from
the outside in. Never a fixed six with gaps. The tempting shape is a record with
six fields where one is sometimes empty, and then every piece of code that walks
the hierarchy grows a test for nothing-there — which is testing for absence
instead of understanding it. The absence has a reason; model the reason.

## Group — the top, and there is no top above it

Two kinds, and they are peers:

- **the city**, everything inside the wall that is not a megastructure
- **each megastructure**, of which there are several

A group has no parent. There is no single object that everything hangs from —
the city is a *forest* of groups, not one tree. That is a consequence of the
megastructures not being contained by the city they sit in: they are their own
thing, quartered on their own terms.

Megastructures are the great circular works. Candidates read off the painting,
pending confirmation: the amphitheatre on the west bank, the ringed colonnade on
the east with its golden tree, the domed rotunda on the promontory, the smaller
dome on the western peninsula, and the great willow — which is not a building but
is the largest circular thing in the city by a wide margin.

## Quadrant — the scale at which people never meet

Four to a group. The city is quartered; each megastructure is quartered the same
way, which works only because both happen to be round.

A quadrant is not merely a container. **It is a social horizon.** Somebody living
in the north-east of a structure can wander all day and never cross anyone from
its south-west. That is the level at which the city stops being one place.

The consequence lands in [filters](006-filters-and-the-weave.md) without anything
being built for it: because what a filter shows is what one *person* knows, and
because knowledge accumulates where a person actually goes, a citizen's knowledge
will come out **shaped like their quadrant** — dense inside it, blank across the
divide. The hatching will draw the horizon on its own.

## District — a set of blocks, and nothing more

A district is membership. Its outline is the outer edges of the blocks that
belong to it, computed rather than traced, so districts cost **no drawing at
all** — only the decision, per block, of which district it is in.

The same is true of quadrants, one level up. **Everything above the block is
free**, geometrically. Only the block and the building are hand-made.

## Block — a corner, and the people who share it

Five to seven freestanding buildings, gathered around an intersection: as few as
three at a T-junction, four at a crossroads, more when a building is close enough
to be seen down the street. Its borders are made of intersections, and those
intersections are listed in the tome with everything they connect to — see
[the tome](007-the-tome.md).

Socially it is **a community**: a rough collection of houses that tend to do
things together, a parallel storyline running alongside every other block's. Some
larger, some smaller. Everyone may go wherever they like; if there is not enough
room, room gets made.

Structurally it is a loop of street runs meeting at corners — see
[the fence network](004-the-fence-network.md). The social reading and the drawn
reading are the same object seen two ways, and neither needs the other changed.

**A block owns half of every street around it.** The traced line runs down the
road's centre, because two blocks facing each other share one edge. So **there is
no street object** — a lane is where two blocks meet rather than a place in its
own right. Nobody stands *in* a street; they stand in a block, on its half of the
road. Public space is the open buildings and the squares, and a square is a
block.

## Building — the stone that roots people

One freestanding structure. Mostly **unrestricted**: it is rare for a building to
be barred to people, and the largest are entirely free to enter. That is about
who may walk in, which is a different property from whether the building is
**open** in the sense the scaffold means — open to being changed. A building can
admit anyone and take on nothing. Most are closed all the time.

> The building is stone, and can't adjust easily, meaning it's what roots people.

That sentence is the design. People move; stone does not; and everything rigid
about life in this city grows in the gap between those two facts. It rhymes with
the vision's own line — *walls are heavy, and hard to move when the city expands*
— so the same physical truth governs how the city grows and why a person's life
does not.

And it is now literal rather than figurative. Stone is **closed**, so it gives and
never receives. A person is **open** when at rest, and a person rests at home. So
the only hours in the day when anybody can be changed at all are the hours spent
inside a building that is broadcasting at them and cannot be broadcast back at.
You become the architecture during the only hours you are able to become
anything. That is the rigidity, and no rule was written to produce it — it is two
rules from [the scaffold](009-the-scaffold.md) touching.

Buildings carry their own facts: who owns the roof, what the ground floor trades
in, whether the stair is shared. Those are not written by hand into a pile. A
building accumulates them by being stood in — see [the scaffold](009-the-scaffold.md)
— and a building with nothing recorded is one where nothing has yet happened often
enough to name, not an error.

For the mouse to reach one, a building gets a **rough hand-placed zone** — a
crude shape over the roof, not a traced outline. There are only a handful per
block and they sit well apart, so crude is enough, and it is seconds of work
rather than a minute.

## House — an apartment, and somebody's whole life

A house is a dwelling **inside** a building. Not a freestanding thing — several
share a roof. Three to five rooms, holding one family or one person.

Houses are **almost always restricted**. Someone lives there.

They have **no geometry whatsoever** — no footprint, no zone, no point. A house
is a row in a list inside its building, reached through the tome. The painting's
roofs were never drawn with individual dwellings in mind and inventing them would
be inventing, not observing.

### What a house is like inside

Built haphazardly, looking nothing like an apartment now. Railings and bannisters
and banners everywhere. **Vaulted ceilings, commonly twenty feet.** Wooden beams
hung from them on chains, and from those beams things arranged at whatever height
you please.

That last detail is not decoration — it says the interior is **used vertically**.
A room here is not a floor plan with furniture on it; it is a tall volume with
things hanging in it at chosen heights. Anything that ever draws or generates an
interior has to start from that, or it will produce rooms from the wrong century
and the wrong world.

### The lives inside

Family, trades, martial, learned — as many lives as there are districts, and you
pick. Choosing between them is a thing the game is *about*, given a city whose
whole problem is that it tells you which to choose.

## The scale of it

Rough estimates from sample crops, not counts. **The coverage tool in
[the tracing mode](005-the-tracing-mode.md) should report the real numbers** once
blocks exist; these are here to make the size of the work visible, not to be
trusted.

| Level | How many | Hand-made? |
| --- | --- | --- |
| group | ~6 | named by hand |
| quadrant | ~24 | four per group, by hand |
| district | tens — the flat view letters about twenty | membership only |
| block | **~2,000** | **traced** |
| building | **~10,000** | **a rough zone each** |
| house | ~20,000–40,000 | listed, no geometry |

## Related documents

- [The map surface](002-the-map-surface.md) — how the zoom picks a level
- [The fence network](004-the-fence-network.md) — how blocks are actually stored
- [the scaffold](009-the-scaffold.md) — what happens inside all of this
- [Open questions](013-open-questions.md)
