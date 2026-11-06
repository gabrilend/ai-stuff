# parser_coverage.lua

Which of a map's files the project can read (issue A06). Opens each map,
lists every stored file, and runs the project's own parser on each file it
has one for. `src/cli/parser-coverage.lua` prints the result.

Each file's answer is **read**, **failed** (the parser raised or gave
nothing back; the message is kept), or **no_parser**; a standard map file
the map doesn't hold is **missing**. Standard files (`mpq/standard_names.lua`)
are each their own kind; every other file counts under its extension
(`*.mdx`), so imports give one row.

| Function | Takes | Gives |
|----------|-------|-------|
| `run(paths, options)` | map paths; `options.kinds`, a set of kinds to look at | report: `maps`, `kinds` (standard first, then extensions), `summary[kind]` (parser, maps read/failed/missing/no parser, files read/failed/unread), `totals` |
| `scan_map(path, options)` | one map | `{name, path, files, kinds, missing, error}` |
| `map_status(map, kind)` | | `"read"`, `"failed"`, `"missing"`, `"no_parser"` or `"error"` (map didn't open) |
| `text(report, options)` | `options.verbose`, `options.matrix` | plain text: totals, summary, matrix, kinds with no parser, failures |
| `markdown(report)` | | the same as a Markdown report |
| `json(report)` | | JSON, keys sorted (same maps, same bytes) |
| `failures(report)`, `unread_kinds(report)`, `totals_line(report)` | | the parts the outputs are built from |
| `STANDARD`, `BY_EXTENSION` | | which module and function reads each kind; add a parser here |

Reads maps only; writes nothing. Test: `src/tests/test_parser_coverage.lua`.
