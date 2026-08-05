# Issue #023: Record model provenance as narrative beats

## Current Behavior

Which model produced a given reply is not recorded anywhere in an exported
transcript. A reader cannot tell whether a passage was written by Opus, by
Fable, or by anything else, and cannot tell where a session changed from one
to another.

This is the one piece of harness envelope traffic that plainly matters to the
narrative — knowing which model was working, and when that changed, is part of
understanding how a project developed. Issue #022 classifies the rest of the
envelope traffic and deliberately leaves this case out, because the obvious
way to capture it is the wrong way.

### Why the slash command is the wrong source

The `/model` command is the most frequently used slash command in the corpus,
appearing 25 times across surviving session logs. Every one of those
invocations records this shape:

```
<command-name>/model</command-name>
<command-message>model</command-message>
<command-args></command-args>
```

The arguments are empty, in all 25 cases, because `/model` opens an
interactive picker rather than taking its choice on the command line. So the
command records **that the picker was opened** and never **what was chosen**.
Keeping the command and dropping everything else would preserve precisely the
half that carries no information.

The command's output does carry the answer, in a `<local-command-stdout>`
block:

```
Set model to ^[[1mOpus 5 (1M context)^[[22m and saved as your default for new sessions
```

That string is usable but poor as a source. It is prose composed for a
terminal, wrapped in the ANSI escape sequences issue #021 exists to remove,
and its wording varies — observed forms include `Set model to …`, `Set model
to … (default)`, `Set model to … with max …`, and `Kept model as …`.

That last form is the decisive objection. **`Kept model as Opus 5 (1M context)
(default)`** is what the log records when the picker was opened and nothing
was changed. A reader of the command alone would report a model switch that
never happened.

### The better source already exists

Every assistant message in a session log carries the model that produced it,
as a plain identifier string, in the message's `model` field. This is not an
intention or a confirmation — it is a record of what actually served the reply.

Counting that field across the four surviving delta-version session logs:

| model identifier | assistant messages |
| --- | --- |
| `claude-opus-5` | 410 |
| `claude-fable-5` | 354 |

The field is present on every assistant message, so a change of model is
detectable as a change in that field between one message and the next, with no
dependence on a slash command having been used at all.

That last point matters beyond convenience. A model can change without any
`/model` invocation: through a command-line flag at launch, through a changed
default in the settings file between sessions, or through a fallback when a
model is unavailable. Reading the per-message field catches all of those. The
slash command catches none of them.

## Intended Behavior

A transcript records which model was working, and marks the points where that
changed, as short narrative beats placed inline where the change occurred.

The record is derived from the per-message model field — the trace the system
left behind — rather than from the command the user typed. The `/model`
command itself and its confirmation output are treated as housekeeping and
dropped by issue #022's classification, because the fact they were reaching
for is captured more reliably elsewhere.

## Data shapes (ground truth, from real sessions)

| field | type | contents |
| --- | --- | --- |
| the assistant message's `model` field | string | a bare model identifier, e.g. `claude-opus-5`, `claude-fable-5` |

The identifier is the API model name, not the display name the picker shows.
The picker's confirmation says `Opus 5 (1M context)`; the message field says
`claude-opus-5`. The two are not the same string, and the context-window
variant visible in the display name is not visible in the message field.

## Suggested Implementation Steps

1. **Track the model across the message loop.** As assistant messages are
   walked, hold the model identifier seen on the previous assistant message.
   A differing identifier on the current message is a switch.
2. **Emit a beat at the switch point, not a header everywhere.** The transcript
   should not annotate every reply with its model — that is noise at the scale
   of hundreds of messages. One short line where the model changes carries the
   same information and reads as narrative.
3. **Record the opening model once.** The first assistant message establishes
   which model the session began with. Without that, a transcript with no
   switches records nothing at all, and a transcript with one switch records
   only the destination.
4. **Do not translate identifiers into display names.** Mapping
   `claude-opus-5` to `Opus 5` requires a table that goes stale every time a
   model is released, and the failure is silent — an unmapped identifier
   either vanishes or renders as a blank. The bare identifier is unambiguous
   and needs no maintenance.
5. **Leave sidechain sessions alone unless they differ.** A subagent runs its
   own model, recorded the same way in its own log. Whether a subagent's model
   deserves a beat depends on whether subagent transcripts are captured at all,
   which is a separate unresolved matter noted in Open Questions.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the file changed.
- `backup-conversations` — the Stop-hook exporter that drives the parser.
- `issues/022-classify-harness-envelope-traffic.md` — drops the `/model`
  command and its confirmation on the strength of this issue capturing the
  same fact better. The two should be decided together.
- `issues/021-strip-terminal-escape-codes-from-transcripts.md` — the `/model`
  confirmation string is the main carrier of the escape sequences that issue
  removes; reading the message field instead avoids the problem rather than
  cleaning it up.
- `issues/024-backfill-existing-transcript-corpus.md` — model beats can only
  be added to transcripts whose session logs still exist.

## Metadata

- **Priority**: unset — see Open Questions.
- **Complexity**: Low. One tracked string and a comparison in a loop already
  being walked.
- **Dependencies**: Should be decided alongside #022, which drops the source
  this issue replaces.
- **Impact**: Transcripts record which model did the work. Only derivable for
  sessions whose logs survive; already-exported transcripts cannot gain this
  retroactively without their logs.

## Success Criteria

- A transcript states which model the session opened with.
- Each point where the model changed is marked once, inline, at that point.
- A session that used one model throughout contains exactly one such
  statement.
- No model beat is derived from a `/model` invocation, so a picker that was
  opened and dismissed produces no beat.

## Open Questions

1. **Do we want to implement this at all?** No information is currently being
   lost — the model was simply never recorded. This adds something new to the
   transcripts rather than repairing something broken, and a reader who does
   not care which model wrote a passage gains nothing from it.
2. **Should the beat carry anything besides the model identifier?** The
   confirmation strings in the corpus mention a context-window variant and, in
   one case, an effort level. Neither appears in the per-message model field.
   Capturing them means reading the confirmation prose after all, for a
   fraction of the information.
3. **Is a switch mid-session interesting, or only the session's model?** If
   the goal is a reader understanding how the project was designed, "this
   session was Opus" may be all that matters, and marking three switches
   inside one session may be more precision than the narrative wants.
4. **What should a beat look like on the page?** It is neither a user turn nor
   an assistant turn, and the transcript currently has only those two kinds of
   heading. Issue #022 introduces a third kind for compaction recaps; whether
   model beats reuse that mechanism or need their own is unresolved.
5. **Do subagent transcripts need this too?** Subagent session logs are
   currently not captured at all — Claude Code moved them from the project
   folder into a nested `subagents/` directory that the exporter's file search
   does not reach, and no subagent transcript has been written since that
   change. That gap is unrecorded in any issue file and needs one, independent
   of this issue.
6. **Should the opening model be stated even when it never changes?** Stating
   it always is consistent and lets a reader know without hunting. Stating it
   only when something changes keeps quiet sessions quiet. These are different
   documents and the choice is a matter of taste.
