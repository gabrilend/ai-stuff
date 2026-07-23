# 1-005 — Media Dispatch Table

## Phase 1: The Thread

## Current Behavior

Nothing knows that a `.mkv` should open in mpv and a `.lua` in neovim.

## Intended Behavior

A single dispatch table mapping a file's **kind** (and, underneath, its
extension) to the program that should view it. Two lookups live here:

1. `kind_of(path)` — extension → kind (video / audio / image / text / doc /
   other), used by the scanner to stamp `kind`.
2. `viewer_for(kind)` — kind → `{ program, args }`, used by the navigator to
   open the file under the cursor.

Default mapping (all confirmed present on this machine):

| kind  | program | examples                          |
|-------|---------|-----------------------------------|
| video | mpv     | mkv, mp4, webm, avi, mov          |
| audio | mpv     | mp3, flac, opus, wav, ogg         |
| image | feh     | png, jpg, jpeg, gif, webp         |
| doc   | zathura | pdf, epub                         |
| text  | nvim    | txt, md, lua, sh, c, h, json, ... |
| other | (none)  | → fallback                        |

An unknown kind falls back to `xdg-open` **and prints a warning** that a
fallback was used — fallbacks are warnings, never silent. The whole thing is a
table, not an if-else ladder: adding a format is adding a row.

## Suggested Implementation Steps

1. `EXT_TO_KIND` table (extension string → kind string).
2. `KIND_TO_VIEWER` table (kind → `{program, args}`); `other`/unknown absent so
   the caller triggers the flagged fallback.
3. `M.kind_of(path)`, `M.viewer_for(kind)` reading those tables.
4. All defaults overridable from `config.lua` so the user can re-point a kind.

## Related

- `libs/08-media-dispatch.lua` (implementation)
- `src/03-cataloger.lua` (uses `kind_of`), `src/09-navigator.lua` (uses
  `viewer_for`)

## Metadata

- Status: In progress
- Phase: 1
- Blocks: 1-001, 1-006
