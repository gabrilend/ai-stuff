# parser-coverage.lua

Says which files in the test maps the project can read, and whether it
reads them. It opens every map in `assets/` (or the ones named), runs the
project's reader for each file inside, and reports by kind of file: how
many maps hold one, how many of those read without an error, which kinds
have no reader yet, and a matrix of map against kind.

## Command line

```
luajit src/cli/parser-coverage.lua [--dir DIR] [options]
```

| Option | Meaning |
|--------|---------|
| `--dir DIR` | the project root (default `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute`); must come first |
| `-m`, `--map FILE` | one map; repeat for more. Default: every `.w3x`/`.w3m` in `assets/` |
| `-f`, `--file KIND` | only this kind; repeat for more (`war3map.w3e`, `*.blp`) |
| `-v`, `--verbose` | every failure's error (not only the first three of a kind), and the seconds spent reading each kind |
| `--matrix` | print only the matrix, as Markdown |
| `--json` | print the whole report as JSON |
| `--markdown FILE` | also write the report as Markdown to FILE |

Exit status: 0, or 1 when a map couldn't be opened.

## Kinds of file

- A map's own data files by name: `war3map.w3i`, `war3map.w3e`,
  `war3mapUnits.doo`, `scripts\war3map.j` and so on. These are always
  listed, and a map without one shows ○ in the matrix.
- Every other file by extension: `*.blp`, `*.mdx`, `*.slk` ...
- A file the archive holds without a name (StormLib lists it as
  `File00000041.xxx`) counts as `*.mdx` or `*.blp` when its first bytes say
  so, and otherwise by StormLib's guessed extension. `*.xxx` means StormLib
  couldn't guess.
- The archive's own `(listfile)`, `(attributes)` and `(signature)` are
  left out.

Which reader reads which kind is the table `READERS` at the top of the
file. A reader that raises an error, or returns nothing, failed on that
file.

## Functions

Loaded with `dofile` (as the test does), the file returns its functions
instead of running:

| Function | Takes | Gives |
|----------|-------|-------|
| `kind_of(name, bytes)` | a file's name in the archive, its bytes (optional) | its kind, or nil for the archive's own files |
| `read_file(kind, bytes)` | a kind and the file's bytes | `"success"`, `"fail"` and the error, or `"no_parser"`; and the seconds taken |
| `scan_map(path, only)` | a map's path; optionally a set of kinds | `{name, path, files, kinds}`, or nil and why it didn't open |
| `report(paths, only)` | a list of map paths; optionally a set of kinds | `{generated, maps, unreadable, kinds, order, totals}` |
| `status(map, kind)` | a scanned map, a kind | `"success"`, `"fail"`, `"no_parser"` or `"missing"` |
| `terminal(report, verbose)`, `markdown(report, verbose)`, `matrix(report)`, `json(report)` | a report | the text of each output |

## Tests

`src/tests/test_parser_coverage.lua` (two test maps, about a second).
