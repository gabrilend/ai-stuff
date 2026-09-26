# 044-issue-files.lua

Reading and checking a blueprint's issue files. An **issue**: `id`, `name`,
`path`, `text` (strings); `sections` (heading → text); `blocked_by` (sorted
ids from the Blocked by section); `acceptance` (commands: the lines of the
Acceptance section's fenced block, or its backticked bullets).

| Function | In | Out |
|---|---|---|
| `read(path)` | `<id>-<name>.md` | an issue; refuses another name shape |
| `find(folder, id)` | issues folder; id | the path of that issue's file, or nil |
| `check(issue, row)` | issue; its outline row | findings: a missing required section, blockers unlike the outline's, no acceptance command, a name unlike the outline's |
| `validate(validator, blueprint, path)` | house validator path; blueprint folder; issue path | the validator's findings, less "blocker has no file" (a neighbour's trouble, handled by the machine). Refuses when the validator is missing |
| `REQUIRED` | | Current Behavior, Intended Behavior, Suggested Implementation Steps, Acceptance, Blocked by, Covers |
