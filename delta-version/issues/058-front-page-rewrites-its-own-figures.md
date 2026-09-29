# Issue 058: The Front Page Rewrites Its Own Figures

**Status**: In progress (built and tested; open questions below unanswered)
**Priority**: Medium
**Created**: 2026-09-23
**Type**: Extension of the project census (`scripts/census-projects.lua`)
**Related**: `027-basic-reporting-framework.md` (the census answers much of it),
`completed/047-readme-table-of-contents-generator.md` (another generator that
writes a README)

---

## Current Behavior

**Built (2026-09-23).** Every step below is in place, including the
answers the owner gave to the first round of open questions.

- **Slots:** the README holds twenty-five census slots, including both
  tables, and the page is current.
- **Tests:** `scripts/test-census-projects.sh` passes 26 of 26 checks.
- **Commit gate:** a stale page cannot be committed. A tracked hook,
  `scripts/hooks/pre-commit`, is linked in as `.git/hooks/pre-commit`. It
  runs `--check-readme` on the staged README whenever README.md is part of a
  commit, and leaves every other commit alone.
- **Ranking:** changes to a project's materials are not counted. Those are
  `input/`, `output/`, generated `docs/HTML/` and `llm-transcripts/`. One
  regenerated HTML copy had touched 1,522 files in a quarter, and one
  project's changes were 98% transcripts.
- **Phases:** when the dashboard cannot confirm a project's phases, the
  census counts the project's own progress files (`N-progress.md` or
  `phase-N-progress.md`). neocities-modernization therefore shows 17. This is
  a fallback, so it prints a notice every run. It needs at least two
  progress files. The shared `scripts/` project keeps only one, so it shows
  "—".

- **Authorship:** the hero-less-moba "more work than anything else"
  sentence is gone. Its replacement, in the owner's layout, is four slots:
  - `human_written`: the owner's typing, plus every `notes/` folder;
  - `machine_written`: the model's conversation text;
  - `source_generated`: the repository's own code;
  - `docs_generated`: its documents, issue files included.

  All four are read from issue 059's measure. They are printed rounded, with
  the new `millions` format (`tenths` remains available), because the
  totals grow with every conversation, including the one that commits the
  README. Exact figures would be stale before the
  commit gate read them.

The issue stays open until its last open question is answered.

**Before this issue** — the census counted projects and issues and printed
them, and a person copied the printed figures into the root `README.md` by
hand. Between runs the page
drifts: on 2026-09-23 it said ninety projects and 47% where the census said
ninety-one and 46%, and every house-convention count had moved.

Three parts of the page have no generator at all:

- **The Active Development table** — "ranked by files touched in the last
  three months". The ranking, and the phase count in its last column, were
  worked out by hand and had fallen out of order.
- **Numbers written as words inside prose** — "ninety projects",
  "seventy-two sit at the top level", "the other eighteen", "thirteen
  further ideas".
- **The conventions sentence** — "22 have the RAM-tier symlink, 24 read
  from an `input/` directory…". The census's `--conventions` mode prints
  these numbers, but its renderer does the counting itself, so no other
  output can reuse them.

Two argument-handling faults sit in the same code:

- `--dir=` is read only when it is the first argument. Placed after the
  mode, it is silently ignored.
- The overall percentage divides by the total issue count, which can be
  zero when a directory other than this repository is censused. The zero
  becomes the most negative integer LuaJIT can hold, and prints as
  `-9223372036854775808%`.

## Intended Behavior

One command brings every generated figure on the front page up to date,
and a second command reports, without writing, whether the page is stale:

    census-projects.lua --write-readme   # rewrite README.md's marked slots
    census-projects.lua --check-readme   # exit 1 and name the stale slots

The prose stays hand-written. Only the numbers and the two tables are
generated, and each generated value sits between a pair of invisible HTML
comments that name it:

    containing <!-- census:projects:words -->ninety-one<!-- /census --> projects

- The **slot name** before the colon picks a value, from the counts or from
  a table.
