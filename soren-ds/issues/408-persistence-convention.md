# 408 — Persistence convention

## Current behavior

The filesystem boxes (406, 407) can read and write paths but the
kernel has not committed to *which* paths hold *what* persistent
state. Without that, the device cannot remember its handedness
setting, its last-foreground apps per screen, or which drawer
mapping the user picked.

## Intended behavior

The persistence rules from `011-filesystem.md` get implemented
as actual reads and writes:

- `/settings/handedness` — one byte: `r` or `l`. The default at
  first boot is `r`.
- `/settings/last-foreground-bottom` — the name of the app the
  bottom screen was showing when the device last powered off.
  Default at first boot is `editor` (the programming
  environment).
- `/settings/last-foreground-top` — same for the top screen.
  Default at first boot is `messenger`.
- `/settings/drawer-swap` — one byte: `0` or `1`. Default at
  first boot is `0` (the standard mapping).

A small `settings` module exposes:

- `settings_load()` — called from `kernel_main` after the FAT
  layer is up. Reads each setting file through `path-exists`
  and `read-path`; if any is missing, uses the default and
  schedules a write.
- `settings_save_<name>(value)` — called by whichever app owns
  the setting when the user changes it. Writes the new value
  through `write-path`.
- `settings_get_<name>()` — returns the current value from the
  in-memory cache.

The compositor (phase 6) reads `last-foreground-bottom` and
`last-foreground-top` on boot to decide what each screen shows.
The input router (phase 5) reads `handedness` and `drawer-swap`
to interpret button presses. The settings module bridges those
consumers and the filesystem.

## Suggested implementation steps

1. `settings_load()` with per-setting load and default-write.
2. `settings_save_*()` per setting.
3. `settings_get_*()` from the in-memory cache.
4. In `kernel_main`, call `settings_load()` between FAT bring-up
   and the compositor's first frame.

## Related documents

- `docs/011-filesystem.md` — persistence rules section.
- `docs/004-input-model.md` — what handedness and drawer-swap
  affect.

## Blocked by

406, 407.

## Blocks

phase 5 (input router needs handedness and drawer-swap), phase 6
(compositor needs last-foreground-*).
