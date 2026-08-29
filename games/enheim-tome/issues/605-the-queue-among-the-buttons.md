# 605 — The Queue, Among the Buttons

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 604 |
| Blocks | 702 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | **4** — whether queue order needs to be visible |

## Current behavior

Buttons exist. Pressing one does nothing that persists.

## Intended behavior

Queued moves appear **on the button that made them**, and go is one more button in
the pane.

No new region, and the queue is shown in the same language as the actions that
fill it — you queued a thing by pressing there, so the pending thing is there.

### Why this and not a list

A separate list would need a fourth region in a narrow column, squeezing the text
pane between two welded bands. And it would separate the pending action from the
place you press to make another, which are the same thought.

### The tension, stated plainly

**A queue is a sequence. Buttons in fixed positions have no order.**

The pane can show that one button has two moves pending and another has one. It
cannot show which happens first. If order matters to play, this presentation is
wrong and the queue needs somewhere with a sequence in it.

**Working ruling:** a small count badge per button, order not shown.

This is really **a mechanics question wearing an interface question's clothes**,
and it should be answered from that side. If a queue is a set of intentions the
world resolves in its own order, the badge is right and simple. If it is a program
executed in sequence, it is not. See open question 4.

A badge must not be only a number in a colour; it needs to read as a count without
relying on hue.

### Go, and the fact that time is only ever now

The world does not advance by itself. It advances when you make a move, or when
you press **go** on moves you queued. See [702](702-the-world-advances-on-a-move.md).

So go is the single most consequential control in the interface, and it is one
button among many identical ones. It should be distinguishable by **position and
shape** — a reserved cell, a different outline — rather than only by colour, and
pressing it with an empty queue should do nothing rather than advance time by
nothing.

## Suggested implementation steps

1. Hold the queue as an ordered list, even though the presentation does not show
   order — so that if the ruling changes, the data is already right.
2. Badge each button with the count of queued moves originating there.
3. Reserve a cell for go, marked by shape as well as by colour.
4. Allow a queued move to be cancelled, by some interaction on its button; if more
   than one is pending there, the last queued is cancelled first.
5. Do nothing on go with an empty queue, and say so rather than silently ignoring.
6. Test that queuing from two buttons badges both, and that cancelling removes the
   right one.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [Open questions](../docs/012-open-questions.md) — question 4
