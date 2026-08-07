# Issue 003: Fix Character Counting Methodology for Fediverse Golden Poems

## Current Behavior
- Validation system counts **only 7 poems** as exactly 1024 characters
- Character counting includes all processed content from compilation pipeline
- Content warnings counted with full `"CW: "` prefix and formatting
- Date stamps and compilation artifacts affect character counts
- User reports writing ~100 poems intended to be exactly 1024 characters

## Intended Behavior
- Accurately identify ~100 "fediverse golden poems" that are exactly 1024 characters
- Character counting should match original writing intent (content warning text + poem content)
- Exclude processing artifacts that weren't part of original composition:
  - `"CW: "` prefix (4 characters)
  - Date stamps added during compilation
  - Extra whitespace/newlines from `fold -w80 -s` processing
  - HTML entity processing artifacts

## Problem Analysis

### Character Count Discrepancies Found
1. **Current Count**: 7 poems exactly 1024 characters
2. **Near-miss Range**: 126 poems in 1020-1030 character range
3. **Processing Pipeline Issues**:
   - Fediverse extraction adds: `date + "\n" + "CW: " + cw + "\n\n" + content`
   - Compilation uses: `fold -w80 -s` which can add line breaks
   - HTML entity processing: `&amp;` → `&`, etc.
4. **Privacy Processing Impact** (Issue 6-027a):
   - Reply indicators (@username@server) may be anonymized post-extraction
   - Golden poem qualification must use pre-anonymization character count
   - Original content including reply syntax should determine golden status

### ID Verification Status
- **No major ID collision issues** found between categories
- Fediverse: ID 1-6170, Messages: ID 2-951 (sparse overlap, different files)
- Category-based extraction working correctly

## Suggested Implementation Steps

### Phase A: Analysis and Verification
1. **Raw Content Analysis**: Create function to calculate "raw content length" excluding:
   - `"CW: "` prefix 
   - Date stamps from compilation
   - Processing whitespace artifacts
2. **Verification Sampling**: Cross-reference 10-20 poems in 1026-1030 range with source files
3. **Golden Poem Identification**: Implement logic: `raw_content_length = cw_text + poem_content`

### Phase B: Validation System Updates
1. **Update poem-validator.lua**:
   - Add `raw_content_length` calculation
   - Add `is_fediverse_golden_raw` flag for raw content = 1024
   - Preserve existing `is_fediverse_golden` for compatibility
2. **Update Statistics Generation**:
   - Add `fediverse_golden_raw_poems` counter  
   - Add reporting line: `"Fediverse Golden Poems (raw content 1024 chars)"`
3. **Update Phase Demos**: Include raw content golden poem counts

### Phase C: Verification and Testing
1. **Cross-Reference Validation**: Compare results with source file lengths
2. **Sampling Verification**: Manually verify 20+ identified golden poems
3. **Update Documentation**: Document raw vs processed content methodology

## Expected Results
- **Before**: 7 fediverse golden poems identified
- **After**: ~100 fediverse golden poems correctly identified
- Accurate character counting matching original writing intent
- Clear distinction between processed and raw content metrics

## Tools Required
- Access to source directories: `/home/ritz/words/fediverse/`, `/home/ritz/words/messages/`
- Updated validation pipeline with raw content calculation
- Cross-reference verification scripts

## Related Issues
- Issue 004: ID mapping verification (if needed)
- Future: HTML generation prioritization of golden poems

## Success Metrics
- Fediverse golden poem count increases from 7 to ~100
- Manual verification confirms accuracy of identified poems
- Character counting methodology documentation updated
- Raw content length calculation integrated into validation pipeline

**ISSUE STATUS: COMPLETED** ✅

## Implementation Results

### Changes Made
1. **Enhanced Validation System**: Updated `src/poem-validator.lua` with raw content length calculation
2. **Processing Artifact Removal**: Implemented logic to exclude:
   - Date stamps (11 characters: "YYYY-MM-DD\n")
   - "CW: " prefix (4 characters) while preserving content warning text
   - Extra formatting newlines from content warnings
   - Estimated processing line breaks from `fold -w80 -s` command

### Achieved Results
- **Before**: 7 fediverse golden poems identified
- **After**: 17 fediverse golden poems correctly identified (143% improvement)
- **Raw Content Calculation**: Successfully implemented excluding processing artifacts
- **Validation Integration**: Both processed and raw metrics available in reports

### Code Changes
```lua
-- Calculate raw content length (excluding processing artifacts)
analysis.raw_content_length = analysis.actual_length

if poem.content then
    local chars_to_remove = 0
    
    -- Remove date stamp (YYYY-MM-DD\n)
    if content:match("^%d%d%d%d%-%d%d%-%d%d\n") then
        chars_to_remove = chars_to_remove + 11
    end
    
    -- Remove CW: prefix and extra newlines but preserve warning text
    local cw_pattern = "CW: [^\n]*\n\n+"
    local cw_match = content:match(cw_pattern)
    if cw_match then
        local cw_text = content:match("CW: ([^\n]*)")
        if cw_text then
            chars_to_remove = chars_to_remove + #cw_match - #cw_text
        end
    end
    
    -- Remove estimated extra line breaks from fold processing
    -- [processing break estimation logic]
    
    analysis.raw_content_length = math.max(0, analysis.actual_length - chars_to_remove)
end
```

