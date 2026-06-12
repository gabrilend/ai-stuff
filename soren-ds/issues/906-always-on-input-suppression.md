# 906 — Always-on input box suppression

## Current behavior

The per-app queue (905) has a state field but the foreground vs
background distinction is still all-or-nothing. The background
lifecycle doc's central mechanism — a single suppression bit
per always-on input box — has not been built.

## Intended behavior

Every box descriptor (208) gains an `always_on_input` flag. Box
authors set it true on boxes that should fire only when the app
is foreground — the button event consumers, the touch consumers,
the radial-menu chord receiver. Box authors leave it false on
boxes that fire regardless of foreground state — inter-app
linkage entries, peer message arrival boxes, timer-fire boxes,
file-write completion boxes.

Each box instance (301) gains a `suppressed` byte. The byte is
atomic for safe cross-worker reads. The byte is set when the app
transitions to background, cleared when the app transitions
back to foreground.

The gathering function (206) checks the byte before deciding
whether to fire. If suppressed, the gather skips this box for
this round. Values that arrived on suppressed boxes' input slots
queue up; when the byte clears, the next gathering attempt
catches up by firing for each queued value.

The check is a single acquire load on the hot path — cheap
enough to not measure under load.

When an app transitions to background, the state-change
mechanism walks every box instance in the app's map, identifies
those with `always_on_input` set, and sets their `suppressed`
byte. The transition back clears the bytes in one pass.

This is the entire foreground/background distinction. No
separate event tables, no thread suspension, no shared mutable
state under a lock. One bit per always-on input box per app.

## Suggested implementation steps

1. `always_on_input` flag on `box_descriptor_t`.
2. `suppressed` byte on `box_instance_t`.
3. Suppressed-check on the gathering function in 206.
4. Walk-and-set-suppressed pass at state transition.
5. Update the launch utility boxes (309) and the
   filesystem/input/transport boxes to set the flag on the
   relevant ones.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

206, 208, 301, 905.

## Blocks

907, 908.
