# 018 - Date-range transcript naming

## Current behavior

Transcripts are named by the span of dates they cover, and a directory listing
reads like a calendar:

- single-day conversation -> `jul-3-26.md`
- multi-day conversation  -> `jul-3-26-through-jul-5-26.md`

Collisions take a `_agent-N` suffix; the first claimant of a span keeps the
bare name. Identity is the header line `# Conversation Summary: <id>`, not the
filename, so files can be renamed freely while the toolchain keeps finding
them. The exporter is the sole naming authority (issue 020) and re-derives
every name on every run.

**The dates are wrong by one timezone offset, and so are the file mtimes.**
Both faults live in `libs/conversation-parser.lua`, and they were introduced
deliberately by step 1 of this ticket's original plan, which called for the
date to be pulled straight out of the ISO string "to sidestep timezone math".

*The filename fault.* A session log records each message as an ISO instant
ending in `Z` — `2026-09-17T02:49:33.001Z` — and the trailing `Z` means that
clock reading is UTC. The date reducer plucks the year, month and day
characters out of that text and uses them verbatim as the calendar date. A
conversation held at 7:49pm local on the 16th is therefore filed under the
17th. Every conversation after roughly 5pm local is filed a day late.

*The mtime fault.* Turning a clock reading into an instant is done by handing
the year/month/day/hour/minute/second fields to Lua's `os.time`, which
interprets the table it is given as **local** time. The fields are UTC. The
instant produced is wrong by exactly the local offset from UTC, and it is that
instant which gets stamped onto the transcript as its modification time:

| quantity | value |
| --- | --- |
| `os.time` on the UTC fields of `2026-09-17T02:49:33Z` | 1789638573 |
| true epoch of that instant | 1789613373 |
| difference | 25200 s — exactly 7 h, the PDT offset |

The two faults agree with each other, which is why neither was visible: the
comment above the date reducer states that UTC was chosen in both places so
that "naming and the on-disk timestamp never disagree". They do not disagree.
They are wrong together.

*Confirmation independent of this code.* In `/mnt/mtwo/programs/claude-code`
the transcript directory's own mtime — set by the kernel when the last file
was written, and untouched by any of this — reads `2026-09-16 19:49:35 -0700`,
while the file written at that moment, `sep-17-26.md`, carries a stamped mtime
of `2026-09-17 02:49:33 -0700`. Seven hours apart. The kernel says Wednesday
evening; the name and the stamp both say Thursday morning.

## Intended behavior

A transcript is named for the calendar dates on which the conversation
happened **in the local timezone of the machine that held it**, and its mtime
is the true instant of its last message. Naming rules are otherwise unchanged:
same token format, same span form, same collision suffixes, same header-based
identity.

Concretely, the two reducers in the parser are corrected:

- the instant builder parses the ISO string as the UTC it declares itself to
  be, rather than feeding UTC fields to a constructor that reads them as local;
- the date reducer renders that corrected instant in local time, rather than
  copying the UTC date characters out of the source text.

The existing corpus is migrated to match. Each transcript is dated from the
strongest evidence that still exists for it, and where every witness has
failed the file is reported and left alone rather than given an invented date.
Re-derive these counts with the migration tool's own dry run, which reports
and writes nothing; they are recorded here as of 2026-09-21:

| group | count | what dates it | repeatable |
| --- | --- | --- | --- |
| session log survives | 159 | the exporter rebuilds it from source | yes |
| prompt history | 68 | both ends, from epoch milliseconds | **yes** |
| stamp alone, sound | 99 | the fault inverted back out of the stamp | no |
| preserved by request | 299 | nothing; left exactly as found | n/a |

That comes to 104 files renamed and 63 restamped in place. Fifty-five of the
renames are files still carrying their original conversation id as a name —
this ticket's first migration never reached them, and dating them now
finishes that job as well.

### The prompt-history file as a second source

`~/.claude/history.jsonl` holds one line per prompt the user sent, carrying
the session id it belonged to and a `timestamp` field that is a **Unix epoch
in milliseconds**. An epoch count is an absolute instant with no timezone
folded into it, so it cannot carry the fault being fixed here. The earliest
prompt of a session is exactly the start date that a frozen transcript's own
stamp cannot supply — a stamp records only the last message.

Validated before being relied on: across the 168 conversations for which both
a session log and prompt-history lines survive, the local start date derived
from the log and the one derived from the prompt history agree 168 times and
disagree zero times.

The history bounds a session by its first and last **prompt**, and a
conversation ends with the assistant's reply, which lands after the last
prompt. So the stamp remains the better witness for the end, and the history
is used for the end only when the stamp has been disproved.

### Inverting a stamped modification time

