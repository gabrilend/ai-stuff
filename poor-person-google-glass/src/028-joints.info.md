<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 010 (tolerance records on the model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 028-joints

The program behind `./joints`: `luajit src/028-joints.lua <project-dir> [find|work] MODEL-FILE [--distance D]`. Finds joints and merges the records (default contact distance: 0.5% of the model's size); works out every joint with an equation, binding inputs to the joint's measures (in mm) and its parts' materials, and writes output/joints/MODEL.results.lua and MODEL.report.md; any problem (unassigned material, unknown measure, mismatched unit) is listed and nothing is written. Finds its code beside itself, so the project folder may hold data only. Writes output/goodbye.
