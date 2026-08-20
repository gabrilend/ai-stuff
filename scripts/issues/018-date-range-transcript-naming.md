# 018 - Date-range transcript naming

## Current behavior

The Stop-hook utility (`backup-conversations`) writes one markdown summary per
conversation into each project's `llm-transcripts/` directory. Files are named
after the raw conversation id the source JSONL carries:

- main conversations  -> `<uuid>_summary.md`
- agent sidechains     -> `agent-<hash>_summary.md`

These names are opaque: you cannot tell when a conversation happened without
opening the file. The `_summary.md` suffix also silently does two extra jobs
that several sibling scripts lean on:

1. it distinguishes real transcripts from the *derived* analytics that live in
   the same folder (`wordcloud.md`, `robot-analytics.md`, `*-vN-*.md`, ...);
2. it is the only place the conversation id is recorded that those scripts
   read back (they do `basename "$f" _summary.md`).

Because of (1) and (2), renaming the files naively breaks four consumers:
`batch-transcript-backup.sh`, `conversation-analytics.sh`,
`conversation-wordcloud-poet.sh`, and `claude-conversation-exporter.sh`.

## Intended behavior

Name each transcript by the span of wall-clock dates it covers, so a directory
listing reads like a calendar:

- single-day conversation -> `jul-3-26.md`
- multi-day conversation  -> `jul-3-26-through-jul-5-26.md`

The date token is `<lowercase-month>-<day-no-leading-zero>-<2-digit-year>`.
When more than one transcript resolves to the same span in the same folder, the
extras get a disambiguating suffix placed immediately before `.md`:
`jul-3-26_agent-1.md`, `jul-3-26_agent-2.md`, ... The first to claim a span
keeps the bare name. In steady state the collisions on a given day are usually
the agent sidechains of that day's main conversation, so the suffix reads
naturally.

The rename must be **idempotent** — the hook fires on every conversation end,
so re-running it must reuse a conversation's existing file (and rename it only
when the span actually grows) rather than minting a fresh `_agent-N` each time.
Idempotency is anchored on the machine-readable header line the parser already
writes: `# Conversation Summary: <id>`. That same header line becomes the true
discriminator for "is this file a transcript?" (positive marker), replacing the
`_summary.md` suffix everywhere.

Old transcripts (everywhere in the repo) are migrated to the new scheme. Their
source JSONLs are mostly deleted, so their start dates are unrecoverable; they
are named by their end date only, taken from the file mtime (which the utility
stamped from the last message's timestamp). Files already in the new format are
skipped, so the migration is safe to re-run.

## Suggested implementation steps

1. `libs/conversation-parser.lua` - track the first message timestamp as well
   as the last; emit `START_DATE:` and `FINAL_DATE:` (a bare `YYYY-MM-DD`
   pulled straight from the ISO string, to sidestep timezone math) on stderr
   alongside the existing `FINAL_TIMESTAMP:` used for mtime stamping.

2. `libs/transcript-discovery.sh` (new shared library) - the single home for
   every naming rule so the producer, the migration tool, and the consumers all
   agree. Provides: a header-marker test, a transcript-lister for a directory,
   a header conv-id reader, a date-token formatter, a span-basename builder, a
   new-format-name test, and the collision-aware free-name picker.

3. `backup-conversations` - parse to a temp file, read the two dates, build the
   span basename, resolve the destination through the shared library (reusing
   this conversation's existing file when present), then move the temp into
   place. Process main conversations before agent sidechains so the main one
   claims the bare name. Remove the dead fuzzy-computing descriptive-name block
   (its binary does not exist and it would fight the new scheme).

4. `migrate-transcript-names.sh` (new tool) - walk every `llm-transcripts/`
   under a root, select transcripts by the header marker (not the suffix, so
   hand-written docs like `project_evolution_summary.md` are left alone), skip
   anything already in the new format, derive the end-date from mtime, and
   `git mv` each file to its collision-resolved new name.

5. Consumers - switch from the `*_summary.md` glob to header-based discovery and
   read the conv id from the header:
   - `batch-transcript-backup.sh`
   - `conversation-analytics.sh`
   - `conversation-wordcloud-poet.sh`
   - `claude-conversation-exporter.sh`

6. `README-backup-conversations.md` - document the new naming and the header as
   the stable identity marker.

## Related files

- `backup-conversations`, `libs/conversation-parser.lua` (producer)
- `libs/transcript-discovery.sh` (new), `migrate-transcript-names.sh` (new)
- `batch-transcript-backup.sh`, `conversation-analytics.sh`,
  `conversation-wordcloud-poet.sh`, `claude-conversation-exporter.sh` (consumers)
- `README-backup-conversations.md` (docs)

## Notes / carried-over data

- The header marker is reliable: across the repo, 409/409 real transcripts start
  with `# Conversation Summary: `, and zero derived/hand-written `.md` files in
  the transcript folders do.
- `Generated on:` inside a file is NOT a usable date — a bulk regeneration
  rewrote it to the regen time on many files. mtime is the trustworthy signal.
  (2026-08-20: that finding is now enforced rather than merely recorded. The
  exporter treats the line as volatile, compares transcripts with it excluded,
  and leaves a file alone when it is the only difference — see issue 020,
  item 4. Until then the line re-dirtied every transcript in every project
  after every assistant turn.)
- Same-repo, single git tree; subprojects are plain directories, not submodules,
  so one migration pass with `git mv` covers everything.
