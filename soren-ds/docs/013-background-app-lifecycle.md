# Background app lifecycle

Each launched app is a soramech map running on the phase 2 thread
pool. Different apps run on different work queues so the scheduler
can pause one app's queue without touching the others'. This doc
describes the three states an app's queue can be in, how
transitions happen, and the small bit of machinery in each app's
map that makes the transitions cheap.

## Three states

- **Foreground.** The app's queue accepts every task. The
  compositor is copying the app's surfaces forward (one app per
  screen — there are two foregrounds total, one per screen,
  unless one app holds both). The app's "always-on" input boxes
  are firing on every relevant input event. This is the obvious
  case: the app is the one in front of the user, doing what it
  does.
- **Background.** The app's map is still resident in RAM. The
  queue still accepts background-eligible tasks but is blocked
  from firing the always-on input boxes the foreground version
  uses. The app is alive but quiet. Inter-app links arriving at
  the app (a messenger receiving an rmail delivery, the editor
  being handed text from another app) still fire — they enter
  through the inter-app linkage entry boxes, which are
  always-eligible. Routine input polling does not.
- **Asleep.** The app's queue is suspended. No tasks fire at all.
  The map is still in RAM with its slot store intact. The app
  wakes when something pushes a value into one of its
  always-eligible entry boxes — the same boxes that fire while
  it was background. From the outside, asleep looks like
  background that has paid the additional cost of being told
  "don't even bother."

The transitions:

```
                  user follows a link to this app
                  ──────────────────────────────────►
   asleep            background                foreground
            ◄──── new wake signal arrives ──── 
              ─── nothing happens for T ────►
                                              ◄──── user follows a link away
```

A power-off freezes the in-RAM state; the next power-on starts
fresh from the persisted foreground apps (`011-filesystem.md`).

## The always-on input box

The mechanism that makes the foreground/background distinction
cheap: every app's map contains a small set of **always-on input
boxes** — boxes whose input is a `read` source that the kernel's
event router pushes values into on every input frame. These boxes
are how the app sees button presses, touch events, and drawer-open
requests.

The kernel marks each always-on input box on the map with a
single flag. When an app transitions to background, the kernel
sets a per-box "suppressed" bit on every flagged box in that
app's map. The runtime's firing rule checks the bit before
firing — if it's set, the box does not fire, and any values that
arrived on its input slot stay pending until the bit clears.
Transitioning back to foreground clears every bit on that app's
flagged boxes in one pass, and the runtime catches up by firing
the box for whatever values are pending.

Background-eligible boxes — the ones that should still fire while
the app is in background — simply do not carry the flag. Inter-app
linkage entry boxes, peer-message arrival boxes, and timer-fire
boxes are all in this category. They keep working regardless of
where in the lifecycle the app is.

This is the entire foreground/background distinction. No separate
event dispatch table per state, no thread suspension, no shared
mutable state under a lock. One bit per always-on input box.

## The per-app queue

Phase 2's thread pool exposes one global work queue by default.
Apps complicate that picture: when an app goes to background, the
pool needs to keep firing its background-eligible tasks while
suppressing its always-on ones, and an asleep app needs to stop
firing entirely without affecting other apps.

The launch design: each loaded app gets its own work queue, and
the worker threads round-robin across the per-app queues. The
queues themselves are the same ring-buffered structure phase 2
gives every other consumer; the only addition is a state field
(`foreground` / `background` / `asleep`) that workers check before
draining the queue.

- **Foreground** queues drain at full speed.
- **Background** queues drain everything that is not suppressed.
  Workers walk the queue, fire tasks whose source box doesn't
  have the suppressed bit, and skip the rest.
- **Asleep** queues are not drained at all. Workers skip them
  during their round-robin pass.

A queue's state change is a single atomic write, with release
ordering, that workers observe via acquire on their next loop.
No locks are held during draining; the suppressed-bit check is
already part of the firing rule and pays no additional cost.

When the user follows an inter-app link to an asleep app, the
arriving value pushes the queue out of asleep into background
(the wake event is itself a background-eligible task), the new
foreground gets set on the screen the link came in on, and the
app's state ticks up to foreground when the compositor commits
the screen swap.

## When an app sleeps

The kernel never automatically sleeps apps in the launch system.
Background apps stay in background until the user closes them
explicitly. Phase 9 may revisit this — long-idle background apps
that haven't fired a non-trivial task in some duration are
candidates for sleep — but the launch behaviour is "background
forever unless the user closes."

The reason for the conservatism: paging is not in scope (see
`007-memory-model.md` and `009-deferred-work.md`). An asleep app
still occupies RAM. The only thing sleep buys over background is
a marginal CPU saving from skipping the suppressed-bit check.
Until we have a real memory pressure problem to solve, the
suppressed-bit check is fine.

The user can ask the system to close an app entirely — that is
the only way an app actually leaves RAM. Closing is exposed as a
drawer option, never automatic.

## A worked example: messenger receiving while editor is foreground

The user is editing a document. The editor is foreground on the
bottom screen. The messenger is background on the top screen — it
was foreground there until the user followed a link to the editor.

A peer sends an rmail message. The radio driver delivers the bytes
to the transport router (`006-transport-and-networking.md`). The
transport router wires into the messenger's
peer-message-arrival box, which is background-eligible. The
message arrival fires; the messenger's map runs the message
through its decryption and storage path; the storage path emits
a `write-path` box invocation against `/messages/<peer>/`; the
write lands on the SD card. The messenger now has new content.

Because the messenger is background, no surfaces redraw. The
user keeps editing.

A few minutes later, the user follows the editor's "to messenger"
inter-app exit. The compositor swaps the bottom screen's
foreground to the messenger; the messenger's per-app queue
transitions out of background to foreground; the messenger's
always-on input boxes (button reading, touch reading) un-suppress
and fire; the messenger draws its conversation view, including
the new message that arrived during the editor session. The user
reads it.

No part of that sequence required the messenger to be told "wake
up" or "you have new content" or "you have focus now." The
mechanism is: tasks fire when their boxes' inputs are ready, the
suppressed bit gates which tasks count, and the foreground swap
is what flips the bit.

## What's next

Phase 6 builds the inter-app linkage that drives the foreground
swap. Phase 9 turns on the MMU so a buggy background app cannot
scribble over a foreground one. Phase 9 is also where the
automatic-sleep policy gets revisited, when there is a launch
system to measure memory pressure against.
