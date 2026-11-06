# Issue 303d: Every Test Map's Script, Read and Analysed

**Phase:** 3 - Triggers and JASS
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** 303 (`src/parsers/j.lua`, `src/tests/test_j.lua`)
**Related:** A03 (the test runner's 2026-11-06 note), 309a (trigger file tests)

---

## Current Behavior

Found when the test runner began testing the project's own `assets/`
(A03, 2026-11-06): `test_j` fails "All test maps should lack war3map.j
(minimal maps)": 17 of 19 lack it; Conquest-v8-fix and
Master-Crafters-Final-Conquest (added 2026-11-02) hold `war3map.j`.

**Why the test asserted it.** Issue 303's implementation notes record, as
a finding, that the 16 test maps of the time held no `war3map.j`
("minimal maps without triggers"), and the test turned that finding into
an assertion. It was never a requirement, and the finding itself was
mistaken: every one of those maps has a script, kept as
`scripts\war3map.j` (where protected maps keep it, and where the game
reads it when there is no `war3map.j`), which `j.extract` didn't look
for. The editor (`editor/init.lua`), the scene loader and the game
(`demo/wc3map/scene.lua`, `game.lua`) already read either name.

Read under that name, the analyser found no functions in 17 of the 19
scripts:

- **Lone CRs.** The DAoW maps' and War-in-the-Plaguelands' scripts end
  most lines with a lone carriage return (as `editor/textedit.lua` notes);
  the analyser split lines on LF only, so it saw a handful of very long
  lines and no `function` at the start of any.
- **`constant function`.** Four DAoW scripts each declare 13 functions as
  `constant function`; the analyser and `j.validate`'s block count took
  only `function`, so those scripts read as unbalanced.

## Intended Behavior

- `j.extract` reads `war3map.j`, or `scripts\war3map.j` when there is
  none, as the rest of the project does.
- `j.parse` analyses a copy of the script in which a lone CR is an LF (the
  same length, so positions still point into `raw`, which stays as
  given); `line_count` counts lines so ended.
- `constant function` declarations are functions, in `j.parse` and in
  `j.validate`'s count.
- `test_j` reads every test map's script and checks it has `main` and
  `config` and validates, in place of the assertion that none has one.

## Acceptance Criteria

- [x] All 19 test maps' scripts are found (2 as `war3map.j`, 17 as `scripts\war3map.j`), have `main` and `config`, and validate
- [x] Synthetic tests: a lone-CR script, a CRLF script, a constant function, and `j.extract`'s two names and their order
- [x] `test_j` passes (112 checks); `test_309a`'s JASS sections pass as before

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/parsers/j.lua`: `j.extract`'s second name; the lone-CR copy in
  `j.parse`; `constant function` in `find_functions` and `j.validate`.
  Only tests use this module, so nothing else changes.
- `src/tests/test_j.lua`: the "Maps Without war3map.j" section becomes
  "Every Map's Script"; a new section for line endings, constant
  functions and the scripts folder. Against the parser before this issue,
  7 of the new checks fail.
- Across the 19 scripts the analyser now finds 625 to 2,921 functions
  each.

### Decisions (2026-11-06)

- **The expectation changes, and why.** The old assertion recorded what
  the old maps were believed to hold, not something the parser should
  ensure, and it was wrong about the old maps too. Every WC3 map runs a
  script, so the test now asserts what is true of every map: a script is
  found, and it has the two entry points and validates. That is a
  stronger check than before: it reads 19 real scripts where the old one
  read none.
- **`scripts\war3map.j` is the second place, not the first**, as in the
  editor and the scene loader: a map with both runs `war3map.j`.

### Still open

- `test_309a`'s "J Parser Tests (Real Maps)" section looks only for
  `war3map.j` (it checks `archive:has` itself rather than calling
  `j.extract`); it reads the two new maps' scripts and passes.
