# 814 — A Valence Changes Who Nearby Is Open

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 810, 813 |
| Blocks | — |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

An arc is created and lands somewhere. A person's status comes from their curve
and from nothing else, so what happens around them cannot reach them.

## Intended behavior

An arc carries a **valence**, and bystanders respond to it by changing status.

> if people are angry, if they're fighting, negative emotions... people around tend
> to close themselves up, because they want to bring good things into their life.
> Usually. Some people are manic depressive haha. So two people are closed and
> interacting, sometimes it can bring good fortune to those around them too - it
> depends entirely on the context.

### This is the second thing that sets a status, and it overrides the curve

[810](810-open-and-closed-are-a-line-on-the-curve.md) makes a status a function of
the day. This makes it a function of the day **and what is happening nearby**.

**The activity line is a person's schedule. An arc can shut them regardless of
it.** A person resting quietly in a block where something ugly is happening closes,
even though their curve says they should be open.

### The usual response, and the exception that is not a special case

The common case is that a bad arc closes you — you shut yourself to keep bad things
out. It is **not universal**, and the exception belongs on the person rather than
bolted onto the rule: some people open to exactly what makes everyone else close.

So a person carries a **disposition** — how they respond to valence — and the
dispatch is on that, per person, rather than an `if negative then close` with a
list of exceptions beside it.

### It closes the loop, and the loop is the game

Stated as one line: **what happens to people changes who is open, and who is open
changes what happens to people.**

Before this ticket the scaffold runs one way — the day decides who is open, who is
open decides what moves. With it, the system feeds back on itself, which is where
a neighbourhood that behaves like a neighbourhood comes from rather than a set of
independent schedules.

### Good fortune travels the same way

The valence is not only negative. *Sometimes it can bring good fortune to those
around them too* — so an arc can open bystanders as easily as shut them, and which
it does *depends entirely on the context.* The scaffold carries the valence and the
disposition and lets those two decide; it does not classify arcs into good and bad
in advance.

### Nearby is adjacency

Same as [813](813-two-closed-actors-make-an-arc.md): this block, or a block sharing
an edge. There are no distances in this game, so a valence cannot have a radius,
and a wall genuinely stops a mood.

## Suggested implementation steps

1. Add a valence to the arc record.
2. Add a disposition to the person record — how this person answers a valence —
   and make it a dispatch table keyed on the person, not a branch with exceptions.
3. Apply valence to bystanders in this block and blocks sharing an edge, after the
   arc is created and before the next hour's gathering.
4. Make the override explicit in the code: a status is the curve's answer unless a
   valence has spoken, and a comment should say which path means what.
5. Test that a valence never crosses a wall.
6. Test that a person whose disposition inverts the usual response opens on exactly
   the arcs that close everybody else in the same gathering.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [810 — open and closed are a line on the curve](810-open-and-closed-are-a-line-on-the-curve.md) — the schedule this overrides
- [813 — two closed actors make an arc](813-two-closed-actors-make-an-arc.md) — where a valence comes from
