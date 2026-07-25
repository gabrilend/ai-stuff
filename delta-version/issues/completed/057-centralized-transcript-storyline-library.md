# Issue 057: Centralized Transcript Storyline Library

**Phase**: 0 - Tooling
**Status**: Completed 2026-07-23
**Priority**: Medium
**Created**: 2026-07-23
**Related**: 056 (Recursive Transcript Summarization — per-repo tables of contents),
049 (LLM Transcript Abstraction Viewer), 035g (Transcript-to-Commit Provenance)

> Original unsorted note, preserved verbatim:
> *"we should make a delta-version script which grabs all the LLM-transcripts and
> puts symlinks to them in a centralized library directory so the user can read
> the storyline of programming from beginning to end."*

---

## Current Behavior

Built and passing its test suite. `scripts/build-storyline-library.sh` rebuilds
`library/storyline/` on demand: at completion time, 409 transcripts shelved
across 17 projects, spanning 2025-09-18 through 2026-07-24, with 2 UUID-named
files loudly excluded (they carried no date token; they were later found to be
empty husk sessions and are retired by the exporter — scripts issue 020).
`scripts/test-storyline-library.sh` proves the seven promises: builder
completes, every link resolves, shelf count matches an independent recount,
every name carries an ISO date prefix, spans shelve under their start date,
re-runs converge to the identical shelf, and a non-symlink intruder halts the
builder instead of being deleted. The reverse date parser
(`transcript_token_to_ymd`, `transcript_basename_start_ymd`) was contributed
to the shared rulebook `ai-stuff/scripts/libs/transcript-discovery.sh` beside
its mirror image. The exact counts above go stale as sessions accumulate —
re-run the builder for live numbers.

### The world before this issue

Every project keeps its own `llm-transcripts/` directory, filled by the
existing backup toolchain. Each transcript's first line is
`# Conversation Summary: <conv-id>` and its filename carries a date token
(e.g. `jul-3-26.md`, spans like `jul-1-26-through-jul-2-26.md`, `_agent-N`
collision suffixes). The development history was **sharded by project**: to
read what happened across the monorepo during a given week, you visited a
dozen directories and mentally interleaved date tokens that do not even sort
lexically (`jul-3-26` sorts after `jul-11-26` as text, but happened before it
in time). There was no single place where the storyline of programming could
be read from beginning to end.

## Intended Behavior

A delta-version script builds a **centralized library directory** —
`delta-version/library/storyline/` — containing one symlink per transcript found
anywhere in the monorepo (plus any external repos listed in the existing config).
The symlink names are prefixed with an ISO date (`YYYY-MM-DD`) derived from each
transcript's date token, so a plain alphabetical listing *is* the chronology:

```
library/storyline/
  2025-12-10_words-pdf_dec-10-25.md          -> ../../../words-pdf/llm-transcripts/dec-10-25.md
  2026-07-01_soren-ds_jul-1-26-through-jul-2-26.md
  2026-07-01_soren-ds_jul-1-26-through-jul-2-26_agent-1.md
  2026-07-02_delta-version_jul-2-26-through-jul-3-26.md
  ...
```

Reading top to bottom is reading the history of the entire endeavor in the order
it was lived — across every project at once, sessions from different repos
interleaving on the days they actually overlapped.

The library is a **regenerated artifact, not a curated one**. Running the script
again rebuilds it from scratch (or prunes dead links and adds new ones — same
observable result). It is never edited by hand; if a link is wrong, the generator
is wrong, and the generator gets fixed.

## Design Decisions

- **Symlinks, not copies.** The per-project `llm-transcripts/` directories remain
  the single source of truth. The library holds only pointers, so summaries added
  by issue 056 appear in the library view automatically, with zero duplication.
- **Relative symlink targets.** Links point at `../../../<project>/llm-transcripts/<file>`
  rather than absolute paths, so the whole ai-stuff tree can move between machines
  (or between the two mounts of this very repo) without breaking the library.
- **Sortable-date prefix as the ordering mechanism.** The existing date tokens are
  human-friendly but unsortable; the ISO prefix makes the filesystem itself the
  index. For span filenames (`-through-`), the *start* date orders the link,
  because that is when the story of that session began.