Where no second source exists the fault is still exactly invertible. The
stored stamp was built by reading UTC clock fields as if they were local;
rendering that stamp back in local time therefore returns the original UTC
reading verbatim, and re-reading that as UTC gives the true instant. Both
halves consult the daylight-saving rules for their own date, so the error
cancels across the year.

### Stamps that describe the copy, not the conversation

The first version of this migration trusted every stamp, and it was wrong to.
A bulk copy, a restore or a checkout rewrites every file's modification time
to the moment of that operation. In `world-edit-to-execute`, 297 of 299
transcripts carry the identical second `2026-01-07 18:13:39` — not 297
conversations ending together, but one `cp` and its shadow. Trusting those
stamps produced names like `dec-16-25-through-jan-7-26`, inventing a
three-week conversation out of a filesystem event.

Counting files per stamp does not catch this on its own, because a
conversation and its sidechains honestly do share a last message: a hundred
files on one stamp can be perfectly truthful. What separates the two cases is
a second witness. Where a file's session is in the prompt history, roughly
when it ended is already known; a stamp sitting a day or more past that is
recording something that happened *to* the file rather than *in* it. One such
disproof condemns the stamp for every file sharing it, because one event
wrote them all.

The payoff is larger than the avoided error. Those files had been named for
the copy's date and nothing else — a folder of `jan-7-26_agent-1` through
`jan-7-26_agent-266`. Twenty-six of them are in the prompt history, and are
now recoverable to the days they were actually held.

### Why a one-shot tool is the right shape here

Issue 020 retired an earlier one-shot migrator because the exporter
re-derives names on every run and simply overruled it. That reasoning does
not reach these files: the exporter iterates over session logs, and these
have none, so it will never revisit them. The migration is stable precisely
where the exporter is absent — and the one group the exporter *can* still
reach is the one group this tool refuses to touch.

### Only one group cannot be dated twice

A file with prompt history takes BOTH of its ends from there, and its own
timestamp is not consulted at all. The end is therefore the last prompt
rather than the assistant's closing reply, which lands afterwards and is
recorded nowhere in the history. Measured across the archive, that choice
moves the calendar day for one file in sixty-eight — `jun-21-26.md`, whose
final reply arrived after midnight — and five further files already took the
prompt date because it was the later of the two.

One file's end date is a small price for what it buys. A count of
milliseconds since the epoch names an instant outright rather than
describing a clock reading, so nothing about these verdicts depends on the
current state of the file being judged. They can be re-decided at any time,
before or after the repair, with the same result — no note required, and no
harm from one being lost, or from a file moving between folders.

### The remaining group cannot be dated twice

For the 99 files with nothing but their own timestamp, correcting it means
converting it twice over, and that operation has no way of telling whether it
has already been applied: given an already-correct time it subtracts the
offset again. Measured on a real file, an evening conversation walks `02:49`
-> `19:49` (correct) -> `12:49` -> `05:49`, and eventually across midnight,
renaming itself into the wrong day as it goes. Nothing inside a transcript
distinguishes a corrected timestamp from an uncorrected one.

So each folder gets a `.timezone-repaired` note once its files are in place,
and folders holding one are skipped. The note sits beside the transcripts
rather than in one central ledger, because restoring a folder from a snapshot
taken before the repair also removes its note - and such a folder does need
repairing again.

#### Why the prompt history cannot supply an idempotency test for the rest

The obvious objection is that the prompt history counts from an absolute
instant, so why is anything derived from it repeatable-unsafe? Because it
only supplies the START. A conversation closes with the assistant's reply,
which lands after the last prompt and is therefore not in the history at
all, so the END still comes from the file's own stamp.

That suggests a test: a conversation cannot have ended before its last
prompt, so if inverting the stamp puts the end earlier than the last prompt,
the stamp must already have been corrected. Measured across the 168 sessions
that still have both a log and prompt history, the gap between the last
prompt and the last message runs:

| measure | value |
| --- | --- |
| median | 9.9 min |
| 90th percentile | 133 min |
| 99th percentile | 45 h |
| maximum | 61.7 h |
| sessions with a gap of 7 h or more | 9 of 168 |

So the test fails. Nine sessions in 168 would be read as already-repaired and
silently left uncorrected, which is the class of quiet wrong answer this
whole ticket exists to avoid. Re-derive with the gap measurement alongside
the other checks before revisiting this.

The same measurement is what settled the question above in the other
direction. If the gap between the last prompt and the last message is too
unreliable to *test* with, it is also — at a median of ten minutes — too
small to be worth *keeping*, which is why the history group now takes its end
from the last prompt and gains repeatability by doing so.

