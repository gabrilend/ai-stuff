# 049-acceptance.lua

Runs an issue's acceptance commands, exactly as written, from the design
folder: each with `bash -c` under `timeout`, one at a time, stopping at the
first failure; the output is kept as `acceptance.txt` in a turn folder.

| Function | In | Out |
|---|---|---|
| `run(case, issue, turn_folder, limit)` | case table; issue (044); turn folder or nil; seconds or nil (`LIMIT`, 120) | `{ ok = true }` or `{ ok = false, command (string), output (last 60 lines), timed_out (boolean) }` |
