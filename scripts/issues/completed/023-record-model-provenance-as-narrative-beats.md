# Issue #023: Record model provenance as narrative beats

**Status: shipped.** The header lists every model that served a reply, in
first-appearance order, and a change of model is marked inline in the margin
where it happened. A session that used one model throughout names it once in
the header and carries no inline marks. The harness placeholder model, under
which Claude Code files its own notices, is excluded from the list and its
messages are rendered as notices rather than as prose the model wrote.

The reasoning below was checked against the corpus before implementing and
held up; two of its counts were stale and have been corrected in place.

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
appearing 64 times across 32 surviving session logs. Every one of those
invocations records this shape:

```
<command-name>/model</command-name>
<command-message>model</command-message>
<command-args></command-args>
```

The arguments are empty, in every one of them, because `/model` opens an
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

That last form is the decisive objection, and the corpus settles it with a
number. **`Kept model as Opus 5 (1M context) (default)`** is what the log
records when the picker was opened and nothing was changed, and that is what
happened in 13 of the 64 invocations — one in five. A reader deriving a switch
from the command alone would report a model change that never happened, in a
fifth of all cases.

Re-derive both counts by searching the session logs under the sessions root
for `<command-name>/model</command-name>` and for `Kept model as`; the ratio
is the thing that matters and it will drift as the corpus grows.

### The better source already exists

Every assistant message in a session log carries the model that produced it,
as a plain identifier string, in the message's `model` field. This is not an
intention or a confirmation — it is a record of what actually served the reply.

Counting that field across every surviving session log on the machine:

| model identifier | assistant messages |
| --- | --- |
| `claude-opus-5` | 49,302 |
| `claude-opus-4-8` | 8,647 |
| `claude-fable-5` | 4,166 |
| `claude-fable-5-1` | 1,225 |
| `claude-haiku-4-5-20251001` | 791 |

Five distinct models across roughly sixty-four thousand replies. Four of the
five are also named somewhere in a `/model` confirmation. The fifth is not:
`claude-haiku-4-5` wrote 791 replies and appears in no confirmation anywhere
in the corpus, because nobody ever picked it. It is the model subagents are
delegated to, so it arrives without a slash command by construction.

That single row is the argument in miniature. The picker records choices; the
per-message field records what actually ran. Where the two disagree, the
second is the one telling the truth.

The field is present on every assistant message, so a change of model is
detectable as a change in that field between one message and the next, with no
dependence on a slash command having been used at all.

That last point matters beyond convenience. A model can change without any
`/model` invocation: through a command-line flag at launch, through a changed
default in the settings file between sessions, or through a fallback when a
model is unavailable. Reading the per-message field catches all of those. The
slash command catches none of them.

## Intended Behavior

A transcript records which model was working in two places, because two
different readers ask the question. The file header lists every model the
session used, answering "what wrote this?" once, from outside. Short narrative
beats then mark inline, in place, each point where the model changed —
answering "did the writer just change?" for a reader already deep in the prose.

The record is derived from the per-message model field — the trace the system
left behind — rather than from the command the user typed.

This issue originally asked for the `/model` command and its confirmation to
be dropped entirely by issue #022, on the grounds that the fact they reach for
is captured more reliably here. The developer has since asked for the opposite:
the command should survive into the transcript, rendered as one readable line
naming the command and what it did. Those are not in conflict once the two
jobs are told apart.

