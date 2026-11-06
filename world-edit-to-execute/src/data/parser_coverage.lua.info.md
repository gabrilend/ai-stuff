# parser_coverage.lua

Which of a map's files the project can read (issue A06). Opens each map,
lists every stored file, and runs the project's own parser on each file it
has one for. `src/cli/parser-coverage.lua` prints the result.

Each file's answer is **read**, **protected** (a map protector's
placeholder: the module's `protected(data)` names it and the parser
refuses it with that reason, issue A06a), **failed** (the parser raised or
gave nothing back; the message is kept), or **no_parser**; a standard map
file the map doesn't hold is **missing**. Standard files (`mpq/standard_names.lua`)
are each their own kind; every other file counts under its extension
(`*.mdx`), so imports give one row.

| Function | Takes | Gives |
|----------|-------|-------|
| `run(paths, options)` | map paths; `options.kinds`, a set of kinds to look at | report: `maps`, `kinds` (standard first, then extensions), `summary[kind]` (parser, maps read/protected/failed/missing/no parser, files read/protected/failed/unread), `totals` |
| `scan_map(path, options)` | one map | `{name, path, files, kinds, missing, error}` |
| `map_status(map, kind)` | | `"read"`, `"protected"`, `"failed"`, `"missing"`, `"no_parser"` or `"error"` (map didn't open) |
| `text(report, options)` | `options.verbose`, `options.matrix` | plain text: totals, summary, matrix, kinds with no parser, protected files, failures |
| `markdown(report)` | | the same as a Markdown report |
| `json(report)` | | JSON, keys sorted (same maps, same bytes) |
| `failures(report)`, `protected_files(report)`, `unread_kinds(report)`, `totals_line(report)` | | the parts the outputs are built from |
| `STANDARD`, `BY_EXTENSION` | | which module and function reads each kind; add a parser here (a module's `protected` function is used when it has one) |

Reads maps only; writes nothing. Test: `src/tests/test_parser_coverage.lua`.
