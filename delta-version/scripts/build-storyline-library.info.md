# build-storyline-library.sh

Rebuilds the centralized transcript storyline library: one symlink per real
LLM transcript anywhere in the collection, planted in
`delta-version/library/storyline/` with an ISO-date-prefixed name so that an
alphabetical listing reads as a chronology. Created by issue 057.

Run it from anywhere; it is idempotent and converges on every run.

## Usage

```
scripts/build-storyline-library.sh [--dir <ai-stuff-root>] [--help]
```

- **`--dir <path>`** — re-root the run at a different ai-stuff tree
  (default: the hard-coded `DIR` at the top of the script, overridable by the
  `DIR` environment variable).
- **Exit codes** — `0` clean build; `2` built but some files were excluded
  (each one is listed on stderr with a reason); `1` hard error, nothing built.

## What it produces

`library/storyline/YYYY-MM-DD_<project>_<original-name>.md` symlinks:

- Monorepo projects get **relative** targets (`../../../<project>/llm-transcripts/<file>`)
  so the whole tree can move without breaking links.
- External projects (from `config/external-projects.conf`,
  `[external_directories]` section) get **absolute** targets, because they do
  not move with the tree.

## Internal pieces (black boxes)

| Piece | In | Out |
|---|---|---|
| `parse_arguments` | CLI args | sets `DIR`, or prints usage and exits |
| `load_shared_rulebook` | `DIR` | sources `scripts/libs/transcript-discovery.sh`; hard-fails if absent |
| `discover_transcript_directories` | `DIR`, config file | lines of `origin<TAB>project<TAB>path`, one per `llm-transcripts/` dir found |
| `clear_stale_links` | library dir | removes previous symlinks only; hard-fails on any non-symlink intruder |
| `link_one_transcript` | origin, project, dir, file | one symlink created, or one entry appended to the exclusion report |
| `build_links` | discovery output | the full shelf; applies the header test via `transcript_list_files` |
| `print_report` | accumulators | shelf count, date span, and the loud exclusion list (stderr) |

## Leans on (shared rulebook: `ai-stuff/scripts/libs/transcript-discovery.sh`)

- `transcript_list_files` — recognizes real transcripts by their header line,
  never by filename.
- `transcript_basename_start_ymd` / `transcript_token_to_ymd` — the reverse
  date parser (filename token → ISO date), contributed by issue 057 as the
  mirror image of `transcript_span_basename`. Span names order by their
  *start* date.

## Deliberate behaviors, so nobody "fixes" them

- Files with no parseable date token are **excluded and loudly reported** —
  never guessed into the timeline. The exporter (`backup-conversations`) is
  the single naming authority; re-running it on the offending project either
  renames the file correctly or retires it as an empty husk (issue 020 in the
  scripts project). Never rename transcripts by hand — the exporter re-derives
  every name from the session log and will overrule you on the next Stop hook.
- The in-file `Generated on:` line is ignored on purpose: it records when the
  export ran, not when the session happened.
- The storyline directory is generated and gitignored; edit the generator,
  never the shelf.
