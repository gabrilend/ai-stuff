# 00-config.lua — info

The settings sheet. Declares only; does nothing. Every path is built from `DIR`.

## Fields

- `roots[]` — the data drives to walk (`/mnt/cmdo`, `/mnt/mtwo`, `/mnt/dile`,
  `/mnt/kaun`, `/home/ritz`). One scanner process per root.
- `exclusion_source` — path to the shared unified `.gitignore`
  (`/mnt/mtwo/programming/ai-stuff/.gitignore`).
- `always_exclude[]` — names git omits by convention, appended to the shared
  list. Default `{ ".git" }`.
- `paths` — `tmp`, `assets`, `catalog`, `input`, `output`.
- `chronology` — default `{ field, direction }` for the chronological walk.
- `walk` — `{ skip_excluded }`.
- `viewer_overrides` — optional per-kind viewer replacements (empty by default).
