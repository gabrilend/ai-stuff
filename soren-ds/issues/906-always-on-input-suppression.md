# 906 — Always-on input box suppression

## Current behavior

The per-app queue (905) has a state field but the foreground vs
background distinction is still all-or-nothing. The background
lifecycle doc's central mechanism — a single suppression bit
per always-on input box — has not been built.

## Intended behavior

**An app stops receiving input by having the arrow taken away, not by
having a flag consulted.**

The old plan put a `suppressed` byte on every box that consumes input
and had the firing decision check it. There is no firing decision to
put a check inside — the readiness check runs as the tail of a write,
on one station, and adding a per-box condition to it would put a branch
on the hottest path in the system to answer a question that changes
four times an hour.

Instead, the input router's arrows into a backgrounded app are
**detached**, in a batch, and reattached when it comes forward.

```
   foreground    input router ──→ [ way in ] ──→ the app
   background    input router      [ way in ]      the app
                        │
                        └─→ nothing wired here. the value is discarded
                            at the source, by the ordinary rule that an
                            exit wired to nothing discards.
```

| | the old plan | this |
|---|---|---|
| cost while foreground | one load per firing decision | nothing |
| cost while background | one load per firing decision | nothing |
| what happens to input meanwhile | queues up in the app's ports | discarded where it was produced |
| what it costs to switch | a walk setting a byte per box | one batch rewire per app |

**Discarding rather than queueing is the correction, not a compromise.**
The old plan had a backgrounded app accumulate every button press,
every touch, every stick reading, and then replay all of them the
instant the user switched back — an app that had been in the background
for ten minutes would come forward and act out ten minutes of input.
That is a bug the mechanism was going to deliver on purpose.

**Which arrows come off is a property of the wiring, not of the box.**
The old plan needed a flag per box because it had to know which boxes
were input-driven. Here the question answers itself: the arrows that
come off are the ones running from the input router to this app. An
arrow from the transport layer, or from a timer, or from another app's
link, was never one of them and needs no marking.

**Batching matters here for the reason it always does.** Detach the
arrows one at a time and the app receives a partial frame — buttons but
not the stick — for however long the loop takes. One batch means every
arrow stops at the same instant, and starts again at the same instant.

## Suggested implementation steps

1. Record, per app, which arrows run from the input router into it —
   which is the same "what belongs to this app" question parking (213)
   and closing (909) both need, and the third place asking for it.
2. Detach and reattach as batch rewires (207).
3. A test that a backgrounded app receives nothing, and that coming
   forward does not replay anything that happened while it was away.
4. A test that an arrow from a timer or from another app's link still
   arrives while backgrounded, since that is the distinction the whole
   mechanism exists to draw.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

207 (batch rewiring), 905.

## Blocks

907, 908.
