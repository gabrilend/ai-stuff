# 018-the-case.lua

One folder per piece of software (docs/003): its record, ledger, lock, and
the folders later phases fill.

A **case table** (from `open` or `load`): the stored fields `name`, `source`
(absolute, links resolved), `opened`, `harness` (`claude-code` or
`stand-in`), `target` (the person's words; `input/target` overrides), `hold`
(`none`, `middle`, `foundation`) — all strings — plus paths filled in:
`folder`, `ledger`, `lock`, `record_file`, `input`, `output`, `survey`,
`blueprint`, `issues`, `design`, `turns`.

| Function | In | Out |
|---|---|---|
| `open(project, name, source, harness)` | paths table (013); lower-case dashed name; source folder; harness name | the case table; makes every folder, `case.lua`, the ledger's first line. Refuses a bad or taken name, a missing source, a source inside this project |
| `load(project, name)` | paths table; name | the case table; refuses a missing case or one with no ledger |
| `save(case)` | case table | rewrites `case.lua` from its stored fields |
| `take_lock(case)` / `drop_lock(case)` | case table | writes / removes `lock` (process id and time); taking refuses when present, naming the holder |
| `requests(case, ledger_lines)` | case table; `ledger.read` result | two arrays of file names in `input/`: all requests, and new ones (no `request-received` names them). `target` and `README` are settings, not requests |