- The **format** after it says how to write that value: `digits` (1,259),
  `words` (ninety-one) or `Words` (Ninety-one, for the start of a sentence).
- Block slots (`active_table`, `appendix_table`) sit on lines of their own
  and are replaced whole.

GitHub does not show the comments, so a reader sees plain prose.

**A slot name the census does not know is an error, and so is a marker
with no closing comment.** Either stops the run, and the file is left
untouched. A value that is merely missing never becomes a blank.

### The Active Development table

- **Ranking:** projects are ranked by how many file changes git recorded
  inside each one over the last three months. Each changed path is credited
  to the project whose directory is the longest match at the start of the
  path, so `games/enheim-tome/…` goes to that game and not to `games`.
  The top eleven are shown.
- **Focus column:** read from `delta-version/assets/project-focus.lua`, a
  table of one hand-written sentence per project. When a project enters the
  top eleven without a sentence, the run stops and names the project,
  because the page should not ship with an empty cell.
- **Issues column:** the census's own completed/total count.
- **Phases column:** the number of phases the shared progress dashboard
  finds in the project. If the dashboard raises warnings about that
  project's phase numbering, the cell shows "—" and the census prints a
  notice to stderr naming the project. A guessed phase count is not
  printed.

## Suggested Implementation Steps

1. **Split counting from printing (conventions).** Move the convention
   counts into a data function that returns a table. The terminal renderer
   and the README slots then both read that table.
2. **Measure activity.** Add a data function that reads git history with
   `--name-only` for the last three months, credits each path to a project
   by longest directory-prefix match, and returns the projects sorted by
   change count.
3. **Count phases.** Load the shared progress dashboard as a library
   (`dashboard.collect`, `dashboard.warning_lines`). A project with
   warnings gets no phase count.
4. **Number words.** Add a function that writes 0–999 in English words
   ("ninety-one", "seventy-two"), since numbers in the prose are written
   out.
5. **Slot table.** A dispatch table maps each slot name to a function that
   returns the value, plus a second dispatch table from format name to
   formatter. Both are defined once, and anything missing from them is an
   error.
6. **Splicer.** Read `README.md` and replace every slot's contents. With
   `--write-readme`, write to a temporary file beside the README and rename
   it over the original, so the README is never half-written. With
   `--check-readme`, compare and report.
7. **Arguments.** Read `--dir=` from any position. Treat a zero total as
   0%.
8. **Mark up the README.** Put markers around every figure the census can
   produce. Where a figure has no generator and none is worth writing (for
   example "the seven projects under `games/`"), rephrase the prose so it
   holds no number.
9. **Test.** Add `scripts/test-census-projects.sh`. It runs the splicer on
   copies in a temporary folder and checks that:
   - a second write changes nothing;
   - an unknown slot fails and leaves the file byte-identical;
   - an unclosed marker fails;
   - `--check-readme` exits 1 on a copy with a stale figure;
   - number words are right at the edges: 0, 13, 20, 91, 100, 999;
   - `--dir=` works after the mode as well as before it.
10. **Document.** Update `census-projects.info.md` with the new modes, the
    slot and format tables, and the focus file.

## Answered questions (2026-09-23)

- **The hero-less-moba "more work than anything else" claim:** replace it
  with a comparison of human work against machine work: the characters the
  owner typed (pastes count, because pasting implies reading, except pasted
  error or log text) against what the model produced. Totals and a ratio.
  This is built as issue 059 and becomes a slot here.
- **Commit gate:** yes. Built as the pre-commit hook above.
- **neocities' phases:** "how many phases does neocities have? put that
  number in there." It keeps 17 progress files, and the census now counts
  them when the dashboard cannot confirm the phases itself.
- **Every change or each file once:** neither. The count was inflated by
  input and output materials, which are now excluded.

- **`scripts/` showing "1 phase":** the owner said "you decide". Decided:
  the progress-file fallback needs at least two progress files. A single
  tracker over flat-numbered issues is no evidence of phases, so `scripts/`
  now shows "—".

## Open questions

None remain.
