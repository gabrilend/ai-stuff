# 009 — The Scaffold

What happens when people are in a place at an hour, and the smallest set of parts
that lets a context develop without anybody deciding in advance what it will be.

This document replaces an earlier one that described events as hidden objects
people carried. That design priced itself, in its own text, at twenty to forty
thousand written facts and "two to four years" of typing before the game worked.
A design that states that number about itself has been refuted by its own
estimate. The old text is in the repository's history, and the working note at
`notes/the-open-and-the-closed` holds the conversation that replaced it.

> "holding an event" doesn't make sense unless you mean "holding a party" or
> "throwing a party" or "playing catch" or "tossing grenades".

An event is an occurrence, not a possession. Nothing below is stored as a pile of
authored facts; all of it is computed from where people are and what they are
like.

## The two statuses

Every actor, at every hour, is **open** or **closed**. There is no third state and
no in-between.

| Glyph | Status | Meaning |
| --- | --- | --- |
| `O` | open | **open to being changed.** Receives. |
| `\|` | closed | not open to being changed. Gives. |
| `(.)` | open, changing | the dot is the mark of alteration |
| `\|.\|` | closed, changing | the same dot, on the other status |

**Things are always exchanging.** Exchange is unconditional and never has to be
triggered. The statuses decide only which direction it runs in: **the closed
gives, the open receives.**

That is the opposite of the intuitive reading, and the intuitive reading is
wrong. The closed thing is not withholding. It is the **source** — it has a
definite character and imparts it. The open thing is not generous; it is
**malleable**. A city of nothing but open people would circulate nothing, because
nobody would be holding anything firmly enough to give.

### Where a person's status comes from

A line drawn across the activity curve already defined in
[the day and the curve](008-the-day-and-the-curve.md). Above the line, closed.
Below it, open. **Busy is closed. Rest is open.**

Nothing new is authored and nothing new is drawn. The curve widget already in
[the tome](007-the-tome.md) becomes the instrument that shows a rigid life at a
glance:

```
hours   0  3  6  9 12 15 18 21
curve   _  .  #  #  #  -  .  _
        ------------------------  the line
status  O  O  |  |  |  O  O  O

and the life the city insists on:

curve   #  #  #  #  #  #  #  #
status  |  |  |  |  |  |  |  |
        never open. nothing reaches her.
```

This retroactively explains a sentence document 008 wrote without knowing what it
meant — *"a curve pinned high all day is telling you something about that
person."* It is telling you they are never open.

So *"you must work a job"* stops being a mood and becomes a mechanism. **The city
enforces rigidity by filling the day.** A person whose hours are spoken for is a
person nothing can reach, and the instrument that shows it was already on screen.

### The impact ratio

> the ratio between the total time in the day and the "open" times determines how
> impactful each specific situation is

Impact runs **inverse** to how much of the day an actor spends open. Two open
hours out of twenty-four means each of those two lands with enormous force.
Open most of the day and nothing in particular changes you.

The humane reading, and the one that matches the vision's complaint: the labourer
whose day is pinned to work has almost no open hours, and so the few they have
matter more than anything that happens to anybody at leisure.

The consequence for places is darker and nobody designed it. **Most buildings are
closed, all the time.** In the limit, a thing that has never once been open has
unbounded impact the single time it is forced. The sacred grove that burns is
maximally consequential *precisely because it had never opened before.* The
arithmetic hands the city a cheap violent path and an expensive patient one, and
says outright that the violent one works better. No morality system was added to
produce that. It fell out of two rules meeting.

## Character is a sparse map of minted axes

A character is a map from **axis name** to a value between zero and one. Not a
fixed-width vector — there is no declared list of dimensions anywhere in the
program.

Axes are **minted on demand** as a place develops a nature. Most places carry
very few. A place with a long history carries many. "How many axes does this city
have" is not knowable in advance and is not supposed to be.

