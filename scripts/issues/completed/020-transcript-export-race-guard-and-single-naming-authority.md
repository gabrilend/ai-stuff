# 020 - Transcript export race guard and single naming authority

**Status: completed 2026-07-25. Amended 2026-08-20.** Both guards live in the
exporter and are covered by `tests/test-transcript-export-guards.sh` (fixture
sessions, no real data touched). The two production husks were retired on
first run — one of them out from under a date-name a stray rename had given
it — and the storyline shelf reports zero exclusions. The guard also
immediately flagged one genuine ends-with-user conversation in soren-ds
(frozen history, exported as-is with the warning). The migrator is `-done`,
pending removal after one commit.

The 2026-08-20 amendment closes a gap this issue left open. The idempotency
built here made a transcript's *filename* a function of the session log but
left its *contents* out of that promise, so every export still rewrote every
transcript under a fresh generation stamp. Item 4 of *Intended behavior* and
step 6 below carry the missing half.

## Current behavior (as found before this issue)

The Stop-hook exporter (`backup-conversations`) fires after every assistant
reply and re-derives every transcript's name and content from the session
JSONLs. Three problems live in and around it:

1. **A read/write race eats the final reply of a session.** The Stop event and
   the JSONL append of the assistant's message are sibling consequences of the
   same completion — the hook is not ordered after the disk write. When the
   exporter wins the race it exports a conversation that ends with the user's
   message and no reply. Multi-turn sessions self-heal (each export rewrites
   the whole file), but the last reply of a session has no later export to
   repair it, so one-exchange sessions can stay truncated forever. Observed:
   the soravoice project's only transcript, generated the same second as the
   missing reply's timestamp.

2. **Message-less sessions produce husk transcripts with UUID names.** A
   session that was opened and titled but never exchanged a message has no
   timestamps, so the exporter's warning path names its transcript by raw
   conversation id. The husk file is a 179-byte blank page; the UUID name is a
   state flag other tools misread as a misspelling. One such "fix" attempt
   (renaming by hand via the migrator) was reverted by the exporter within
   minutes, because names here are projections of the JSONL, not stored facts.

3. **Two programs write transcript names.** The exporter (continuous,
   timestamp-derived) and `migrate-transcript-names.sh` (one-shot,
   mtime-derived) disagree on rare inputs and fight via the filesystem; the
   enforcer that runs after every reply always wins. The migrator's bulk
   job (issue 018 step 4) is complete: 420/422 files were converted, and the
   remaining two are husks, not stragglers.

## Intended behavior

**The exporter is the one and only program that names, renames, or removes
transcript files.** Everything else — analytics, the storyline shelf, future
summarizers — reads names through the shared rulebook and writes none.

1. **Race guard, in the exporter**: the parser reports when a conversation
   ends with a user message and no assistant prose after it — the only shape
   the race can produce. On that signal the exporter waits a beat and
   re-parses, a few bounded tries; if the shape persists it exports as-is and
   prints one loud line saying so. Bounded, because during any export some
   *other* live session legitimately sits mid-reply; those repair themselves
   on their own next Stop.

2. **No husk transcripts**: a session with no message timestamps gets no
   transcript file at all — and if an earlier run (or a rename) left one
   under any name, the exporter retires it, keyed by the conversation id in
   the file header. The warning stays as a printed line instead of a
   filename. With this, every file the exporter ever writes matches the one
   date-token grammar from `libs/transcript-discovery.sh`, and the storyline
   shelf's exclusion report converges to empty.

3. **Migrator retired**: renamed to `-done` per house deprecation convention,
   removed after one commit. References to it in other tools' hint text are
   updated to point at the exporter instead.

4. **A re-export says nothing when nothing was said**: the exporter re-derives
   a transcript's *name* from the session log on every run, and must re-derive
   its *contents* on the same terms — writing only where they actually differ.
   The obstacle is the exporter's own output: the parser stamps a fresh
   "Generated on:" wall clock into every file it produces, so comparing bytes
   against what is already on disk answers "did anything change?" with a
   permanent yes. The comparison steps over that one line, and where only the
   stamp would move, the file on disk is left exactly as it is. The mtime is
   deliberately exempt from the skip: it is a projection of the log in the same
   way the name is, so it is enforced on every run whether or not the prose
   moved — which is also what repairs a file some checkout or copy scrambled.
   Nothing in git watches an mtime, so enforcing it costs no churn.

## Suggested implementation steps

1. `libs/conversation-parser.lua` — compute "ends with an unanswered user
   message" at the final-flush point (a user turn exists; the assistant-prose
   buffer is empty), return it alongside the three dating signals, and emit
   `ENDS_WITH_USER:1` on stderr with the others.

