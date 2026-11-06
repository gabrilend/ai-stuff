# settings.lua

Reads a project's transcript-site settings, fills in the defaults, and
refuses what it does not understand. The one place a project says how it
keeps its conversations; the field table is in `README.md`.

## Public functions

- `load(project, file) -> settings` — reads `file`, or the project's own
  `transcript-site.settings.lua` when `file` is nil, or nothing when there
  is neither, and resolves it. A named file that does not exist is an error.
- `resolve(project, raw) -> settings` — checks and fills a raw table. Every
  path comes back absolute (read from `project` unless it starts at `/`).
  Adds `project`, `base_path` (the route from the pages up to the site
  root) and `pages_folder` (`output` joined with `pages`).
- `check(raw)` — the refusals alone: a field not in the list, a field of
  the wrong kind, a `films` table missing any of its twelve fields or
  holding one more.
- `colours_css(settings) -> string` — the project's `colours_css` function's
  answer, or the palette file's colours through `site-palette.lua`.
- `route_up(pages) -> string` — `""` → `"."`, `"story"` → `".."`,
  `"site/story"` → `"../.."`.
- `DEFAULT_FILE_NAME` — `"transcript-site.settings.lua"`.

## Why refuse an unknown field

A misspelt field would be quietly ignored, and the project would get the
default without knowing it had asked for something else.
