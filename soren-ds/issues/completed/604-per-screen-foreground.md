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

## Open questions

- *What is an app?* A surface's owner is a station (601).
- *What does the foreground hold: a name or a number?* The issue's
  `screen_set_foreground(screen, app_name)`.
- *Can a background app keep its surfaces where the foreground app wants
  one?* As built in 601, no owner may overlap another's rectangle, so the
  app in the background would block the app in front, and "background
  app surfaces remain allocated" could not hold.
- *What is the foreground before anything sets it?*
- *What do the system's surfaces do?*
- *How does a change show?* The new app's surfaces may not be marked, and
  the old app's pixels are still on the screen.
- *How does an app subscribe to `foreground-changed`?*

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *The top-level program that placed the owner's station*, through
   every program placed inside another: `program_app_of` in 068.
2. *A program's number*, so the swap is one atomic exchange. Finding an
   app by name is for the callers that know names, boot (605) and the
   link transition (610).
3. *Yes: each app has each screen to itself.* 601's check now refuses an
   overlap only between two owners of the same app. Two apps may hold the
   same rectangle, and only the foreground's shows.
4. *`SURFACE_APP_NONE`:* the surfaces of owners no program placed, which
   share one app between them (so they keep 601's rule among
   themselves). That is what boot and the tests draw with, and it keeps
   603 unchanged until a foreground is set.
5. *They show on every foreground* (`SURFACE_APP_SYSTEM`). They never
   conflict with an app's, since the drawers (606) are the system's and
   sit over apps.
6. *The whole screen is painted again.* The exchange comes first and the
   exposure after it, so a frame in between copies only the new app. The
   other order could paint the old app once more and leave it there. A
   background app's marks are taken and dropped by the compositor; the
   whole-screen paint when it comes back covers them.
7. *Boxes it places in its own map,* driven by any tick it has:
   `foreground_start`, `foreground_track` (the last foreground rides a
   loop), and `foreground_changed`, a comparator against an all-zero
   event. The first tick reports the foreground the app starts with.

## What happened

Built on the twin as answered above:

- `src/system/110-foreground.c` and `.h`: `screen_set_foreground` and
  `screen_get_foreground`.
- `program_app_of` in `src/engine/068-programs.c`.
- In `104-surfaces.c`: `surface_app_of`, an app on every surface, and
  the per-app conflict check.
- The filter in `107-compositor.c`.
- The event boxes in `src/boxes/111-foreground.c`.

`twin/tests/112-test-foreground.c` (26 checks):

- Apps, and who may hold what.
- No foreground yet.
- A switch paints out the old app.
- A background app drawing shows nothing, and when it comes back it
  shows what it drew meanwhile.
- The system's surface stays on top.
- Setting the same foreground again paints nothing.
- The event boxes tell each change once, nothing when nothing changed,
  and nothing about the other screen.

## Related documents

- `docs/005-display-and-compositor.md`.
- `docs/013-background-app-lifecycle.md`.

## Blocked by

207, 603.

## Blocks

605, 610.