2. `backup-conversations` — per conversation: if the signal is present,
   re-run the parser after a short sleep, up to 3 tries; on surrender print
   "ends with an unanswered user message; exported as-is". If no timestamps:
   delete the temp file, look up the conversation's existing claim via
   `transcript_find_claim`, remove it if present with a printed notice, and
   write nothing. Document the naming-authority rule at the top of the
   function. Allow the `~/.claude/projects` root to be overridden by an
   environment variable so tests can point the exporter at fixture sessions.

3. `migrate-transcript-names.sh` → `migrate-transcript-names.sh-done` via
   `git mv`; drop it entirely in a later commit. Update the storyline
   builder's exclusion-hint line (delta-version) and its info companion,
   which currently recommend the migrator.

4. Tests in `tests/`: fixture JSONLs exercising (a) a complete one-exchange
   conversation → transcript contains the reply; (b) a husk with a
   pre-existing claim file → no transcript written, claim retired; (c) an
   ends-with-user log → loud surrender line appears and the file still
   exports. Run against a scratch project directory via the environment
   override.

5. Cross-project: delta-version issue 056 (transcript summarization) plans a
   third name-writer; amend it so its rename step goes through the rulebook
   and the exporter preserves summarized names (see Notes).

6. `libs/transcript-discovery.sh` — name the volatile header line in a
   constant, add a fingerprint of a transcript's body computed with that line
   excluded, and a same-content predicate over two fingerprints. Comparing by
   fingerprint rather than by diff keeps the cost one short string per file;
   the corpus runs to hundreds of kilobytes apiece.
   `backup-conversations` — after the destination is chosen and before the temp
   file is moved into place: when the destination *is* the conversation's
   existing file and the two say the same thing, delete the temp, re-stamp the
   mtime anyway, print "Unchanged:" instead of "Created:", and move on. Only
   the overwrite-in-place case may be skipped; a destination that differs from
   the claim means the conversation crossed into a new day and the file has to
   be re-placed under its new span name.
   Tests in `tests/test-transcript-export-guards.sh`: (d) a second pass over
   settled fixtures leaves a transcript byte-identical *and on the same inode*
   — the inode is what distinguishes "left alone" from "rewritten with the
   same words", which the mtime cannot, since the writing path stamps the
   mtime back from the log either way; (e) a pass after appending an exchange
   still rewrites the file, so the skip cannot over-fire; (f) a hand-scrambled
   mtime is restored without the contents being rewritten.

## Related files

- `backup-conversations`, `libs/conversation-parser.lua` (the authority)
- `libs/transcript-discovery.sh` (the rulebook the authority speaks through)
- `migrate-transcript-names.sh` (retired by this issue)
- `delta-version/scripts/build-storyline-library.sh` + `.info.md` (hint text)
- `delta-version/issues/056-recursive-transcript-summarization.md` (amended)
- `issues/018-date-range-transcript-naming.md` (the naming scheme this
  issue closes the loopholes of)

## Notes

- The race was proven, not assumed: the truncated export's "Generated on"
  stamp and the missing reply's message timestamp share the same second, and
  re-running the exporter against the settled JSONL produced the full
  transcript with unchanged code.
- Any fixed pre-export sleep was rejected: it bets on the width of a window
  we have one sample of, and it spends the delay on every export instead of
  the one ambiguous shape. Check for the fingerprint, retry briefly, surrender
  loudly.
- Issue 056 interplay: the exporter re-places any claim whose basename differs
  from the derived span base. A summarizer that renames files to
  `<slug>-<date>.md` will be reverted unless the base comparison learns that a
  claim whose name *ends with* the derived date token is already in scheme.
  That comparison lives in one place (the exporter's claim check); 056 should
  widen it there, through the rulebook, rather than adding a competing
  renamer.
- The name/content asymmetry survived three weeks unnoticed because it hides
  well: every individual transcript reads correctly, every mtime is correct
  (stamped back from the log), and only `git status` disagrees — where it looks
  like ordinary pending work rather than a fault. In minimal-soramech, 116 of
  the first 145 transcript changes ever committed were the stamp line and
  nothing else, 80% of the churn, and one commit message had already named the
  phenomenon in passing — "seven files just restamp" — without anyone following
  it back to the cause. The general shape is worth keeping: a tool that
  re-derives an artifact from a source on every run is only idempotent if
  *everything* it derives is a function of that source. One wall-clock reading
  in the output is enough to break it, and the breakage is invisible until
  something outside the tool starts keeping score.
