# Issue #043: A shell command writes only inside its own folder

## Current Behavior

Complete, 2026-10-20; steps 10-12 added and complete 2026-10-21. The question is one question with four answers (Yes, This time, Always, No), step 12; steps 10 and 11 record the forms it passed through. `harness-hooks/refuse-outside-writes` sits under the
PreToolUse Bash matcher and the file-tool matcher, `answer-outside-write`
before and after the question tool, and `merge-agent-scratchpad` on
SessionEnd, all in `~/.claude/settings.json` (earlier settings kept as
`settings.json.before-outside-writes-hook`). Checked live from the
monorepo-root session that built it: a shell write and a Write to `/tmp`
refused; a write into its own scratchpad allowed and into another
session's refused; an Edit of `~/.claude/settings.json` refused, its
question asked, answered Yes by the owner, read by the answer hook, and the
same Edit then let through once, the grant spent. On 2026-10-21 the
four-answer question was asked live for another settings edit (answered
Yes) and `forget-session-permits` installed under SessionEnd. Later that
day the two-question form was asked live, answered Once, and used to
rewrite the two global Always entries per project and the two live
sessions' lists in the new format; a session in the project that answered
Always was then let through, and one in another project refused. The session-end move has
not yet been seen on a real session ending. Tests:
`tests/test-refuse-outside-writes.sh`, `tests/test-answer-outside-write.sh`,
`tests/test-merge-agent-scratchpad.sh`, and the reader's redirect cases in
`tests/test_shell-command-scan.lua`, all run by `test-refusal-gates`.

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

9. Asking the person: Yes, Always, No. The owner, 2026-10-20: "we should
   ask the user a question with three answers, yes, always, and no ...
   That's the always answer. Yes is 'yes, but once.'" A hook cannot ask
   the person anything itself (it runs without the terminal), and Claude
   Code's own permission dialog can be answered by the auto-mode classifier,
   so the agent asks with its question tool and a hook reads the answer:
   - When the gate refuses a write whose places it could pin down, it
     files a request in RAM (`/dev/shm/claude-outside-writes/requests/`,
     itself outside every session's folder, so no agent can write one): an
     id, the session, the places, and the exact question to ask. The
     refusal gives the agent that question word for word: the places named
     in the question text, and three answers, "Yes" (this once), "Always"
     (anything in these folders, from now on, for every session) and "No".
   - `harness-hooks/answer-outside-write`, after the question tool runs,
     reads the answers Claude Code recorded (the person's, not the
     agent's), finds the request by the id in the question, and checks the
     question and its answers are exactly the ones filed and that the
     session is the one refused. Yes: a grant for those places, for that
     session, spent on the next write that needs no more than them. Always:
     each place's folder (the folder a file is in, or the folder itself) is
     added to the allowed list, `~/.claude/outside-write-allowed-folders`,
     one real folder per line, kept on disk. No, anything else, or a
     question that does not match: nothing.
   - The same hook, before the question tool runs, refuses a call that
     arrives with answers already filled in, since that would let an agent
     answer for the person.
   - The gate treats places inside an allowed folder as inside, and spends
     a matching grant before refusing.
   - Requests and grants last 30 minutes. The `! touch` permission stays as
     the person's own way through: an agent cannot make the file, because
     writing to /tmp is itself refused.
   - Tests: `tests/test-answer-outside-write.sh`.
10. A fourth answer, "This session", between Yes and Always. The owner,
   2026-10-21: "update the yes / always / no to include a fourth option,
   'yes-until-end-of-session' or 'always temporarily' or something
   similar". It opens the same folders Always would, for the session that
   was refused only, until that session ends (four is the most answers the
   question tool takes):
   - the folders are kept in RAM, `<state>/session-allowed/<session id>`,
     one per line, and the gate reads them beside the allowed list;
   - `harness-hooks/forget-session-permits`, on SessionEnd, removes that
     file and the session's unspent grants. A session killed without
     ending keeps them until a reboot empties RAM, or until it is resumed
     and ends properly;
   - tests in `tests/test-answer-outside-write.sh`, which ends a session
     and checks This session and an unspent Yes are forgotten and Always is
     not.

11. How long and how wide, asked apart; Always never global. The owner,
   2026-10-21, wanting "yes, for this session only" for one file, and on
   being told Always and a per-project answer differ only in who is
   covered: "replace 'this project' with 'always'. That's what always
   should be, it should never give global permissions. Can you prune any
   that already exist and replace them with project specific
   permissions?" So the one call to the question tool carries two
   questions, both tagged with the request id:
   - **How long?** Once (this write), This session (until it ends),
     Always (from now on, for sessions working in this same project
     folder), No.
   - **How wide?** This file (exactly the places refused), This folder
     (anything inside the folder each is in). Once covers just the write
     either way; No ignores it.
   - "This project" is the session's own folder, as a real place: the same
     folder the gate measures "inside" by.
   - The allowed list on disk holds one line per permission:
     `<project>\t<file|folder>\t<place>`. The session list in RAM holds
     `<file|folder>\t<place>`. A file permission covers exactly that place;
     a folder permission covers it and everything below.
   - The two global entries already on the list were rewritten for the
     project whose session answered them (found in the sessions' logs:
     `world-edit-to-execute/issues` for `/mnt/kaun/wow-chat-2026`,
     `custom-client/docs` for
     `/mnt/mtwo/games/azeroth-core/decomp-client`), and the two sessions'
     This-session lists in RAM rewritten as folder lines.
   - The answer hook grants nothing unless both questions were asked
     exactly as filed and both answered.

12. One question again, four answers. The owner, 2026-10-21: "I don't
   think we should have a double question prompt, we have 4 option slots
   and we only need 'yes' 'always' 'this-time' and 'no'", and asked what
   each means: "yes is one single write, this time is until session
   closes, always is forever, and no means no." Width: "The file's
   folder." So step 11's second question is gone:
   - **Yes**: this one write (a grant, as Once was).
   - **This time**: anything in the folder each place is in, for this
     session until it ends (as This session + This folder was).
   - **Always**: anything in those folders, from now on, for sessions in
     this same project folder (step 11's project rule stands; "forever"
     is in time, not in reach).
   - **No**: nothing.
   - The lists keep their `<file|folder>` kind column, so a file-wide
     permission can come back without a format change; answers now only
     ever write `folder` lines.

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
  next has a write refused spends it. Answered 2026-10-20 by the owner's
  question design (step 9): a "Yes" is a grant for one session and named
  places. The `! touch` file is kept as the person's own route and still
  belongs to no session.

## Related Documents and Tools

- `issues/completed/042-a-project-may-reach-its-own-ram-tiers.md` — the tiers, and
  the hook that lets file tools reach them.
- `libs/shell-command-scan.lua`, `libs/hook-gate.lua` — the shared reader
  and hook parts.
- `README-refusal-gates.md` — the gates, together.
