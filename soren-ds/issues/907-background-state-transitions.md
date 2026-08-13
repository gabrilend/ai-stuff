# 907 — Background state transitions

## Current behavior

The per-app queue (905) carries a state, the suppression bits
(906) are wired, but nothing yet drives the transitions. The
state of an app's queue stays at whatever it started as.

## Intended behavior

The state transitions tie together the foreground swap, the
suppression mechanism, and the queue's state byte:

- **foreground → background.** Triggered by the link transition
  (610) when the user follows a link away from this app on this
  app's only screen. The transition (a) walks the app's
  box instances and sets the `suppressed` byte on every
  always-on-input box (906) with release ordering, (b) sets the
  app's per-app queue state to `background` (905).
- **background → foreground.** Triggered by the link transition
  when the user follows a link back to this app. The transition
  (a) sets the app's queue state to `foreground`, (b) reattaches
  the input router's arrows into the app as one batch (906).
  Nothing is caught up on, because nothing was queued — input
  produced while the app was away was discarded where it was
  produced, which is what the user expects and what the old
  suppression plan would have got wrong.
- **foreground → asleep.** Not in scope at launch. The launch
  system never auto-sleeps; only user-initiated close (909)
  takes an app out of running state.
- **background → asleep.** Not in scope at launch (per
  `013-background-app-lifecycle.md`).
- **asleep → background.** Triggered by a wake signal (908)
  arriving for an asleep app. The signal is itself a forward
  inter-app link or a peer message; the wake path leaves the
  app in background state, where the link transition that
  followed it will (if applicable) tick it up to foreground.

Each transition is the same shape: an atomic state write on the
queue, an atomic walk over the box instances. Both happen with
release ordering; workers reading state observe with acquire.

The transitions are bounded — each app has a handful of
always-on input boxes, the walk runs in microseconds.

## Suggested implementation steps

1. `transition_to_background(app)` — combined queue + walk.
2. `transition_to_foreground(app)` — symmetric.
3. Hook into the link transition (610) — calls the right
   transition on the leaving and arriving apps.
4. Tests: walk transitions under load and assert no in-flight
   task gets cut off.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

610, 905, 906.

## Blocks

908, 910.
