# 605 — Boot foreground restoration

## Current behavior

The system has a foreground assignment per screen (604) but at
boot there is no logic that decides what to put there. The
filesystem persists the last-foreground per screen (408), but
the kernel doesn't yet read those files and start the
corresponding apps.

## Intended behavior

`boot_restore_foregrounds()` runs after the filesystem and
runtime are up but before the compositor's first tick:

1. Read `/settings/last-foreground-bottom` through `read-path`
   (406). If the file doesn't exist (first-boot), default to
   `editor`. If it exists, the file's contents are the name of
   the app the bottom screen should foreground.
2. Read `/settings/last-foreground-top`. Default to `messenger`
   if first-boot.
3. For each named app, load its program from `/apps/<name>/`
   through the loader (306). Loading *is* starting: the last thing
   the loader does is write the fixed values, and writing one runs
   the readiness check on its station. There is no separate submit.
   The app begins running in the background.
4. Once the apps have loaded, call `screen_set_foreground(bottom,
   "editor")` and `screen_set_foreground(top, "messenger")`
   (or whichever names came from settings).
5. The compositor's next tick paints the foregrounds' surfaces.

If a named app fails to load — its `/apps/<name>/` is missing,
its source is broken, its compilation fails — the system falls
back to the first-boot defaults and logs a warning through the
CDC-ACM stream.

This is the only place the kernel decides what to run; from this
point forward, the running set evolves through inter-app links
the user follows.

## Suggested implementation steps

1. `boot_restore_foregrounds()` — the orchestration above.
2. Call from `kernel_main` after settings, FAT, and runtime
   are up.
3. Fallback path for missing or broken apps.

## Related documents

- `docs/005-display-and-compositor.md` — boot and persistence
  section.
- `docs/011-filesystem.md` — persistence rules.

## Blocked by

303, 308, 406, 408, 604.

## Blocks

611 (the demo restores its apps via this path).