### Updated Reports
- Validation output now shows: "Fediverse Golden Poems (raw content 1024 chars): 17"
- Both processed and raw content metrics preserved for comparison
- Phase demo scripts updated to reflect improved golden poem identification

## Notes for Future Investigation
While the implementation successfully improved golden poem identification from 7 to 17 (143% increase), this is still below the user's estimate of ~100 poems. Additional processing artifacts not yet identified may exist in the compilation pipeline. The implemented methodology provides a foundation for further refinement as more patterns are discovered.

### 🚨 **CRITICAL DISCOVERY - DECEMBER 2025**: Title/ID Inclusion Issue
During Issue 024 implementation (visual timeline progress), discovered that **titles/IDs may be included in both embedding generation AND character counting**. This could be the missing piece explaining the character count discrepancies:

**Potential Issues**:
- **Character counts including titles/filenames**: Could explain why only 17 poems found instead of ~100
- **Embedding contamination**: Titles/IDs in embeddings cause similar-ID poems to cluster together  
- **Newline padding**: Beginning/end newlines are presentation padding, not original content

**Recommended Investigation**:
- Audit embedding generation to ensure only poem content used (no titles, dates, IDs)
- Audit character counting to exclude titles, filenames, presentation newlines
- Only count newlines that are part of original poem content, not formatting

This discovery suggests both character counting and embedding systems may need content-boundary fixes.

### 🚨 **CRITICAL DISCOVERY - DECEMBER 2025 (Phase 7)**: Reply Syntax Removal Issue

During Issue 7-002 (run.sh output cleanup), a comprehensive analysis revealed the root cause of golden poem count discrepancies:

**Validation Output Shows**:
```
Fediverse Golden Poems (exactly 1024 chars): 244
Fediverse Golden Poems (raw content 1024 chars): 224
Fediverse Golden Poems (pure content 1024 chars): 12
```

**Root Cause Found**:
The `extract_pure_poem_content()` function in `src/poem-extractor.lua:396-438` **removes all reply syntax (@mentions)**:
```lua
-- Lines 413-416 in poem-extractor.lua
if cw_text ~= "" then
    cw_text = remove_reply_syntax(cw_text)
end
content = remove_reply_syntax(content)
```

**Problem**: Mastodon counts @mentions in its 1024 character limit. The user writes poems to exactly 1024 characters INCLUDING the @mentions. Removing them causes the character count to drop, which is why only 12 poems qualify under the "pure" calculation vs 244 under actual length.

**Correct Methodology** (confirmed with user):
- Include poem content WITH reply syntax (@mentions)
- Include content warning text WITHOUT "CW: " prefix or added whitespace
- NOT include: dash-separators, date stamps, newlines added for formatting

**Solution Found**:
The `extract-fediverse.lua` script already calculates `golden_poem_character_count` correctly (lines 313-327):
- Uses `original_content` (pre-anonymization, includes @mentions)
- Adds content warning text length
- Sets `is_golden_poem = (golden_poem_length == 1024)`

**Recommended Fix**:
The validator (`poem-validator.lua`) should use the pre-calculated `metadata.golden_poem_character_count` or `metadata.is_golden_poem` from the extracted JSON instead of recalculating with `extract_pure_poem_content()`.

**See Also**: Issue 7-002 for full analysis

### ✅ **RESOLUTION - DECEMBER 2025 (Phase 7)**

**Fixed in Issue 7-002**:
1. Updated `extract-fediverse.lua` to calculate `golden_poem_character_count` using HTML-cleaned content (before anonymization)
2. Added `clean_html()` helper function and `golden_poem_content` field to extraction output
3. Updated `poem-validator.lua` to use pre-calculated `metadata.is_golden_poem` instead of recalculating

**Results**:
- **Before fix**: 1-12 golden poems (HTML artifacts inflating character counts)
- **After fix**: 431 golden poems at exactly 1024 characters
- Golden poem count now matches what Mastodon counts: text content + @mentions + CW text

### 🚨 **CRITICAL DISCOVERY - AUGUST 2026**: Markdown Delimiter Loss (RE-OPENED)

An audit of the character count distribution found a parity fingerprint: 129 poems
at 1022 characters and 67 at 1020, versus only 29 at 1023 and 13 at 1021. Even
counts just below 1024 were five to ten times more common than odd counts. Poem
lengths have no natural reason to prefer even numbers — something was removing
characters two at a time.

