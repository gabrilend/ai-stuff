# claudemd-revise.lua

The first slice of issue 040: guidelines for a CLAUDE.md, learned from
events that keep happening. Each one is applied only when you approve it.

```
claudemd-revise.lua event correction "Use vimfolds in every function."
claudemd-revise.lua suggest            # events seen 3+ times -> proposals, worded by the model
claudemd-revise.lua list               # pending proposals, each with why
claudemd-revise.lua approve P001 --target=$HOME/.claude/CLAUDE.md
claudemd-revise.lua rollback P001 --target=$HOME/.claude/CLAUDE.md
claudemd-revise.lua history --id=P001     # or --action=approved, --since=2026-11-01
claudemd-revise.lua show P001             # its events, proposal and timeline
claudemd-revise.lua diff P001             # what its approval changed
claudemd-revise.lua report --since=2026-11-01
claudemd-revise.lua verify                # the audit trail's integrity checks
claudemd-revise.lua conflicts             # guidelines pulling against each other
claudemd-revise.lua prune --keep=100      # backup rotation: shows; add --yes to remove
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
- **Append-only files.** `events.tsv`, `proposals.tsv` and `audit.tsv`
  only ever get new lines. A proposal's status is its last status row on
  the audit trail (proposed, approved, rejected, rolled-back). Its row in
  `proposals.tsv` keeps the status it was filed with. Older state folders,
  whose `proposals.tsv` was rewritten in place, still read correctly, and
  `verify` checks that their statuses agree.
- **State** (events, proposals, backups, `audit.tsv`) lives in
  `~/.local/share/claudemd-revisions`, outside any repository, because events
  can hold anything said in a session. `--state=DIR` moves it.

**The audit trail (issue 040d):**
- **`history`** prints the trail. It can be narrowed to one proposal, one
  action, or the rows on or after a date.
- **`show`** traces one guideline from the events it was worded from,
  through its proposal, to every audit row about it.
- **`diff`** shows what an approval changed: the backup against the file
  the approval wrote. That file is rebuilt from the backup and checked
  against the checksum recorded at the time.
- **`report`** counts events by kind, proposals by status, and actions.
- **`verify`** checks the trail and exits 1 on any problem:
  - every row is whole;
  - rows are in date order;
  - each row names a known proposal;
  - each proposal's trail starts with its proposal;
  - no proposal is filed twice, and any status kept in `proposals.tsv`
    agrees with its last action;
  - every approval's backup is still there, or was removed by `prune`.

  A target edited since its approval is noted, but is not a problem.
- **`conflicts`** reports, and decides nothing:
  - approved guidelines in one file that share two or more topic words
    where one is a "don't" (never, not, avoid...) and the other is not;
  - corrections recorded since a guideline's approval that share two or
    more of its topic words;
  - approvals rolled back, and any guideline proposed again after.
- **`prune`** rotates the backups. It keeps the newest `--keep` (default 100,
  going by the date in each backup's name) and, however old, every backup a
  rollback still needs: the last approval of each proposal that is approved
  now. Without `--yes` it only lists what it would remove. Each removal is a
  `pruned` row on the audit trail, so `diff` says the backup was pruned
  rather than lost, and `verify` does not count it as a problem. Files in
  `backups/` not named as approvals name them (`ID-DATE-TIME.md`) are left
  alone.

Tested by `test-claudemd-revise.sh` (81 checks) against the stand-in model
in `libs/stand-in-model/`.
