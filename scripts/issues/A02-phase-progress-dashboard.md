# Issue A02: Phase Progress Dashboard

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** High
**Dependencies:** None
**Blocks:** A04 (shares the issue-name reader)

---

## Current Behavior

Built. `progress-dashboard.lua` counts any project's issues by phase and
prints a terminal chart, a markdown table, or JSON. It reads names through the
shared reader `libs/issue-names.lua`, counts an issue as done when it sits in
`issues/completed/`, and prints everything it could not place as a warning
(exit status 1). Tested by `tests/test_issue-names.lua` and by read-only runs
against soren-ds, six-sided-dice-layer-cake, usb-c-universal-encoder,
delta-version, neocities-modernization, apple-IIds, my-own-custom-vtt,
jurassic-maze, symbeline-realms, world-edit-to-execute and wow-chat-2026.

---

## Intended Behavior

One statistics source for issue progress that documentation, phase demos and
the issue-lifecycle skill can point at instead of writing numbers down.

- **Phase from the name, in every shape found on disk.** Compact (`522-x`
  phase 5 issue 22; `1001-x` phase 10 issue 01; `16-x` phase 1 issue 6),
  dashed (`9-007-x`, `10-004c-x`), lettered (`A04-x`). How many digits a
  compact name spends on the issue number is decided per project from
  evidence, because the name alone cannot say whether `1001` is phase 10 or
  phase 1.
- **Status from location.** `completed/` or `done/` = done; `superseded/`,
  `will-not-implement/`, `declined/`, `archive/` = retired (shown, left out of
  the percentage); top level, `pending/`, `unsorted/`, `please-sort/`,
  `design-driven/`, `phase-N/` = open; `demos/`, `examples/`, `analysis/` =
  not issues. Checkboxes are counted for information only.
- **Warnings instead of guesses.** A name with no valid phase, a folder not in
  the table, a phase with no progress file, a split nothing confirmed, or a
  file whose `phase-N/` folder disagrees with its name is reported.
- Progress files (`phase-3-progress.md`, `10-progress.md`) are never counted
  as issues.

---

## Suggested Implementation Steps

1. **Shared reader** — `libs/issue-names.lua` (see its `.info.md`):
   - `split_name` reads one filename into shape, id, sub-issue letter and
     description; nil for files that are not issue-shaped.
   - `location_status` table maps the first folder under `issues/` to a status.
   - `scan` lists every file under `issues/` with `find`, collects phase
     evidence (progress files, `phase-N/` folders), picks the digit width with
     `choose_width`, assigns phases, applies `phase-N/` folder overrides, and
     returns the issues plus a report of everything unplaced.
   - `choose_width` scores widths 2, 1, 3: +10 when a name that states its own
     phase (`1020-phase-10-demo`) splits to it, −10 when it does not, +1 for a
     phase with evidence, −1 for a name left with no valid phase (too short,
     or a leading-zero phase like "02"). Ties go to 2, the house rule's width.
2. **Dashboard** — `progress-dashboard.lua`: `collect` groups the reader's
   issues by phase; three renderers in a dispatch table (terminal, markdown,
   JSON); `warning_lines` turns the report into sentences; argument handlers
   in a dispatch table, unknown flags are errors. Hard-coded `DIR` default,
   overridable by argument.
3. **Tests** — `tests/test_issue-names.lua` builds tiny fake projects in a
   scratch folder: phase-10 names, a width-3 project proven by a demo name, a
   width-1 project, dashed and lettered shapes, retired and unknown folders,
   folder overrides, leading-zero rejection, missing `issues/`.

---

## Scope decisions

- **No per-project symlinks.** The script has one home and is called by
  absolute path; a copy or symlink in each project's `src/cli/` would be a
  second place to go stale.
- **No interactive TUI mode.** The dashboard generates data; a viewer is a
  separate concern (house rule: keep generation and viewing apart). A TUI can
  read `-j` output if one is ever wanted.
- **No caching.** The largest project scanned (neocities, 288 issues) runs in
  well under a second.

---

## Related Documents

- `progress-dashboard.info.md`, `libs/issue-names.info.md`
- `validate-issues` (A04) — reads names through the same reader
- `~/.claude/skills/issue-lifecycle/SKILL.md` — points here for progress numbers

---

## Open questions

- Delta-version files its issues into `phase-1/` and `phase-2/` folders while
  its names count in one sequence (001–057) and its `issues/CLAUDE.md` says it
  has no phases. The dashboard follows the folders and reports the
  disagreement. Should delta-version's names or folders change?
- Neocities has one name, `9-001f1-...`, with a two-level sub-issue index
  ("f1"). The reader does not accept multi-character indexes and reports it.
  Should the naming rule allow them?