It would not help the stamp-only group in any case: those files have no
absolute witness at all, only a corrupted one, and nothing distinguishes a
corrupted value from a clean one. For them out-of-band state is not a
workaround but the only available answer.

Noticed in passing: 3 of the 168 have a *negative* gap, a prompt recorded
after the log's last message. That is the "ends with an unanswered user
message" case the exporter already warns about (issue 020), showing up
independently in the timing data.

### What the first real run taught

The run was attempted and stopped in its first folder, which is worth
recording in full because both faults were in the half of the tool that had
no tests.

**An array expansion that is not what it looks like.** The guarded form
`${array[@]+"${array[@]}"}`, which safely expands a possibly-empty array,
does not have a working equivalent for indices: in `${!array[@]+...}` the
leading `!` means *indirect expansion* - look up the variable named by this
value - so bash read a list of fifty-five filenames as one variable name and
refused it. The run aborted after parking that folder's files under temporary
names and before moving them to their real ones. Nothing was lost; the
contents and timestamps were intact under predictable names, and `--recover`
reversed it exactly. An arithmetic loop over a count replaces it.

**A false test as the last thing a loop body runs.** Under `pipefail`, a
`while` loop hands its pipeline the status of the last command its body ran.
A body ending in `[ -e marker ] && printf` therefore reports failure whenever
the final folder has no marker, which aborted the report when counting zero
repaired folders. An `if` returns zero and does not.

Both are the same underlying mistake: the planner had tests from the first
commit and the part that moves files did not, so the only way to exercise it
was against the live archive. The search roots are now overridable by
environment precisely so a fixture tree can stand in for it, and
`tests/test-transcript-repair-apply.sh` covers the renames landing, the
timestamps written, the chain where one file wants the name its neighbour is
giving up, a second run being a no-op, and the recovery path.

## Suggested implementation steps

0. `backup-transcript-corpus` — snapshot the whole corpus first, and verify
   the snapshot by reading it back rather than by trusting an exit code. The
   transcripts are the only surviving record of most of these conversations,
   and the modification times are themselves evidence, so the snapshot
   records each one as a number in the manifest as well as leaving it to the
   archive. Numbered zero because it precedes the decision to proceed.

1. `libs/conversation-parser.lua` — correct the instant builder to parse the
   trailing `Z` as UTC, and the date reducer to render in local time. Replace
   the comment defending the old UTC choice so the next reader is not told
   the superseded reasoning is still in force.

   One trap inside the correction, which cost a wrong first attempt: standard
   Lua has no `timegm`, so the offset must be measured by converting twice and
   taking the gap. A UTC breakdown reports no daylight saving, and handing
   that field straight back forces the second conversion to the standard
   offset while the first had guessed the daylight one. The measured gap is
   then an hour short — correct all winter, wrong all summer. The field has to
   be cleared so both passes guess alike.

2. `tests/test_conversation-parser-timezone.lua` — drive the parser over
   fixtures in the small hours UTC and assert the local dates and the exact
   instants, in two different zones and across both daylight-saving
   boundaries. The absence of such a test is why the fault survived: the two
   halves agreed with each other, so only an absolute reference exposes them.

3. `libs/transcript-repair-plan.lua` — decide what every archived transcript
   should be called and stamped. Owns the tier reasoning, the disproof of
   flattened stamps, span ordering, and collision slots. Emits a plan and
   changes nothing.

4. `repair-transcript-timezone` — carry the plan out. Finds the folders,
   supplies each file's stored stamp (Lua cannot ask the filesystem for one),
   renames through `git mv` where tracked, restamps, and commits per
   repository against a transcript-only pathspec. Renames pass through a
   temporary name so a cycle of files swapping names cannot clobber.

5. `tests/test-transcript-repair-plan.sh` — run the planner over a fixture
   folder holding one file of each evidence kind, including a disproved stamp,
   and assert the tier and the name it picks for each.

5b. `tests/test-transcript-repair-apply.sh` — run the whole tool over a
   fixture tree and assert on the filesystem afterwards. This is the test
   whose absence let both of the faults above reach a real run.

5c. Naming is decided in two passes over a folder rather than one. When every
   file slides back a day, the name each wants is usually held by its
   neighbour, who is sliding too; a single pass sees the neighbour still in
   place and pushes the file to `_agent-1`, a suffix that means *sidechain*
   to every reader of this archive. The first pass works out what each file
   deserves and therefore which names are being given up; only then can the
   second hand them out.

6. Run order matters: this tool first, `rederive-transcripts --write` second.
   The exporter is the naming authority and is idempotent, so it settles last
   and claims whatever slots remain.

7. One commit per repository, transcripts only. Several repositories holding
   transcripts have unrelated work in progress; staging is restricted by
   pathspec so that work is neither committed nor disturbed.

