# Issue #025: Capture subagent session logs

## Current Behavior

Subagent conversations — the side conversations a session spawns when it
delegates work to a helper agent — are exported alongside the conversation
that spawned them, in both of Claude Code's storage layouts.

### Where Claude Code keeps them

Subagent logs used to sit loose in the project's session folder as
`agent-*.jsonl`. Since mid-2025 they are written one level down, in a folder
named after the parent session:

```
~/.claude/projects/<project>/<parent-session-uuid>/subagents/agent-<hash>.jsonl
~/.claude/projects/<project>/<parent-session-uuid>/subagents/agent-<hash>.meta.json
```

The `.meta.json` beside each log records what kind of helper it was (a
general-purpose agent, a fork, ...), the one-line description it was given,
and how deep in the spawning tree it sat. The exporter does not read it yet
(see Open Questions).

For roughly seven months the exporter looked only in the old place, found
nothing, and said nothing; the error-swallowing that hid this is covered by
issue 034.

### How the exporter finds them

`backup-conversations` has two ways of choosing what to export (issue 034):

- **After every reply (the Stop hook)** it exports the conversation Claude Code
  names, followed by every log in that conversation's `subagents/` folder.
- **By hand (a sweep)** it exports every main conversation in the project's
  session folder first, then every helper log in both layouts — loose
  `agent-*.jsonl` files, and `*/subagents/agent-*.jsonl`. The sweep prints how
  many of each it found, so a future layout change shows up as a surprising
  "0 helper-agent log(s)" instead of as silence.

The order is deliberate: the naming rulebook (`libs/transcript-discovery.sh`)
hands the bare date name to the first claimant of a date span and numbered
`_agent-N` slots to later ones, and main conversations are meant to hold the
bare names.

### Forked helpers

A forked helper inherits its parent's whole conversation instead of starting
from a fresh prompt. Its log therefore opens with a `fork-context-ref` record
pointing back at the parent, and its orders arrive in an unusual shape: as a
text block riding along with the answer to the parent's spawning call (a tool
result). The parser skips any message that opens with a tool result, so a
fork's transcript used to be a header and nothing else — the orders were
skipped, and with no user turn ever opened, every reply after them was too.

`libs/conversation-parser.lua` now recognises a fork log by its
`fork-context-ref` record, and reads the text blocks of the first tool-result
message in a fork as the request. Ordinary logs keep the old rule, so no
existing transcript changes shape. The harness's fixed fork preamble
(`<fork-boilerplate>`) is dropped like the other harness envelopes: it is
identical in every fork and written by neither speaker.

### What a helper's transcript contains

The helper's instructions, every piece of prose it wrote, and its final
message. A helper's full report travels back to its parent through a tool
call, which the parser drops like every tool call; the report is kept in the
parent's transcript, where it arrived as a message.

### How a helper's transcript is named

Built and tested on 2026-09-23 as described under Intended Behavior: helpers
are named `<task words>-<date>.md`, exported before their parent, and the
parent's "helper finished" line links to the helper's file. Tried against a
real session (the one that drafted the RGPL) in a scratch folder: its three
helpers came out as `draft-the-rgpl-license-sep-23-26.md`,
`human-vs-machine-work-ratio-sep-23-26.md` and
`3d-shapes-gif-generator-sep-23-26.md`, and all five "finished" lines in the
parent linked to them.

Helper transcripts already in the projects' folders keep their old
date-numbered names (`sep-22-26_agent-7.md`) until their conversation is
exported again — by the Stop hook when that session next replies, or by the
archive-wide rebuild, `rederive-transcripts --write`, which re-runs the
exporter over every project with surviving logs. Its read-only report now
has a line "Helper transcripts to be renamed after their task", counting
helpers whose log survives but whose name is still date-only (the owner asked
on 2026-09-24 that the renaming live in that sweep). A helper whose log is
gone has lost its description too and keeps its old name.

The same day, `rederive-transcripts` was found to spell session folders the
old way (slashes to dashes only), so it reported every project with a dot in
its path — `/mnt/mtwo/.claude/claude-code`, `/mnt/mtwo/.dominions6` and its
mods — as having no logs, and `--write` skipped them. It now uses the same
rule as the exporter.

