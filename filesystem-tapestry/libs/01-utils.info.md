# 01-utils.lua — info

Shared toolbox: loud logging and a small JSON codec. Read this instead of the
source unless chasing a specific bug.

## External functions

- `log_info(msg)` / `log_warn(msg)` / `log_error(msg)` — write a coloured
  (only on a terminal) line to **stderr**. `log_warn` is how every fallback in
  the system announces itself, so it is deliberately loud. Returns nothing.
- `basename(path) -> string` — final path segment.
- `extension(path) -> string` — lower-cased extension without the dot, `""` if
  none. Looks only at the last segment, so a dotted parent directory cannot pose
  as a file type.
- `json_encode(record) -> string` — encode a **flat** table (string keys;
  string/number/boolean values) as one-line JSON. Keys are sorted for stable,
  diffable output. Strings are fully escaped, so paths with quotes, tabs, or
  unicode survive.
- `json_decode(line) -> value` — parse one JSON value (objects, arrays, strings
  with `\uXXXX`, numbers, booleans, null). Reads back exactly what
  `json_encode` wrote; robust enough for hand-authored `input/` too.

## Notes

- stderr for logs keeps stdout clean for data.
- The codec is intentionally narrow (flat records) — that is all the catalog
  needs, and narrow means fast.
