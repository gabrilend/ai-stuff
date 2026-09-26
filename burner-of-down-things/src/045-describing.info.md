# 045-describing.lua

Writing every issue of the blueprint in parallel.

| Function | In | Out |
|---|---|---|
| `step(project, case, rows, options)` | paths table; case table; outline rows; pool options | `{ described = ids, failed = ids, turns = number }`. Every row with no `described` line gets a describe turn, all in one set; each file is checked for shape, then by the house validator; failures get a new turn with their findings, up to 3 per issue; the third failure appends `describe-failed`. A breach raises an error |
| `issue_path(case, row)` | | `blueprint/issues/<id>-<name>.md` |
