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
