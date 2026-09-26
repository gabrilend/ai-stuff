# 028-include-lines.lua

Finds which file includes which, and resolves the names.

| Name | In | Out |
|---|---|---|
| `scan(scanner, text)` | scanner name (`lua`, `c`, `shell`, `python`, `javascript`); file text | array of `{ name (string), kind (require/include/import/source), outside (boolean) }`. Only lines holding a scanner keyword are pattern-matched; commented lines are skipped |
| `resolve(from, name, scanner, all_paths)` | including file's path; name as written; scanner; set of every surveyed path | resolved path and `"yes"`, or the name and `"no"`. Tries relative to the including file, then to the root, with the scanner's spellings (Lua dots → slashes, `.lua`, `/init.lua`, …) |
| `normalise(path)` | relative path | path with `.` and `..` resolved, or nil if it climbs out |
| `SCANNERS` | | per scanner: comment prefix, link kind, patterns |

LuaJIT's `gmatch` reads a leading `^` as a literal caret, so anchored
patterns are matched once per line with `match` instead.
