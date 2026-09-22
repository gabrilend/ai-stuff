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

### The overloaded suffix

`_agent-N` still means two things: "a helper conversation" and "a second
conversation claiming the same date span". The header line
(`# Conversation Summary: agent-<hash>` for a helper, a uuid for a main
conversation) tells them apart without ambiguity; the filename alone does not.
This was left as it is — see Open Questions.

## Intended Behavior

Capture them (decided September 2026: the owner confirmed the gap was a real
loss and asked for it fixed). Every helper conversation reaches the project's
`llm-transcripts/` folder on the same Stop hook that saves its parent, and a
search that stops finding helpers where helpers exist says so.

## Suggested Implementation Steps

1. Extend the search to the nested layout, keeping main-conversations-first
   ordering (`backup-conversations`: the helper-listing routines for one
   session and for a whole sweep).
2. Report the counts the sweep found.
3. Teach the parser the fork shape (`libs/conversation-parser.lua`: pre-pass
   three, the fork exception in the user-message branch, and the
   `fork-boilerplate` removal in the envelope splitter).
4. Test with fixtures in both shapes:
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

- **Status**: complete. The open questions below refine the result; none of
  them block the capture itself.
- **Complexity**: Low for the search; the fork shape needed a parser change.
- **Dependencies**: none.

## Success Criteria

- A project whose sessions spawned helpers produces transcripts for them.
- A fork's transcript carries its orders and its replies.
- A sweep that finds no helper logs reports the count.
- A reader can tell a helper transcript from a same-day collision without
  opening the file — not met; see Open Questions.

## Open Questions

1. **Should the `_agent-N` suffix be split?** Helpers and same-day collisions
   still share it. The header tells them apart; the filename does not. Splitting
   means a second suffix (for example `_sub-N` for helpers), which changes the
   naming rulebook and every tool that reads names through it (the storyline
   library in delta-version, `rederive-transcripts`,
   `check-transcripts-are-filed-right`). Left unsplit until the owner decides it
   is worth that change.
2. **Should a helper's transcript name its parent and its description?** The
   `.meta.json` beside each log has the one-line description it was given and
   its type; the log's records carry the parent session id. One header line
   ("Helper for <parent> — <description>") would make a folder of helper
   transcripts readable without opening them. Other tools read only the first
   line of a transcript, so a second header line is believed safe.
3. **Should the Stop hook also report a zero?** The sweep prints its helper
   count; the hook exports one session and does not, because a session with no
   helpers is normal. A layout change would still surface on the next sweep.
