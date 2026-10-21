# The refusal gates, and committing only your own lines

Small scripts that sit in front of every shell command Claude Code runs and
refuse a specific bad habit each, plus a note-taking hook and three commands that
together let a session commit exactly the lines it wrote. They are installed as
hooks in `~/.claude/settings.json`, so they apply to **every session on this
machine, in every project**.

Every script Claude Code runs as a hook lives in `harness-hooks/` (moved there
2026-10-20, so the things that judge each session sit in one place). Each hook
still takes the scripts folder as its folder (`DIR`), since that is where its
shared libraries (`libs/`) are. The commands below (`commit-own-changes` and
the rest) are run by sessions, not by Claude Code, and stay in the scripts
folder; so does `backup-conversations`, a command of its own that the Stop
hook also calls with `--hook`.

| Script | Kind | What it does | Token to lift it once |
| --- | --- | --- | --- |
| `refuse-directory-change` | gate (before Bash) | refuses `cd`, `pushd`, `popd` | `touch /tmp/claude-allow-cwd-change` (any one move), or `echo /a/folder > /tmp/claude-allow-cwd-change` (a move there only); expires after ten minutes |
| `refuse-relative-commit-ref` | gate (before Bash) | refuses a history-changing git command that counts backwards to its commit instead of naming it | `touch /tmp/claude-allow-relative-commit-ref` |
| `refuse-foreign-lines` | gate (before Bash) | refuses a plain `git commit` that would record anything, pointing at `commit-own-changes` | `touch /tmp/claude-allow-foreign-commit` |
| `refuse-outside-writes` | gate (before Bash, Edit, Write, MultiEdit, NotebookEdit) | refuses a file tool writing, or a command that writes (redirection, `sed -i`, `tee`, `cp`, `mv`, `rm`, …) anywhere but the session's folder, its two RAM rooms, or `/dev/null` and its kind; never answers "allow", so Claude Code's classifier still judges every command it lets by | `touch /tmp/claude-allow-outside-write` |
| `answer-outside-write` | hook (before and after AskUserQuestion) | reads the person's Yes / This session / Always / No to the write gate's question from what Claude Code records, and grants once, allows the folder until the session ends, allows it for good, or grants nothing; refuses a question that arrives with its answers filled in | — |
| `forget-session-permits` | hook (SessionEnd) | removes the folders a session was allowed "This session" and its unspent Yes grants | — |
| `merge-agent-scratchpad` | hook (SessionEnd) | moves the session's Claude Code scratchpad into `/tmp/<name>/agent-scratchpads/<session>/` behind the session folder's `tmp` link; leaves it in place when there is no link | — |
| `allow-own-ram-tiers` | permission (before Read, Edit, Write, MultiEdit, NotebookEdit, Glob, Grep) | answers "allow" for a path inside the session's own project's RAM tiers, so Claude Code's folder boundary does not ask; says nothing about any other path | — (it only widens) |
| `carry-working-folder-name` | hook (SessionStart, CwdChanged) | makes each command's shell show the folder name Claude Code has on record, not the one inherited at launch | — |
| `record-own-edits` | note-taker (after Edit, Write, MultiEdit, NotebookEdit, Bash) | appends every line the session adds or removes to its edit ledger | — |
| `commit-own-changes <repo> -F -` | command | commits only this session's lines, built on a private staging list | — |
| `stage-own-changes [repo]` | command | previews what `commit-own-changes` would commit; writes nothing | — |
| `claim-own-change <file>...` | command | claims whole files the ledger could not see being written | — |
| `adopt-left-behind-changes <repo> -- <path>...` | command | takes ownership, line by line, of uncommitted work whose session has ended, leaving lines any other ledger holds | — |

`refuse-unscoped-commit`, the commit gate before `refuse-foreign-lines`, is
retired; see "Why the commit gate changed" below.

Each gate spends its token on the next offending command and deletes it. A
permission granted once is not a permission granted forever, and the tokens are
separate on purpose — allowing one directory change should not also allow one
foreign commit, nor one blind reset. A token that cannot be deleted (a
directory with something in it) is not honoured, since it would otherwise
permit every later command.

### Moving the session's folder when the person allows it

The directory gate's permission can name its folder, and it expires (issue
041 in `issues/`):

- `! touch /tmp/claude-allow-cwd-change` allows any one move;
  `! echo /new/place > /tmp/claude-allow-cwd-change` allows a move to that
  folder only. A named permission does not let a move elsewhere through, and
  is kept for the move it was made for. Folders are compared by where they
  really are, so the old name of a folder and its new name match.
