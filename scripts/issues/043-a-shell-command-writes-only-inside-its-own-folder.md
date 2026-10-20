# Issue #043: A shell command writes only inside its own folder

## Current Behavior

Built 2026-10-20, steps 1–8 done except installing the session-end hook (step 8), which
needs the owner's one-time permission to write the settings. `harness-hooks/refuse-outside-writes` sits under the
PreToolUse Bash matcher and the file-tool matcher in
`~/.claude/settings.json` (the earlier settings kept as
`settings.json.before-outside-writes-hook`), and refused a live shell write
and a live Write to `/tmp` from the monorepo-root session that built it.
`tests/test-refuse-outside-writes.sh` passes and runs inside
`test-refusal-gates`; the reader's redirect tests pass in
`tests/test_shell-command-scan.lua`. The session's own Claude Code scratchpad
is allowed; every other place under `/tmp/claude-<uid>/` is refused.

What follows is the problem as it was first described.

Claude Code keeps a list of folders a session may work in (the
folder it started in, plus extras) and checks its file tools against it.
Shell commands are not checked against that list at all: in auto mode a
classifier reads each command and decides whether it looks risky. So
`sed -i`, `>`, `tee`, `cp`, `mv` and `rm` reach files anywhere the user's
account can, and agents in this monorepo have been seen doing exactly that
to files outside the folder they were started in ("agents are constantly
sneaking through using things like sed or stuff", the owner, 2026-10-20).

None of the existing gates (`harness-hooks/refuse-*`) looks at where a
command writes.

## Intended Behavior

A PreToolUse gate on Bash, `harness-hooks/refuse-outside-writes`, reads the
command with the shared shell reader, collects every place it would write,
and refuses the command when any of them lies outside:

- the folder the session is in (the hook input's `cwd`), and
- that folder's own two RAM tiers, found exactly as `allow-own-ram-tiers`
  finds them (issue 042): the `tmp` link in the session's folder only,
  `/tmp/<name>` and `/tmp/<name>/shared-memory` → `/dev/shm/<name>`, each
  only when it lies under its RAM root;
- plus the handful of device files a command writes to without writing a
  file: `/dev/null`, `/dev/stdout`, `/dev/stderr`, `/dev/tty`, `/dev/fd/*`.

Places are compared by where they really are (links followed), the same way
as issue 042.

**Two tests, both must pass.** The owner, 2026-10-20: "we should design it
so that it gets both tests. They should both be allow for it to succeed."
So this gate never answers "allow" — an "allow" from a hook would skip
Claude Code's classifier. It refuses, or it stays silent and the classifier
judges as before. A command runs only when the gate finds nothing outside
and the classifier lets it through. A command that only writes into the
project's own tiers is still judged by the classifier, because what it runs
(`lua tmp/tmp/build.lua`) can do anything.

**Where a command writes**, by command word (a table from command name to a
small reader of its arguments):

- every redirection that writes: `>`, `>>`, `>|`, `<>`, `&>`, `&>>`, and `>&`
  with a file name rather than a descriptor (`2>&1` writes no file);
- `tee`, `touch`, `mkdir`, `rm`, `rmdir`, `truncate`, `shred`, `chmod`,
  `chown`, `chgrp`: every argument that is not an option;
- `cp`, `mv`, `install`, `ln`, `rsync`: the destination (the last
  argument, or the folder after `-t` / `--target-directory`); `mv` also its
  sources, which it removes;
- `sed`, `perl` with `-i` (in place): the files after the script;
- `dd`: `of=`;
- `curl` `-o`/`--output`, `wget` `-O`/`--output-document`, `tar` and
  `unzip` with `-C` / `-d` when extracting, `patch` `-o` or its file.

A path holding a variable is expanded from the variables the same line sets
(the reader's `expand_known`) and from the gate's own environment (`$HOME`,
which a session's commands share); `~` is the home folder. A target that
still cannot be placed — an unset variable, a command substitution — is
refused with a sentence saying the gate cannot tell where it writes, rather
than passed: an unchecked write is what this gate is for.

**A place that cannot be pinned down is refused even when a permission is
waiting**, and the permission is kept: an unexpanded variable, a command
substitution, or a file tool given a path that is not absolute (relative,
or `~`). The owner, 2026-10-20: "help guard against relative paths even when
explicitly allowed". (What prompted it was a permitted Write that Claude
Code displayed as `../../../../home/ritz/.claude/...`; the tool had in fact
been given the absolute path, and the display is relative to the session's
folder.)

**The person's way through** is the same as the other gates: a one-time
permission file, `/tmp/claude-allow-outside-write`, created by the person
(`! touch /tmp/claude-allow-outside-write`), spent and deleted by the next
refused command. The refusal names the places it found outside, and says
how to ask.

When the gate cannot read its input it announces that and lets the command
run, as every gate here does (`gate.warn_and_allow`).

## Suggested Implementation Steps

1. Teach `libs/shell-command-scan.lua` to keep redirection targets instead
   of dropping them: each command gains `redirects`, a list of
   `{ op = string, target = string }` (`op` as typed: `>`, `>>`, `&>`, `>&`,
   `<`…). `words` is unchanged, so the three gates that use it see no
   difference. Add reader tests for the new field, and update
   `libs/shell-command-scan.info.md`.
2. Move the tier-finding out of `allow-own-ram-tiers` into a shared
   `libs/own-ram-tiers.lua` (the session folder's tiers, as real places),
   so the two hooks cannot drift apart; `allow-own-ram-tiers` uses it.
3. Write `harness-hooks/refuse-outside-writes`: read through
   `libs/hook-gate.lua`; for each command of `scan.all_commands`, collect
   redirect targets and the targets its command word's reader names;
   expand; place each with `realpath -m` against `cwd`; refuse with the
   list of places outside unless the token is spent.
4. `tests/test-refuse-outside-writes.sh`: inside and outside for each
   command family, both names of a folder, the tiers by both names, another
   project's tiers, `/dev/null` and `2>&1`, a target in a variable the line
   sets and one it does not, `$(...)` as a target, `bash -c` and `eval`
   carrying a write, a heredoc written into a file, the token spent once,
   unreadable input. Run it from `test-refusal-gates`.
5. Install under the PreToolUse Bash matcher in `~/.claude/settings.json`,
   keeping `settings.json.before-outside-writes-hook`.
6. Row and paragraph in `README-refusal-gates.md`; known limits listed
   there (below).
7. The file tools that write (Edit, Write, MultiEdit, NotebookEdit) are
   judged by the same gate, through a table from tool name to a reader of
   the path it names (Bash is read as shell; Read, Glob, Grep are not
   listed, so reading stays free), and the gate is installed under the
   file-tool matcher as well. Tests for each tool, inside and outside.
8. Claude Code's scratchpad: the session's own counts as inside, and its
   contents end up in the project's exec room. Claude Code builds the
   scratchpad as `<temp root>/<slug>/<session>/scratchpad`, the temp root
   being `$CLAUDE_CODE_TMPDIR` or `/tmp/claude-<uid>`; it reads that once,
   from its own environment, at start, so no hook can move it (a hook is a
   child process and cannot change its parent's environment). Instead:
   - `libs/own-ram-tiers.lua` gains a finder for one session's
     scratchpad, by the session id the hook input carries (only ids made of
     letters, digits and dashes; the slug found by looking, not guessed).
   - `refuse-outside-writes` counts that session's scratchpad as inside,
     matched by shape (`<temp root>/<any slug>/<this session id>/scratchpad`
     and below), not looked up on disk: Claude Code makes the folder only on
     first use, and a lookup refused the first write into it (found live,
     2026-10-20, a `mkdir -p` into a fresh scratchpad). Another session's
     scratchpad, and the session's other temp folders (`tasks/`), stay
     outside. The on-disk finder stays for the merge hook, which needs the
     folder to exist.
   - `harness-hooks/merge-agent-scratchpad`, on SessionEnd, copies the
     scratchpad into `<exec room>/agent-scratchpads/<session>/` and removes
     it only when the copy worked; a resumed session merges into the same
     folder. No exec room (no `tmp` link in the session's folder), an
     empty scratchpad, or none: nothing happens. A failed copy is exit 1 with
     a message, the scratchpad left whole.
   - `tests/test-merge-agent-scratchpad.sh`, run from `test-refusal-gates`;
     scratchpad cases in `tests/test-refuse-outside-writes.sh`.
   - Installed under `SessionEnd` in `~/.claude/settings.json`.

## Known Limits (stated, not built)

- A program or script the command runs writes wherever it likes: the gate
  reads the command's text, not what it does. That is the classifier's
  half of the two tests.
- `git` writes inside whichever repository `-C` names; not judged here.
- Aliases, functions, `source`, and a script piped into a shell are not read
  (the reader's own limits).
- Claude Code's own writes outside the folder through its file tools (a
  plan file under `~/.claude/plans/`, say) are refused like any other.

## Open Questions

- Where should temporary files go? Answered 2026-10-20: "should be
  /tmp/project-name/agent-scratchpads/ instead. Then we can allow it." Then,
  after hearing that Claude Code's temp folder is fixed at start: "why
  don't we just let the agents write to their default directories, and
  then merge their stuff into the correct directory when they finish
  completely?" Built that way (step 8). A session killed without ending
  never runs SessionEnd, so its scratchpad stays under /tmp/claude-<uid>/
  until the next reboot empties it.
- Should the gate also cover the file tools? Answered 2026-10-20: "um.......
  yes?" Built (step 7).

- The permission is not tied to a session or a place: whichever session
  next has a write refused spends it, even one in another terminal. Should
  it work like the folder gate's, where the file may name a folder
  (`! echo /home/ritz/.claude/skills > /tmp/claude-allow-outside-write`)
  and then allows only a write inside it, and expires after ten minutes?
  Asked 2026-10-20; unanswered.

## Related Documents and Tools

- `issues/completed/042-a-project-may-reach-its-own-ram-tiers.md` — the tiers, and
  the hook that lets file tools reach them.
- `libs/shell-command-scan.lua`, `libs/hook-gate.lua` — the shared reader
  and hook parts.
- `README-refusal-gates.md` — the gates, together.