**An axis and a filter are the same object.** [Filters](006-filters-and-the-weave.md)
defines a filter as a name, a colour, an angle, a mode, and a reading of
`(person, place) → a number, or nothing`. An axis minted on demand is exactly
that record, so the filter list is not authored — it grows as the city grows
axes. Answer A9's ruling that any number of filters may be active at once,
weaving rather than stacking, turns out to have been load-bearing for a reason
nobody knew at the time.

And **nothing stops being a special case.** Document 006 calls *nothing* the most
important value — zero means this person knows the hazard here is low, nothing
means they have no idea. Under minted axes, bare painting is a place that has not
grown that axis at all. Not missing data. A way of looking that does not yet
apply here.

### Natural character

Every place has a character it holds before anybody visits: physical facts that
do not move. On the water. In the willow's shadow. Backed onto the wall. Steep.
Stone.

This is the seed the whole system needs. Because places differ naturally, the
people formed by them differ on the morning the game starts, without one person
being authored. **The seed is geography.**

## The gathering, and the share of one over N+1

At an hour, in a block, there is a set of actors. **The place is one of them.**

Every actor present contributes an equal share of **1 / (N + 1)**, where N is the
number of people and the extra one is the room.

> if five people are in a room, the room is 1/6th

That is a constant deleted rather than tuned, and it produces the right behaviour
at every scale on its own:

| Who is present | The room's share | What that means |
| --- | --- | --- |
| nobody | 1/1 | an empty place is entirely itself |
| one person | 1/2 | alone at home, you are half the building |
| five people | 1/6 | the room is one voice among six |
| fifty in a square | 1/51 | a crowd is its crowd, not its stones |

**A place's resistance to change is inversely proportional to how busy it is.**
Crowds change places; solitude preserves them. Nothing was tuned to get that.

### The flow

Every actor present, **including the room and including yourself**, contributes
its character at `1 / (N + 1)`. The blend of all of them is the sound of the room.

- **Open actors adopt the blend.** They become it.
- **Closed actors keep what they had**, and keep contributing it.

You retain your own voice at exactly the same weight as everyone else's, which is
why a person alone in a closed building drifts halfway toward the stone, and a
person in a crowded square barely moves at all.

This is also, exactly, the earlier ruling that a place's character is derived from
the people who visit it *plus a little bit of its own natural character*. Those
are not two rules. When an open room adopts the blend, its own prior character is
its one share of what it becomes. The little bit is `1 / (N + 1)`.

**And it explains why most of the city never changes.** A closed room does not
adopt. Most buildings are closed all the time, so most buildings hold their
natural character forever and impose it on everyone who rests in them. Only a
place that is open develops a nature at all.

## Sparks

Two closed actors meet. Neither can receive. What happens is not transfer.

> when two closed things meet, sparks fly. Sometimes they just bounce off one
> another, but I'm assuming you meant when they are intent on interacting - there
> will be a new character arc that is created, sometimes it just plays on the
> room, sometimes it sticks with someone nearby

Three parts, and the scaffold must carry all three without deciding any of them:

**Intent is a precondition.** Closed meeting closed usually just bounces. Sparks
need the two of them to be intent on interacting. The scaffold holds a slot for
intent; what fills it is not settled here.

**What is created is an arc, not a value.** Not a number added to somebody's
character — a new thing with a shape and a duration, which is where an axis that
nobody previously held comes from.

**Where it lands is context.** It may play on the room. It may stick with someone
nearby. It may do neither. The scaffold does not choose; it provides the places an
arc can land and lets the situation decide.

> like two closed hands grasped around one another, lifting to see the view atop
> the roof

Two things that cannot take from each other, gripping, and the result is
elevation and a view neither of them had. That is the productive case, and it is
productive without either party having changed.

### Valence, and what watching does to a bystander

> if people are angry, if they're fighting, negative emotions... people around
> tend to close themselves up, because they want to bring good things into their
> life. Usually. Some people are manic depressive haha. So two people are closed
> and interacting, sometimes it can bring good fortune to those around them too -
> it depends entirely on the context.

