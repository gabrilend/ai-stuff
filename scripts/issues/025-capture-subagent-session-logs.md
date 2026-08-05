# Issue #025: Subagent session logs are no longer captured

## Current Behavior

Subagent conversations — the sidechains a session spawns when it delegates
work — are not being exported. They have not been since Claude Code changed
where it stores them, and nothing reported the change.

### How the exporter looks for session logs

`backup-conversations` builds its work list by listing files in the project's
session-log directory under `~/.claude/projects/`. It does this in two passes,
deliberately ordered so that main conversations claim the plain date-based
filename and sidechains fall into the collision slots behind them:

1. every `*.jsonl` directly in the project directory, excluding names starting
   with `agent-`
2. every `agent-*.jsonl` directly in the project directory

Both passes look **only** in the project directory itself. Neither descends
into subdirectories.

### What Claude Code now does

Subagent logs used to sit flat in the project directory as `agent-*.jsonl`,
which is exactly what the second pass was written to find. They are now
written one level down, in a directory named after the parent session, under a
`subagents/` folder:

```
~/.claude/projects/<project>/<parent-session-uuid>/subagents/agent-<hash>.jsonl
```

Counting across all projects on disk:

| measure | count |
| --- | --- |
| flat `agent-*.jsonl` files the exporter can see | 0 |
| nested `subagents/*.jsonl` files it cannot see | 101 |
| most recent nested subagent log | 2026-07-29 |

The second pass now matches nothing, anywhere. Every subagent log in existence
is in the nested layout.

### How long this has been broken

The most recent transcript in the corpus whose header records a genuine
sidechain conversation id is
`delta-version/llm-transcripts/dec-21-25_agent-1.md`, whose first line reads
`# Conversation Summary: agent-a68961a`.

Transcripts with more recent dates do carry an `_agent-N` suffix in their
filenames, but that is misleading — see below. Checking their headers shows
plain conversation uuids, not sidechain ids. The newest examples,
`games/first-person-spellcraft/llm-transcripts/jul-21-26-through-jul-22-26_agent-1.md`
and `soren-ds/llm-transcripts/jul-2-26-through-jul-3-26_agent-1.md`, both hold
ordinary uuids.

### The overloaded suffix that hid it

The `_agent-N` suffix means two different things, and that is why the gap was
invisible from a directory listing.

The naming rulebook (`libs/transcript-discovery.sh`) hands out `_agent-1`,
`_agent-2`, and so on as **collision slots**: when a transcript's date-span
name is already taken, the next claimant gets a numbered suffix. Separately,
the ordering of the exporter's two passes was designed so that sidechains would
land in exactly those slots, which made "has an `_agent-N` suffix" and "is a
sidechain" the same thing in practice.

They stopped being the same thing when two ordinary conversations began sharing
a date span — a second session on the same day now takes `_agent-1` — and they
stopped being the same thing again when sidechains left the directory the
exporter searches. The suffix kept appearing, so nothing looked wrong.

### Consequence

Subagent logs are subject to the same retention deletion as any other session
log. Under the previous 30-day default, every subagent conversation older than
a month has already been deleted without ever being exported. The 101 currently
on disk are inside the retention window and are recoverable today; the
retention window is now 20 years (issue #024 records the setting), so nothing
further will be lost to deletion, but nothing already deleted comes back.

## Intended Behavior

Unresolved, because it depends on whether subagent conversations are wanted in
the corpus at all. Two coherent positions:

**Capture them.** The exporter's search descends into the nested layout, and
subagent conversations get transcripts as they did before the layout change.

**Do not.** Subagent transcripts are mostly tool-driven work with little of the
design reasoning the corpus exists to preserve. If they were never valued, the
loss is not a loss, and the correct fix is to delete the now-dead second pass
rather than extend it — leaving a program that claims to look for something it
does not want.

What is not acceptable is the present state: a search that looks for sidechains
in a place they no longer exist, finds nothing, and reports nothing.

## Suggested Implementation Steps

These apply only under the capture position.

1. **Extend the search to the nested layout**, keeping the two-pass ordering
   intact so that main conversations still claim plain names and sidechains
   still fall behind them.
2. **Decide how a sidechain's parent is recorded.** The nested path names the
   parent session, which the flat layout never did. That relationship is
   information the corpus has never had, and the transcript directory is flat,
   so it has nowhere obvious to go. See Open Questions.
3. **Disambiguate the suffix.** With sidechains and same-day collisions both
   landing in `_agent-N`, a reader cannot tell which is which without opening
   the file and reading its header. Whichever meaning keeps the suffix, the
   other needs a different one.
4. **Report what the search found.** A pass that finds zero sidechain logs
   across an entire corpus is the signal that would have caught this in July.
   Per project convention a silent absence is a fallback, and a fallback is a
   warning.

## Related Documents and Tools

- `backup-conversations` — the file changed; the two-pass search is at the top
  of its transcript-writing routine.
- `libs/transcript-discovery.sh` — owns the collision-suffix rules that the
  sidechain naming depends on.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — establishes the exporter as sole naming authority, which constrains any
  change to how these files are named.
- `issues/018-date-range-transcript-naming.md` — where the date-span naming and
  its collision behaviour were designed.
- `issues/024-backfill-existing-transcript-corpus.md` — the 101 surviving
  subagent logs are a backfill opportunity that exists only while they survive.

## Metadata

- **Priority**: unset — see Open Questions.
- **Complexity**: Low to extend the search. The naming disambiguation is the
  part with judgement in it.
- **Dependencies**: None. Independent of #019, #021, #022, #023.
- **Impact**: Under the capture position, 101 subagent conversations become
  exportable. Under the other position, a dead code path is removed and the
  program stops implying it captures something it does not.

## Success Criteria

Under the capture position:

- A project whose sessions spawned subagents produces transcripts for them.
- A reader can tell a sidechain transcript from a same-day collision without
  opening the file.
- A run that finds no sidechain logs where sidechain logs exist reports it.

Under the other position:

- The second search pass is removed rather than left matching nothing.

## Open Questions

1. **Do we want subagent transcripts at all?** This is the question the whole
   issue turns on. They are bulky and mostly mechanical, and the corpus exists
   to show how the project was designed rather than how each delegated task was
   executed. If they were never wanted, the honest fix is deletion of the dead
   path, not repair.
2. **If they are wanted, should the parent-child relationship be visible?** The
   nested source layout records which session spawned which subagent. The
   transcript directory is flat and has never carried that relationship. Making
   it visible means either encoding it in filenames or introducing
   subdirectories, and the second would change assumptions the naming rulebook
   and every consumer of it currently make.
3. **Which meaning keeps the `_agent-N` suffix?** It currently serves both
   "sidechain" and "second file claiming this date span". Splitting them is
   necessary under the capture position and needs a name for whichever meaning
   moves.
4. **What is the actual invariant that broke here?** Two readings: that the
   suffix was overloaded from the start and got away with it while sidechains
   were the only source of same-day collisions, or that "one conversation per
   project per day" quietly stopped being true and took the suffix's meaning
   with it. Which reading is right decides whether the fix is a new suffix or a
   different naming scheme.
5. **Should the 101 surviving logs be exported retroactively?** They are inside
   the retention window now, so this is possible today and will remain possible
   under the 20-year window. It is the same class of decision as issue #024 and
   should probably be decided with it.
6. **How would a future layout change be noticed?** This one produced no error
   for roughly seven months. Whatever answers question 4 should also answer
   what would have made this visible in July.
