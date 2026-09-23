# Issue 9-011: Display Content Warnings from ActivityPub

## Status
- **Status**: REOPENED (2026-09-22). Sorted from `next-issue-please-sort`.
- The first round (below, "Original Problem Statement" onward) made content
  warnings appear at all. This round makes the box that holds them fit the
  83-column frame.

## Priority
Medium

## What the Owner Reported

> for this one:
>
> ```
>  -> file: fediverse/696
> ═════════──────────────────────────────────────────────────────────────────────────
>  ┌──────────────────────────────────────────────────────────────────────────────┐
>  │ CW: re:                                                                      │
>  │ scary-absurdist-magic-symbolism-discipline-honor-dedication-virtue-safehavens-meditation-[presupposed │
>  │ destinations]-hypnosis-[clarity of purpose]-[something about how turntables turn │
>  │ or something]                                                                │
>  └──────────────────────────────────────────────────────────────────────────────┘
>
>
>  @user-521
>
>  am i not wretched enough to be
> ┌─────────┐                                                           ┌───────────┐
> │ similar │                       chronological                       │ different │
> ╘════════─┴───────────────────────────────────────────────────────────┴───────────┘
> ```
>
> the content warning is wrapped weirdly. we should be able to wrap on dashes as
> well as spaces. A character counting script, run on the entire output, would
> help identify these issues, which we could solve one by one.

## Current Behavior (reopened)

- **There are five separate content-warning box builders**, and they disagree:
  - The main-thread `format_warning_box` in `src/flat-html-generator.lua`
    (around lines 1702-1730) wraps at 80 using `wrap_single_line_80_chars`
    (around line 1330). That wrapper counts bytes, not visible characters, and
    only breaks at spaces, so a word longer than the line is never split. The box
    interior is then limited to 76 and padded by byte count. Lines of 77-80
    characters, and any long dash-joined run, stick out through the right edge.
    This is exactly the fediverse/696 sample: its warning is 170 characters,
    one run of it is about 95 characters with no space.
  - Two builders inside the threaded worker (around lines 4075-4083 and
    4102-4110) do not wrap at all: the whole warning sits on one line.
  - The word pages (`src/generate-word-pages.lua`, around lines 790-818) also
    do not wrap.
- **Word pages wrap poem text with their own byte-based wrapper**
  (`generate-word-pages.lua`, around lines 823-838). It never breaks long words
  and collapses the author's spacing, unlike the shared
  `wrap_preserving_indent` in `libs/text-formatter.lua` (around line 211), which
  keeps spacing and hard-breaks long words (issue 10-021).
- **Measured across 300 word pages**: warning boxes are the largest single
  cause of over-wide lines, between 86 and 217 columns (see 9-006 for the full
  measurement).
- **The mix of ═ and ─ in the sample is not a box fault.** It is the progress
  fill from issue 8-035: ═ marks the part of the bar already reached, ─ the
  rest. Nine filled cells on the top bar match ╘ plus eight ═ on the bottom
  line. It looks strange only because this poem is placed at about 11%, and that
  percentage is itself wrong (reopened 8-045).

## Intended Behavior (reopened)

One content-warning box, used by every page type, that always fits inside the
frame: every line of it exactly as wide as the frame's interior, measured in
visible characters. Long warnings wrap at spaces and also after dashes. A token
that is still too long for one line (a URL, a magnet link) is cut at the line
edge.

## Suggested Implementation Steps (reopened)

1. **Done 2026-09-22:** `format_cw_box(text, box_width)` in
   `libs/text-formatter.lua`. It takes the warning text and the box's total
   width (the text area is 4 narrower), collapses whitespace runs to single
   spaces, measures in visible columns, breaks at the latest space or just
   after the latest dash that fits (the dash stays on the line), cuts tokens
   that still do not fit, and pads every line to exactly the box width. It
   does not indent the box; the caller places it. Nothing calls it yet — that
   is step 2, which changes every page and is checked against the next build.
2. **Done 2026-09-23.** Replace all five builders (main-thread `format_warning_box`, the two worker
   builders, the word-page builder, and any chronological-page copy) with calls
   to it. The duplicate-code umbrella for this is 8-058, and 10-048 (codebase
   consolidation sweep) is related. Built: all five call
   `format_cw_box(text, 80, true)`; the new `shrink` argument lets a short
   warning keep the small box the pages always drew (text area 20 to 76,
   box 24 to 80), while a long one wraps inside 80. The worker and word-page
   copies indent the box one column, as before (81 at most).
3. **Done 2026-09-23.** Make word pages wrap poem text with the shared
   `wrap_preserving_indent` path instead of their own wrapper. Built: they
   call `format_poem_content(main_content, 80)`, the same one-column margin,
   80-column wrap the other pages use -- visible-width measuring, the
   author's spacing kept, long words (web addresses) cut at the edge. Their
   own wrapper counted bytes, collapsed runs of spaces and never broke a word.
   Checked by rebuilding 60 word pages with the real generator
   (`--html-only --words 60`) and running `scripts/validate-output` on them:
   0 over-wide lines, 0 misshapen frames, 829 warning boxes on those pages
   (the full scan before the change had 23,858 over-wide lines across the
   7,283 word pages, 18,281 of them warning boxes).
