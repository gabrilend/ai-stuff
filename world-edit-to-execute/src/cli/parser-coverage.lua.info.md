# parser-coverage.lua

Prints which files in the test maps the project can read: per kind of file,
how many maps read it, failed, or don't hold it, and how many files have no
parser yet; then a map-by-kind matrix. Built on `src/data/parser_coverage.lua`
(issue A06).

Usage: `luajit src/cli/parser-coverage.lua [--dir DIR] [-a] [-m MAP] [-f KIND] [-v] [--matrix] [--json] [--markdown FILE] [MAP ...]`

- No maps named, or `-a`: every `.w3x`/`.w3m` in `DIR/assets`.
- `-f KIND` (repeatable): only that kind, e.g. `war3map.w3e` or `*.mdx`.
- `-v`: every failure with its message. `--matrix`: the matrix alone.
- `--json`: JSON instead of text. `--markdown FILE`: also write a Markdown report.

Exit 0 when nothing failed, 1 when a file failed or a map would not open,
2 on a usage error. Reads the maps only.
