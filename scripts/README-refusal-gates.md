# The refusal gates

Three small scripts that sit in front of every shell command Claude Code runs and
refuse a specific bad habit each. They are installed as `PreToolUse` hooks on
`Bash` in `~/.claude/settings.json`, so they apply to **every session on this
machine, in every project**.

| Script | Refuses | Token to lift it once |
| --- | --- | --- |
| `refuse-directory-change` | `cd`, `pushd`, `popd` | `touch /tmp/claude-allow-cwd-change` |
| `refuse-unscoped-commit` | a `git commit` that does not name its files | `touch /tmp/claude-allow-unscoped-commit` |
| `refuse-relative-commit-ref` | a history-changing git command that counts backwards to its commit instead of naming it | `touch /tmp/claude-allow-relative-commit-ref` |

Each gate spends its token on the next offending command and deletes it. A
permission granted once is not a permission granted forever, and the tokens are
separate on purpose — allowing one directory change should not also allow one
repository-wide commit, nor one blind reset.

## Why each exists

**The working directory belongs to the person at the terminal.** When a command
walks off to another folder, every later command inherits the move, and the
prompt, the status line and the person's own sense of where they are quietly
disagree with reality. Nearly every real need has a flag instead — `git -C`,
`make -C`, `tar -C` — so refusing costs almost nothing.

**A bare `git commit` does not commit your work.** It commits whatever is in the
index, and in a monorepo where several assistants work at once the index belongs
to the repository rather than to whoever is typing. This is not hypothetical: one
session's commit message ended up attached to another session's files, while the
first session's own work stayed uncommitted and unnoticed for hours.

Scoping the `git add` does not fix it. That still leaves the correctly-staged
files sitting there for anybody else's bare commit to carry away. Naming the
paths on the **commit** is what fixes it, because those paths are taken straight
from the working tree, the rest of the index is ignored, and nothing is left
staged between commands.

**`HEAD~1` is not a name, it is a sum.** Nothing about it is checked. It means
"one step back from wherever HEAD is standing at the instant this runs", and HEAD
moves — another session commits, an earlier command on the same line commits, a
rebase lands, a merge fast-forwards. When that happens the sum does not fail. It
quietly resolves to a different commit, and `reset --hard` does not ask twice.

A hash is the opposite kind of reference. It is checked rather than computed:
either that object is there and is the one that was read out of the log a moment
ago, or git refuses the command. **The failure mode of a wrong hash is an error
message. The failure mode of a wrong count is a lost afternoon.** Reading the log
first and pasting the hash also puts a person's eyes on the commit about to be
destroyed, which is most of the value of the pause.

## What is allowed

```
git commit -- some/path                 named paths, index ignored
git -C repo commit -F - -- some/path    the same, message on stdin
git commit --amend --only               correcting a message, no new files

git reset --hard 4f2a1c9                a name; checked, not computed
git reset --hard HEAD                   no count; "throw away my edits"
git log --oneline -5 HEAD~5             reading is not modifying
git log HEAD~5 && git reset --hard 4f2a1c9
                                        each part of a line is judged alone
git show HEAD^{commit}                  peeling names the same commit
git reset --hard main                   a branch is a name, not a distance
git checkout 4f2a1c9                    and so is a hash, obviously
git push --force-with-lease origin main forced, but nothing is counted
git push origin HEAD~1:main             a count, but git will reject it itself
```

The third gate covers the subcommands that move history around — `revert`,
`reset`, `rebase`, `cherry-pick`, `commit`, `branch`, `tag`, `replace`,
`filter-branch` — and also `checkout`, `switch` and `restore`, which move no
history at all. Those last three are there because the same slip destroys
uncommitted work instead: `git checkout HEAD~1 -- somefile` overwrites that file
in the working tree from wherever the count lands, and no commit is holding the
version it just wrote over. A bare `git checkout HEAD~1` to detach and look
around is caught too, which is the deliberate cost of catching the other.

`push` is the exception to all of that. It is gated only when a force flag is on
the line as well, because an ordinary push that mentions a count is git's argument
to have rather than this gate's — git rejects a non-fast-forward push by itself. A
forced one is different: it lands on a branch other people have already pulled,
and nothing in their reflog undoes it. `--force-with-lease` counts as a force flag
here, since checking that the remote tip has not moved is a different question
from whether you counted back the right number of commits.

A branch or tag name is accepted. It is mutable state like `HEAD` is, so this is
a line drawn rather than a principle carried to its end — but `main` was asked
for by name rather than by distance, and insisting on a raw hash would cost every
ordinary `git rebase main`.

The reading commands — `log`, `show`, `diff`, `blame` — are left alone entirely,
because counting backwards to look at something is how the hash gets found in the
first place, and a gate that stopped that would be telling you to fetch water in
the bucket it just took away.

## What these are not

**None is a security boundary.** They read commands as text rather than
understanding them, so a `--` inside a commit message would satisfy the second
one without scoping anything. And the assistant they constrain can edit these
files, remove the hook that installs them, or create the tokens itself.

What they buy is not prevention. It is that the careless form is not available by
habit, and that every way around is something a person would see in the
transcript — a token being touched, a script being edited. **An honour system
with a witness, not a lock.**

## If a gate is wrong

Fix the script, not the caller. All three were tested in both directions before
installation, by `test-refusal-gates`, which keeps its cases in a file rather
than typing them at a prompt — a gate reading commands as text cannot tell a
command from a command quoted inside another command, so typing the bad forms in
order to test them gets them refused.

Four of those cases are worth knowing about. Two are the same mistake seen from
both sides: a pathspec on an earlier `git add` must not vouch for the bare commit
that follows it, and a `HEAD~5` on an earlier `git log` must not condemn the
hash-named reset that follows it. Both are fixed by judging each part of a line
on its own, and the second was written in from the start because the first had
already been paid for once.

The third is the one the new gate actually got wrong on its first attempt: `@` is
git's own shorthand for HEAD, so `@~2` is the same count wearing a hat, and the
character class that decided "a reference comes before this tilde" had not been
told that `@` is one.

The fourth caught itself in the act. Quoted spans are stripped before the scan
runs, so that a tilde in a commit message is invisible to it — but the stripper
worked one line at a time, and a quoted span running across a newline kept its
inner lines exposed. The gate refused the very edit that was adding the checkout
examples to its own documentation. Two changes fixed it: sed's `-z`, so a span
can cross a newline, and stripping double-quoted spans before single-quoted ones,
so that an apostrophe in prose cannot open a span that swallows the command after
it. Both directions are now pinned by tests.

Disable any of them by removing its entry from `hooks.PreToolUse` in
`~/.claude/settings.json`. Backups of that file from before each was added sit
beside it as `settings.json.before-cd-hook`, `settings.json.before-commit-hook`
and `settings.json.before-relative-ref-hook`, and can be deleted once you are
happy.
