# Issue 042a: The Integration Audits Still Unbuilt

**Parent:** 042 (project integration checker) -- completed
**Type:** Tool extension
**Script:** `delta-version/scripts/check-utilities.sh`

---

## Current Behavior

The checker built under 042 audits delta-version's own scripts (present,
executable, parse cleanly, sane first line), checks the external tools it
depends on, checks the folder layout, and walks every project for
`project.meta.json` and the `delta-guide.md` link, fixing what it can and
filing issue files for what it cannot.

Three of the flags it advertises in `--help` do nothing yet:
`--tui-audit`, `--transcripts` and `--issue-standards` print
"TUI/transcript/issue checks not yet implemented" (the placeholder sits
near the end of the script, under the "TODO: Implement TUI audit" comment).
042 listed these as deferred when it finished; they are carried here so 042
could move to completed/ without leaving work unrecorded, which is the
house rule for an issue with deferred work.

---

## Intended Behavior

Each advertised flag does what it says, or is removed from the help text.

1. **`--issue-standards`** -- for every project, every issue file has the
   three required sections (Current Behavior, Intended Behavior, Suggested
   Implementation Steps) and a name of the house shape
   (`{PHASE}{ID}-{DESCR}`, sub-issues `{PHASE}{ID}{INDEX}-{DESCR}`).
   Before building this, check whether the issue-lifecycle skill's
   validator (planned under `scripts/issues/A04-issue-validator.md`) already
   covers it; if it does, this flag calls that validator rather than
   holding a second copy of the rules.
2. **`--transcripts`** -- every project that has conversations under
   `~/.claude/projects/` has an `llm-transcripts/` folder, and the folder is
   not empty. The "is each transcript in the right project" half already
   exists as `scripts/check-transcripts-are-filed-right`; call it, do not
   repeat it.
3. **`--tui-audit`** -- decide first whether this is still wanted. It was
   meant to find scripts with hand-rolled menus that should use the shared
   bash menu library, and that library is itself on its way out in favour of
   the Lua menu. If it is not wanted, remove the flag and its help line.

Not carried over from 042's deferred list, on purpose:
- *Integration status file (`config/project-integration.json`)* and
  *shared-utilities registry (`config/shared-utilities.conf`)* -- the
  project census (`scripts/census-projects.lua --conventions`) now answers
  "which projects have which conventions" from the files themselves, which
  is the house preference over a hand-kept status file that goes stale.
- *Symlink suggestions beyond delta-guide.md* -- no second shared file has
  been proposed for linking.

---

## Suggested Implementation Steps

1. Read the placeholder block in `check-utilities.sh` and the three flag
   handlers in its argument parser.
2. Decide `--tui-audit` (keep or remove) with the owner.
3. Implement `--transcripts` by calling the existing filing check and
   adding the "folder exists and is not empty" test.
4. Implement `--issue-standards` on top of the shared validator once it
   exists (see A04 in `scripts/issues/`).
5. Add each new check to the script's own test run and to
   `delta-version/issues/progress.md`.

---

## Open Questions

- Is `--tui-audit` still wanted now that the bash menu library is being
  retired?

---

## What Happened (2026-11-02)

All three flags are settled; nothing in `check-utilities.sh` prints "not yet
implemented" any more.

- **`--issue-standards`** runs the shared validator (`scripts/validate-issues`,
  the tool A04 planned) on each project and counts every line it prints as a
  finding. No rule is copied into the checker: names, sections, duplicate ids,
  orphan sub-issues and one-sided links are all the validator's. A project
  with no `issues/` folder is noted and not counted. The first ten findings
  per project are printed, then "... and N more" and the validator command
  that prints them all.
- **`--transcripts`** counts the conversations Claude Code has on record for
  the project's own folder (under `~/.claude/projects/`, or
  `CLAUDE_SESSIONS_ROOT`), looking the folder up both as written and with
  symlinks resolved. With any on record, `llm-transcripts/` must exist and not
  be empty. The filing half is `scripts/check-transcripts-are-filed-right`
  run with the project folder as its root.
- **`--tui-audit`** is removed, flag, variable and help line. An unknown
  option is now refused with exit 1 instead of being taken as a project name,
  so the old flag says it is gone rather than quietly "checking" a project
  called `--tui-audit`.

Two faults found on the way were fixed:
- `--all-projects` found nothing outside Ritz's machine:
  `list-projects.sh` was called with no directory, so it scanned its own
  hard-coded default, and when external projects are included (the config's
  default) it ignored a directory given on the command line anyway. The
  checker now names its own monorepo, and `list-projects.sh` passes the
  named directory through to the listing that includes externals.
- An issue filed from a project audit ("create issue file") went into
  delta-version's `issues/` folder whatever project it was about; it now goes
  into the audited project's.

**Decisions (the open question, answered):**
- `--tui-audit` is not wanted. The bash menu library it would have pushed
  scripts towards is being retired for the Lua menu, and moving scripts onto
  the Lua menu is already tracked in `scripts/issues/014`.
- Both new audits report only. Their remedies are an edit to issue files or a
  run of the exporter (the only program allowed to write and name
  transcripts), so offering to "fix" or to file an issue per finding would
  only add noise; findings are counted as skipped and the run exits 1.
- A record folder's name is the path with every character that is not a
  letter, digit or dash turned into a dash, which is how Claude Code names
  them. The shared filing check only turns slashes into dashes and does not
  resolve symlinks, so an export it calls misfiled is counted only when the
  record it points to is under neither of the project's own keys.
- Only conversations started in the project folder itself count. One started
  in a subfolder or at the monorepo top does not say which project it was
  for, and a prefix match would confuse `console-demakes` with
  `console-demakes-2`.
- `luajit` joins the dependency check, since the validator runs on it.

**Tested:** `scripts/test-check-utilities.sh` (new, 26 checks) builds a
pretend monorepo in RAM with the real checker, lister and shared tools
linked in, projects each wrong in one way, and a pretend conversation store;
run as `scripts/test-check-utilities.sh <monorepo>`. A run over this
monorepo's real projects (`--all-projects --issue-standards --transcripts`)
completes and reports the findings the validator gives directly.
