<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 008-say-goodbye

Writes `output/goodbye`, the run's receipt (issue 005).

| Offers | Takes |
|---|---|
| `write(project_dir, summary)` | summary: file, format (strings); triangles, parts, frames_drawn (whole); seconds_run, read_seconds (numbers); screenshot (path or false); black_share (0..1, only with a screenshot: pure-black pixels mean the capture failed) |
