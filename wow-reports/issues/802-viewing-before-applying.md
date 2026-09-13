# 802 - Viewing before applying

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | 801 |
| Blocks | 803, 804 - nothing may be applied before it can be read |

## Current behaviour

Nothing to view.

## Intended behaviour

The owner's framing, in their words: *we view the changes, then can apply it.*
Viewing is a required step, not a convenience, and the two acts are separated so
that neither can happen by accident as a side effect of the other.

A rendered change set shows, per entry, what moves and why: the old value, the
new one, the build it was observed at, which source claimed it, and how
confident the dating is. It groups by entity so that a person reading it sees
"this ability changed in four ways" rather than four unrelated lines.

It also shows what it is *refusing* to emit and why, because the refusals are
the interesting part. An ability that does not exist in the target era, a value
whose dating is unknown, a field the emitter has no mapping for - each is a
visible line in the view rather than a silent absence. A reviewer cannot notice
an omission that was never printed.

The view is generated from the change set and reads nothing else, keeping the
project's standing separation between producing data and showing it. It must be
possible to produce a view for a change set that is never applied.

## Suggested implementation steps

1. Render to plain text first - it is what gets read in a terminal next to the
   command that would apply it.
2. Render to a page second, sharing the viewer's style, so a large change set
   can be sorted and filtered. A change set covering a whole expansion's worth
   of tuning is thousands of lines and is unreadable as a flat list.
3. Summarise honestly at the top: how many entries, how many entities, how many
   refused and for which reasons. The refusal count is the number most likely to
   reveal that the emitter is misconfigured.
4. Make applying take the viewed change set as its input rather than
   re-computing. If applying re-derives its own change set, the thing reviewed
   and the thing applied are two different objects and the review guarantees
   nothing.
