# summarize-overseer.sh

Issue 056d: finds the saved conversations that have no summary yet. When
the configuration turns it on, it summarizes each one and folds the
summary in.

```
summarize-overseer.sh                          # what it would do (run=off)
summarize-overseer.sh --repo /mnt/mtwo/programs/r-mail
summarize-overseer.sh --dry-run                # a preview even when run=on
```

**What is in scope.** Each session under `~/.claude/projects/` records the
folder it ran in, in its own `cwd` field. That field is read, rather than
the dashed folder names, which are ambiguous. A session's folder maps to
a repository:
- inside the ai-stuff root (with `include_all_ai_stuff=true`), the project
  folder it sits in;
- outside it, the repository listed in `[extra_repos]` that holds it.

Anything else is skipped.

**What is still to do.** Each transcript in a repository's
`llm-transcripts/` folder counts, as the shared rulebook
(`scripts/libs/transcript-discovery.sh`) decides by the header line. A
transcript is already summarized when its folder's table of contents
holds its entry, or its summary block is in place. The table of contents
is what counts first, because the exporter drops the block when it writes
a conversation again.

**What it does.** This is set by the `[overseer]` section of
`config/transcript-summary-repos.conf`:

| Setting | Off (default) | On |
|---------|---------------|----|
| `run` | lists what it would summarize | runs `summarize-transcript.lua` and `apply-summary.sh` on each, at most `max_per_run` (default 10) per run |
| `export` | - | first runs `scripts/backup-conversations --all REPO` for each repository, for sessions the reply hook missed |
| `commit` | - | commits, in each repository, only the files the run changed |

`export` and `commit` act only when `run` is on, and never under
`--dry-run`. A transcript that fails is named, and the rest are still done
(exit 1). It installs nothing: put it on a schedule by hand once a few
runs have been read.

Tested by `test-summarize-overseer.sh` (30 checks). The real summarizer
and applier run against the stand-in model in `libs/stand-in-model/`, and
a stand-in exporter only records its calls.
