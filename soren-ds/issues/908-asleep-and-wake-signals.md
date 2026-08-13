# 908 — Asleep state and wake signals

## Current behavior

The launch system never automatically sleeps an app — background
is the resting state. But the asleep state still exists as a
shape: an app whose queue is paused, woken only by an explicit
external signal. Phase 9 builds the mechanism even though phase
8's apps don't trigger it; the modeller (phase 10) and any
future apps that want background-quiet behaviour will.

## Intended behavior

An asleep app's per-app queue (905) is in state `asleep`.
Workers' round-robin walk skips asleep queues entirely. Nothing
in the app runs.

A wake signal arrives in one of three shapes:

- **Inter-app link.** The link transition (610) discovers the
  target app is asleep. Before pushing the carried value, the
  transition flips the target's queue state from `asleep` to
  `background` (the app comes alive in background; the
  transition then promotes it to foreground per 907).
- **Peer message.** The transport layer (709) delivers a UDP
  datagram addressed to an asleep app's receive port. The
  dispatch flips the target's queue from `asleep` to
  `background` before pushing the value into the target's
  entry box.
- **Timer fire.** A self-arming timer box (309) configured to
  wake an asleep app fires; the timer's wake path flips the
  target's queue state and pushes the tick value.

Each wake shape is a small wrapper around `app_queue_set_state`
(905) plus the same ordinary delivery into the app's way in (309)
that the non-asleep path uses. The kernel doesn't track the
difference between "delivered to an awake app" and "woke an
asleep app" beyond the state byte; the delivery is the same
delivery either way, running the same readiness check on the same
station.

A way to put an app to sleep manually exists too, for use cases
that want the explicit control:

- `app_request_sleep()` — moves the app's queue from
  `background` to `asleep`. Refused if the app is the
  foreground on any screen.

This isn't called by the launch apps. It's exposed for the
modeller and for any later apps that find a reason.

## Suggested implementation steps

1. The three wake paths integrated into 610, 709, and 309.
2. `app_request_sleep()` — the manual route.
3. Documentation note in `docs/013-background-app-lifecycle.md`
   if the wake mechanics aren't already explicit.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

309, 610, 709, 905, 907.

## Blocks

910.
