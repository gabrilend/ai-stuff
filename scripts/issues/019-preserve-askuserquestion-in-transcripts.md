# Issue #019: Preserve AskUserQuestion exchanges in transcripts

**Status: in progress.** The question side shipped and works. The answer side
ships broken — it recovers answers by re-parsing an English sentence whose
format has since changed, so the user's own typed words are silently dropped.
This file has been updated to describe the real data available, which was not
known when the first implementation was written.

## Current Behavior

The conversation parser (`libs/conversation-parser.lua`) turns a session's
JSONL into a readable `.md` by keeping every user prompt and every block of
assistant prose, and dropping all tool calls and tool results.

`AskUserQuestion` is the one deliberate exception. When the parser meets that
tool call it renders the exchange in place instead of discarding it. **The
question side of this works correctly**: every question, its header, and every
option's label and description survive into the transcript.

**The answer side does not work.** Answers are recovered by string-searching
the tool-result *prose sentence* for the question text followed by `="`, then
reading forward to a guessed boundary. That sentence's format has grown since
this issue was first written, and the recovery routine has two stale
assumptions, each of which fails silently rather than erroring.

### Failure 1 — an unquoted answer is read as no answer at all

The routine anchors on `"<question text>"="`, requiring a double-quote
immediately after the equals sign. The harness emits three answer shapes:

| shape in the result sentence | when it occurs | anchor matches? |
| --- | --- | --- |
| `"Q"="Some Label"` | an option was picked, with no preview | yes |
| `"Q"="Some Label" selected preview:\n…` | an option with a preview was picked | yes, but over-reads |
| `"Q"=(no option selected) notes: …` | **free text typed, no option picked** | **no** |

The third shape has no quote after the equals sign, so the anchor is never
found, the answer is recorded as absent, and the transcript prints
`→ (no answer recorded)`. This is the highest-value content in the whole
exchange — the user's own reasoning, in their own words — and it is the one
case that is thrown away.

