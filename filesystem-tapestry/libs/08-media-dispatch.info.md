# 08-media-dispatch.lua — info

Two lookup tables: extension → kind, and kind → viewer program. Adding a format
is adding a row.

## External functions

- `kind_of(path) -> string` — the file's kind from its extension: `video`,
  `audio`, `image`, `doc`, `text`, or `other`. The scanner stamps this onto every
  record.
- `viewer_for(kind) -> { program, args, terminal } | nil` — the program that
  opens that kind. Returns **nil** for `other`/unknown, which is the signal for
  the navigator to take the announced `xdg-open` fallback. `terminal = true`
  (neovim) means "run in the foreground and wait"; `false` (mpv/feh/zathura)
  means "open a window, detached".
- `apply_overrides(overrides)` — merge per-kind viewer overrides from
  `config.viewer_overrides` at startup, so a user can re-point a kind without
  editing this file.

## Default mapping

| kind  | program | terminal |
|-------|---------|----------|
| video | mpv     | no       |
| audio | mpv     | no       |
| image | feh     | no       |
| doc   | zathura | no       |
| text  | nvim    | yes      |
| other | (none)  | → xdg-open fallback |
