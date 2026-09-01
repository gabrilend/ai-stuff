# 810 — Open and Closed Are a Line on the Curve

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 704, 807 |
| Blocks | 811, 812, 814, 815 |
| Reads | [the scaffold](../docs/009-the-scaffold.md), [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Actors have characters and a day. Nothing says which way anything moves between
them.

## Intended behavior

**Every actor, at every hour, is open or closed.** No third state, no in-between.

| Glyph | Status | Meaning |
| --- | --- | --- |
| `O` | open | **open to being changed.** Receives. |
| `\|` | closed | not open to being changed. **Gives.** |
| `(.)` | open, changing | the dot is the mark of alteration |
| `\|.\|` | closed, changing | the same dot, on the other status |

The glyphs are not decoration. They are how a status is drawn wherever one is
shown, and the dot means change is happening to whichever status carries it.

### The direction is the opposite of the intuitive reading

**The closed gives. The open receives.** Exchange is unconditional and never has to
be triggered; the statuses only decide which way it runs.

A closed thing is not withholding — it is the **source**, holding a definite
character and imparting it. An open thing is not generous — it is **malleable**. A
city of nothing but open people would circulate nothing, because nobody would hold
anything firmly enough to give.

Anybody implementing this from intuition will get it backwards. It is worth a
comment at the point of use.

### A person's status is a line across the activity curve

Nothing new is authored and nothing new is drawn. The curve
[704](704-the-time-curve.md) already builds — activity across the day, five
distinguishable levels — with a threshold on it.

**Busy is closed. Rest is open.**

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

This retroactively explains a sentence
[the day and the curve](../docs/008-the-day-and-the-curve.md) wrote without saying
what it meant: *a curve pinned high all day is telling you something about that
person.* It is telling you they are never open.

So **the city enforces rigidity by filling the day**, and the instrument that
shows it was already on screen.

### A place's status is a property of the place

Most buildings are **closed all the time**. They are permanent transmitters: they
give their character to everyone standing in them and take nothing back, forever.

This is a different property from whether a building can be walked into. A
building can admit anyone and take on nothing — see
[406](406-a-building-and-its-facts.md), which uses *unrestricted* and *barred* for
access precisely so the words do not collide.

### The impact ratio

Impact runs **inverse** to how much of the day an actor spends open. Two open hours
out of twenty-four means each lands with enormous force; open most of the day and
nothing in particular changes you.

The consequence for places is darker and nobody designed it: a thing that has never
once been open has, in the limit, unbounded impact the single time it is forced.
See [815](815-forcing-a-closed-thing-open.md).

## Suggested implementation steps

1. Read the threshold from `input/what-to-start-with`. It is a tunable, not a
   constant.
2. Compute a person's status as a function of `(person, hour)` off the curve.
   Never store it — it is derived, like whereabouts.
3. Give a place a status field instead, defaulting to closed, and make closed the
   value that needs no explanation.
4. Draw the four glyphs wherever a status is shown.
5. Report, per person, the fraction of the day they are open — that number is the
   impact ratio and everything downstream reads it.
6. Test that a curve pinned above the line yields no open hours at all, and that
   the direction of flow is closed-to-open in every code path.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [The day and the curve](../docs/008-the-day-and-the-curve.md) — the curve the line is drawn on
- [704 — the time-curve](704-the-time-curve.md)
- [406 — a building and its facts](406-a-building-and-its-facts.md) — access, which is a different property
