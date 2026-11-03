# Issue 056d: Summary Overseer

**Phase**: 0 - Tooling
**Status**: Completed (2026-11-03), previewing only by default
**Priority**: High
**Created**: 2026-11-03 (split out of 056, which specified it)
**Parent**: 056 (Recursive Transcript Summarization)

---

## Current Behavior

056b summarizes one transcript and 056c folds a summary in, but each has to
be run by hand on one file.

## Intended Behavior

As specified in 056 step 4: `scripts/summarize-overseer.sh` builds the work
list from `~/.claude/projects/`. It reads each session's own `cwd` and
keeps repositories under the ai-stuff root or listed in the
configuration. It runs 056b then 056c on every transcript not yet
summarized, skipping the ones already done, with `--dry-run`, a
single-repository option, and committing.

## Suggested Implementation Steps

1. Map each session's `cwd` to a repository in scope.
2. List each repository's transcripts with the shared rulebook, and pick
   out those with no summary.
3. Summarize and apply each, a bounded number per run.
4. Export first and commit after, each only when configured.
5. Test in a RAM folder against the stand-in model.

## What Happened

Built as `scripts/summarize-overseer.sh`, with
`scripts/summarize-overseer.info.md` and
`scripts/test-summarize-overseer.sh` (30 checks). The real summarizer and
applier run against the stand-in model, and a stand-in exporter only
records its calls. No model was downloaded or run, and nothing was
installed or scheduled.

**Decided while building (my own calls, in the shape decided for 056c and
039):**

- **It previews by default.** `run=off` in the new `[overseer]` section of
  `config/transcript-summary-repos.conf` lists what it would do and
  changes nothing. `export` and `commit` are separate settings, also off,
  and act only when `run` is on. `--dry-run` previews even then.
- **"Already summarized" means the table of contents holds the
  conversation's entry, or the summary block is in place.** The table of
  contents comes first because the exporter drops the inline block when it
  writes a conversation again.
- **`--repo PATH` picks one repository.** `--dir` stays the monorepo, as in
  every other tool here.
- **`max_per_run` (default 10) bounds the model work per run.** The rest is
  left for later runs, and the overseer says how many.
- **Commits take only the files the run changed:** each summarized
  transcript, the table of contents, and a renamed file when renames are
  on. Other work in the repository is left as it was.
- **Exporting again is optional (`export=on`).** The reply hook already
  exports each conversation, so the overseer summarizes what is there.
