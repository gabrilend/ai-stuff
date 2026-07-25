# 030-stats — the one measurer

Honest numbers about renders, so documentation cites a tool instead
of stale statistics. Two modes: measure (render a scene, sequential
or many-hands, and report stage CPU clocks plus real wall time) and
summarize (every report in output/ as one table — read-only).
The wall clock is read from the system at nanosecond resolution and
feeds reporting only; os.clock sums CPU across threads, which makes
parallel work look slower — the distinction is documented at the
file head.

## Usable surface

- **wall() → seconds** — fractional epoch time, read-only.
- **measure(dir, scene, workers) → bytes, facts** — workers 0 means
  the sequential runner.
- **say(facts)** — one measurement, spoken plainly.
- **summarize(dir) → count** — the reports table.

CLI: `luajit src/030-stats.lua [dir]` summarizes;
`luajit src/030-stats.lua [dir] <scene> [workers]` measures.