- **The library directory is gitignored.** Tracking hundreds of symlinks would
  smear regeneration churn across every commit; the house preference is to
  reference the generator, not freeze its output. A short tracked `library/README.md`
  explains what the directory is and which script rebuilds it.
- **Errors over fallbacks.** A transcript whose filename yields no parseable date
  token is reported loudly at the end of the run (file listed, reason given) and
  excluded — never silently guessed into the timeline. Same for broken pre-existing
  links that don't belong to a known transcript.
- **Rename-tolerant by regeneration.** Issue 056 will rename transcripts to
  `<slug>-<date>.md`; this breaks nothing here because each run re-derives links
  from what is actually on disk. The date-token parser must therefore read the
  token from the *end* of the basename, tolerating an arbitrary slug prefix.
- **The month table in the shared rulebook is declared globally on purpose**
  (`declare -gA`). Discovered the hard way: this builder sources the rulebook
  from inside a function, and a plain `declare -A` there silently creates a
  table *local to the sourcing function* — it vanishes when that function
  returns, every date lookup fails, and all 411 transcripts land in the
  exclusion report. The loud-exclusion design caught this on the first run;
  a silent-skip design would have shipped an empty shelf that looked fine.

## Suggested Implementation Steps

1. **New script** `delta-version/scripts/build-storyline-library.sh`, following
   house conventions: hard-coded `${DIR}` at the top overridable by argument,
   vimfolded functions, a top-of-file comment fit for a general, and a companion
   `build-storyline-library.info.md` describing its callable pieces.
2. **Discovery**: walk the monorepo root for `llm-transcripts/*.md`, recognizing
   real transcripts by their header line via `transcript_is_summary` from the
   shared `transcript-discovery.sh` — never by filename. Include external repos
   from the existing external-projects configuration; skip per-repo
   `table-of-contents.md` and other non-transcript markdown by the same header test.
3. **Date derivation**: parse the date token at the end of each basename
   (month-name, day, two-digit year; spans use the start date) into `YYYY-MM-DD`.
   Consider contributing this reverse-parser back into `transcript-discovery.sh`
   beside `transcript_span_basename`, since it is the mirror image of logic that
   already lives there.
4. **Link naming**: `<iso-date>_<project-name>_<original-basename>`. The project
   name comes from the directory containing `llm-transcripts/`. Original basename
   is kept so nothing is lost and collisions are impossible.
5. **Regeneration**: clear and rebuild the library each run (or equivalently,
   prune links whose targets vanished and add the missing ones). Print a summary:
   how many links, spanning which dates, how many files excluded and why.
6. **Bookkeeping**: add `library/storyline/` to delta-version's gitignore, write
   the tracked `library/README.md`, and register the new script with the
   utility-health-checker if applicable (issue 042's tooling).

## Related Documents
- `ai-stuff/scripts/libs/transcript-discovery.sh` — header recognition and
  date-token construction this script mirrors.
- `ai-stuff/scripts/batch-transcript-backup.sh` — already walks every
  `llm-transcripts/` directory; its discovery approach is the model for step 2.
- `issues/056-recursive-transcript-summarization.md` — will rename transcripts
  and add summaries; the library must coexist (see Design Decisions).

## Tools Required
- bash, GNU coreutils (`ln -s`, `find`), the shared transcript-discovery library.
- No LLM, no network — this is pure filesystem choreography.

## Metadata
- **Complexity**: Low-Medium (the only subtle part is date-token parsing and
  span handling)
- **Dependencies**: transcript-discovery.sh; benefits from but does not require 056.
- **Impact**: The whole monorepo's development history becomes readable as one
  continuous, chronologically interleaved narrative from a single directory.

## Success Criteria
- `ls library/storyline/` lists every transcript in the monorepo in true
  chronological order, oldest first.
- Every link resolves; links are relative and survive relocating the ai-stuff root.
- Re-running the script after new sessions, renames (056), or deletions converges
  to a correct library with no manual cleanup.
- Files with unparseable dates are loudly reported, never silently placed.
- The script and its info.md follow the `${DIR}`/vimfold/comment conventions.
