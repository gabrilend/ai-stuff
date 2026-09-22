# The refusal gates, and committing only your own lines

Small scripts that sit in front of every shell command Claude Code runs and
refuse a specific bad habit each, plus a note-taking hook and two commands that
together let a session commit exactly the lines it wrote. They are installed as
hooks in `~/.claude/settings.json`, so they apply to **every session on this
machine, in every project**.

| Script | Kind | What it does | Token to lift it once |
| --- | --- | --- | --- |
| `refuse-directory-change` | gate (before Bash) | refuses `cd`, `pushd`, `popd` | `touch /tmp/claude-allow-cwd-change` |
| `refuse-relative-commit-ref` | gate (before Bash) | refuses a history-changing git command that counts backwards to its commit instead of naming it | `touch /tmp/claude-allow-relative-commit-ref` |
| `refuse-foreign-lines` | gate (before Bash) | refuses a `git commit` whose index holds a line this session did not write, or whose form bypasses the index | `touch /tmp/claude-allow-foreign-commit` |
| `record-own-edits` | note-taker (after Edit, Write, MultiEdit, NotebookEdit, Bash) | appends every line the session adds or removes to its edit ledger | — |
| `stage-own-changes [repo]` | command | stages only this session's lines, with `git apply --cached` | — |
| `claim-own-change <file>...` | command | claims whole files the ledger could not see being written | — |

`refuse-unscoped-commit`, the commit gate before `refuse-foreign-lines`, is
retired; see "Why the commit gate changed" below.

Each gate spends its token on the next offending command and deletes it. A
permission granted once is not a permission granted forever, and the tokens are
separate on purpose — allowing one directory change should not also allow one
foreign commit, nor one blind reset. A token that cannot be deleted (a
directory with something in it) is not honoured, since it would otherwise
permit every later command.

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
2. **`stage-own-changes` stages.** For each file in the ledger it compares the
   working tree with the index, with no context lines, keeps each change block
   whose every line is claimed, renumbers the kept blocks so they still line up,
   and applies them with `git apply --cached --unidiff-zero`. New files wholly
   written by the session are added whole. The project's `llm-transcripts/`
   folder is staged alongside. Blocks it leaves out are listed by file and line
   — "foreign" (none of it is ours) or "mixed" (our line touches someone else's
   with no unchanged line between, so git cannot take one without the other).
3. **`refuse-foreign-lines` checks.** Before any `git commit`, it reads the
   index of the repository the commit will use and refuses if any staged added
   or removed line (outside `llm-transcripts/`) is not in the ledger, listing
   them by file and line. It also refuses the forms that bypass the index:
   `-a`/`--all`, `-i`/`--include`, `--only` with paths, a pathspec,
   `--pathspec-from-file` — and a line that stages with a raw git command and
   commits in the same breath, because the gate runs before the line does.

The everyday shape:

```
stage-own-changes /mnt/mtwo/programming/ai-stuff
git -C /mnt/mtwo/programming/ai-stuff commit -F - <<'EOF'
...message...
EOF
```

If the gate lists lines that are **someone else's staged work**, do not unstage
them without asking the user — they may be about to commit them. Ask who goes
first. If the lines are **yours but came from a shell command the ledger did
not see**, claim the file out loud (`claim-own-change <file>`) and try again.

### Why the commit gate changed

The previous gate, `refuse-unscoped-commit`, insisted every commit name its
paths (`git commit -- <paths>`). Naming paths makes git take those files whole
from disk and ignore the index. That kept other sessions' *staged files* out,
but a file holding your edit and someone else's uncommitted edit was committed
whole — their lines included — and staging individual lines with
`git apply --cached`, which the standing instructions ask for, was thrown away.
The person's call, when asked which rule should win: *"let's prefer the
claude.md implementation. We need more rigid guard-rails about always committing
just lines that were edited by us."* So now the index is kept, and checked
line by line against what the session is known to have written. The design is
issue 032, `issues/032-commit-only-your-own-lines.md`.

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

## If a gate is wrong

Fix the script, not the caller. `test-refusal-gates` holds every case — kept in
a file rather than typed at a prompt, since typing the bad forms gets them
refused — and runs the reader's own tests (`tests/test_shell-command-scan.lua`)
and the ledger/staging/commit test in a scratch repository
(`tests/test-own-lines.sh`). Run it after any change:

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
