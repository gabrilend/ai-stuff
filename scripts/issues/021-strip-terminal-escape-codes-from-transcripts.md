# Issue #021: Strip terminal escape codes from exported transcripts

## Current Behavior

Some of the text Claude Code writes into a session's JSONL was composed for a
terminal, not for a file. The clearest case is the output of a slash command,
which the harness records verbatim inside a `<local-command-stdout>` wrapper.
That output carries ANSI escape sequences — the byte `0x1B` (escape) followed
by `[`, some digits, and a letter — which a terminal interprets as "turn bold
on", "set foreground colour", "reset", and so on.

The conversation parser (`libs/conversation-parser.lua`) copies this text
through unchanged. The escape bytes end up as literal control characters
inside the exported `.md` file.

Example, as it currently sits in a transcript (the `ESC` bytes shown here as
`^[`, since they are invisible):

```
<local-command-stdout>Set model to ^[[1mOpus 5 (1M context)^[[22m and saved as
your default for new sessions</local-command-stdout>
```

### Why this has gone unnoticed

The transcripts are usually read in a terminal, where these bytes do exactly
what they were written to do: the model name renders in bold and nothing looks
wrong. The corruption only becomes visible somewhere that treats the file as
text rather than as a terminal stream — an editor, a diff, a web page, a
search index, or another program parsing the markdown.

That matters here specifically, because the project intends to serve all
documentation as styled HTML pages (`docs/HTML/` per project convention). An
escape byte in a markdown file becomes visible garbage the moment it is
rendered as HTML rather than printed to a TTY.

### Measured blast radius

Counted across every transcript under `ai-stuff/*/llm-transcripts/` and
`ai-stuff/*/*/llm-transcripts/`:

| measure | value |
| --- | --- |
| transcripts containing at least one escape sequence | 42 |
| total transcripts in the corpus | 484 |
| share of corpus affected | roughly 9% |

This is the widest-spread content defect found in the transcript corpus —
wider than the question-answer losses in issue #019, though far less severe,
since nothing is lost here, only polluted.

The sequences actually present, by frequency:

| sequence | meaning | occurrences |
| --- | --- | --- |
| `ESC[22m` | bold off | 61 |
| `ESC[2m` | dim on | 44 |
| `ESC[39m` | default foreground colour | 31 |
| `ESC[38;5;<n>m` | 256-colour foreground | 38 across four colours |
| `ESC[1m` | bold on | 17 |
| `ESC[0m` | reset all attributes | 10 |
| `ESC[0;32m`, `ESC[1;33m` | green, bold yellow | 10 |

All of them are Select Graphic Rendition sequences — the styling subset. No
cursor-movement, screen-clearing, or query sequences appear in the corpus,
which means the removal is purely subtractive: there is no case where an
escape sequence carries information that the surrounding plain text does not.

## Intended Behavior

Text extracted from a session log is stripped of ANSI escape sequences before
it is written to a transcript. The visible characters are preserved exactly;
only the control bytes are removed. A line that read as bold in a terminal
reads as plain text in the file, with no other change.

This is a content-fidelity fix and touches nothing about naming, identity, or
which messages are included — those remain governed by
`issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
and issue #022 respectively.

## Suggested Implementation Steps

1. **One stripping helper, applied at a single choke point.** Add a helper
   near the existing content formatter in `libs/conversation-parser.lua` that
   removes escape sequences from a string. Apply it inside the existing
   content-formatting path so every piece of extracted text passes through it
   once, rather than sprinkling calls at each call site — a new extraction
   path added later should inherit the behaviour without anyone remembering
   to.
2. **Match the general form, not the observed cases.** The corpus currently
   contains only styling sequences, but the pattern should cover the escape
   byte followed by `[`, any run of digits and semicolons, and a terminating
   letter. Matching only the sequences seen today would repeat the mistake
   issue #019 documents — writing a parser against a sample rather than a
   format.
3. **Strip only, never reinterpret.** Do not attempt to convert bold codes
   into markdown emphasis. The styling was chosen for a terminal by a program
   that had no idea this text would become a document, and inferring intent
   from it invents structure that was never meant.
4. **Test with a fixture.** Following `tests/test-transcript-export-guards.sh`,
   a fixture JSONL containing a slash-command output with bold and 256-colour
   sequences, asserting the exported markdown contains no `0x1B` byte and that
   every visible character survives in order.
5. **Add a corpus check.** A search for the escape byte across all
   `llm-transcripts/` directories should return nothing once the corpus is
   re-derived. Until issue #024 is decided, it will keep returning the 42
   already-written files, so the check is a report rather than a test.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the file changed.
- `backup-conversations` — the Stop-hook exporter that drives the parser.
- `issues/019-preserve-askuserquestion-in-transcripts.md` — the other
  content-fidelity defect found in the same investigation.
- `issues/022-classify-harness-envelope-traffic.md` — decides whether the
  `<local-command-stdout>` blocks that carry these sequences are kept at all.
  If they are dropped, this issue's blast radius shrinks but does not vanish,
  since escape sequences could appear in any preserved text.
- `issues/024-backfill-existing-transcript-corpus.md` — decides whether the 42
  already-polluted transcripts get re-derived.

## Metadata

- **Priority**: unset — see Open Questions.
- **Complexity**: Low. A single string transformation at one choke point, with
  no judgement calls in it.
- **Dependencies**: None. Independent of #019 and #022, though the order it is
  done in relative to #022 changes how much text it has to clean.
- **Impact**: Transcripts become valid plain text. No information is lost,
  because the removed bytes carry only presentation.

## Success Criteria

- No exported transcript contains the byte `0x1B`.
- Visible characters are preserved exactly, in order, with no substitutions.
- A transcript containing no escape sequences is byte-for-byte unchanged by
  the fix.

## Open Questions

1. **Do we want to implement this at all?** Read in a terminal, the affected
   transcripts look correct today. The defect only surfaces in an editor, a
   diff, or the planned HTML documentation pages. If the corpus is only ever
   read in a terminal, this is invisible and doing nothing is defensible.
2. **Should this be done before or after issue #022?** If #022 drops
   slash-command output entirely, most of the polluted text disappears on its
   own and this fix becomes a guard against future cases rather than a repair.
   Doing #021 first means cleaning text that may later be discarded.
3. **Is stripping the right verb, or should the escape sequences be
   preserved somewhere?** They record something real — that this line was
   styled, and how. Nothing currently wants that information, but the project
   treats the transcript corpus as a historical record, and this is the only
   issue here that deliberately destroys bytes rather than reorganising them.
4. **Should the stripping apply to user-typed text as well as harness output?**
   A user could paste terminal output containing escape sequences into a
   prompt. Removing them would be editing what the user said, which the
   project's append-only instincts argue against, but leaving them means the
   corpus check in step 5 can never reach zero.
