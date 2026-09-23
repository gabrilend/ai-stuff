# Issue #032: A commit carries only the lines this session wrote

## Current Behavior

Commits in the monorepo are guarded by a gate that insists every `git commit`
name its paths (`git commit -- <paths>`). Naming paths makes git take those
files whole from the working tree and ignore the index. That solved one problem
-- another session's staged files riding along in your commit -- and created
another:

- **Hunk-level staging is thrown away.** The standing instructions say to stage
  with `git apply --cached`, so that only the lines you changed are committed.
  A path-named commit ignores what was staged, so a file holding both your edit
  and someone else's uncommitted edit is committed whole, the other person's
  lines included, with nothing to say it happened.
- **The gate cannot tell whose lines are whose.** It reads the command text.
  It has no idea which lines in a file this session wrote, so "name your paths"
  is the strongest thing it can ask for, and a path is a coarse thing to name
  when two people are working in the same file.
- **The other gates read commands as text with regular expressions**, and the
  review of 2026-09-22 found shapes that slip past them: a shell keyword or
  `builtin`/`command`/`eval`/`NAME=value` in front of `cd`; a quoted revision
  (`'HEAD@{1}'`); `git -C "/quoted path" reset ...`; `$(git rev-parse HEAD~1)`;
  and commands over 64 KB, where a pipe into `grep -q` is cut short and the
  check silently counts as "no match". They also refuse harmless text that
  mentions the bad forms inside heredoc bodies and quoted strings, and they
  allow a command through silently when they cannot read their input.

**Status (2026-09-22):** everything in the steps below is built and passes
`test-refusal-gates` (177 cases, including the reader's tests and the
scratch-repository ledger test). Step 7 is done: the settings carry the ledger
hook and `refuse-foreign-lines` in place of `refuse-unscoped-commit`, which is
retired as `refuse-unscoped-commit-done`. The first commit through the new
route (a shell rename, claimed out loud, staged from the ledger, passed by the
gate) succeeded on the day of the switch. What remains is the open questions
below.

**Superseded in part by 032a (same day):** staging into the shared index and
checking it before `git commit` left a gap between the gate's look and the
commit, and another session's commit swept 55 staged files through it. Commits
now go through `commit-own-changes`, which builds each one on a private
staging list; `stage-own-changes` only previews, and the gate refuses every
plain `git commit`. The ledger, the claim command and the ledger hook described
here are unchanged.

## Intended Behavior

**A commit may carry only lines this session wrote**, and the thing that checks
it knows which lines those are, because it was watching when they were written.

The person's answer that settled the design, recorded as given: *"let's prefer
the claude.md implementation. We need more rigid guard-rails about always
committing just lines that were edited by us, it's far too easy to sweep
someone else's changes in and get confusing git commits."* So staging follows
the standing instruction (`git apply --cached`), and the commit commits the
index exactly -- no `-a`, no pathspec -- after a gate has checked that every
line in the index is one this session claimed.

Four pieces:

1. **A ledger** (`record-own-edits`, a hook that runs after every file edit).
   Each time an edit, a whole-file write, a notebook edit or a shell command
   with a reported file diff completes, the lines it added and removed are
   appended to a per-session ledger in RAM (`/dev/shm/claude-own-edits/`). The
   ledger is append-only: one line per claimed line, written in a single call,
   so two edits finishing at once cannot lose each other's records.
2. **A claim command** (`claim-own-change <file>...`). For files produced by a
   shell command that reported no diff -- a generator, a `mv`, a `sed` whose
   result the harness did not capture -- the session claims the whole file out
   loud. The claim is visible in the transcript, which is the point: a
   whole-file claim is a statement a person can read and dispute.
3. **A staging command** (`stage-own-changes [repo]`). For every file in this
   session's ledger that sits in the repository, it builds a zero-context diff
   of the working tree against the index, keeps only the change blocks whose
   every added and removed line is claimed, and stages them with
   `git apply --cached --unidiff-zero`. The project's `llm-transcripts/` folder
   is staged alongside, since the standing instructions attach transcripts to
   every commit. Blocks it cannot stage -- mixed with foreign lines, or foreign
   outright -- are listed by file and line, not dropped silently.
4. **A commit gate** (`refuse-foreign-lines`). Before any `git commit` runs, it
   reads the index of the repository the commit targets and refuses if a single
   staged added or removed line (outside `llm-transcripts/`) is not in this
   session's ledger. The refusal lists the foreign lines by file and line
   number and says how to take them back out of the index. It also refuses the
   commit forms that bypass the index (`-a`, `--all`, `-i`, `--include`,
   `--only` with paths, a pathspec, `--pathspec-from-file`), and it refuses a
   line that stages with a raw git command and commits in the same breath,
   because the gate runs before the line does and would be checking an index
   that is about to change. Staging with `stage-own-changes` in the same line is
   allowed, since that command only ever stages claimed lines.

