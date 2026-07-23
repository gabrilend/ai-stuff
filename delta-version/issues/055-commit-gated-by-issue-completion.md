# Issue 055: Commit-Gated-By-Issue-Completion Hook and Wrapper Tool

**Status**: Open
**Priority**: High
**Created**: 2026-05-21
**Type**: Harness configuration + new wrapper utility

---

## Current Behavior

The Claude Code harness in this repository can invoke `git commit` directly via
the Bash tool at any moment it pleases. There is nothing in `settings.json` or
`settings.local.json` that forces a commit to be tied to an issue ticket. As a
result, commits routinely happen without an issue file being marked complete,
without the corresponding ticket having been moved to `issues/completed/`, and
without `issues/progress.md` being updated.

The project already has most of the building blocks the workflow needs:
- `scripts/manage-issues.sh` exposes a `complete_issue` function that validates
  an issue file and moves it from `issues/` into `issues/completed/`. It then
  prints a hand-written checklist of remaining manual steps — one of which is
  "commit changes to version control" — but does not perform the commit itself.
- `.claude/settings.local.json` already exists and permits a few utility
  scripts under `Bash(...)` allowlist entries.

What is missing is the *coupling*: nothing prevents a commit-without-ticket,
and nothing performs ticket-move-plus-commit as a single transaction.

### Concrete symptoms
- A bot can stage a pile of unrelated edits and commit them with a fresh
  message, leaving the issue file behind in the unfinished pile.
- A bot can mark an issue "in progress" forever and never close the loop.
- Commits do not have a guaranteed back-reference to the ticket they implement.

---

## Intended Behavior

There is exactly **one path** by which the harness is permitted to produce a
git commit: a custom wrapper tool that takes an issue file as input, verifies
the issue is ready to close, moves the issue into `completed/`, stages the
resulting tree, and only then creates the commit.

Everything else about the harness's git access stays the same:
- `git add`, `git status`, `git diff`, `git log`, `git stash`, `git checkout`,
  `git restore`, branch operations, worktree operations — all still allowed.
- The bot can still freely edit issue files in place, including flipping a
  status line to "in progress" or rewriting the **Current Behavior** section
  while work is partially done. Those edits are not commits and are not
  gated.
- Only the act of producing a commit object is gated.

### What the wrapper tool does, in order

1. Accepts the path to the issue file the bot believes is complete.
2. Runs the existing validator (`validate_issue` in `manage-issues.sh`) to
   confirm the issue has all required sections.
3. Refuses to proceed if the working tree has staged or unstaged changes
   *outside* of the directories the bot is allowed to touch for this issue.
   The bot must clean up other people's work before committing, or
   explicitly confirm.
4. Moves the issue file from `issues/` into `issues/completed/`.
5. Updates `issues/progress.md` to mark the issue as completed.
6. Stages the move and the progress update along with whatever was already
   staged.
7. Builds a commit message that begins with the issue's title line and
   includes the issue number, then opens the commit.
8. Prints the resulting commit hash and a short summary back to the bot.

If any step fails the wrapper aborts and leaves the working tree exactly
where it was — no partial moves, no orphan commits.

### What the hook does

A `PreToolUse` hook on the Bash tool inspects every command the harness is
about to run. If the command text contains `git commit` and was not invoked
by the wrapper, the hook exits non-zero with a short message pointing the
bot at the wrapper script. That is the entire policy.

---

## Suggested Implementation Steps

### 1. Create the wrapper script

```bash
# -- {{{ commit_completed_issue
function commit_completed_issue() {
    local issue_file="$1"

    # honor the project convention for DIR
    DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

    # the wrapper sets this so the gate hook can recognize its own commit
    export DELTA_VERSION_COMMIT_VIA_WRAPPER=1

    # reuse the existing validator from manage-issues.sh rather than
    # re-implementing it; keep the logic in one place
    source "${DIR}/scripts/manage-issues.sh"

    validate_issue "$issue_file" || return 1
    refuse_if_foreign_changes_staged || return 1

    move_issue_to_completed "$issue_file" || return 1
    update_progress_log "$issue_file" || return 1

    git add "$issue_file" "${DIR}/issues/completed/" "${DIR}/issues/progress.md"
    build_and_open_commit "$issue_file"
}
# }}}
```

