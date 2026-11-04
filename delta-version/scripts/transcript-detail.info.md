# transcript-detail.lua

The first slice of issue 049 (049a): a conversation transcript at a chosen
level of detail.

```
transcript-detail.lua llm-transcripts/dec-10-25.md --detail=2
transcript-detail.lua llm-transcripts/dec-10-25.md --detail=1 --classes=dec-10-25.classes.tsv
transcript-detail.lua llm-transcripts/dec-10-25.md --detail=3 --report
```

The transcript is split at its `### User Request N` / `### Assistant
Response N` headings, or at every `### ` heading in other files. The local
model (`libs/llama-chat-client.lua`) gives each section one of five classes:

| Level | Keeps |
|-------|-------|
| 1 | ESSENTIAL: major decisions and outcomes |
| 2 | + IMPORTANT: key discussion and milestones |
| 3 | + USEFUL: supporting context |
| 4 | + VERBOSE: retries and long asides (only NOISE is dropped) |
| 5 | everything; the model is not asked |

- **Kept sections are the original text, word for word.** Each run of left-out
  sections becomes one line, such as `*[3 sections left out at detail level 1]*`.
- **Nothing is hidden by a failure.** A section the model cannot class (no
  answer, or an unclear one) is kept and counted as unclassed. If the model
  cannot be reached at all, everything is kept and the exit status is 1.
- **`--classes=FILE`** saves each section's class with a fingerprint of its
  text and reuses it while the text is unchanged. All four levels then cost
  one pass of the model, and an edited section is classed again.
- **The summary line** on stderr gives the sections kept, the characters kept,
  how many sections the model was asked about, and how many are unclassed.

Tested by `test-transcript-detail.sh` (30 checks) against the stand-in model
in `libs/stand-in-model/`.