Alongside, the two surviving text gates move from regular expressions to a
**shared shell-word reader** (`libs/shell-command-scan.lua`) that splits a
command line the way a shell does: quotes, backslashes, heredoc bodies,
command and process substitutions, `eval` and `bash -c` bodies, and the prefix
words that put something in front of a command (`NAME=value`, `env`, `command`,
`builtin`, `exec`, `time`, `nice`, `nohup`, `sudo`, `timeout`, and the shell
keywords `if then else elif do while until !`). Each gate then asks its
question of real commands rather than of text.

When a gate cannot read its input -- missing JSON library, unreadable JSON, a
command field that is not there -- it says so to the person as a warning
(`systemMessage`, plus standard error) and lets the command run. That is a
fallback, and it is announced every time rather than taken silently.

## Suggested Implementation Steps

1. **Find the real payloads before writing the ledger.** The session records
   under `~/.claude/projects/` show what a tool returns: an edit returns a
   `structuredPatch` (change blocks whose lines are prefixed ` `, `-`, `+`);
   a whole-file write returns `type` `create` or `update`, the new `content`,
   and for an update a `structuredPatch` too; a shell command that edited files
   the harness was tracking returns `bashEditDiff`, holding a list of files each
   with change blocks of the same shape, plus `changedFiles`. The hook's
   `tool_response` carries that same object. A shell command learns its session
   from `CLAUDE_CODE_SESSION_ID`; a hook learns it from `session_id` in its
   input. Subagents share their parent's session, so their edits land in the
   same ledger.
2. **Write the shell-word reader** as a LuaJIT library with a small dispatch
   table of character handlers, plus helpers for "the words of this command
   after its prefixes" and "the nested command lines inside it". Test it on its
   own before any gate uses it.
3. **Write the shared gate helpers** (`libs/hook-gate.lua`): read the hook input
   through dkjson, spend a one-time token, print a refusal, print an announced
   warning.
4. **Rewrite the directory gate and the relative-reference gate** on top of the
   reader. Keep their tokens and their messages. Widen the relative-reference
   gate to `stash drop/pop/apply/branch stash@{N}`, `checkout -`, `switch -`,
   `ORIG_HEAD`, `:/text`, `update-ref`, `worktree add` and `notes`. Skip the
   values of message options and every word after `--` (those are paths, and
   editor backup files end in `~`).
5. **Write the ledger hook, the claim command, the staging command and the
   commit gate.** Commit gate first checks the command form, then runs
   `git <the command's own global options> diff --cached -U0` so it inspects the
   same repository the commit will use.
6. **Tests.** Extend `test-refusal-gates` with every bypass and false refusal
   from the review, and add a scratch-repository test for the ledger, the
   staging command and the commit gate. Run them all.
7. **Switch the installed hooks**: add the ledger as a `PostToolUse` hook, put
   `refuse-foreign-lines` where `refuse-unscoped-commit` was, and retire
   `refuse-unscoped-commit` (mark it `-done`, remove after one commit).

## Known limits

- **Claims are by line text within a file.** A foreign line that is
  character-for-character identical to a line this session added to the same
  file passes. A blank line or a lone `end` is the realistic case. Positions
  shift as files are edited, and text is what survives that; the cost is this
  gap.
- **A shell command that edits files the harness was not tracking reports no
  diff.** Those files need `claim-own-change`, or the gate refuses them. That is
  the right direction to fail.
- **A command piped into a shell** (`echo '...' | bash`) is not read by the
  gates. Heredocs fed to a shell interpreter, `eval` and `bash -c` are.
- **Not a security boundary**, like the gates before it: the session can write
  its own ledger or claim any file. The claim is visible in the transcript,
  which is what makes it an honour system with a witness.

## Open questions

1. ~~Should a `git commit --amend` that only rewords need a token?~~ Answered by
   032a: every plain `git commit` that records something is refused, amends
   included; commits here are append-only, and the token covers exceptions.
2. ~~Should the ledger be cleared when a session ends, or left in RAM until
   reboot?~~ Answered 2026-09-22: kept until reboot, so a resumed session keeps
   its claims. That is the behavior as built; no `SessionEnd` hook is added.
3. Is a whole-file claim (`claim-own-change`) too blunt for files two sessions
   share? The alternative is a claim by line range, which is more typing for
   the session and harder for a person to read in the transcript.
4. ~~The staging command staged the `llm-transcripts/` folder of every project
   the session touched, other sessions' transcripts included (seen 2026-09-22
   in neocities-modernization). Which transcripts should ride along?~~ Answered
   by 032a: a transcript rides along when its header names this conversation or
   one of its helpers, wherever it lives; file names are by date, but every
   transcript's first line says whose conversation it is.

## Related

- `032a-commit-through-a-private-staging-area.md` -- the next step: commits
  built on a private staging list (`commit-own-changes`), after a race on the
  shared one swept one session's staged files into another's commit
- `README-refusal-gates.md` -- the gates, the ledger and the commit route
- `test-refusal-gates` -- the cases, kept in a file so they are read, not run
- `refuse-unscoped-commit` -- the gate this replaces
