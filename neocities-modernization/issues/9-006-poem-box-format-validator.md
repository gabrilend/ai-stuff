# Issue 9-006: Poem Box Format Validator

## Status
- **Status**: REOPENED (2026-09-22). Sorted from `next-issue-please-sort`.
- **Build this first** among the issues reopened on 2026-09-22 (8-045, 9-011,
  10-025, 10-036, 16-010, 2-010). It measures the problems those issues fix, so
  it gives a baseline before any of them change and a pass/fail check after.

## What the Owner Reported

> dear AI, please write a character counting script and count every line before the
> program is is finished.

and, under the fediverse/696 sample (see 9-011):

> A character counting script, run on the entire output, would
> help identify these issues, which we could solve one by one.

## Current Behavior

`scripts/validate-poem-box-format` exists (built 2026-03-18, described under
"Implementation Complete" below) but does not do what the owner asks:

- **It checks one file at a time.** It takes a single file (or `--test`), has no
  way to walk `output/`, and nothing in `run.sh` calls it.
- **Its size constants are out of date** (around lines 22-37 of the script): it
  expects an 82-column frame, the right junction at column 69 and a 58-column
  gap between the navigation boxes. The real values are 83, 70 and 59.
- **It does not decode HTML entities**, so `&amp;` counts as five characters
  instead of one.
- **It treats a whole `<pre>` block as one poem box.** Run on
  `output/wordcloud/affection.html` it reports 1361 errors. 652 of them are
  "expected 82, got 83" and 326 are "expected 84, got 83": correct lines
  flagged as wrong.

**What the output actually looks like** (measured 2026-09-22 on 300 word pages
under `output/wordcloud/`, counting visible characters on each line inside
`<pre>` after removing tags and decoding entities; the poem pages themselves
were not on disk to measure):

- 371,900 lines are 83 columns (the regular frame) and 176,648 are 84 (the
  golden frame).
- **966 lines are wider than 84**, the widest 340 columns.
- Causes of the over-wide lines: content-warning boxes (86-217 columns, see
  9-011), URLs (93-159), dash-joined text (89, 177), one `magnet:` link (340),
  and golden-frame lines (90).

## Intended Behavior (reopened)

One command that checks every generated page and fails the build when any line
is wider than its frame, or when any link points at a page that does not exist.
Its report groups the problems by cause, so they can be fixed one kind at a
time, as the owner asked.

## Suggested Implementation Steps (reopened)

1. Rewrite `scripts/validate-poem-box-format` (or replace it with a new
   whole-output validator) in the house script shape: a hard-coded `${DIR}` at
   the top that an argument can override, all paths relative to it.
2. Walk every `output/**/*.html` file, spread across all CPU cores (the owner's
   rule: batch work is never single-threaded).
3. For each line inside `<pre>`: remove tags, decode entities, count visible
   UTF-8 characters.
4. Decide the allowed width from the kind of frame the line belongs to: 83 for
   a regular frame, 84 for a golden frame, the boost-bar width for boosts.
   Correct the size constants to 83 / 70 / 59.
5. Sort each over-wide line into a cause: content-warning box, URL, plain
   text, progress bar, frame border.
6. Check every relative link in every page resolves to a file that exists.
   This is the check that catches the "next page" not-found reported in 10-036.
7. Write the grouped report, with file and line for each problem, into
   `tmp/shared-memory/`, making sure that folder exists first. Print counts per
   cause. Exit non-zero if anything is over-wide or any link is broken.
8. Call it from `run.sh` after the HTML and word-page stages, and show its
   counts in the phase demo.
9. Keep the `--test` self-tests, updated to the real sizes, and add cases for
   entity decoding and multi-byte characters.

## Related Issues

- 8-045 (reopened) — progress bars over-long because the percentage is over 100
- 9-011 (reopened) — content-warning boxes wider than the frame
- 10-036 (reopened) — "next page" link to a page that was never written
- 16-010 (reopened) — mobile layout; needs over-wide lines gone first
- 8-058 — duplicate bar and box drawing code

## Original Intended Behavior

A programmatic validator that checks character counts and structure for each line of a formatted poem box:

### Expected Structure (Regular Poems - 82 chars)
```
═══════════════════════════════════════════════════════════════────────────────────  (82 chars: progress bar)
 content line 1 (up to 80 chars)
 content line 2
┌─────────┐                                                            ┌───────────┐  (82 chars: 11 + 58 + 13)
│ similar │                      chronological                         │ different │  (82 visible chars)
╘═════════╧══════════════════════════════════════════════════──────────┴───────────┘  (84 chars with corners)
```

### Validation Rules
1. **Top progress bar**: Exactly 82 characters (═ and ─ only)
2. **Content lines**: Start with single space, up to 80 chars content
3. **Nav top line**: Exactly 82 chars (11 + 58 spaces + 13)
4. **Nav middle line**: 82 visible chars (excluding HTML tags)
5. **Bottom line**: 84 chars total (╘ + 82 interior + ┘), with junctions at positions 10 and 69

### Junction Character Rules
- Position 10: ╧ if in progress section, ┴ if in remaining section
- Position 69: ╧ if in progress section, ┴ if in remaining section

## Suggested Implementation Steps

1. Create `validate_poem_box_format(formatted_output)` function
2. Strip HTML tags for visible character counting
3. Check each line type against expected character count
4. Verify junction characters at correct positions
5. Return validation report with line-by-line results
6. Optionally integrate into HTML generation pipeline for automatic validation

## Example Validation Output
```
Line 1 (progress bar): 82 chars - OK
Line 2 (content): 45 chars - OK
Line 3 (nav top): 82 chars - OK
Line 4 (nav mid): 82 visible chars - OK
Line 5 (bottom): 84 chars - OK
  - Left junction at 10: ╧ (in progress) - OK
  - Right junction at 69: ┴ (in remaining) - OK
```

## Related Documents

- Issue 9-003: HTML Rendering and Performance Fixes (formatting fixes)

## Priority

Medium - Useful for development and preventing regression.

## Implementation Notes

### Character Count Reference
- Regular poem width: 82 chars interior
- Golden poem width: 84 chars interior (with ╔ and ┐/┤ borders)
- Progress bar: 82 chars (═ for progress, ─ for remaining)
- Nav box left: 11 chars (┌─────────┐ or │ similar │)
- Nav box right: 13 chars (┌───────────┐ or │ different │)
- Nav box gap: 58 chars (for regular) or 60 chars (for golden)

### Implementation Complete (2026-03-18)

Created `scripts/validate-poem-box-format`:
- UTF-8 aware character counting via `count_visible_chars()`
- HTML tag stripping via `strip_html_tags()`
- Line type detection: progress bars, nav boxes, bottom lines, content
- Golden poem detection (╔ corner character)
- Junction character position validation
- Self-test suite (`--test` flag) - all 5 tests pass
- File validation mode for checking actual HTML output

**Discovery**: Initial validation of production HTML revealed poem boxes are 83 chars wide rather than the documented 82 chars. This indicates either:
1. The CONFIG constants need calibration to match actual dimensions
2. There's formatting drift that should be investigated

The validator is functional and serves as a diagnostic tool. CONFIG constants can be adjusted as actual dimensions are verified.

**Files Created**:
- `scripts/validate-poem-box-format` (476 lines)
