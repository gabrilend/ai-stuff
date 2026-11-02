# summarize-transcript.lua

Boils one conversation transcript down to a summary, a one-sentence title, a
file-name slug and a table-of-contents paragraph, with the local model.
Issue 056b. It changes no file; `apply-summary.sh` (056c) uses the result.

## How it works

1. **Split.** The header (`# Conversation Summary: ID`) is set aside. The
   body is cut into exchanges: a `### User Request N` and the
   `### Assistant Response N` parts that answer it. A file with no such
   headings is cut at blank lines.
2. **Slice (map).** Exchanges are packed in order into slices of at most
   `context - reserve - overhead` tokens, counted exactly by the server's
   `/tokenize`. A request is never read apart from its answer. An exchange
   bigger than a slice is cut between lines, and a single line bigger than a
   slice between words. The model summarises each slice
   (`Task: summarize-slice.`).
3. **Merge (reduce).** The slice summaries are packed the same way and merged
   (`Task: merge-summaries.`), level after level, until one is left. Each
   level's fan-in is logged (`reduce level 2: 8 -> 3`). If no two summaries
   fit in one slice, merging could never shrink them, so the run stops and
   says to raise `--context` or lower `--reserve`.
4. **Title and blurb.** Two more passes over the final summary. The title's
   first sentence is kept, without quotes or Markdown. The slug is that
   sentence in lowercase ASCII words joined by `-`, at most 60 characters, cut
   at a word boundary (`untitled-session` if nothing is left). The blurb is
   folded onto one line.

Every answer has any `<think>...</think>` block removed first (Qwen3 writes
one unless told not to).

## Usage

    summarize-transcript.lua TRANSCRIPT [--out=FILE] [--json] [--quiet]
                             [--context=N] [--reserve=N] [--overhead=N] [--plan]

| Option | Meaning |
|---|---|
| `--context=N` | the model's context in tokens; default 16384, the words-pdf server's `--ctx-size` |
| `--reserve=N` | tokens left for the answer; default 1024 |
| `--overhead=N` | tokens left for the instruction; default 512 |
| `--plan` | print the slices (exchanges and tokens of each) and stop; only `/tokenize` is called |
| `--out=FILE` | write the result to FILE instead of standard output |
| `--json` | JSON instead of the plain record |
| `--quiet` | no progress lines on standard error |

Exit status: 0 done; 1 the model failed, was unreachable or could not shrink
the summaries; 2 usage error, unreadable or empty transcript, or a budget
under 16 tokens.

## The plain record

    transcript-summary v1
    conversation: <id>
    source: <path>
    title: <one sentence>
    slug: <slug>
    slices: <N>
    levels: <reduce levels; 0 when one slice was enough>

    ## Blurb
    <one paragraph>

    ## Summary
    <the final summary>

## The model

Reached through `libs/llama-chat-client.lua`. `INFERENCE_CHAT_HOST` moves
it; the default is the words-pdf llama.cpp server. Temperature is the
client's 0.3.

## Tests

`test-summarize-transcript.sh [--dir MONOREPO]` runs every path against the
stand-in model (`libs/stand-in-model/`; no download, no real model), whose
`/tokenize` counts words so a small `--context` forces many slices. 40
checks:

- one slice and no merge;
- whole exchanges per slice (`--plan`);
- one merge level and several;
- an oversized exchange;
- summaries that cannot shrink;
- a `<think>` block;
- a model error;
- a long slug;
- `--out`, `--json`, and a file with no headings;
- usage errors;
- an unreachable model.