The rebuild was run on 2026-09-26, after a verified snapshot of the whole
archive (`backup-transcript-corpus`, kept under
`/home/ritz/ai/transcript-snapshots/`): 53 projects, 256 transcripts written,
no failures. It left 20 helpers date-named, all in the Claude Code program
folder, because that project's sessions are split between two session
folders — `-mnt-mtwo-programs-claude-code` from before it was moved on
2026-09-22 and linked back, and `-mnt-mtwo--claude-claude-code` since — and
the sweep, which knows only the resolved path, found the newer one alone. A
hand run of the exporter under the old spelling
(`backup-conversations /mnt/mtwo/programs/claude-code`) renamed them. See
open question 6.

Open questions 2, 4, 5 and 6 below are still unanswered, so the issue is in
progress.

## Intended Behavior

Capture them (decided September 2026: the owner confirmed the gap was a real
loss and asked for it fixed). Every helper conversation reaches the project's
`llm-transcripts/` folder on the same Stop hook that saves its parent, and a
search that stops finding helpers where helpers exist says so.

### Helpers are named after their task (decided 2026-09-23)

The owner asked that a helper's transcript be titled with the one-line
description it was spawned with, followed by the date:

```
Agent "Draft the RGPL license"  ->  draft-the-rgpl-license-sep-22-26.md
```

- The words come from the `.meta.json` beside the helper's log (its
  `description` field, a string). Lowercased; every run of characters that is
  not a letter or digit becomes one dash; leading and trailing dashes dropped.
- The date part is the same date-span token a main conversation gets
  (`sep-22-26`, or `sep-22-26-through-sep-23-26`), placed LAST. The rulebook
  already reads dates from the end of a name
  (`transcript_basename_start_ymd`, written in anticipation of exactly this
  shape), so the storyline library and everything else that orders
  transcripts by date keeps working unchanged.
- Two helpers with the same description on the same day take the usual
  numbered slots: `draft-the-rgpl-license-sep-22-26_agent-1.md`.
- A helper whose `.meta.json` is missing, unreadable, or has no description is
  an export error for that helper, not a quiet fall back to a date-only name.
  Every one of the 147 helper logs on the machine on 2026-09-23 had one.
- Helpers no longer compete with main conversations for bare date names, so
  the `_agent-N` suffix goes back to meaning only "a second claimant of this
  name" — this settles the first open question below.
- Helper transcripts already on disk under their old date-only names are
  re-placed automatically on their next export: the claimed file's base no
  longer matches the wanted base, which is the existing "span grew" path.

### Main conversations keep date-only names (decided 2026-09-26)

Considered and declined: naming main conversations after the session title
Claude Code generates. That title is made once, from the first message, and
the owner's sessions are long and change purpose more than once, so a title
would describe only the opening. Helpers are different: each is spawned for
one task and its description stays true for its whole life.

### The parent's line names the helper's file (decided 2026-09-23)

The line in the parent's transcript that reports a helper finishing ends with
a link to that helper's transcript:

```
*[background task] Agent "Draft the RGPL license" finished — [draft-the-rgpl-license-sep-22-26.md](draft-the-rgpl-license-sep-22-26.md)*
```

The harness's notification carries a task id (a string such as
`a112f69cc1a1ad9eb`); a helper's log is `agent-<that id>.jsonl`, and its
transcript's header line is `# Conversation Summary: agent-<that id>`. So:

- The exporter saves helpers BEFORE their parent (reversing the old order,
  which only existed to keep bare date names for main conversations — no
  longer needed now that helpers have their own names).
- Before parsing a main conversation, the exporter writes a small table of
  "helper id, tab, transcript filename" lines — one per helper transcript in
  the folder, read from headers — to the RAM scratch tier, and passes its
  path to the parser through the environment variable
  `TRANSCRIPT_HELPER_NAMES`.
- The parser, meeting a notification whose task id is in the table, appends
  the link. A notification whose id is NOT in the table is left as it was:
  background shell commands also notify, and they have no transcript. A
  helper that finished but has no transcript (it never spoke) is the same
  case — its log produced no file, so there is nothing to link to.

## Suggested Implementation Steps

1. Extend the search to the nested layout, keeping main-conversations-first
   ordering (`backup-conversations`: the helper-listing routines for one
   session and for a whole sweep).
