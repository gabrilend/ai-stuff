# roadmap-from-history.lua

The second slice of issue 051 (051b). It reads a project's development
phases from its git history and drafts a roadmap.

```
roadmap-from-history.lua soren-ds --no-model          # phases from git alone, plain names
roadmap-from-history.lua soren-ds                     # ... named by the local model
roadmap-from-history.lua soren-ds --json              # the same as JSON
roadmap-from-history.lua soren-ds --write             # saved as docs/roadmap.md and .json if neither exists
roadmap-from-history.lua soren-ds --out=/tmp/r.md     # ... or saved elsewhere
roadmap-from-history.lua soren-ds --phases=4 --gap-days=30
```

**The phases come from git alone.** Every commit touching the folder is
read, merges left out. A new phase starts at a break, scored from:

| Signal | Weight |
|--------|--------|
| a quiet spell of `--gap-days` (default 14) or more before the commit | 3 |
| the commit before made a version or a release (`v1.2`, "release") | 3 |
| the commit before updated the README | 1 |
| the commit is large (20 files or 1,000 lines) | 1 |
| the commit is the first to touch a folder | 1 |

A break needs a score of 2. The strongest breaks are kept, up to
`--phases` (default 8) phases, with no phase shorter than three commits.

**The names come from the model** (`libs/llama-chat-client.lua`), one call
per phase, given its dates, the folders it changed most and its commit
subjects. The first line of the answer is the name; the rest, if any, is
the description. A `<think>` block is dropped. With no model reachable, or
`--no-model`, or where the model fails for a phase, the phase keeps a plain
name ("Work in src/ and docs/") and a plain description (its dates, folders,
and first and last subjects). The roadmap says which way each phase was
named.

Each phase also lists its five largest commits, in order, and why it
starts where it does.

**Nothing is replaced.** `--write` and `--out` refuse a path that already
exists; `--write` checks both files before writing either.

Tested by `test-roadmap-from-history.sh` (37 checks) against the stand-in
model in `libs/stand-in-model/`.
