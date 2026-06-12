# 604 — Per-screen foreground

## Current behavior

The compositor (603) walks every surface on a screen and copies
dirty ones forward. But every app's surfaces would composite —
two apps drawing on the same screen would conflict, two apps on
different screens would each draw their own thing but with no
notion of "this app is the foreground here." The system needs a
per-screen foreground assignment.

## Intended behavior

Each screen tracks a single *foreground app* identifier. The
compositor's per-frame walk (603) is filtered: only surfaces
whose owning box belongs to the foreground app on that screen
get composited forward. Background apps still own their
surfaces and may still write into them; the compositor just
ignores them.

The runtime exposes:

- `screen_set_foreground(screen, app_name)` — atomically swap
  the foreground for the named screen. Called by the link
  transition mechanism (610) when an inter-app link fires, and
  by the boot restoration (605) at startup.
- `screen_get_foreground(screen)` — read the current foreground.
  Apps can subscribe to a `foreground-changed` event box that
  fires whenever the value changes.

The foreground swap is a single atomic store on the screen's
foreground field; release ordering on the store and acquire
ordering on every read. The compositor's next tick (603) reads
the new value and starts compositing the new foreground's
surfaces; the previous foreground's surfaces stay allocated and
get skipped.

Background app surfaces remain allocated in memory and continue
to receive writes from their owning maps (the input router
delivers events to background apps too, just without composite
output). This is what makes the round-trip-through-inter-app-
linkage feel like the app "was still there" — because it was.

## Suggested implementation steps

1. `screen_foreground` field per screen — atomic pointer or
   small integer app id.
2. `screen_set_foreground()`, `screen_get_foreground()`.
3. Filter in 603's per-surface walk on the owner's app id.
4. `foreground-changed` event box for subscribers.

## Related documents

- `docs/005-display-and-compositor.md`.
- `docs/013-background-app-lifecycle.md`.

## Blocked by

207, 603.

## Blocks

605, 610.