- **The confirmation line is a record of an action the user took.** It belongs
  where it happened, in the user's own sequence, reading as `/model — set
  Fable 5.1` or `/model — kept Opus 5 (1M context)`. The verb matters: the
  log distinguishes a change from a dismissal, and 13 of 64 invocations were
  dismissals. Issue #022 owns this rendering.
- **The model beat is a record of what actually served each reply.** It is
  derived from the per-message field, catches the changes no picker saw, and
  is the only source that can. This issue owns that.

The two will sometimes sit near each other and say compatible things in
different vocabularies — the display name `Fable 5.1` beside the identifier
`claude-fable-5-1`. That redundancy is worth its cost: one is what the user
did, the other is what the machine did, and a transcript that shows only the
first cannot explain a reply written by a model nobody picked.

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
3. **List every model used in the file header.** Collect the distinct
   identifiers in a first pass and write them beside the generated-on line, in
   the order they first appear. Without this a transcript with no switches
   records nothing at all, and a transcript with one switch records only the
   destination. This is also what makes a single-model session carry no inline
   beats while still naming its model.
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
- `issues/022-classify-harness-envelope-traffic.md` — renders the `/model`
  command and its confirmation as one readable line in the user sequence. It
  no longer drops them; see Intended Behavior for why both records are kept.
- `issues/025-capture-subagent-session-logs.md` — subagent logs are not
  reaching the exporter at all, which is why `claude-haiku-4-5` shows 791
  replies in the logs and appears in no transcript.
- `issues/021-strip-terminal-escape-codes-from-transcripts.md` — the `/model`
  confirmation string is the main carrier of the escape sequences that issue
  removes; reading the message field instead avoids the problem rather than
  cleaning it up.
- `issues/024-backfill-existing-transcript-corpus.md` — model beats can only
  be added to transcripts whose session logs still exist.

## Metadata

- **Priority**: confirmed by the developer; all six open questions are now
  answered and the design is settled.
- **Complexity**: Low. One tracked string and a comparison in a loop already
  being walked.
- **Dependencies**: Should be decided alongside #022, which drops the source
  this issue replaces.
- **Impact**: Transcripts record which model did the work. Only derivable for
  sessions whose logs survive; already-exported transcripts cannot gain this
  retroactively without their logs.

## Success Criteria

- The file header lists every model the session used, in first-appearance
  order.
- Each point where the model changed is marked once, inline, at that point.
- A session that used one model throughout names it in the header and carries
  no inline beats at all.
- No model beat is derived from a `/model` invocation, so a picker that was
  opened and dismissed produces no beat — while the dismissal itself still
  appears, as a rendered command line, per issue #022.

## Open Questions

1. ~~**Do we want to implement this at all?**~~ **Answered: yes.** Asked and
   confirmed by the developer. The reasoning that made it worth doing is the
   Haiku row in the table above — 791 replies from a model that appears in no
   confirmation, so the thing being added is not decoration but the only
   record of who wrote a measurable slice of the corpus.
2. ~~**Should the beat carry anything besides the model identifier?**~~
   **Answered: no, it carries the bare identifier.** The context-window
   variant and the effort level live only in the confirmation prose, and that
   prose is now rendered in place by issue #022 rather than discarded. The
   information is therefore already in the transcript, at the point the user
   caused it, and does not need reading a second time through a worse source.
3. ~~**Is a switch mid-session interesting, or only the session's model?**~~
   **Answered: both, and they are different readers.** See question 4.
4. ~~**What should a beat look like on the page?**~~ **Answered: two places,
   not one.** The developer asked for the models listed in the file header
   *and* marked inline wherever they change — "so we can feel the difference
   in character."

   That phrase is the specification. The header answers a question asked from
   outside the file — what wrote this? — and is read once. The inline beat
   answers a question asked from inside it, mid-paragraph, when the prose
   changes temperature and the reader wants to know whether the writer
   changed with it. A header alone cannot do the second job, because by the
   time the difference is felt the header is a thousand lines behind.

   The beat is right-aligned with the assistant's prose, since it is a fact
   about the machine rather than about the user, and carries the bare
   identifier per question 2.
5. ~~**Do subagent transcripts need this too?**~~ **Partly answered.** The gap
   this question noticed now has its own issue file, #025: Claude Code moved
   subagent logs into a nested `subagents/` directory the exporter never
   descends into, so no sidechain has been exported since. What remains open
   is the narrower question — once those logs are reaching the exporter again,
   does a subagent's model deserve a beat of its own, or is it enough that the
   sidechain is a separate file? Cannot be settled until #025 ships.
6. ~~**Should the opening model be stated even when it never changes?**~~
   **Answered: yes, in the header, always.** The header lists every model the
   session used, so a single-model session lists one and a reader learns it
   without hunting. Inline beats then mark only changes, so a session that
   never changed model carries no inline beats at all and stays quiet. The
   two-place answer in question 4 dissolves this question rather than choosing
   a side of it.
