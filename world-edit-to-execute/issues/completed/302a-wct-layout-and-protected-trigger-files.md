# Issue 302a: war3map.wct as the Editor Writes It, and Protected Maps' Trigger Files

**Phase:** 3 - Triggers and JASS
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** 301 (`src/parsers/wtg.lua`), 302 (`src/parsers/wct.lua`), 309a (trigger file tests)
**Related:** A03 (the test runner's 2026-11-06 note), A06 (parser coverage reports the same files)

---

## Current Behavior

Found when the test runner began testing the project's own `assets/`
(A03, 2026-11-06). Two maps added on 2026-11-02 are the first test maps
with `war3map.wtg` and `war3map.wct`, and all four files fail
(`test_309a` 6 failures, `test_wct` 2):

| Map | File | What it holds | Error before |
|-----|------|---------------|--------------|
| Conquest-v8-fix | war3map.wtg | 0 bytes | "Invalid data: too short or nil" |
| Conquest-v8-fix | war3map.wct | 0 bytes | "Empty WCT data" |
| Master-Crafters-Final-Conquest | war3map.wtg | 23 bytes of text, "Universal Conquest Lock" | "expected 'WTG!' magic, got 'Univ'" |
| Master-Crafters-Final-Conquest | war3map.wct | 1,828 bytes: a real file | "String length 1702129221 exceeds data size" |

Three are a map protector's work: the game runs `war3map.j` and never
reads the trigger files, so protectors empty them or put something else
in their place (both maps keep their script, `war3map.j`). The fourth is
a real file the parser misreads:

- **The WCT header.** The parser took version 1's header comment as a
  length-prefixed string and then the trigger count. The file has the
  comment as a NUL-terminated string, then the map's custom script code
  (length-prefixed), then the count. Master-Crafters' file is exactly
  that: version 1, the editor's default comment ("Enter map-specific
  custom script code below. ..."), a custom script of length 0, 417
  trigger entries of length 0, and nothing left over (4 + 148 + 4 + 4 +
  417 x 4 = 1,828 bytes).
- **The closing NUL.** Each length counts the text's closing NUL, which
  the parser returned as part of the text.

## Intended Behavior

- `wct.parse` reads version 1 as above and returns `header_script` (the
  map's custom script code) beside `header_comment`; texts come without
  their closing NUL. Version 0 is read as before.
- `wtg.protected(data)` and `wct.protected(data)` say whether a file looks
  like a protector's work, with the reason; `wtg.parse` and `wct.parse`
  return nil and that reason for such a file, so a caller sees "protected
  map: war3map.wtg is not a trigger file (it starts with 'Univ', not
  'WTG!')" rather than a misleading parse error.
- The tests treat a protected map's file as protected (see the decision
  below), and every other trigger file must parse.

## Acceptance Criteria

- [x] Master-Crafters' `war3map.wct` parses: version 1, the default comment, an empty custom script, 417 entries, none with text
- [x] The three protected files are refused with the protector reason, not a parse error
- [x] `test_309a` and `test_wct` pass; their synthetic WCT data is laid out as the editor writes it
- [x] `test_wtg_*`, `test_triggers`, `test_trigger_editor` pass as before

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/parsers/wct.lua`: `read_cstring` for the comment; the custom script
  read with `read_sized_string`, which now drops a closing NUL and checks
  that its length field is there; a trigger count that can't fit the data
  is refused; `wct.protected`.
- `src/parsers/wtg.lua`: `wtg.protected`, checked first in `wtg.parse`.
  A file that starts with `WTG!` and then fails is still an ordinary
  parse error.
- `src/tests/test_309a_trigger_files.lua`: `make_synthetic_wct` writes the
  editor's layout (comment with NUL, a custom script, NUL-counted
  lengths), with two new checks on the custom script and a text without
  its NUL; the real-map WTG and WCT sections count protected files apart
  and check each is refused with the protector reason.
- `src/tests/test_wct.lua`: `create_wct_data` writes the same layout and
  takes a custom script; new tests for the custom script, an emptied file,
  and Master-Crafters' file read field by field; the real-map list shows a
  protected file as `PROTECTED` and fails if it isn't refused with that
  reason.

### Decisions (2026-11-06)

- **How tests treat a protected map's trigger files.** The issues so far
  (301, 302, 309a) say the test maps are protected and their trigger
  files absent, so coverage of these parsers rests on synthetic data;
  they say nothing of files that are present but emptied or replaced.
  Decided: such a file is recognised (`wtg.protected`, `wct.protected`),
  refused with that reason, and reported as protected, not counted as a
  file that failed to parse. The test still fails if a protected file is
  refused for any other reason, and every trigger file that isn't a
  protector's must parse (Master-Crafters' WCT does). This keeps the
  checks as strict as before for real trigger files; it only stops
  counting a protector's placeholder as a parser bug.
- **What counts as protected.** A WTG file of no bytes or that doesn't
  start with `WTG!`; a WCT file of no bytes. A WCT file with content must
  parse: its first bytes are a version, so there is no magic to tell a
  placeholder from a damaged file, and calling every unreadable WCT
  "protected" would hide parser bugs like the one fixed here.
- **The synthetic WCT data changes, and why.** It was written in the
  parser's old idea of the layout, so it passed while the parser failed on
  the first real file; it now follows the real file. The assertions it
  served are all still made.
- **Version 0** (Reign of Chaos) stays as the parser had it (no comment,
  no custom script); no test map has a version 0 file to check it against.

### Still open

- Reforged's WCT layout (version 0x80000004) is not read; it is refused as
  an unsupported version.
- The parser coverage report (A06, open pull request) counts these files
  as failures; once this is in, it could report protected files apart.
