# Issue #042: A project may reach its own RAM tiers

## Current Behavior

Complete, 2026-10-20. `harness-hooks/allow-own-ram-tiers` answers "allow"
for the session's own rooms (checked against the scripts project's real
tiers), `tests/test-allow-own-ram-tiers.sh` passes and runs inside
`test-refusal-gates`, and the hook sits under PreToolUse in
`~/.claude/settings.json` (the earlier settings kept as
`settings.json.before-ram-tier-hook`). Every hook script lives in
`scripts/harness-hooks/`. Finding the rooms moved into the shared
`libs/own-ram-tiers.lua` when issue 043's write gate came to need the same
answer, so the two hooks cannot disagree.

What follows is the problem as it was first described.

Claude Code keeps its own list of folders a session may work in: the folder
the session started in, plus any extra folders named at launch or in
settings. Its file tools (Read, Edit, Write, MultiEdit, NotebookEdit, Glob,
Grep) stop and ask whenever a path falls outside that list.

Every project keeps its scratch space in RAM (issue 033):

    <project>/tmp                    -> /tmp/<name>            (the exec tier)
    /tmp/<name>/shared-memory        -> /dev/shm/<name>        (the artifact tier)

A path written as `<project>/tmp/shared-memory/run.log` resolves to
`/dev/shm/<name>/run.log`, which is outside the list, so reading a log or
writing a scratch file in the project's own RAM tier is stopped and asked
about, every time, in every project. The standing instructions require logs
and ephemeral outputs to live there, so the boundary fights the rule.

There is no hook gating file access by folder. A shell command (`sed -i`,
`>`, `tee`) is not checked against the folder list at all; that is a
separate problem, discussed with the owner on 2026-10-20 and left out of this
issue by their choice.

The hook scripts were scattered among the scripts folder's commands, so
nothing showed which scripts Claude Code itself runs against every session.

## Intended Behavior

A PreToolUse hook, `allow-own-ram-tiers`, sits in front of the file tools and
answers "allow" for a path that lands inside the session's own project's RAM
tiers, which skips Claude Code's question. For every other path it says
nothing, and Claude Code's own boundary decides as before.

"The session's own project" is the folder the session is in (the hook
input's `cwd`), and only that folder: its own `tmp` link, never one found
by walking upward. A session whose folder has no link, even one in a
subfolder of a project, gets no exception, and Claude Code asks the person.
The owner, 2026-10-20, on a first version that walked up as
`restore-ram-tiers` does: "this seems like a bug waiting to happen ... that
symlinked one must be in the root of where the agent is running otherwise it
needs to ask the user."

The two tiers are where that link, and the `shared-memory` link inside it,
really lead (every link followed), and only those two ("good, and ONLY those
two locations"). A tier counts only if it lies under the exec root (`/tmp`)
or the artifact root (`/dev/shm`) respectively — the same rule
`ensure-ram-tiers` enforces — so a `tmp` link pointed at a disk folder, or at
a root itself, never widens the boundary.

The path asked about is compared by where it really is: links followed for
every part that exists, so `<project>/tmp/x`, `/tmp/<name>/x` and a symlink
elsewhere that leads into the tier are all the same answer, and a path whose
last parts do not exist yet (a file about to be written) is judged by the
nearest part that does. A path that merely starts with the tier's name
(`/tmp/<name>-other/`) is not inside it.

When the hook cannot read its input, it says so to the person (the house
rule: an announced fallback is a warning) and gives no answer, which leaves
Claude Code's own boundary in charge — the safe direction, since this hook
only ever widens access.

Every script Claude Code runs as a hook lives in `scripts/harness-hooks/`:
`allow-own-ram-tiers`, `refuse-directory-change`, `refuse-foreign-lines`,
`refuse-relative-commit-ref`, `record-own-edits`, `restore-ram-tiers`,
`carry-working-folder-name`. Each still takes the scripts folder as its
`DIR`, because its shared libraries are in `scripts/libs/`.
`backup-conversations` stays in the scripts folder: it is a command in its
own right that the Stop hook also calls with `--hook`.

## Suggested Implementation Steps

1. `harness-hooks/allow-own-ram-tiers` (LuaJIT): read the input through
   `libs/hook-gate.lua`, and find the rooms through `libs/own-ram-tiers.lua`; take the path from `file_path`
   (Read/Edit/Write/MultiEdit), `notebook_path` (NotebookEdit) or `path`
   (Glob/Grep), through a table from tool name to field; check for a `tmp`
   link in the session's folder only; find the two tiers; answer with
   `permissionDecision: "allow"` and a short reason, or print nothing.
   Real places come from `realpath -m` (`-e` for the tiers, so a link left
   dangling by a reboot names no tier). The two roots are overridable
   through `EXEC_TIER_ROOT` and `ARTIFACT_TIER_ROOT`, as in
   `libs/ensure-ram-tiers`, so tests can stand in for /tmp and /dev/shm.
2. Add `gate.allow()` to `libs/hook-gate.lua`, the allowing twin of
   `gate.refuse()`.
3. `tests/test-allow-own-ram-tiers.sh`: scratch projects with whole tiers,
   cases inside each tier by both names, a new file not yet written, a
   sibling folder sharing a prefix, `..` climbing out of a tier, a path in
   the project but outside the tiers, another project's tiers, a project
   with no `tmp` link, a session in a subfolder and one in the folder above
   (both no exception), a trailing slash on the session's folder, a `tmp`
   link into a disk folder or at a root, a dangling link, a
   `shared-memory` link out of the RAM root, each tool's path field, and
   unreadable input. Run it from `test-refusal-gates`.
4. Install under `PreToolUse` in `~/.claude/settings.json` with the matcher
   `Read|Edit|Write|MultiEdit|NotebookEdit|Glob|Grep`, keeping a copy of the
   settings as `settings.json.before-ram-tier-hook`, as was done for the
   earlier hooks.
5. Move every hook script into `scripts/harness-hooks/` (`git mv`, so the
   history follows), point every hook command in `~/.claude/settings.json`
   there, and point the tests (`test-refusal-gates`, `tests/test-own-lines.sh`,
   `tests/test-ram-tiers.sh`, `tests/test-commit-own-changes.sh`,
   `tests/test-adopt-left-behind.sh`) at `${DIR}/harness-hooks/`. Grep the
   monorepo and `~/.claude/skills` for the old paths afterwards.
6. Add a row, a paragraph and the folder's description to
   `README-refusal-gates.md`.

## Open Questions

- Should shell commands that only touch the project's RAM tiers be allowed
  the same way? Claude Code's auto mode judges shell commands by reading
  them, not by the folder list, so they are not stopped for this reason
  today; nothing is built for them here. The owner, 2026-10-20: "they
  shouldn't be stopped if they're working on their own files, right?"
  Answered the same day: no "allow" for shell commands. The owner: "we
  should design it so that it gets both tests. They should both be allow for
  it to succeed." A shell command gets a refusal-only gate that judges where
  it writes (the folder and these same tiers), and the classifier still
  judges it after; built in issue 043.

## Related Documents and Tools

- `issues/033-ram-tiers-rebuild-themselves.md` — the tier layout.
- `libs/ensure-ram-tiers` — the one definition of the layout and its roots.
- `harness-hooks/restore-ram-tiers` — the session-start hook that rebuilds
  the tiers (and walks upward, which this hook deliberately does not).
- `libs/hook-gate.lua`, `README-refusal-gates.md` — the shared hook parts.
