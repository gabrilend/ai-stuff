# The refusal gates

Two small scripts that sit in front of every shell command Claude Code runs and
refuse a specific bad habit each. They are installed as `PreToolUse` hooks on
`Bash` in `~/.claude/settings.json`, so they apply to **every session on this
machine, in every project**.

| Script | Refuses | Token to lift it once |
| --- | --- | --- |
| `refuse-directory-change` | `cd`, `pushd`, `popd` | `touch /tmp/claude-allow-cwd-change` |
| `refuse-unscoped-commit` | a `git commit` that does not name its files | `touch /tmp/claude-allow-unscoped-commit` |

Each gate spends its token on the next offending command and deletes it. A
permission granted once is not a permission granted forever, and the tokens are
separate on purpose — allowing one directory change should not also allow one
repository-wide commit.

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

## What is allowed

```
git commit -- some/path                 named paths, index ignored
git -C repo commit -F - -- some/path    the same, message on stdin
git commit --amend --only               correcting a message, no new files
```

## What these are not

**Neither is a security boundary.** They read commands as text rather than
understanding them, so a `--` inside a commit message would satisfy the second
one without scoping anything. And the assistant they constrain can edit these
files, remove the hook that installs them, or create the tokens itself.

What they buy is not prevention. It is that the careless form is not available by
habit, and that every way around is something a person would see in the
transcript — a token being touched, a script being edited. **An honour system
with a witness, not a lock.**

## If a gate is wrong

Fix the script, not the caller. Both were tested in both directions before
installation — including the case that motivated the second one, where a
pathspec on an earlier `git add` in the same line must not satisfy the check for
the commit that follows it.

Disable either by removing its entry from `hooks.PreToolUse` in
`~/.claude/settings.json`. Backups of that file from before each was added sit
beside it as `settings.json.before-cd-hook` and `settings.json.before-commit-hook`,
and can be deleted once you are happy.
