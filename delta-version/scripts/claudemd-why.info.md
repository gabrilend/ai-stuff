# claudemd-why.lua

Issue 040g, its first slice: why a guideline exists, found in the
conversations that led to it.

```
claudemd-why.lua "Use vimfolds in every function." --no-model   # the evidence only
claudemd-why.lua P001                        # a proposal from claudemd-revise.lua
claudemd-why.lua P001 --write                # saved under ~/.local/share/claudemd-revisions/analysis/
claudemd-why.lua "..." --transcripts=delta-version/llm-transcripts --most=3
```

**The evidence.** It reads the saved conversations in every `*/llm-transcripts/`
folder of the monorepo, or in the folders named with `--transcripts`. It
looks for exchanges holding most of the guideline's key words: at least
half of them, and at least two when there are two. A key word is four
letters or more, and not a common word.

- The context pack at the top of each transcript is skipped, since it holds
  copies of CLAUDE.md and the like. A guideline is never found just because
  it was already written down.
- The best `--most` exchanges (default 5) are quoted around the line that
  talks about the guideline, and each is cited by file and line.

**The record.** The local model (`libs/llama-chat-client.lua`) drafts a
decision record from the excerpts, with four sections: decision moment,
context, alternatives considered, and reasoning. It cites the excerpts as
[1], [2] and so on, and says "not in the excerpts" where they show nothing.
`--no-model` prints the evidence alone.

**Read-only sources, write-only records.** Transcripts are never changed.
`--write` saves the record as a new file in `analysis/` in
claudemd-revise's state, outside every repository, since excerpts can hold
anything said in a session. It never replaces a record.

Tested by `test-claudemd-why.sh` (22 checks) against the stand-in model in
`libs/stand-in-model/`.
