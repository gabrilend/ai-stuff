# history-kernel.lua

The first slice of issue 051 (051a). It reads what a project set out to
be from its first commits, and drafts its vision document.

```
history-kernel.lua soren-ds --json            # the facts only; no model
history-kernel.lua soren-ds                   # a draft vision, printed
history-kernel.lua soren-ds --write           # ... saved as notes/vision.md if there is none
history-kernel.lua soren-ds --out=/tmp/v.md   # ... or saved elsewhere
```

**The facts come from git alone:**
- the first `--commits` (default 10) commits that touch the folder, each with
  its date, subject and the first lines of its message;
- the README as it stood in the first commit that had one, or the current
  README if no commit had one;
- the build files present now;
- the commit count and the latest commit.

A project can be a whole repository or a folder inside the monorepo. Only
the commits that touch it are read.

**The draft** comes from the local model (`libs/llama-chat-client.lua`). It
is given the facts and asked for `# Vision`, `## The original idea` and
`## What it grew into`, and told to say where intent is unclear rather
than guess. The draft ends with a comment saying how many commits it was
drawn from, and that it should be checked.

**Nothing is replaced.** `--write` and `--out` refuse a path that already
exists.

Tested by `test-history-kernel.sh` (24 checks) against the stand-in model in
`libs/stand-in-model/`.
