# Issue A04: Issue Validator

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Dependencies:** A02 (shared issue-name reader)

---

## Current Behavior

Built. `validate-issues` checks any project's issue files and prints one line
per finding, then the next free id per phase. Tested by
`tests/test_validate-issues.lua` and by read-only runs against enheim-tome (0
findings, matching its own `validate-issue-graph`), soren-ds,
my-own-custom-vtt, scripts, delta-version, wow-chat-2026 and
neocities-modernization — each of which has real findings to work through.

---

## Intended Behavior

A project-abstract checker the issue-lifecycle skill runs when an issue is
created, edited or completed.

- **Names** follow `{PHASE}{ID}{INDEX}-{DESCR}`: `.md` extension, description
  in lower-case words joined by dashes.
- **Sections**: every open issue has headings containing "Current Behavior",
  "Intended Behavior" and "Implementation Steps" (the three the house rules
  require). Completed issues are immutable, so their sections are checked only
  with `--completed`.
- **Duplicate ids** among open and completed files (a superseded file keeping
  an old id is history, not a collision).
- **Orphan sub-issues**: `104a` with no `104`.
- **Links**: ids named under "Blocked by", "Blocks", "Dependencies" or
  "Depends on" must have files; when a project writes links in both
  directions, each link must be stated on both sides. Links in retired files
  are ignored.
- **Next free id** per phase, in the phase's own shape; `--next PHASE` prints
  only that.
- Findings are errors (exit 1): the house rule counts warnings as errors.

---

## Suggested Implementation Steps

1. **Read names through the shared reader** `libs/issue-names.lua` (built in
   A02), so phases agree with the dashboard. Numbering uses `name_phase` (what
   the name says), not a `phase-N/` folder override.
2. **Link fields in four shapes** — `extract_links`: a header-table row
   (`| Blocked by | 101 |`), a bold label (`**Blocks:**`), a bold bullet
   (`- **Blocks**:`), or a `##` heading whose body runs to the next heading.
   Labels map to a direction in the `link_labels` table.
3. **Ids from free text** — `ids_in_text`: dashed ids removed first, then
   lettered, then compact; a token counts only if it names a phase the project
   has issues in, so years, percentages and "Phase 4" are not links.
4. **Checks** — `check_name`, `check_sections`, duplicate and orphan passes,
   then the edge pass collecting "blocker → blocked" pairs with who asserted
   them, and the agreement pass (only when both directions are in use).
5. **Options** in a handler table: `[DIR]`, `--next PHASE`, `--file PATH`
   (per-file checks for one file, links that touch it), `--completed`.
   Unknown flags are errors. Hard-coded `DIR` default.
6. **Tests** — `tests/test_validate-issues.lua`: a clean project exits 0 and
   numbers correctly; a messy project shows each finding kind once; `--file`
   narrows; a missing `issues/` exits 2.

Ancestor: `/mnt/mtwo/programming/ai-stuff/games/enheim-tome/validate-issue-graph`
(link agreement for one project's table-row format). This tool generalises its
check and does not edit files; its `--fix` union rewrite was not carried over.

---

## Scope decisions

- **No acceptance-criteria or header-field checks.** The house rules require
  three sections, not checkboxes or a Phase/Type/Priority header; checking
  for them would fail most projects for following the rules.
- **No `--fix`.** Rewriting issue files automatically would touch completed
  issues, which are immutable; a person or the skill fixes the open side.
- **No JSON or quiet mode.** Findings are already one line each and the exit
  status is the quiet answer.
- **No per-project symlinks.** One home, called by absolute path.

---

## Related Documents

- `validate-issues.info.md`, `libs/issue-names.info.md`
- `progress-dashboard.lua` (A02)
- `~/.claude/skills/issue-lifecycle/SKILL.md`

---

## Open questions

- Several projects write links in both directions but keep them only half in
  step (soren-ds ≈320 one-sided links, my-own-custom-vtt ≈80, delta-version
  ≈80). Should the one-sided check stay strict, or should a project be able to
  declare that it records links in one direction only?
- `wow-chat-2026` has about 70 issue files without a `.md` extension
  (`1001-rmail-dns-style-addresses`, ...). Rename them, or treat
  extensionless files as a separate convention there?
