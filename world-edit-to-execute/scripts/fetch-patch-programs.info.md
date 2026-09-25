# fetch-patch-programs.sh

Collects Blizzard's Warcraft III patch programs from public mirrors into
`wc3-installs/patch-programs`, one file per version and game, and records
where each came from. Running it again changes nothing.

| Option | Takes | Does |
|--------|-------|------|
| `[DIR]` | project root (string) | first argument; defaults to the project path |
| `--only VERSION` | version (string, e.g. `1.24e`) | fetch that version only (both games if both are listed) |
| `--game GAME` | `tft` or `roc` | fetch one game's programs only |
| `--list` | — | print each listed program as present or missing |

## Inputs and outputs

- **Reads** `wc3-installs/patch-sources.tsv`: tab-separated rows of version
  (string), game (`tft`/`roc`), source (URL or `file://` path), member of a
  zip (string, or `-` when the source is the program itself), saved-as file
  name (string).
- **Writes** each program to `wc3-installs/patch-programs/<saved-as>` and
  appends a row to `wc3-installs/patch-programs/sources.tsv`: saved-as,
  version, game, sha256 (hex string), source, member, fetch time (UTC ISO 8601).
- **Refuses** a present file whose checksum differs from its record (exit 1);
  a failed download or missing zip member is reported and the run goes on,
  ending with exit 1.