The script lives at `scripts/commit-completed-issue.sh`. It is the *only*
process that ever sets `DELTA_VERSION_COMMIT_VIA_WRAPPER=1`.

### 2. Add the gate hook to settings.json

The harness's `PreToolUse` hook receives the full tool input as JSON on
stdin. For Bash invocations the relevant field is the command string. The
hook is a tiny script that reads the JSON, looks at the command, and exits
non-zero if it sees a `git commit` that did not come through the wrapper.

```bash
# -- {{{ gate_git_commit
# Reads {"tool_input": {"command": "..."}} on stdin.
# Exits 0 (allow) unless the command contains `git commit` AND the wrapper
# environment marker is missing.
function gate_git_commit() {
    local payload command
    payload=$(cat)
    command=$(echo "$payload" | jq -r '.tool_input.command // ""')

    case "$command" in
        *"git commit"*)
            if [[ -z "$DELTA_VERSION_COMMIT_VIA_WRAPPER" ]]; then
                echo "git commit is gated. Run scripts/commit-completed-issue.sh <issue-file> instead." >&2
                exit 2
            fi
            ;;
    esac
    exit 0
}
# }}}
```

The hook lives at `scripts/hooks/gate-git-commit.sh` and is wired in via
`.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command",
            "command": "/mnt/mtwo/programming/ai-stuff/delta-version/scripts/hooks/gate-git-commit.sh" }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(/mnt/mtwo/programming/ai-stuff/delta-version/scripts/commit-completed-issue.sh:*)"
    ]
  }
}
```

### 3. Make `manage-issues.sh complete_issue` defer to the wrapper

Right now `complete_issue` prints "remember to commit" at the end. Replace
that with a call into the wrapper so there is exactly one code path that
closes a ticket. The wrapper still calls `validate_issue` and the move
function directly so it does not depend on the manage-issues entry point.

### 4. Document the new flow

- Add a short note to `docs/development-guide.md` describing the gated
  commit policy and pointing at the wrapper.
- Add the new wrapper script and the hook script to `docs/table-of-contents.md`.
- Add an `.info.md` companion for the wrapper that lists its inputs and
  outputs.

### 5. Test the gate

Two cases that must both pass before this issue closes:
- A bare `git commit -m "..."` is rejected by the hook with the expected
  message and does not produce a commit.
- A run of `scripts/commit-completed-issue.sh <a-real-issue-file>` validates,
  moves the file to `completed/`, updates progress, and produces a single
  commit that contains the move.

A third case worth probing: the hook must not interfere with `git commit-tree`,
`git rebase` reword operations, or any other plumbing command that contains
the word "commit" but is not the high-level porcelain. The matcher needs to
be a little stricter than substring; prefer a word-boundary regex.

---

## Related Documents

- `scripts/manage-issues.sh` — already implements ticket validation and move-to-completed; the wrapper composes around it
- `scripts/initialize-issue.sh` — sister utility on the opening side of the lifecycle
- `.claude/settings.local.json` — where the new permission entry and hook get wired in
- `docs/development-guide.md` — where the gated-commit policy gets written down
- `issues/progress.md` — updated automatically by the wrapper on each completion

## Tools Required

- `jq` for parsing the hook payload
- the existing `manage-issues.sh` validator
- `git` (obviously) with standard porcelain available to the wrapper

## Metadata

- **Priority**: High — this changes the harness's behavior, and the longer
  it goes ungated the more orphan commits accumulate
- **Complexity**: Medium — the wrapper itself is small; the subtle work is
  in making the hook's matcher precise enough to not over-block
- **Dependencies**: None blocking; benefits from issue 043 if/when that lands
- **Impact**: Every future commit produced by the harness goes through this
  path

## Success Criteria

- The harness cannot produce a commit by calling `git commit` directly. The
  hook rejects it with a clear message naming the wrapper.
- The wrapper, when handed a valid issue file, performs the validate → move
  → stage → commit sequence as one atomic operation, or fails cleanly.
- `git log` after a wrapper run shows exactly one new commit whose tree
  contains the move from `issues/foo.md` to `issues/completed/foo.md`.
- `git status` after a wrapper run is clean (or contains only files
  belonging to other in-flight work the bot deliberately left untouched).
- A bot session can still freely run `git add`, `git diff`, `git status`,
  worktree commands, and ordinary file edits — only the commit step is
  gated.
