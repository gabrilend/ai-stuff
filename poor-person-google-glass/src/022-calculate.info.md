<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 009 (tolerance calculations): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 022-calculate

The program behind `./calculate`: `luajit src/022-calculate.lua <project-dir> [NAME...]`. Checks (019) and works out (020) each calculation in input/calculations/, writes output/calculations/NAME.results.lua (keys sorted, so the same results make the same file) and NAME.report.md (via 021), prints one line per answer, and writes output/goodbye with pass and fail counts.