## Related files

- `backup-conversations`, `libs/conversation-parser.lua` (producer; the
  parser now exports its UTC-to-instant helper so the repair tool corrects
  dates by the very same reasoning rather than keeping a second copy)
- `libs/transcript-discovery.sh` — naming rulebook; takes a plain
  `YYYY-MM-DD` and is timezone-clean, so it needs no change
- `libs/transcript-repair-plan.lua` (decides), `repair-transcript-timezone`
  (acts), `rederive-transcripts` (rebuilds the group with surviving logs)
- `~/.claude/history.jsonl` — the prompt history
- `backup-transcript-corpus` — the snapshot taken before any of this runs
- `tests/test_conversation-parser-timezone.lua`,
  `tests/test-transcript-repair-plan.sh`
- `README-backup-conversations.md` (docs)

## Notes / carried-over data

- The header marker is reliable: across the repo, every real transcript starts
  with `# Conversation Summary: `, and no derived or hand-written `.md` file in
  a transcript folder does.
- `Generated on:` inside a file is NOT a usable date — a bulk regeneration
  rewrote it to the regen time on many files. (2026-08-20: now enforced rather
  than merely recorded — the exporter treats the line as volatile, compares
  transcripts with it excluded, and leaves a file alone when it is the only
  difference; see issue 020, item 4.)
- Any count of this corpus must start from the real mount point `/mnt/mtwo`.
  `/home/ritz/programming` is a symlink to `/mnt/mtwo/programming`, and a sweep
  that walks both counts every file twice (issue 024 records this being got
  wrong once already).
- Agent sidechains do not appear in the prompt history, which records user
  prompts only. A sidechain's dates come from its own log or from its mtime.
- A transcript folder whose files all share one mtime would mean a bulk copy
  had flattened the stamps, leaving the third tier nothing to invert. Checked
  across the corpus: no folder is in that state. Files that do share an mtime
  are sidechains of one conversation, which legitimately share a last message.

## What was kept, and what was retired

The migration was carried out once and the archive is correct, so the tools
built only to carry it out were removed afterwards rather than left lying
around pretending to be part of the system. They are one commit deep and
recoverable by name:

    git show af27794e -- scripts/repair-transcript-timezone

Retired: `repair-transcript-timezone` and its `.info.md`,
`libs/transcript-repair-plan.lua` and its `.info.md`,
`tests/test-transcript-repair-plan.sh`, `tests/test-transcript-repair-apply.sh`,
and the 60 `.timezone-repaired` notes they dropped in the transcript folders.
The notes existed to stop the repair running twice; with no repair to run,
nothing reads them and their instruction had no tool behind it.

Kept, and not to be removed:

- **the correction itself**, in `libs/conversation-parser.lua`
- **`tests/test_conversation-parser-timezone.lua`** — the correction converts
  a time and converts it back, which reads like pointless double work and
  invites being "simplified" into the single call that caused all this. That
  simplification would pass unnoticed for months. This test fails on it
  immediately, and is the reason the fault cannot quietly return.
- **`backup-transcript-corpus`** — nothing to do with timezones. Taking a
  verified snapshot before doing something irreversible to the archive is a
  standing need.
- **the depth fix in `rederive-transcripts`**, which was two levels too
  shallow to see a project that had a live session log all along.

Anything here that needs doing again starts by recovering the tool from the
commit above, which is also where to read what it did.

## Open questions

- The transcripts in the preserved project keep names taken from a copy's
  date. Twenty-six of them could be dated from the prompt history if the
  folder's consistency were ever judged less important than its accuracy.
  Left open deliberately rather than closed - though acting on it now means
  recovering the retired tool from the commit named above first.
- The day-wide window for disbelieving a stamp is a judgement, not a
  measurement. Nothing in the corpus now sits near the boundary, but nothing
  checks that either. Should the tool report its closest call, so the window
  can be revisited on evidence rather than re-argued?
- 55 files in transcript folders carry no conversation-id header and are not
  transcripts at all. They have never been examined as a group. What are they?

### Settled

- **Worktrees are excluded, permanently.** Measured rather than assumed: of
  the 442 conversations held inside worktree transcript folders, all 442 also
  exist outside one. Nothing lives only there, so excluding them loses
  nothing and avoids staging the same rename through two views of one
  repository.
- **Folders outside version control are repaired anyway.** Ten transcript
  folders sit in directories that are not git repositories. The repair is
  correct whether or not it can be recorded, so it is applied; the only
  consequence is that those changes have no undo.
- **The tooling is committed alongside the transcripts** rather than ahead of
  them. Each rename is a line or two, so the change and its consequences can
  be read together on one screen.
