<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 002-say-goodbye

The last act: writes `output/goodbye`, the run's receipt.

| Offers | Takes | Gives |
|---|---|---|
| `write(project_dir, summary)` | summary: seed (whole), frames_drawn (whole), steps_run (whole), seconds_run (number) | the file: date, seed, frames, steps, seconds. A missing or stale goodbye means the run did not end cleanly. |
