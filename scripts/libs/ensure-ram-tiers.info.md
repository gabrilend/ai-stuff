# ensure-ram-tiers

The one definition of a project's RAM scratch space: builds it, repairs it
after a reboot has emptied RAM, and lets Claude Code sessions in the project
write into it without being asked (issues 033, 042). Bash, sourced or run;
`ensure-ram-tiers.lua` beside it calls it for Lua programs rather than
restating the layout.

Layout: `<project>/tmp` → `/tmp/<name>` (exec room; `/tmp/<name>/tmp/` holds
things that get executed) and `/tmp/<name>/shared-memory` → `/dev/shm/<name>`
(artifact room: logs, builds). The exec room must lie strictly below `/tmp`,
the artifact room strictly below `/dev/shm` — the same rule as
`own-ram-tiers.lua`, which the access hooks use. `EXEC_TIER_ROOT` and
`ARTIFACT_TIER_ROOT` in the environment move the roots, for tests only.

After every build or repair it gives `<project>/.claude/settings.local.json`
two path rules, `Edit(//tmp/<name>/**)` and `Edit(//dev/shm/<name>/**)`, by
the rooms' real places. Only ever adds; a file already holding both is not
rewritten; a file that is not a JSON object is refused and left untouched.
Rules rather than extra working folders, because a folder that is missing
when Claude Code starts (as the rooms are after a reboot) is not honoured,
while a rule is. Needs jq.

| mode | executed | sourced | does |
| --- | --- | --- | --- |
| ensure | `ensure-ram-tiers [--ensure] <project>` | `ensure_ram_tiers <project>` | for tools about to write into `tmp/`: makes the door if missing, rebuilds the rooms, writes the rules; a real `tmp` folder (an init-project sandbox) is left alone |
| restore | `ensure-ram-tiers --restore <project>` | `restore_ram_tiers <project>` | for the session-start hook: as ensure, but never makes a door that is not there |
| convert | `ensure-ram-tiers --convert <project>` | `convert_ram_tiers <project>` | for a person: replaces an empty on-disk `tmp`, or a door into the wrong place that leads nowhere or to an empty folder, with the standard door; refuses anything that would lose files; in a git repository adds the bare line `tmp` to the project's `.gitignore` (`tmp/` does not match a link) |

Every mode takes one project folder (string, relative or absolute), prints
nothing on success, and on failure prints one line beginning
`ensure-ram-tiers:` to standard error and returns 1 (it never exits when
sourced). `--help` prints the file's header.

Lua: `tiers.ensure(project [, scripts_dir])`, `tiers.restore(...)`,
`tiers.convert(...)`; a refusal becomes a Lua error carrying the same line.

Rules are not marked as this tool's, so a rule for a room whose door was
later repointed stays in the settings beside the new one. Moving or renaming
a project does not cause that (the door goes with it); the move-project skill
says what to look for when a door is repointed.

Tests: `tests/test-ram-tiers.sh` (run with `test-refusal-gates`).
