# mpq-extract.lua

Lists or extracts the files in any Blizzard MPQ archive, including an archive
inside a patch program. Uses StormLib through `src/mpq/stormlib.lua`.

## Commands

| Command | Takes | Does |
|---------|-------|------|
| `list <archive> [mask]` | archive path; wildcard (default `*`) | prints size, compressed size, flags, locale and name of each matching file, then a count |
| `extract <archive> <name> <dest-file>` | archive path; file name; destination | writes one file |
| `all <archive> <dest-folder> [mask]` | archive path; folder; wildcard | writes every matching file, turning backslash paths into folders; refuses names containing `..` |

Options before the command: `--dir DIR` (project root), `--listfile FILE`
(extra names; default: the standard Warcraft III map file names from
`src/mpq/standard_names.lua`).

Issue: `issues/completed/112a-stormlib-build-and-update-script.md`