- A permission older than ten minutes is removed the next time the gate sees
  a move, the refusal says so, and it is not used. Without this, a
  permission given for a move that never reached the gate (see below) waited
  for whatever move came next.
- **Ask for the move as a command of its own: `cd /new/place` alone.**
  Claude Code drops a leading `cd DIR &&` when DIR is the folder the session
  is in, comparing real places, so after a folder is moved and its old name
  left as a link, `cd /new/place && pwd` from the old name never reaches the
  gate and never moves; `cd /new/place` alone does.
- **A new name for the folder the session is in takes two steps.** Tried
  live 2026-10-18: a permitted one-step `cd` from a folder's old name to its
  new name ran, and the next command was back at the old name, since Claude
  Code moves its record of the session's folder only when the real place
  changes. So: `! echo /new/place > /tmp/claude-allow-cwd-change`, then
  `cd /new` (the new name's parent; a real move, the permission kept), then
  `cd /new/place` (the permission spent). A one-step move between names is
  refused, says so, and spends nothing.
- **Why the old name sticks at all:** each command's fresh shell inherits the
  `claude` program's own `PWD`, set when it was launched, and bash keeps an
  inherited `PWD` that names the folder it is in. `carry-working-folder-name`
  (a hook on `SessionStart` and `CwdChanged`, through Claude Code's
  `CLAUDE_ENV_FILE`) re-enters the folder by the name Claude Code has on
  record before every command. Start a session in the folder by the name you
  want, and that name is what it shows.
- **A session already stuck on an old name** (one that cannot be restarted):
  run `carry-working-folder-name --now /the/name/wanted`, then give one
  permission and have the session make one real move (into a subfolder).
  Claude Code reads the session's environment files only when one of its
  hooks fires; after that move, every command shows the wanted name.

Found 2026-10-18, when a project moved disks and the session, started under
the old name, could not be moved to the new one: the chained move was
dropped, the permission was left armed, and nothing said why.

### The project's own RAM tiers

Claude Code's file tools work only inside the folders a session was started
with, and stop to ask about anything else. Every project's scratch space
lives outside them, in RAM: `<project>/tmp` leads to `/tmp/<name>`, and
`tmp/shared-memory` to `/dev/shm/<name>` (issue 033). So reading a project's
own log stopped for a question every time. `allow-own-ram-tiers` looks only
at the `tmp` link in the folder the session is in (never one above it),
follows it and the `shared-memory` link inside it, and answers "allow" for
any path that really lands in one of those two rooms, and nowhere else. A
room counts only when it lies below its RAM root (`/tmp`, `/dev/shm`), so a
`tmp` link aimed at a disk folder or at a root widens nothing; a session
whose own folder has no link gets no exception, even inside a project;
another project's rooms are not this session's. It never refuses, and when it cannot
read its input it announces that and gives no answer, leaving Claude Code's
own boundary in charge (issue 042, `tests/test-allow-own-ram-tiers.sh`).

Shell commands are not covered by that hook: Claude Code does not check
them against its folder list at all, which is why a `sed -i` outside the
folder used to go through. `refuse-outside-writes` covers them instead, as
a refusal only (issue 043, `tests/test-refuse-outside-writes.sh`). It reads
the command with the shared reader, which keeps redirection targets aside
for it, and asks a table of commands where each writes (`sed`/`perl` with
`-i`, `tee`, `cp`, `mv`, `rm`, `touch`, `mkdir`, `chmod`, `ln`, `install`,
`truncate`, `dd of=`, `curl -o`, `wget -O`, `tar`, `unzip -d`, `patch`,
`rsync`, `find -delete`/`-exec`). The places allowed are the session's
folder, its two RAM rooms (the same `libs/own-ram-tiers.lua` the hook above
uses), and `/dev/null`, `/dev/stdout`, `/dev/stderr`, `/dev/tty`,
`/dev/fd/N`. A target it cannot work out (a variable set outside the line,
a command substitution, or a file tool given a relative or `~` path) is
refused even when a permission is waiting, and the permission is kept: a
permission covers a write whose destination can be seen, and these have
none. (Asked for 2026-10-20 after a permitted Write showed in Claude Code as
`../../../../home/ritz/.claude/...`. That was only Claude Code displaying an
absolute path relative to the session's folder; the tool had been given the
absolute path.) The two judgements are joined by
design, in the owner's words: "They should both be allow for it to
succeed." This gate can only say no; when it says nothing, the classifier
still decides. A program the command runs, `git -C`, and paths fed through
`xargs` are not seen.

The same gate judges the file tools that write (Edit, Write, MultiEdit,
NotebookEdit) by the path they name, by the same rule. Claude Code's own
question for such a path is no guard in auto mode, where the classifier can
answer it. Reading outside the folder stays free. A refusal here outranks
`allow-own-ram-tiers`'s "allow" (a deny from any hook wins), though the two
never disagree: the rooms are inside for both.

**Asking the person: Yes, This session, Always, No.** When the gate refuses a write
whose places it can pin down, it files a request (in
`/dev/shm/claude-outside-writes/`) and hands the agent one question to ask
word for word with the question tool: the places in its text, a tag
`[outside-write <id>]`, and the answers Yes (this once), This session
(anything in these folders, for this session until it ends), Always
(anything in these folders, every session, from now on) and No. `answer-outside-write`
reads the answer from what Claude Code records after the person picks one,
checks the question was asked exactly as filed and by the session refused,
and acts: a Yes is a grant that session spends on its next write needing no
more than those places; a This session adds the folders to a list in RAM
under the session's id, which `forget-session-permits` removes when the
session ends; an Always adds the folders to
`~/.claude/outside-write-allowed-folders`, which every session's gate
reads. A hook cannot ask the person itself (it runs without the terminal),
and Claude Code's own permission dialog can be answered by the auto-mode
classifier, hence the agent asking and a hook reading. The agent cannot
forge any of it: the request store and the allowed list are outside every
session's folder, and a question arriving with answers filled in is
refused. `! touch /tmp/claude-allow-outside-write` still works as the
person's own route (an agent's `touch` there is itself refused).
Tests: `tests/test-answer-outside-write.sh`.

