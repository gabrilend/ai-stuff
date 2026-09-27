# 063-workflows.lua

The design's referees (issue 506): end-to-end workflows written by a
referee turn from the blueprint alone, kept in the case's `workflows/`
folder where no build or repair turn may write. A **workflow**: `{ name
(NN-<name>.sh), path, covers (array of issue ids from its "# covers:" line) }`.

| Function | In | Out |
|---|---|---|
| `write(project, case, target, options)` | paths table; case; what the design should be; pool options | `{ ok = true, count }` or `{ ok = false, findings }`. Up to 3 referee turns; the old set is kept in the first turn's `before/` and put back on failure. Checks: at least one workflow; every workflow names real issues; every issue covered; every workflow FAILS against an empty folder. Appends `refereed` or `referee-failed`; a breach raises an error |
| `list(case)` | | the workflows, by name |
| `run_one(workflow, folder, limit)` | | ok, last 40 lines of output, exit status |
| `run_all(case, limit)` | | the failures: array of `{ workflow, output }` |
