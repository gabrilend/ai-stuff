# Issue #019: Preserve AskUserQuestion exchanges in transcripts

## Current Behavior

The conversation parser (`libs/conversation-parser.lua`) turns a session's JSONL into a
readable `.md` by keeping every user prompt and every block of assistant prose, and dropping
all tool calls and tool results.

`AskUserQuestion` is caught in that net. It is itself a **tool call** (a `tool_use` block in an
assistant message), and its answer comes back as a **tool result** (a `user` message whose
content carries a `tool_use_id`). The parser skips the assistant `tool_use` block (it only keeps
`text` blocks) and skips the user tool-result (the `tool_use_id` marks it as a result). So the
entire exchange vanishes from the transcript:

- the question(s) asked and every option offered,
- which option the user chose,
- and any free-text correction the user typed instead of picking an option.

### Current Issues
- These Q&A moments are frequently where the actual design decisions are made — exactly the
  content most worth keeping. Losing them makes a transcript read as if choices appeared from
  nowhere.
- A downstream summarizer (delta-version issue 056) cannot summarize a decision it never sees.

## Intended Behavior

When the parser meets an `AskUserQuestion` tool call, it renders the exchange as readable
markdown inside the assistant response where it was asked, instead of discarding it. For each
question it shows the header, the question text, every option (label + description), and the
outcome — the option the user selected, or, when the answer matches no option, the user's typed
correction verbatim.

Everything else is unchanged; only `AskUserQuestion` tool calls are rescued. All other tool
calls and results are still dropped.

## Data shapes (ground truth, from a real session)

- **tool_use** (assistant content item):
  `{ type="tool_use", id="toolu_…", name="AskUserQuestion",
     input={ questions=[ { question, header, multiSelect, options=[{label, description}, …] }, … ] } }`
- **tool_result** (user content item): `{ type="tool_result", tool_use_id="toolu_…", content=<string> }`
  where the string is:
  `Your questions have been answered: "Q1"="A1", "Q2"="A2", … . You can now continue with these answers in mind.`
  and each `Ai` is either a chosen option `label` or the user's free-text answer.

Because the exact question texts are known from the `tool_use`, each answer is extracted by
anchoring on `"<question>"="` in the result string and reading to the next question's anchor (or
the trailing sentence) — robust against answers that contain commas or quotes.

## Suggested Implementation Steps

1. **Pre-pass, one lookup table.** After all messages are loaded in `parse_conversation`, scan
   for user tool-results and build `tool_use_id -> result_string`. Cheap; one extra pass.
2. **Formatter.** Add a `format_askuserquestion(input, result_string)` helper (vimfold, near
   `format_content`) that returns the markdown block: per question, the header + question, a
   bulleted option list, and a `→ Selected:`/`→ Answered:` line. If no result is paired (session
   ended before answering), emit `→ (no answer recorded)`.
3. **Loop branch.** In the assistant-message loop, alongside the existing "keep `text` blocks",
   add: if a block is `type=="tool_use"` and `name=="AskUserQuestion"`, append the formatted block
   to `assistant_responses` so it flushes in place with the surrounding prose.
4. **Selected vs. corrected.** An answer that exactly equals an option `label` renders as
   `Selected: <label>`; anything else (free text, or a multi-select join) renders as
   `Answered: <value>` so a correction is visibly distinct from a menu pick.

## Related Documents
- `libs/conversation-parser.lua` — the file changed.
- `issues/018-date-range-transcript-naming.md` — the naming/identity work these transcripts feed.
- delta-version `issues/056-recursive-transcript-summarization.md` — the summarizer that consumes
  these transcripts; preserving decisions here makes its summaries faithful.

## Metadata
- **Priority**: Medium-High
- **Complexity**: Low
- **Dependencies**: None (parser-local change).
- **Impact**: Design decisions made via AskUserQuestion now survive into every transcript and can
  be summarized. No effect on existing prompt/prose extraction.

## Success Criteria
- Re-parsing a session that used AskUserQuestion produces a Q&A block showing each question, its
  options, and the selected option or typed correction.
- A free-text correction is shown verbatim and marked distinctly from a chosen option.
- Sessions without AskUserQuestion are byte-for-byte unchanged.
- Other tool calls/results remain dropped.