4. Tests, beside the existing text-formatter tests (**done 2026-09-22** in
   `libs/text-formatter-test.lua`, all passing; the accented-letter case uses
   "café &amp; crème", the emoji case one 🔥):
   - The fediverse/696 warning produces lines all exactly as wide as the box.
   - Breaks land after dashes when no space is available, and the dash stays
     at the end of the broken line (owner's choice, see Open Questions).
   - A 340-character magnet link is cut into full-width pieces.
   - A warning with emoji or accented letters is padded by visible width.
5. Run the whole-output width validator from reopened 9-006; warning-box lines
   must no longer appear in its report.

## Open Questions

1. When a line breaks at a dash, should the dash stay at the end of the line
   (`virtue-` / `safehavens`) or start the next line (`virtue` / `-safehavens`)?
   The owner asked for an example (2026-09-22: "Dunno. Gimme an example?").
   The CW text `magic-symbolism-discipline-honor`, broken to fit 20 columns:

   Dash stays at the end of the line:
   ```
   magic-symbolism-
   discipline-honor
   ```
   Dash starts the next line:
   ```
   magic-symbolism
   -discipline-honor
   ```
   **Answered** (2026-09-22): "Oh yeah let's say the dash stays at the end."
   The dash stays at the end of the line it breaks (`magic-symbolism-` /
   `discipline-honor`). Step 1's formatter and step 4's dash test follow this.

## Original Problem Statement

Content warnings from Mastodon/ActivityPub posts are not displaying in the HTML output. The ActivityPub `summary` field contains content warnings (CW) that were extracted and stored in `poem.content_warning`, but the HTML generation code only detects in-content "CW:" patterns and misses the ActivityPub field.

**Current behavior:**
- In-content patterns like "CW: topic" or "content warning: topic" are detected and displayed
- ActivityPub content warnings stored in `poem.content_warning` are ignored
- 1,781 poems have content warnings but they don't appear in HTML output

**Expected behavior:**
- Both ActivityPub content warnings (`poem.content_warning`) AND in-content patterns should display
- Content warnings should appear in a box at the top of the poem
- Content warnings should NOT be included in embeddings (semantic similarity)

## Root Cause Analysis

The HTML generation code in `flat-html-generator.lua` was checking for content warning patterns in the poem text content but never looking at the separate `poem.content_warning` field that stores the ActivityPub `summary` value.

The data flow is:
1. ActivityPub extraction (`input/fediverse/files/poems.json`) stores `summary` → `content_warning`
2. `poem-extractor.lua` loads this into `poem.content_warning` (separate from `poem.content`)
3. `flat-html-generator.lua` only checked for in-content "CW:" patterns

## Solution

Add content warning display from `poem.content_warning` field at two locations:
1. `format_content_with_warnings()` - for chronological page
2. effil worker thread's `format_poem_entry()` - for similar/different pages

Both locations now:
1. Check if `poem.content_warning` exists and is non-empty
2. Display it in a box before the poem content
3. Continue to also detect in-content "CW:" patterns (for posts that embed CW in content)

## Embedding Exclusion Verification

Content warnings are **NOT** included in embeddings because:
1. `poem.content_warning` is a separate field from `poem.content`
2. Embedding generation uses only `poem.content` via `extract_pure_poem_content_for_embedding(poem.content)`
3. The two fields are never mixed - content warnings stay in their own field

## Files Modified

| File | Change |
|------|--------|
| `src/flat-html-generator.lua` | Added `poem.content_warning` display at lines 1619-1627 (chronological) and lines 2910-2922 (effil worker) |

## Test Cases

1. **Poems with `poem.content_warning` set:**
   - Should display CW box at top of poem
   - CW text should appear as "CW: [content_warning_text]"

2. **Poems with in-content "CW:" pattern:**
   - Should still detect and display these as before
   - Works independently of ActivityPub content warnings

3. **Poems with both:**
   - ActivityPub CW displays first (from `poem.content_warning`)
   - In-content CW displays second (if present)

## Related Documents

- `input/fediverse/files/poems.json` - Contains `content_warning` field
- `src/poem-extractor.lua` - Loads content_warning at lines 272, 323-324, 344
- `src/similarity-engine.lua` - Uses only `poem.content` for embeddings (line 527)

## Metadata

- **Status**: REOPENED 2026-09-22 (first completed 2026-01-21)
- **Related**: 8-045 (progress percentage), 8-058 (duplicate code), 9-006
  (width validator), 10-021 (whitespace-preserving wrap), 16-010 (mobile layout)
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 9 (Performance Optimization / Bug Fix)
- **Estimated Complexity**: Low
- **Dependencies**: None
- **Affects**: All page types with content warning display

---

## Implementation Progress

### 2026-01-21: Implementation Complete

**Changes Made:**

1. **`src/flat-html-generator.lua`** - Added ActivityPub content warning display
   - Lines 1619-1627: `format_content_with_warnings()` now checks `poem.content_warning` first
   - Lines 2910-2922: effil worker thread checks `poem.content_warning` before in-content CW patterns
   - Both locations use consistent box formatting with proper spacing

**Behavior After Fix:**

1. ActivityPub content warnings display in a box at top of poem
2. In-content "CW:" patterns continue to work
3. Content warnings remain excluded from embeddings (separate field)
4. Both chronological and similar/different pages show content warnings
