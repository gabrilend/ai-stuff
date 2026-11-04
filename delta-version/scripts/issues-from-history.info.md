# issues-from-history.lua

The third slice of issue 051 (051c). It drafts issue files for work a
project has already done, from its git history.

```
issues-from-history.lua soren-ds                    # the plan; nothing written
issues-from-history.lua soren-ds --json             # the plan as JSON (the issue mapping)
issues-from-history.lua soren-ds --out=/tmp/issues  # issue files and issue-mapping.json there
issues-from-history.lua soren-ds --write            # into issues/completed/, for a project with no issues yet
issues-from-history.lua soren-ds --no-model         # titles from the commits alone
```

**Phases** come from `docs/roadmap.json` (or `--roadmap=FILE`), written by
`roadmap-from-history.lua --write`, so the issues follow its phases and
names. Without a roadmap they come straight from the history
(`libs/history-phases.lua`). A roadmap that no longer matches the history
is refused. Commits newer than the roadmap are left out, and the tool says
so.

**Issues.** Within a phase, commits in a row become one issue when they
meet three conditions:
- they work in the same place (the first two folders of their largest
  change);
- they are no more than 3 days apart;
- the issue holds no more than 6 commits.

An issue's id is its phase number followed by its place in the phase: 101,
102, 201. Its type comes from most of its commit subjects: fix, refactor,
test, docs (also set when the commit changed only `.md` files), chore,
otherwise feature.

**Titles** come from the local model (`libs/llama-chat-client.lua`). It
gives the title on its first line and a summary on the lines after, and
the summary becomes the issue's Intended Behavior. When there is no model,
`--no-model` is given, or the model fails on an issue, the title is the
subject of the issue's largest commit.

**Files.** Each issue is written as a completed issue. It has these
sections:
- Current Behavior;
- Intended Behavior;
- What Happened (each commit, with the start of its message);
- Files Changed;
- Metadata, which says it is a draft to check.

**Nothing is replaced, and nothing clashes:**
- `--write` refuses a project that already has issue files, because their
  ids would clash. Use `--out=DIR` there and move issues by hand.
- `--out` needs a new or empty folder.
- Every target is checked before any file is written.

Tested by `test-issues-from-history.sh` (35 checks) against the stand-in
model in `libs/stand-in-model/`.