The session's own Claude Code scratchpad
(`/tmp/claude-<uid>/<slug>/<session>/scratchpad`, matched by the session id
in the hook input, by shape rather than on disk, since Claude Code makes the
folder only on first use) counts as inside too, and no other session's. Claude Code
tells every agent to use it, and it cannot be moved while Claude Code runs:
the program reads where its temp folder lives once, from its own
environment, which no hook can change. So the agent writes there, and
`merge-agent-scratchpad` carries the files into the project's exec room when
the session ends — copied, then the scratchpad removed only if the copy
worked; a resumed session's second ending merges into the same folder.

## Why each exists

**The working directory belongs to the person at the terminal.** When a command
walks off to another folder, every later command inherits the move, and the
prompt, the status line and the person's own sense of where they are quietly
disagree with reality. Nearly every real need has a flag instead — `git -C`,
`make -C`, `tar -C` — so refusing costs almost nothing.

**`HEAD~1` is not a name, it is a sum.** Nothing about it is checked. It means
"one step back from wherever HEAD is standing at the instant this runs", and HEAD
moves — another session commits, an earlier command on the same line commits, a
rebase lands, a merge fast-forwards. When that happens the sum does not fail. It
quietly resolves to a different commit, and `reset --hard` does not ask twice.
A hash is checked rather than computed: **the failure mode of a wrong hash is an
error message; the failure mode of a wrong count is a lost afternoon.**

**The index belongs to the repository, not to whoever is typing.** In a
monorepo where several sessions work at once, a bare `git commit` commits
whatever anybody staged. This is not hypothetical: one session's commit message
ended up attached to another session's files, while the first session's own
work stayed uncommitted and unnoticed for hours.

## Committing only your own lines

Three pieces, one ledger:

1. **`record-own-edits` takes notes.** After every file edit it appends the
   lines the edit added and removed to a per-session ledger in RAM
   (`/dev/shm/claude-own-edits/<session-id>/ledger.tsv`). It learns them from
   what the tool reports: an edit's change blocks, a new file's content, a
   notebook (claimed whole), and — since Claude Code 2.1.271 — the file diff a
   shell command reports when it edits files the harness was tracking. A shell
   command that changed files *without* a diff is named back to the model, so it
   can claim them.
2. **`commit-own-changes` commits, privately.** It never uses the shared
   staging area (`.git/index`). Under a per-repository lock it seeds a private
   staging list in RAM from the branch tip, compares the working tree with it
   for the ledger's files (no context lines), keeps each change block whose
   every line is claimed, renumbers the kept blocks so they still line up, and
   applies them to the private list with `git apply --cached --unidiff-zero`.
   New files wholly written by the session are added whole. Every transcript
   that differs from the tip rides along whole, whoever's conversation it is,
   when it belongs to the session's project (the folder the session runs in)
   or to the project of a file the commit carries (the nearest folder above it
   with `llm-transcripts/`); this conversation's own ride along wherever they
   are, and a deletion left by the exporter's renaming rides with them. (The
   exporter replaces a transcript whole in one step, so there is never a
   half-written one to take.) A block where the session's lines touch someone
   else's ("mixed": no unchanged line between) is taken apart and only the
   session's lines are kept. The repository's `pre-commit`,
   `prepare-commit-msg` and `commit-msg` hooks run as git would run them
   (`--no-verify` skips the first and last). It commits that list with the tip
   as parent and moves the branch only if the branch still points at the tip;
   otherwise it rebuilds on the new tip; then `post-commit` runs. Then it
   brings the shared staging area in step for the files it committed, and only
   those, keeping anything someone staged there by hand on top of the new
   commit. Blocks it leaves out are listed by file and line — "foreign" (none
   of it is ours) or "tangled" (both sessions changed the same place, so the
   order of the two cannot be told). A tangled block stops the commit;
   `--leave-mixed` commits the rest.
