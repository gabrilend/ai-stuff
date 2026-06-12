# 909 — Explicit app close

## Current behavior

An app can sit in foreground, background, or (since 908) asleep,
but there's no path that fully exits it — frees its RAM, frees
its memory region (902), drops its descriptor cache. Without
that, every app the user opens accumulates in RAM until reboot.

## Intended behavior

Each app's drawer gets one option: "close app". Activating it
performs an orderly teardown:

1. Refuse if the app is the foreground on a screen — the user
   must first follow a link away. The refusal shows a small
   inline message in the drawer.
2. Set the app's queue state (905) to `closing`. Workers stop
   picking up tasks from it.
3. Wait for any in-flight tasks on the app to finish — a brief
   spin on the queue's in-flight count.
4. Free the app's memory region (902) and reset its page table
   entries to kernel-only (901). Any held-but-not-currently-
   in-use memory the app accumulated is reclaimed.
5. Drop the app's map_t from the runtime's loaded-maps table.
6. Decrement the artifact reference count (410) on any
   user-compiled boxes the app held.
7. Remove the app's per-app queue from the worker round-robin
   list.
8. Emit an `app-closed` event into the transcript ring.

The app's persisted state on the SD card (its documents, its
drawings, its messages, its settings) is untouched. Closing an
app and reopening it later resumes from the persisted state.

A reverse path — `app_open(name)` — loads the app's map fresh,
allocates a new region, attaches a new queue, restores it to
background state, runs its entry boxes. The link transition
(610) calls this implicitly when targeting an app not currently
loaded.

## Suggested implementation steps

1. The "close app" drawer option in every app's drawer.
2. `app_close(name)` — the orderly teardown.
3. `app_open(name)` — the open path called implicitly by 610.
4. The refusal banner for the foreground case.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

608, 905, 906, 907, 901, 902.

## Blocks

910.
