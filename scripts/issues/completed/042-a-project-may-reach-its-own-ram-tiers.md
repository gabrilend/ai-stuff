# Issue #042: A project may reach its own RAM tiers

## Current Behavior

Reopened 2026-10-23, because the file tools reached the rooms without a
question but **shell commands did not**. The owner, 2026-10-23: "there's a
permissions prompt sometimes when projects want to make or modify files in
their /tmp/ or /dev/shm/ directories. Even in the ones that they technically
*should* own."

**Complete, 2026-10-25.** Built and proven:

- `libs/ensure-ram-tiers` gives each project's local Claude Code settings
  (`<project>/.claude/settings.local.json`) one path rule per room,
  `Edit(//tmp/<name>/**)` and `Edit(//dev/shm/<name>/**)`, every time it
  builds or repairs the rooms, in all three of its modes. Claude Code's own
  path check then passes for a shell command writing into the rooms; the
  classifier and issue 043's gate still judge the command.
- Each room must lie under its own RAM root, in the library as in the hooks.
- `convert` mode replaces an empty disk `tmp`, or a link into the wrong place
  that leads nowhere, with the standard door, and in a git repository adds
  `tmp` to the project's `.gitignore`.
- `tests/test-ram-tiers.sh`: 91 cases, all passing (31 new: rules written,
  merged, not rewritten, refused on bad files; the one-root rule; convert and
  its .gitignore line; the Lua wrapper's convert; jq missing).
  `test-refusal-gates`: 207 cases, all passing.
- Rolled out on the machine: all 44 projects with a `tmp` link were repaired
  (which wrote their rules), and seven empty disk `tmp` folders (hexfire,
  ao3-source-code-import, authorship-tool, factor-IDE-2, llm-http,
  symbeline-2, translation-layer-wow-chat-city-of-chat) and warcraft-iii's
  wrong-root link were converted; 51 projects in all. The ten settings files
  that existed before were backed up first and compared after: each differs
  only by the two new rules. The six converted projects inside git repositories
  were converted again once convert learned the `.gitignore` line, so their
  doors no longer show as untracked; llm-http and symbeline-2 are their own
  repositories, the other four live in the monorepo.
- Proven live with headless sessions (`claude -p`, Haiku, "accept edits"
  mode, which lets file commands through inside the allowed places and asks
  outside them, an ask showing as a refusal in the session's result record),
  each asked to `mkdir` into both of its rooms:

  | Probe | Set-up | Result |
  |---|---|---|
  | control | rules written, local settings not loaded (`--setting-sources user,project`) | refused |
  | listed | rules written before the session | made |
  | fresh | rooms present, no settings; only the session-start hook writes the rules | made (4 of 4 runs) |
  | rebooted | rules written, then both rooms erased before the session | made |

  The first version wrote extra working folders
  (`permissions.additionalDirectories`) instead of rules. With them, "listed"
  was made but "fresh" and "rebooted" were refused: Claude Code reads that
  list once at start, and does not honour a listed folder that is missing
  then, which after every reboot it is until the session-start hook rebuilds
  it. Rules are re-read when a check is made and are patterns, not folders,
  so neither matters. The folder entries written by the first rollout were
  removed again, exactly the two paths per project, by a one-time script
  (kept in that session's scratchpad, `swap-room-folders-for-rules`).

Why shell commands were asked about (found 2026-10-23 by feeding the hooks
made-up inputs and reading Claude Code's program text, 2.1.284):

- **The first open question's premise was wrong**, and so was
  `README-refusal-gates.md`, where it came from (both corrected). Claude Code
  does check shell commands against its folder list: for the commands that
  write (`mkdir`, `touch`, `rm`, `cp`, `mv`, `>` and the rest) it compares each
  target with the session's working folders and answers "ask" for one outside
  them ("... was blocked. For security, Claude Code may only write to files in
  the allowed working directories for this session"). Issue 043's gate never
  answers "allow" (on purpose), so for a write into the rooms it stayed
  silent and Claude Code asked.
- **A hook's "allow" for shell commands was considered and declined.** It
  would skip the classifier, which the owner's "both tests" rule protects.
  The owner, 2026-10-23: "sure I guess".
- **Three smaller causes**, from a census of every project's `tmp`:
  - 33 links led nowhere (a reboot had emptied RAM; the session-start hook
    rebuilds them, so this only lasted until a session started there);
  - 9 projects had a real folder on disk named `tmp` (7 empty, now
    converted; symbeline-realms, 7.4 MB of demo output, image cache and test
    output, and screen-record-stream, one screenshot, are left alone on the
    owner's word: "let's leave those alone for now");
  - warcraft-iii's link led to `/dev/shm/warcraft-iii-run3` ("not
    deliberate", the owner says). The hooks only accepted an exec room under
    `/tmp`, but the library accepted either root for either room, so it kept
    rebuilding a room the hooks never granted: the two definitions disagreed,
    though this issue's first version said they enforced "the same rule".

What follows is the problem as it was first described (2026-10-20).

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
issue by their choice. (Found wrong 2026-10-23: see above.)

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
`ensure-ram-tiers` enforces since 2026-10-23 — so a `tmp` link pointed at a
disk folder, or at a root itself, never widens the boundary.

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

**Shell commands reach the rooms through path rules in the project's own
settings (added 2026-10-23).** Each project's local settings file
(`<project>/.claude/settings.local.json`, which the owner's global git ignore
keeps out of every repository, so this machine's paths do not spread) holds
one rule per room, naming its real place: `Edit(//tmp/<name>/**)`,
`Edit(//dev/shm/<name>/**)` (the doubled slash is Claude Code's mark for an
absolute path; an `Edit` rule covers every file-writing tool and the write
targets of shell commands). With them, Claude Code's own path check passes for
a shell command writing into the rooms, issue 043's gate stays silent for them
as before, and the classifier still judges the command: both tests, as the
owner asked, and no hook says "allow" for a shell command. The file-tool hook
stays as a second route for the same rooms, and the only one for reading.

Rules, not extra working folders: a listed folder that is missing when Claude
Code starts is not honoured for that session, and the rooms are missing after
every reboot until the session-start hook rebuilds them. Rules are patterns,
are re-read at each check, and so work from the first command of the first
session after a reboot, even when the session-start hook is what wrote them.

Nobody writes these rules by hand, and no CLAUDE.md line asks a session to
(the owner asked whether one was needed, 2026-10-23; it is not, since a tool
does it). `libs/ensure-ram-tiers`, the one definition of the layout, writes
them every time it builds or repairs the rooms, so:

- a new project gets them from `init-project.sh` (ensure mode);
- an existing project gets them from the next session started at its top
  folder (`restore-ram-tiers`, restore mode, counting from that session's
  first command) or the next run script that calls ensure mode;
- a project made by hand with no `tmp` link gets nothing, as before.

The file is only ever added to: anything else in it (other rules, extra
folders, other keys) is left exactly as it was, and a file that already holds
both rules is not rewritten at all. A file that is not readable JSON, or whose
rule list is not a list, is refused with a message and left untouched, never
replaced.

The rules are not marked as the tool's, so the tool never prunes them. A rule
goes stale only when a door is repointed to another room: moving or renaming
a project carries the door with it, still leading to the same rooms. The
owner, 2026-10-25, asked for a note rather than marking and pruning ("let's
make a note in the tool about this"): it sits beside convert mode in the
library, in `libs/ensure-ram-tiers.info.md`, and in the move-project skill,
the guide for moving projects (no tool in delta-version moves them), at its
step for fixing paths in the project's own settings.

**One rule for where a room may be, in both definitions.** The exec room
must lie strictly below `/tmp`, the artifact room strictly below `/dev/shm`,
in `libs/ensure-ram-tiers` exactly as in `libs/own-ram-tiers.lua`. A `tmp`
link leading anywhere else is refused by the library with a message, as a
link into a disk folder already is.

**Projects whose `tmp` is not the standard link are converted by the tool,
on request.** A third mode, `convert`, turns a project's `tmp` into the
standard link when nothing would be lost: an empty folder on disk is
removed and replaced, and a link whose target breaks the rule above is
replaced when that target is missing or empty. Anything holding files, or a
file named `tmp`, is refused with a message. It is for a person to run, never
a hook or a run script: an empty `tmp` folder is also what a project inside an
init-project sandbox correctly has.

**The door stays out of git.** Convert mode, in a git repository, adds the
bare line `tmp` to the project's own `.gitignore` (creating it if needed, only
ever adding), as init-project.sh does for a new project. The owner,
2026-10-25: "it's a build artifact right? maybe we should just .gitignore
it." Only the bare line counts: `tmp/` matches folders only, and git sees a
link as a file, which is why llm-http's door showed as untracked despite its
`tmp/` line. A door git already tracks (gif-generator, scripts) stays tracked:
ignoring does not untrack, and untracking is a commit for that project.

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

Added 2026-10-23, for shell commands:

7. `libs/ensure-ram-tiers`: `ram_tier_path_is_under`, a check that takes the
   root it judges against, in place of the either-root check, so the exec
   room must be under `EXEC_TIER_ROOT` and the artifact room under
   `ARTIFACT_TIER_ROOT` (strictly below, as `own-ram-tiers.lua`'s
   `room_under_root`).
8. `libs/ensure-ram-tiers`: `ram_tier_allow_in_settings`, run at the end of
   `ram_tier_repair_behind_door` (so ensure, restore and convert all reach it,
   and the sandbox case, where `tmp` is a real folder, never does). With jq:
   take the file's contents, or `{}` when there is no file; refuse when it is
   not an object or its `permissions.allow` is not a list; return when both
   rules are already there; otherwise append the missing ones after the rules
   already there, write the result to `<file>.writing-<pid>` beside it and
   move it into place. A missing jq is a refusal.
9. `libs/ensure-ram-tiers`: `convert_ram_tiers` and `--convert` (one row in
   the executed form's dispatch table; `--help` prints the header up to its
   first blank line, so it never needs a line count). A standard door is
   simply repaired; a door into the wrong root is removed when
   `ram_tier_is_empty_or_missing` holds for its target; an empty disk folder
   is removed with `rmdir`; then ensure mode builds the standard door. The
   Lua wrapper gains `tiers.convert`.
10. `libs/ensure-ram-tiers`: `ram_tier_ignore_in_git`, called by convert mode
    after every success: inside a git work tree (`git rev-parse
    --is-inside-work-tree`), append `tmp` to `<project>/.gitignore` unless that
    exact line is there; outside one, do nothing. Beside convert mode, the note
    on stale rules.
11. `tests/test-ram-tiers.sh`: the rules are made when there is no file; a
    person's own rule stays first and other keys survive; a file already
    holding both rules keeps its inode (not rewritten); a file that is not
    JSON, JSON that is not an object, and a rule list that is not a list are
    each refused and left byte for byte; the sandbox case writes no settings;
    restore writes the rules too; a door into the artifact root is refused;
    convert takes an empty folder, a wrong-root door leading nowhere or to an
    empty folder, a standard project and a project with no `tmp`, and refuses
    a folder with files, a wrong-root door whose target holds files, and a
    file named `tmp`; convert outside git writes no `.gitignore`, inside git
    adds `tmp` after the file's own lines (and git then shows no door), and a
    second convert adds no second line; the library refuses without jq.
12. Roll out on the machine: back up each project's existing local settings
    file, run restore mode over every project with a `tmp` link and convert
    mode over the empty disk folders and warcraft-iii, then compare each
    backed-up file with its new self.
13. Prove it live with headless sessions in pretend projects (the four
    probes in Current Behavior), reading the result from Claude Code's own
    record of refusals and from the filesystem, never from what the model
    says.
14. Write it down: the library's header and `libs/ensure-ram-tiers.info.md`
    beside it, `init-project.info.md`, `README-refusal-gates.md` (correcting
    its claim that Claude Code never checks shell commands against its
    folders), the project-init skill's list of what a new project gets, the
    move-project skill's settings step, issue 033's rule for where rooms may
    be, and issue 043's note on why its gate never says "allow".

## Open Questions

- (Answered 2026-10-25.) A rule the tool wrote for a room whose door is
  later repointed stays in the file, since the tool cannot tell its rules from
  the person's. Acceptable, or mark and prune? The owner: "let's make a note
  in the tool about this. Isn't there a tool, maybe in delta-version, for
  moving project directories? Maybe it could go there." Noted in the tool and
  in the move-project skill (delta-version has no moving tool).
- (Answered 2026-10-25.) Six converted projects showed their new `tmp` link
  as untracked; which way should they go, and should convert do it? The
  owner: "it's a build artifact right? maybe we should just .gitignore it."
  Convert mode adds the line; the six were converted again.
- (Answered 2026-10-24, by the probes.) After a reboot, does Claude Code
  honour the rooms before the session-start hook has rebuilt them? Not as
  extra working folders; yes as path rules, which is why rules were chosen.
- (Answered 2026-10-20; its premise found wrong 2026-10-23, see Current
  Behavior.) Should shell commands that only touch the project's RAM tiers
  be allowed the same way? Claude Code's auto mode judges shell commands by
  reading them, not by the folder list, so they are not stopped for this
  reason today; nothing is built for them here. The owner, 2026-10-20: "they
  shouldn't be stopped if they're working on their own files, right?"
  Answered the same day: no "allow" for shell commands. The owner: "we
  should design it so that it gets both tests. They should both be allow for
  it to succeed." A shell command gets a refusal-only gate that judges where
  it writes (the folder and these same tiers), and the classifier still
  judges it after; built in issue 043.

## Related Documents and Tools

- `issues/033-ram-tiers-rebuild-themselves.md` — the tier layout.
- `issues/completed/043-a-shell-command-writes-only-inside-its-own-folder.md`
  — the gate that judges where a shell command writes.
- `libs/ensure-ram-tiers` (and `libs/ensure-ram-tiers.info.md`) — the one
  definition of the layout, its roots, the rules it writes and the
  `.gitignore` line convert mode adds.
- `harness-hooks/restore-ram-tiers` — the session-start hook that rebuilds
  the tiers (and walks upward, which this hook deliberately does not).
- `libs/hook-gate.lua`, `README-refusal-gates.md` — the shared hook parts.
- `tests/test-ram-tiers.sh`, `tests/test-allow-own-ram-tiers.sh`.
- `~/.claude/skills/move-project/SKILL.md` — what to do about the rules when
  a project moves.
