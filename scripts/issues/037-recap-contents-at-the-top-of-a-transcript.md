# Issue #037: Recap contents at the top of a transcript

## Current Behavior

When a person steps away from a conversation, Claude Code writes a short
recap of where things stand ("I've reviewed the README: I found stale
figures... Next, I need your answer on..."). It lands in the session log as a
record of its own:

| field     | type   | holds |
|-----------|--------|-------|
| `type`    | string | always `"system"` |
| `subtype` | string | `"away_summary"` for a recap |
| `timestamp` | string | ISO-8601 UTC instant it was written, e.g. `2026-09-23T22:40:45.243Z` |
| `content` | string | the recap's prose, always ending with the boilerplate `(disable recaps in /config)` |

A long session gathers several, each dated; read in order they are a
running summary of how the conversation went. 576 were on the machine on
2026-09-23 (recount with
`cat ~/.claude/projects/*/*.jsonl | grep -c '"subtype":"away_summary"'`).

Built on 2026-09-24 as described under Intended Behavior: the parser now
also reads `system` records of subtype `away_summary`, gathers the body in
memory, and writes the Contents list between the header lines and the first
rule. Tested by `tests/test_conversation-parser-recap-contents.lua` (12
checks) and tried on the real session that drafted the RGPL, which opened
with six recaps from 15:40 to 23:58. Before this, the parser read only `user`
and `assistant` records and every recap was dropped. Existing transcripts
gain their Contents list the next time they are exported. Open questions 1
and 2 are unanswered, so the issue is in progress.

Not to be confused with the **session recap** the parser already keeps: the
machine-written summary that opens a conversation continued after
compaction, which arrives in the user's seat and is rendered under
"Session Recap (written by the harness, not by either speaker)" (issue 022).

## Intended Behavior

A transcript whose log holds recaps opens with a contents list of them, in
the order they were written, directly under the header lines:

```
# Conversation Summary: 5723d726-...

Generated on: ...
Models: ...

## Contents

1. 2026-09-23 15:40, after Request 12 - I've reviewed the README: I found
   stale figures, lines worth rewording and a plan for a visual-style
   section with gifs, and I haven't edited anything yet. Next, I need your
   answer on whether the new algorism-backup folder counts as a project
   before I update the figures.
2. ...

--------------------------------------------------------------------------------
```

- **Time** is the recap's instant in local time, `YYYY-MM-DD HH:MM`, by the
  same UTC-to-local reasoning the filename dates use (the parser's timestamp
  routine).
- **Place** is the number of the last "User Request" heading written before
  the recap — a recap is written while the person is away, so it always
  follows a response. A recap before any request says "before Request 1".
  This is what lets a reader find the spot in the body, and what the HTML
  pages will later turn into a link (not part of this issue).
- **Text** is the whole recap — never shortened or cut (decided by the owner
  on 2026-09-26: the list exists so a reader can skim to where they want to
  read, and a cut recap loses the part that says where that is) — with the
  `(disable recaps in /config)` boilerplate removed: it is an instruction to the person at the keyboard, the same
  kind of harness furniture as the local-command caveat, which is also
  dropped.
- A log with no recaps gets no Contents section: an empty heading says
  nothing.
- Line 1 stays the `# Conversation Summary:` header, which the naming
  rulebook reads as the file's identity.

## Suggested Implementation Steps

1. In `libs/conversation-parser.lua`, send the body to an in-memory buffer
   instead of straight to the file, so the contents list — known only once
   the body has been walked — can be written above it. The header, then the
   contents, then the body, are written to the file at the end.
2. In the main walk over records, meet `system` records with subtype
   `away_summary` and note each one's time, place (the current request
   number minus one) and cleaned text.
3. Write the contents list between the header lines and the first rule,
   wrapped to the same 80-column measure as the rest of the transcript, with
   continuation lines indented under the entry's text.
4. Test in `tests/test_conversation-parser-recap-contents.lua`: a log with
   two recaps gives two numbered entries in order, with the right request
   numbers and local times, and without the boilerplate; a log with none
   gives no Contents heading; line 1 is still the header.
5. Existing parser suites and `tests/test-backup-conversations-sessions.sh`
   pass unchanged.

## Open Questions

1. **Should the recap also appear in the body, at the spot it happened?**
   The contents list says "after Request 12"; a marker line in the body
   there (the way background-task notices are shown) would make the spot
   findable by eye and give the future HTML link a target. It doubles the
   text. Not built until the owner says.
2. **Should the session's title head the contents?** Claude Code names each
   session once, from its first message, with a small model (a `ai-title`
   record, string field `aiTitle`); a name the person gives by renaming the
   session is a `custom-title` record and wins. The owner's sessions change
   purpose over their length, so the title describes only the opening; that
   is why it was declined as a filename (issue 025). Whether it still earns a
   line inside the transcript is unasked.
3. ~~The HTML reader drops the Contents list.~~ Settled 2026-09-26 by issue
   035: the shared reader in `scripts/transcript-site/` reads the list, and
   the page draws it as "How it went" at the top with each "after Request N"
   linking to the turn that follows. double-diaper-dungeon's own copy still
   drops it; its `libs/README-vendored.md` says so.

## Related Documents and Tools

- `libs/conversation-parser.lua` — reads one log, writes one transcript.
- `issues/completed/022-classify-harness-envelope-traffic.md` — the rule that
  harness-written text is shown as what it is, and the other kind of recap.
- `issues/025-capture-subagent-session-logs.md` — the same day's change that
  names helpers after their task.
- `README-backup-conversations.md` — describes the transcript's layout.

## Metadata

- **Status**: in progress (built and tested; open questions unanswered)
- **Complexity**: Low
- **Dependencies**: none
