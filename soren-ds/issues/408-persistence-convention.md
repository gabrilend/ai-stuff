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

## Open questions

- *Do the settings go through the boxes, as step 1 says, or straight to
  the path layer?*
- *What does a setting file that a person edited on a laptop look like
  to the device?*
- *"Schedules a write" — scheduled on what?*
- *Does a save that cannot reach the card change anything?*
- *Where is `settings_load` called from?*

### Proposed answers (UNVERIFIED)

1. *Boxes or path layer?* The path layer (`files_read`, `files_write`
   from 405). The settings module is kernel code that runs before any
   program does, and the boxes are thin wrappers over those same calls,
   so the files are read and written exactly as the boxes would.
2. *Edited on a laptop?* Whitespace around a value is ignored, so `r`
   followed by an editor's newline reads as `r`. A file holding
   anything else, or more than 63 bytes, is put back to its default, on
   the card too, and the developer's line says which. App names are 1 to
   31 letters, digits or `-`, which keeps a path out of a name; they are
   not checked against a list of apps, since no app exists yet.
3. *Scheduled on what?* Nothing: the default is written at once, during
   the load, because the load runs at boot before anything else wants the
   card.
4. *A save that cannot reach the card?* It still changes the value in
   memory, so the device behaves as the person chose for the rest of the
   session, and answers the card's error so the caller knows it was not
   kept. Saves are put in a line, so the file and the memory agree even
   when two saves of one setting race; reads never wait behind a card
   write.
5. *Called from where?* Not yet. The module is built and proven on the
   twin (`src/system/084-settings.c`, `twin/tests/085`), but the device's
   boot does not yet reach the engine or mount the card, so step 4 waits
   on phase 2's 201/202 and on 401. That is why this issue stays open.

## Related documents

- `docs/011-filesystem.md` — persistence rules section.
- `docs/004-input-model.md` — what handedness and drawer-swap
  affect.

## Blocked by

406, 407.

## Blocks

phase 5 (input router needs handedness and drawer-swap), phase 6
(compositor needs last-foreground-*).