2. Report the counts the sweep found.
3. Teach the parser the fork shape (`libs/conversation-parser.lua`: pre-pass
   three, the fork exception in the user-message branch, and the
   `fork-boilerplate` removal in the envelope splitter).
4. Name helpers after their task: a routine in `backup-conversations` that
   reads the description out of the `.meta.json` and turns it into dashed
   words, used in place of the bare date base when the log is a helper.
5. Save helpers before their parent in both the Stop-hook mode and the sweep.
6. Build the helper-name table before each main conversation's parse and
   hand its path to the parser; teach the envelope splitter to keep the task
   id with each note, and the note renderer to append the link.
7. Test: a helper's file is named `<words>-<date>.md`; the parent's note links
   to it; a notification for an unknown id is unchanged; a helper with no
   `.meta.json` fails its export with a message; an old date-named helper
   transcript is re-placed. Update `tests/test-commit-own-changes.sh`'s
   fixture names only if the change breaks them.
8. Rename the existing archive through the sweep: `rederive-transcripts`
   counts date-named helpers in its report and renames them on `--write`
   (by running the exporter); its session-folder spelling matches the
   exporter's.
9. Test with fixtures in both shapes:
   `tests/test-backup-conversations-sessions.sh` (a plain helper, a fork, the
   ordering, the counts). The older suites — `tests/test-transcript-export-guards.sh`,
   `tests/test-transcript-wrapping.sh`, and the parser suites
   `tests/test_conversation-parser-*.lua` — must keep passing unchanged.

## Related Documents and Tools

- `backup-conversations` — the exporter.
- `libs/conversation-parser.lua` — reads one log, writes one transcript.
- `libs/transcript-discovery.sh` — owns the collision-suffix rules the helper
  naming depends on.
- `issues/034-export-only-the-session-that-stopped.md` — the Stop-hook mode
  that exports one session and its helpers, and the end of silent failures.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — the exporter is the sole naming authority; nothing here changes that.
- `issues/018-date-range-transcript-naming.md` — date-span naming and its
  collision behaviour.
- `issues/024-backfill-existing-transcript-corpus.md` — the surviving helper
  logs across all projects are exported by each project's next sweep, or by
  its Stop hook the next time one of those sessions is resumed.

## Metadata

- **Status**: reopened 2026-09-23 for descriptive helper names and the
  parent's link to them. The capture itself is complete.
- **Complexity**: Low for the search; the fork shape needed a parser change.
- **Dependencies**: none.

## Success Criteria

- A project whose sessions spawned helpers produces transcripts for them.
- A fork's transcript carries its orders and its replies.
- A sweep that finds no helper logs reports the count.
- A reader can tell a helper transcript from a same-day collision without
  opening the file — a helper's name starts with its task's words.
- The parent's line for a finished helper links to that helper's transcript.

## Open Questions

1. **Should the `_agent-N` suffix be split?** Settled 2026-09-23 by naming
   helpers after their task: helpers no longer need the suffix, so it keeps
   one meaning.
2. **Should a helper's transcript name its parent?** The description is now
   in the filename. The parent is not: a helper transcript still does not say
   which conversation spawned it, though the parent now links to the helper.
   A second header line ("Helper for <parent>") would close the loop in the
   other direction. Not asked for; open.
3. **Should the Stop hook also report a zero?** The sweep prints its helper
   count; the hook exports one session and does not, because a session with no
   helpers is normal. A layout change would still surface on the next sweep.
4. **Should the description words be shortened?** Descriptions are asked to
   be 3–5 words, so names stay short, but nothing enforces it. Not capped;
   a very long description makes a very long filename.
5. **Should a same-description collision use `_agent-N`?** Two helpers both
   described "Draft the RGPL license" on one day get
   `…-sep-22-26.md` and `…-sep-22-26_agent-1.md`. The word "agent" there
   now reads oddly (both are agents). Left as the rulebook's existing suffix
   to avoid touching the tools that parse it.
6. **Should the sweep find every session folder a project has ever had?** A
   project that was moved and linked back has sessions under both spellings
   of its path, and `rederive-transcripts` visits only the resolved one. Each
   session log records the folder it ran in (the `cwd` field of its records,
   a string), so the sweep could list session folders first and read which
   project each belongs to, instead of guessing folders from project paths.
