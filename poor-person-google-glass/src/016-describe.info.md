<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 016-describe

The describing program (issue 007e), run by the `describe` script: `luajit src/016-describe.lua <project-dir> <description-file>`. Reads, solves, builds; writes output/described/NAME.gltf and NAME.report.md (the description, every part's numbers, every assumption), and output/goodbye. On any refusal prints them all, writes only the goodbye, exits 1.
