# Issue A06a: The Coverage Report Names a Protected Map's Placeholders

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Low
**Dependencies:** A06 and 302a (both open pull requests; this branch is a local merge of the two)
**Related:** 302a's "Still open"

---

## Current Behavior

The parser coverage report (A06) counts a file as read, failed or with no
parser. Its first run gave 8 failures; 4 were the trigger files of
Conquest-v8-fix and Master-Crafters-Final-Conquest. 302a found that three
of those are a map protector's placeholders (Conquest-v8-fix's empty WTG
and WCT, Master-Crafters' WTG holding a line of text) and the fourth a
real WCT file the parser misread. It added `wtg.protected` and
`wct.protected`, and the parsers now refuse a placeholder with that reason.
The report still counted those three as failures, so it named as parser
bugs what 302a decided are not.

## Intended Behavior

- A fifth answer, **protected**: the reader's module has a `protected(data)`
  check, it names the file, and the parser refuses the file with that same
  reason. The reason is kept as the file's message.
- Protected files are counted apart from failures everywhere: the totals
  line, two summary columns (maps and files), the matrix (`prot`), a
  "Protected" list in the text and Markdown, and `"protected"` in the JSON.
- They don't make the tool exit 1; failures still do.

## Acceptance Criteria

- [x] Conquest-v8-fix's WTG and WCT and Master-Crafters' WTG report as protected, with the parsers' reasons
- [x] A placeholder the parser refuses for another reason still counts as failed; one the parser reads counts as read
- [x] Totals, summary, matrix, text, Markdown and JSON show protected files apart
- [x] The tool exits 0 when the only problems are protected files
- [x] `test_parser_coverage` covers the above

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/data/parser_coverage.lua`: `reader_for` keeps the module's
  `protected` function when it has one; `read_one` asks it first and gives
  "protected" when the parser's refusal carries the same reason; the
  counts, `map_status`, the summary and totals, the legend and the three
  outputs gain the new answer; `protected_files(report)` lists them.
- `src/tests/test_parser_coverage.lua`: three stand-in readers (refused
  with the reason, refused for another, read after all) and Conquest-v8-fix's
  real trigger files, through the library and the command-line tool.
  95 checks, from 80. Two hand mutations (protected counted as failed;
  the reason not compared) each fail at least one check.
- Run over the 19 maps: 3,416 files, 3,263 read, 3 protected, 4 failed,
  146 with no parser (A06's first run: 3,262 read, 8 failed). The fourth
  trigger file, Master-Crafters' WCT, now reads, from 302a's fix. The four
  failures left are the two units files (fixed in 202f, open pull request)
  and the imported `.blp` and `.mdx`.

### Decisions (2026-11-06)

- **A new answer, not "read" and not "failed".** 302a decided a
  protector's placeholder is "reported as protected, not counted as a
  file that failed to parse"; the report follows. It isn't "read" either:
  nothing was read.
- **The module says what is protected, and the parser must agree.** The
  report asks the module's own `protected(data)` rather than knowing about
  trigger files itself, so a later parser can add such a check without a
  change here. A file is protected only when the parser refuses it with the
  same reason, as 302a's tests require; a placeholder refused for any other
  reason still counts as failed, so a parser bug isn't hidden.
- **Protected files don't fail the tool's exit code,** for the same reason
  they aren't failures: a released map that strips its trigger files is
  normal and nothing the project can fix.
- **They are listed without `-v`.** Unlike failures they carry no stack
  of messages, and which maps are protected is useful to see at a glance.
- **The branch is a local merge** of A06's branch and 302a's, both open
  pull requests, because the change needs both; the pull request is based
  on A06's branch and says so.