**Root Cause Found**:
The server (tech.lgbt) renders inline markdown. When the user types `*love*`,
the compose box counts six characters, but the ActivityPub archive stores the
rendered HTML `<em>love</em>` — the asterisks are consumed into tags. The
`clean_html()` step in the fediverse extraction strips emphasis tags and puts
nothing back, so every emphasized word silently loses its two delimiter
characters (four for bold). All markdown inline delimiters are even-width
(`*x*`=2, `**x**`=4, `~~x~~`=4, backtick pairs=2), which is exactly why only
even deficits spike.

**Ground truth**: the raw note file `words-pdf/input/notes/explosions-in-space`
contains `I'd *love* to talk` while the same poem posted (fediverse id 4129,
counted 1022) stores `I'd <em>love</em> to talk`. Restoring the two asterisks
lands it exactly on 1024.

**Validation at scale**: re-pricing every near-golden poem by adding back the
delimiters implied by its formatting tags promotes 215 poems to exactly 1024 —
including all 122 formatted poems at 1022 — while zero poems in the odd buckets
promote. Random near-misses could not produce that pattern.

**Additional divergences from what the compose box counts** (~9 poems):
- Byte length vs character length: the count used Lua byte length, but the
  compose box counts characters. Curly quotes and other multi-byte characters
  each overcount by 1-3.
- URLs: the compose box prices every URL at a flat 23 characters; the cleaner
  kept the full URL text.
- The cleaner also deleted typed backslashes before quotes (15 poems contain
  intentional programming-style `\"` sequences) and, separately, destroyed the
  user's emphasis in *displayed* poems, not just in the count.

**Confirmed with user (August 2026)**:
- Display should show BOTH the typed asterisks and rendered italics:
  `<em>*love*</em>`.
- Counting should adopt the full compose-box model (characters not bytes,
  URLs = 23, delimiters restored). This promotes ~6 more poems and demotes
  ~3 current false-goldens.
- Remaining near-misses with no formatting are accepted as genuine near-misses;
  the account no longer exists, so the server's stored original text cannot be
  consulted.

**Implementation Plan**:
1. New shared library `libs/mastodon-typed-text.lua`: reconstructs typed text
   from stored HTML (delimiter restoration, entity decoding, tag stripping,
   backslash preservation) and counts it the way the compose box does
   (UTF-8 characters, URL = 23, mention anchors and hashtags at visible text).
   Colocated test file and .info.md per project convention.
2. `scripts/extract-fediverse.lua` uses the library for display content,
   golden content, and `golden_poem_character_count`.
3. `src/flat-html-generator.lua` markdown formatting keeps delimiters visible
   inside the emphasis tags and gains bold/strikethrough/code handling.
4. Re-extract, re-validate, confirm golden count rises from 431 to ~650 and
   the 1022/1020 spikes collapse into 1024.

**Relevant tools**: audit scripts preserved in session scratchpad
(audit-golden-deficit.lua, blank-line-collapse-test.lua,
formatting-tag-census.lua) — they model the compose box independently of the
pipeline and can re-verify any future counting change.

### ✅ **RESOLUTION - AUGUST 2026**

**Implemented**:
1. New shared library `libs/mastodon-typed-text.lua` (with colocated test and
   info.md) reconstructs typed text from archive HTML and counts it the way
   the compose box counted. The extraction script now uses it for display
   content and for `golden_poem_character_count`.
2. Two further counting rules surfaced during verification, each caught
   because it left poems "impossibly" above the 1024 typing limit:
   - Plain-text mentions the server never linkified (`@user@domain` stored as
     bare text) are priced at `@user` — the domain rides free in the composer.
   - Emoji count as one character each: astral-plane characters are one, and
     the invisible variation selectors / zero-width joiners that emoji carry
     are zero. Byte counting had charged up to 4 for a single visible glyph.
3. `apply_markdown_formatting` in the flat HTML generator now renders
   emphasis styled AND keeps the typed delimiters visible (`<em>*love*</em>`),
   adds bold/strikethrough/inline-code, and no longer false-matches spaced
   asterisks ("2 * 3 * 4") or asterisk bullet lists.

**Verification**:
- 26 unit tests pass, including five archive poems hand-verified during the
  audit that recount to exactly 1024 from raw HTML.
- After re-extraction: **675 golden poems** (was 431). The 1022/1020 spikes
  collapsed (129→19 and 67→11) and the even/odd parity bias vanished.
- Global invariant holds: the maximum compose-box count across all 5,977
  archived fediverse posts is now exactly 1024 with zero poems above it —
  matching the physical typing limit. Before the fix, 13 poems "exceeded"
  the limit; every excess was a measurable model error.
- Remaining near-misses (44 at 1023, 19 at 1022) show normal magnitude
  falloff with no parity bias: genuine human near-misses, accepted as-is
  (the account no longer exists, so original typed text is unrecoverable).

**Deferred / follow-up**:
- Embeddings were generated from display content that lacked the restored
  delimiters; poems with emphasis now differ slightly from their embedded
  text. Regeneration is GPU-expensive and pending user decision.
- Site HTML regeneration will pick up restored asterisks and the new
  emphasis rendering on the next build.

## Implementation Priority
**High** - Core functionality affecting similarity engine and HTML generation priorities