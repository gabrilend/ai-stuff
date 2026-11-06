# 604c — word sessions and the tracker

Part of 604. Depends on: 604a, 604b. Blocks: 604e.

## Status: in-progress

## Current Behavior

Built as described below, in `src/038-word-sessions.lua`, and proven with
a stand-in `claude` (`src/039-word-sessions-test.lua`, 11 checks passing).
**Not yet run with a real Claude Code session**, which is the remaining
step: whether a real headless session, with these permissions and the
house's hooks, writes its one file and passes its check.

Learned while building it:

- The prompt must come straight after `--print`: `--allowedTools` takes
  every argument after it and would swallow a prompt written later.
- A stand-in program kept in `tmp/shared-memory/` cannot run: `/dev/shm`
  is mounted noexec. Executables go in the `tmp/` tier (`/tmp`).
- After the tracker is moved back and its rows are written, git reports it
  as renamed and modified ("RM").

Before this, an unrecognized word had nowhere to go.

## Intended Behavior

`src/038-word-sessions.lua`:

- **briefs in RAM**: for each unknown word, `tmp/shared-memory/say/<run>/
  <word>.md` holds the word, the sentence, the word-file contract (from
  `docs/score-format.md`), the two hand-written examples, and the rule:
  *write exactly one file, `words/<word>.lua`, plus nothing else; check it
  with `luajit src/034-words.lua --check <word>`; then write the word's
  result line at the end of this brief.*
- **all at once**: one headless session per word (`claude -p` with the
  brief, edits allowed, run in the project folder), started together; the
  module waits for all of them. The command is `claude` unless
  `SAY_CLAUDE` names a stand-in.
- **checked, not trusted**: a word counts as taught only if its file exists
  afterwards, loads under the contract, and (for a pattern) its example
  expands and passes the wall. Each session's output is kept in RAM.
- **the tracker in one pass**: every taught word becomes one row of issue
  605's table, written in a single edit. If 605 is in `issues/completed/`,
  it is moved back to `issues/` (git mv) and its status set to open first.
  Words not taught are reported to the person with the reason and are not
  added.

## Suggested Implementation Steps

1. Brief writer.
2. Session launcher: start all, wait all, collect exit status and output.
3. The checker (reuses 604a's loader and the wall).
4. Tracker update with the reopen, one write.
5. `src/039-word-sessions-test.lua` with a stand-in `claude` that writes a
   given word file: two words taught at once, one session that writes a bad
   file (not added), the tracker reopened from `completed/`, rows added in
   one write.