An arc carries a **valence**, and bystanders respond to it by changing status.
That is the second thing that sets open and closed, and it overrides the curve:
**the activity line is a person's schedule, and what happens near them can shut
them regardless of it.**

The usual response to a bad arc is to close — you shut yourself to keep bad things
out. It is not universal, and the exception is a per-person disposition rather
than a special case bolted on. Some people open to exactly what makes everyone
else close.

That makes the loop complete, and it is worth stating as one line: **what happens
to people changes who is open, and who is open changes what happens to people.**

### Nearby means adjacency, because there is no distance

An arc that sticks with "someone nearby" cannot use a radius. The game never
claims a distance — see [what this game is](001-what-this-game-is.md), which
explains why: the painting is an oblique view, ordinary townhouses run 12 to 20
pixels across near the northern wall and 40 to 70 down in the harbour, and any
figure computed from those pixels is wrong by a factor that changes with where
you measured.

So **nearby is the same block, or a block sharing an edge with it.** Nothing else.
A rampart genuinely stops an arc from spreading, because blocks on opposite sides
of a wall share no edge.

## Forcing

The second way an axis is minted, and the one that does not need a second actor.

A closed thing can be made open by an act done to it, and the **forcing itself
mints an axis**:

> if someone walks into a sacred grove and burns it down, then it forces the grove
> to enter the "open" state, and it applies an axis to it that might be "ashen" or
> "consumed" - both of those reflect a different spirit, and the spirit is
> generated on-the-fly because we never know how something will be until we mix it
> up and see

```
the grove:   |   closed forever
                 ↓  burned
            |.|  forced
                 ↓
             O   open, and now it receives
                 ↓
             O   carrying an axis it never held
```

**The word is the thing, and it is generated rather than chosen.** Two names for
the same burning are two different spirits. Which one arrives is not knowable in
advance; it comes out of the mixing. An axis is therefore never a label sitting on
top of a number — the naming is the event.

## What the scaffold refuses to decide

Stated plainly, because these look like gaps and are not:

- **What any particular arc means.** The scaffold makes arcs; context gives them
  content.
- **Whether a given conflict is productive.** It depends entirely on the context,
  and the whole point of building a scaffold is that the context is allowed to
  develop rather than be enumerated.
- **What word a minted axis gets.** Generated at the moment of mixing.
- **What fills the intent slot.** Named here so that it exists; not settled.

What the scaffold *does* reach is [the scene](010-the-scene.md), where axis
interactions become a record and the record becomes words &mdash; words that,
critically, decide nothing back.

> What we want is to build the scaffold upon which that context might develop.

## Datapath summary

```
  the hour ──────┐
                 │
   a person's    │        whereabouts(person, hour) ──▶ a block
   activity      │                                          │
   curve ────────┤                                          │
                 ▼                                          ▼
          above/below the line              the actors present in that block
                 │                                          │
                 ▼                                          │
            O  or  |  ◀───── valence of a nearby arc         │
                 │                                          │
                 └──────────────┬───────────────────────────┘
                                ▼
                    the gathering:  N people + 1 room
                                │
                   every actor at 1/(N+1)
                                │
                 ┌──────────────┴──────────────┐
                 ▼                             ▼
          the closed give              the open adopt the blend
                 │                             │
                 │                             ▼
        two closed + intent            character changes
                 │
                 ▼
             a spark
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
    the room  a nearby  nowhere
              bystander
        │        │
        ▼        ▼
   a minted axis, named at the moment of mixing
        │
        ▼
   which is also a filter, hatched on the map
```

## Related documents

- [The scene](010-the-scene.md) — how all of this becomes words
- [What this game is](001-what-this-game-is.md) — why there is no distance
- [The places of the city](003-the-places-of-the-city.md) — the quadrant as social horizon, and the stone that roots people
- [Filters and the weave](006-filters-and-the-weave.md) — an axis is a filter
- [The day and the curve](008-the-day-and-the-curve.md) — the curve the status is read off
- [Open questions](013-open-questions.md)
- `notes/the-open-and-the-closed` — the conversation this came out of, in the author's words