3. **`refuse-foreign-lines` turns plain commits away.** Any `git commit` that
   would record something — however it is spelled, amends included — is
   refused with a pointer to `commit-own-changes`. Dry runs and `-h` pass.

`stage-own-changes <repo>` previews what `commit-own-changes` would take and
writes nothing.

The everyday shape:

```
commit-own-changes /mnt/mtwo/programming/ai-stuff -F - <<'EOF'
...message...
EOF
```

Add `-- <path>...` (files or folders, repository-relative) to commit one piece
of the work at a time.

Two sessions editing the same file in different places is the everyday case,
not an edge: each commit is built on whatever the branch holds at that moment
plus that session's own blocks, so the two commits land in either order, each
with only its own lines, and nothing is reverted.

If a block of yours is **tangled**, someone else changed the same place as
you (not just the line beside it, which is taken apart without asking);
decide with them (or the user) what that region should say.
If the lines are **yours but came from a shell command the ledger did not
see**, claim the file out loud (`claim-own-change <file>`) and try again.

### Work a finished session left behind

Ledgers live in RAM, one per session. Work a session wrote and never
committed has no owner once that session is gone: a new session has a new
id, and a reboot empties every ledger. On 2026-09-29 a session asked to
commit such a backlog found no route but the token, and the plain commit that
followed carried a rename somebody else had staged (issue 032b).

The gates guard against colliding with somebody who is still working, and
lines whose author has left have nobody to collide with. So a session takes
them over out loud:

```
adopt-left-behind-changes <repo> -- <path>...       # --dry-run to look first
commit-own-changes <repo> -F - -- <path>...
```

It writes every changed line under the paths into this session's ledger,
except lines another session's ledger still claims. Those are **held**, and
reported with the session's id and when its ledger was last written. If that
session has ended but its ledger survived, `--from <session>` takes its lines
too. Adoption works line by line, unlike `claim-own-change`, so a live
session's lines in the same file stay out. A person's own uncommitted hand
edits have no ledger, so they count as left behind; name the scope with care.

### Why the commit gate changed

The previous gate, `refuse-unscoped-commit`, insisted every commit name its
paths (`git commit -- <paths>`). Naming paths makes git take those files whole
from disk and ignore the index. That kept other sessions' *staged files* out,
but a file holding your edit and someone else's uncommitted edit was committed
whole — their lines included — and staging individual lines with
`git apply --cached`, which the standing instructions ask for, was thrown away.
The person's call, when asked which rule should win: *"let's prefer the
claude.md implementation. We need more rigid guard-rails about always committing
just lines that were edited by us."* So the index was kept, and checked line
by line against what the session is known to have written (issue 032,
`issues/032-commit-only-your-own-lines.md`).

That check still shared one staging list between sessions, and on 2026-09-22
it failed in the way only sharing can. One session's gate found the list clean
and approved a line that staged its own lines and then committed; while that
line's staging was still running, another session staged 55 files into the
same list, and the commit carried them under the wrong message. A gate runs
before the command it approves, so no gate can vouch for a list anyone may
write in between. Commits now never touch the shared list: `commit-own-changes`
builds each one on a private list and moves the branch with a compare-and-swap
(issue 032a, `issues/032a-commit-through-a-private-staging-area.md`).

## How the gates read a command

All three gates read commands through one shared reader,
`libs/shell-command-scan.lua`, which splits a line the way a shell does:
quotes, backslashes, comments, heredoc bodies (set aside, since text written to
a file is data), `$( )` and backticks (read as commands of their own), `eval`,
`bash -c`, a heredoc fed to a shell, redirection targets (dropped), and the
words that put something in front of a command — `NAME=value`, `env`,
`command`, `builtin`, `exec`, `time`, `nice`, `nohup`, `sudo`, `timeout`,
`xargs`, and the shell keywords `if then else elif do while until ! { }`.