Two real losses, both from delta-version sessions, both permanent unless the
corpus is re-derived (issue #024):

- `llm-transcripts/jul-25-26-through-jul-26-26.md`, first question: a note
  about keeping the monorepo, wanting one branch per project, and deferring
  git machinery. Rendered as `(no answer recorded)`.
- The same file, later question: a note that worktrees did not work out and
  should be removed entirely. Rendered as `(no answer recorded)`.

### Failure 2 — the end boundary is never found, so one answer eats the rest

Having found an answer's start, the routine bounds its end two ways in order:

1. Search for `", "` followed by the *next* question's anchor. This assumes
   the current answer ends with a double-quote. It does not when the answer
   ends with a preview block or with `(no option selected) notes: …`.
2. Failing that, search for the sentence `". You can now continue`. The
   harness no longer emits this. It now closes with `Read the answers
   carefully — they may request clarification, changes, or that you not
   proceed — and follow what they actually say.`

Both misses mean the answer runs to the end of the string. In
`jul-25-26-through-jul-26-26.md` a single `→ Answered:` line swallows a stray
quote, the words ` selected preview:`, the entire multi-line preview, the
whole following question **and its answer**, and the harness's trailing
instruction sentence. The swallowed question then renders again below,
appearing twice.

### Failure 3 — the selected-versus-typed distinction collapses

An answer is shown as `Selected:` only when it exactly equals an option label.
Because failure 2 glues trailing text onto the captured answer, that equality
test fails and a straightforward menu pick is mislabelled as free text.

### Measured blast radius

Counted across every transcript under `ai-stuff/*/llm-transcripts/` and
`ai-stuff/*/*/llm-transcripts/`:

| symptom | transcripts affected |
| --- | --- |
| `(no answer recorded)` where a note exists | 3 |
| leaked ` selected preview:` and preview body | 2 |
| leaked `Read the answers carefully` instruction | 1 |

These counts are low only because the surviving session logs cover a 30-day
window. Older breakage is already frozen into transcripts whose logs were
culled and cannot be recounted.

### Root cause

This is a **parse of a render**. The harness held structured data, formatted
it into a sentence for the model to read, and this parser tried to un-format
the sentence. The presentation layer is free to change without notice, and it
did — notes, previews, and a new closing sentence were added. Every failure
above is downstream of reading the presentation layer instead of the data
layer. The data layer exists and was simply not known about; see below.

## The data that actually exists (ground truth, verified from real sessions)

The prose sentence never needed to be parsed. Each user JSONL line carrying an
`AskUserQuestion` result has a sibling top-level field, `toolUseResult`, that
holds the whole exchange already structured. Its composition, down to
primitives:

| field | type | contents |
| --- | --- | --- |
| `toolUseResult.questions` | array of objects | one entry per question asked |
| `…questions[i].question` | string | the question text; **doubles as the lookup key below** |
| `…questions[i].header` | string | the short chip label, e.g. `"Repo shape"` |
| `…questions[i].multiSelect` | boolean | whether several options could be chosen |
| `…questions[i].options` | array of objects | each with `label` (string), `description` (string), and optional `preview` (string) |
| `toolUseResult.answers` | object used as a dictionary | key: question text (string) → value: chosen option label (string), or the literal sentinel `"(notes only)"` |
| `toolUseResult.annotations` | object used as a dictionary | key: question text (string) → value: an object with optional `notes` (string) and optional `preview` (string) |

Both dictionaries are keyed by the exact same question text that appears in the
questions array, so recovering an answer is two dictionary lookups per
question. No punctuation, no boundaries, no guessing.

The `"(notes only)"` value is the harness's own marker for *the user declined
the menu and wrote something instead*. It is a distinct value from any option
label, which means the outcome is a **three-state** value, not two:

| state | detected by | render as |
| --- | --- | --- |
| picked an option | `answers[q]` equals some option's `label` | the pick |
| picked an option and annotated it | as above, plus `annotations[q].notes` present | the pick, plus the note |
| declined the menu, wrote a note | `answers[q]` equals `"(notes only)"` | the declination, plus the note |

The original implementation guessed at a two-state model (`Selected:` versus
`Answered:`) because the three-state truth was not visible in the prose.

### Known gap in this data description

No answered **multi-select** question exists in any surviving session log, so
how several picks are joined into the `answers` dictionary value — one
delimited string, or an array — is unverified. This is deliberately left
unresolved rather than guessed at; see Open Questions.

## Intended Behavior

When the parser meets an `AskUserQuestion` tool call, it renders the exchange
as readable markdown inside the assistant response where it was asked. For
each question it shows the header, the question text, every option's label and
description, and the outcome in the three-state form above — with the user's
typed note reproduced verbatim whenever one exists, regardless of whether an
option was also picked.

Everything else is unchanged; only `AskUserQuestion` tool calls are rescued.
All other tool calls and results are still dropped.

## Suggested Implementation Steps

1. **Retire the prose parser.** The routine that recovers answers by anchoring
   on `"<question>"="` inside the result sentence is deleted, not repaired.
   Repairing it would re-create the same class of breakage on the next format
   change.
2. **Read the structured record instead.** The existing pre-pass that maps a
   tool-call id to its result should map to the whole `toolUseResult` object
   rather than to the result string, so the formatter receives the three
   dictionaries described above.
3. **Render three states, not two.** Drive the outcome line from
   `answers[question]`, treating the sentinel `"(notes only)"` as its own case.
   Reproduce `annotations[question].notes` verbatim whenever present, on its
   own line, visually distinct from an option label so the user's words are
   never mistakable for a menu pick.
4. **Do not reproduce preview text.** A preview's content is already visible in
   the option list. Inlining it also feeds multi-line text through the
   80-column wrapper, which turns every newline into a blank line — the cause
   of the twenty-line preview blob currently in the July 25 transcript. Noting
   that a preview existed is sufficient. (Open question: confirm this is
   wanted.)
5. **Fail loudly, not quietly.** If `toolUseResult` is absent, or a question
   text is missing from the `answers` dictionary, print a warning line naming
   the conversation id rather than emitting `(no answer recorded)` as if the
   absence were a fact about the conversation. Per project convention, a
   fallback is a warning and a warning is an error.
6. **Test with a fixture, not live data.** Follow the pattern established by
   `tests/test-transcript-export-guards.sh`: a fixture JSONL containing one
   picked option, one picked-plus-notes, and one notes-only answer, asserting
   all three render distinctly and that the user's note text appears verbatim.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the file changed.
- `backup-conversations` — the Stop-hook exporter that drives the parser.
- `issues/018-date-range-transcript-naming.md` — the naming/identity work these
  transcripts feed.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — establishes the exporter as sole naming authority; this issue changes only
  content, never names.
- `issues/021-strip-terminal-escape-codes-from-transcripts.md` — a second
  content-fidelity defect found in the same investigation.
- `issues/024-backfill-existing-transcript-corpus.md` — decides whether already
  written transcripts get re-derived once this is fixed.
- delta-version `issues/056-recursive-transcript-summarization.md` — the
  summarizer that consumes these transcripts.

## Metadata

- **Priority**: unset — see Open Questions, the first of which is whether to
  do this at all.
- **Complexity**: Low. The structured record removes the hard part; this is
  smaller than the implementation it replaces.
- **Dependencies**: None for new transcripts. Repairing already-written ones
  depends on issue #024.
- **Impact**: Design decisions made through the question tool survive into
  transcripts with the user's own reasoning attached. No effect on prompt or
  prose extraction.

## Success Criteria

- A question answered with notes and no option pick renders the note verbatim,
  and never renders `(no answer recorded)`.
- A question answered with an option pick renders that pick, and any
  accompanying note alongside it.
- No answer line contains text belonging to another question, a preview body,
  or harness instructions.
- A missing or malformed structured record produces a printed warning naming
  the conversation, not a silent `(no answer recorded)`.
- Sessions without `AskUserQuestion` are byte-for-byte unchanged.

## Open Questions

1. **Do we want to implement this at all?** The transcripts are readable
   today and the loss is confined to question exchanges. Fixing it means
   touching the one program that is the sole naming authority for the whole
   corpus, which carries its own risk. Not doing it is a legitimate answer.
2. **Should preview text be reproduced in the answer line, omitted entirely,
   or noted as "a preview was shown" without its body?** Step 4 assumes
   omission. That is an assumption, not a decision.
3. **How should a multi-select answer be joined and rendered?** The data shape
   is unverified because no answered multi-select exists in any surviving log.
   Should the reader handle both a delimited string and an array and warn on
   anything else, or should this wait until a real example is captured?
4. **When the user both picks an option and writes a note, which leads?** The
   pick is the decision; the note is usually the reasoning or a caveat on it.
   Order affects how the transcript reads as narrative.
5. **Should a question that was asked but never answered — session ended
   mid-question — render at all?** It is a real event, but it is also
   indistinguishable in the output from the current bug, which argues for
   marking it differently or omitting it.
6. **Is `"(notes only)"` a stable contract or an incidental string?** It is the
   harness's internal marker and could change exactly the way the prose
   sentence changed. Should the reader treat any value that matches no option
   label as a declination, rather than matching the sentinel literally?
