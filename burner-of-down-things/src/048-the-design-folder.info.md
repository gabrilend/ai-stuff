# 048-the-design-folder.lua

Lays out a case's `design/` as a house project, once.

| Function | In | Out |
|---|---|---|
| `lay_out(project, case)` | paths table; case table | true when it laid the folder out now, false when `design/src` already existed. Makes the scratch doors first (`design/tmp` → `/tmp/burner-of-down-things/cases/<key>`, and inside it `shared-memory` → `/dev/shm/burner-of-down-things/cases/<key>`), runs the house skeleton tool with `--skeleton-only`, writes `design/README` (the case and the ledger head) and `output/first-build` (that model-written acceptance commands will run). Refuses when the tool is missing |
| `scratch_key(case)` | case table | `<name>-<first 8 hex of SHA-256 of the case folder path>` |