The gates used to search the raw text with regular expressions. The review of
2026-09-22 found every bypass and every false refusal came from that:

- `if [ -d x ]; then cd x; fi`, `builtin cd`, `FOO=1 cd`, `eval "cd x"` passed,
  while a heredoc writing a script that contained `cd` was refused.
- `git reset --hard 'HEAD@{1}'` passed, because quoted spans were removed
  before the scan — along with the revision inside them. After
  `git -C "/a path"`, the removal also let `-C` swallow the subcommand.
- A command over 64 KB passed the first two gates: they piped it into
  `grep -q`, which stops reading at its first match; the writer died of a broken
  pipe, and `pipefail` turned that into "no match".
- The relative-reference gate ran one `grep` per word, and a 3000-path
  `git restore` took about 20 seconds — past the 10-second hook timeout, which
  let it through unchecked. The reader walks the line once (about 45 ms).

The relative-reference gate now also covers `stash drop/pop/apply/branch
stash@{N}`, `checkout -` and the other commands where `-` means "the previous
branch", `ORIG_HEAD`, `:/text`, `merge`, `update-ref`, `worktree add`, `notes`,
a forced push by `+refspec`, and a count held in a variable the same line sets
(`R=HEAD~1; git reset --hard $R`). It skips the values of message options and
every word after `--`, so an editor backup file (`file~`) after `--` is a path.

A `cd` inside a child shell — `(cd x && make)`, `$(cd x && pwd)`,
`bash -c 'cd x'` — cannot move the session's directory, and is refused anyway:
partly habit, and partly because `( cd x ); make` and `cd x; make` differ by two
characters. `git -C` leaves nothing to judge.

**Observed on Claude Code 2.1.280:** the harness appears to drop a leading
`cd <the current directory> &&` before hooks see the command, so that no-op
shape passes live even though the directory gate refuses it when fed the text.
"The current directory" is compared by real place: on 2026-10-18 it also
dropped `cd /new/place && pwd` run from an old name that is a link to
`/new/place`, which is a real move of names, not a no-op (see "Moving the
session's folder" above: ask for it alone).
To tell that from a broken gate, try a change inside a subshell — `(cd /tmp &&
pwd)` — which the harness leaves alone and the gate refuses.

## When a gate cannot read its input

It lets the command run, and says so to the person every time, as a warning
(`systemMessage`, and on standard error): "…this command was NOT checked."
The old gates allowed the command silently, reasoning that a crashed gate would
block every command. That was never true — only exit code 2 blocks; any other
failure is a non-blocking error — so the silence bought nothing. An announced
fallback is a warning; a silent one was the bug.

## What these are not

**None is a security boundary.** The session they constrain can edit these
files, remove the hooks, create the tokens, write its own ledger, or claim any
file. What they buy is that the careless form is not available by habit, and
that every way around is something a person would see in the transcript — a
token touched, a file claimed, a script edited. **An honour system with a
witness, not a lock.**

Known limits, each a place where a determined line passes:

- Claims are by line text within a file: a foreign line identical to one of
  ours in the same file (a blank line, a lone `end`) passes.
- `source ./script`, aliases, functions, `shopt -s autocd`, and a script piped
  into a shell (`echo … | bash`) are not read.
- A git alias (`git ci`) and commands that make commits without `git commit`
  (`commit-tree`, `merge`, `cherry-pick`) are not checked by the commit gate.
- `commit-own-changes` runs the commit hooks itself; a hook that inspects
  `.git/index` directly, rather than through git with the `GIT_INDEX_FILE` it
  is given, would see the shared list instead of the commit.

## If a gate is wrong

Fix the script, not the caller. `test-refusal-gates` holds every case — kept in
a file rather than typed at a prompt, since typing the bad forms gets them
refused — and runs the reader's own tests (`tests/test_shell-command-scan.lua`)
the ledger/preview/commit test in a scratch repository
(`tests/test-own-lines.sh`), and the commit route's own suite — two sessions on
one file in both orders, twenty rounds of simultaneous commits, overlaps,
hand-staged entries, a branch moved mid-commit
(`tests/test-commit-own-changes.sh`). Run it after any change:

```
/home/ritz/programming/ai-stuff/scripts/test-refusal-gates
```

A gate can be tried on a copy before it goes live: `test-refusal-gates <dir>`
runs every case against the gates in `<dir>`, and each gate takes the scripts
directory as its second argument, so a staged copy loads its own libraries.
That matters because the installed gates judge every command in every session
the moment the file changes.

Disable any of them by removing its entry from `hooks` in
`~/.claude/settings.json`.
