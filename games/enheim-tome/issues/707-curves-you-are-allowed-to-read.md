# 707 — Curves You Are Allowed to Read

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 502, 704 |
| Blocks | 708 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Any curve can be drawn for anybody.

## Intended behavior

Time-curves are legible only for **your people, and people you have come to
know**. Everybody else has a day you cannot see.

### Why, and why it needs no special machinery

Because **you cannot model a stranger**.

The map is one person's model of the city — see
[502](502-a-reading-takes-a-person.md) — and a day you have never observed is not
part of your model. Refusing to draw it is not the game withholding information;
it is the game not inventing information you do not have.

This is the same shape as a filter answering *nothing* for a place you know
nothing about — see [503](503-nothing-is-a-value.md). Same idea, different
surface: **ignorance is the absence of a reading, not a special state.**

### Acquaintance becomes visible as a stack

This is the pleasing consequence. Early on there is **one curve, your own**. Later
the tome holds a dozen, and sweeping across them shows the city's morning
happening.

So the height of the stack *is* a record of how far you have got. Nobody has to
render a progress figure for "how well do you know this city" — the number of days
you are permitted to look at says it, and says it in a form you can actually use.

### What an unreadable person shows instead

Not a blank, and not a locked icon. They appear in the tome — you can see that
somebody lives here — with their day simply absent, and it should be clear that
this is because you do not know them rather than because the game is hiding it.

The distinction matters: *hidden from you* invites trying to unlock it; *unknown
to you* invites going and meeting them, which is the actual verb of this game.

### Whose acquaintance

The current person's. Taking somebody up changes which curves are readable,
because it is their model now — see [510](510-switching-person-repaints.md). A
servant's list of legible days is short and quite different from a merchant's.

## Suggested implementation steps

1. Ask, for the current person, whether they know a given other person, and gate
   drawing on that.
2. Represent the answer as an absence rather than a flag on the curve, so nothing
   downstream has a curve object it must not draw.
3. Show unknown people in listings with their day absent and the reason plain.
4. Recompute what is readable on switching person; nothing may persist across a
   switch.
5. Test that the same person is readable to one character and not to another, and
   that taking up a character changes the readable set entirely.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [Filters and the weave](../docs/006-filters-and-the-weave.md)
