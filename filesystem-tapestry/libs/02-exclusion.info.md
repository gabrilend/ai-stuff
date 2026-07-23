# 02-exclusion.lua — info

Answers "is this path in an unimportant directory?", built from the shared,
unified `.gitignore` that delta-version maintains across these drives. One source
of truth for what to ignore.

## External functions

- `build(source_path, extra_patterns) -> Matcher` — read the gitignore at
  `source_path`, compile it, append any `extra_patterns` (raw pattern strings),
  and return a Matcher. A missing/unreadable source is a **flagged warning**; the
  returned matcher then excludes nothing. `extra_patterns` exists for names git
  omits by convention (above all `.git`).
- `Matcher:is_excluded(path) -> boolean` — true if the path should be skipped by
  the browse walk. Rules apply in order; a later match wins; a `!` negation
  re-includes.

## The crucial design decision

The shared gitignore's job is "keep binaries out of git", so it lists
**type-globs** like `*.mkv`, `*.mp4`, `*.o`, `*.log`. Our job is different: skip
unimportant **directories**, and the media types git rejects are exactly what the
user most wants to browse. So `build` **drops any pure `*.ext` pattern** and
keeps only directory / specific-name / path patterns. This is why a `.mkv` inside
`my-recorded-videos` stays browsable even though the gitignore names `*.mkv`.

## Matching model

- Bare-name pattern (no slash): matches any single path **segment**.
- Path pattern (has a slash): matches a run of complete segments anywhere in the
  path, bounded by slashes (so `build` cannot match inside `rebuilt`).
- `**` spans segments, `*` stays within one, `?` is one non-slash char; Lua-magic
  characters are escaped.

## Note

Excluded ≠ dropped. This module only **labels**; the scanner still records
excluded files so they remain in the chronological timeline.
