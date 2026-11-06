# claudemd-revise.lua

The first slice of issue 040: guidelines for a CLAUDE.md, learned from
events that keep happening. Each one is applied only when you approve it.

```
claudemd-revise.lua event correction "Use vimfolds in every function."
claudemd-revise.lua suggest            # events seen 3+ times -> proposals, worded by the model
claudemd-revise.lua list               # pending proposals, each with why
claudemd-revise.lua approve P001 --target=$HOME/.claude/CLAUDE.md
claudemd-revise.lua rollback P001 --target=$HOME/.claude/CLAUDE.md
claudemd-revise.lua history
```

- **Events** come in three kinds: correction, instruction and convention.
  Any script can record one with `event`. Two events count as the same when
  their wording matches, ignoring case, spacing and a final full stop.
- **`suggest`** sends each event seen at least `--min` times (default 3)
  that has no proposal yet to the local model (`libs/llama-chat-client.lua`).
  The model words it as one guideline, which is filed as a pending
  proposal. A reply that isn't one `- ` line, or is over 200 characters, is
  reported and not filed.
- **`propose`** files a guideline directly, so scripts can ask for one.
- **`approve`** is the only command that writes a CLAUDE.md, and only to the
  file named by `--target`. There is no default target. It backs the file
  up, then adds the guideline under `## Learned conventions` (creating the
  section at the end if it is missing). It refuses a guideline the file
  already holds.
- **`rollback`** restores the backup, but only while the file's checksum still
  matches the one recorded at approval, so a hand edit made since is never
  thrown away.
- **State** (events, proposals, backups, `audit.tsv`) lives in
  `~/.local/share/claudemd-revisions`, outside any repository, because events
  can hold anything said in a session. `--state=DIR` moves it.

Tested by `test-claudemd-revise.sh` (31 checks) against the stand-in model
in `libs/stand-in-model/`.
