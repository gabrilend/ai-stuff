# Issue 10-027: Fix Golden Poem Trailing Whitespace Detection

## Current Behavior

Poems that users craft to exactly 1024 characters are sometimes not detected as golden poems. Specifically:
- Poem 3738 (fediverse) shows `golden_poem_character_count: 1022` instead of 1024
- User reports using every character available, ending with "or "
- The raw HTML shows no trailing space: `mandate or</p>`

**Near-Golden Distribution** (from poems.json analysis):
```
1020 chars: 67 poems
1021 chars: 13 poems
1022 chars: 129 poems  <-- suspicious spike!
1023 chars: 29 poems
1024 chars: 431 poems (golden)
```

The 129 poems at exactly 1022 characters represents a massive anomaly.

## Investigation Progress (2026-02-18)

### What Has Been Verified/Ruled Out

**1. clean_html() function is correct:**
- Step-by-step trace shows character count at each step
- Key finding: After tag stripping, poem 3738 has **exactly 1024 characters**
- After leading newline strip: **1022 characters** (removes 2)
- The leading `\n\n` comes from first `<p>` tag conversion, not user input

**2. Leading newline stripping IS correct:**
- Compared golden poem 0078 with non-golden poem 3738
- Golden 0078: 1026 after tag strip → 1024 after leading strip ✓
- Non-golden 3738: 1024 after tag strip → 1022 after leading strip
- The stripping is consistent; the difference is in source content

**3. No UTF-8 character counting issues:**
- Both poems are pure ASCII
- `string.len()` byte count equals character count
- No multi-byte characters affecting the math

**4. No hidden whitespace in raw HTML:**
- Hex dump of both poem endings shows no spaces before `</p>`
- Golden: `...sleep</p>` (73 6C 65 65 70 3C 2F 70 3E)
- Non-golden: `...or</p>` (6F 72 3C 2F 70 3E)

**5. Kaomoji fixes don't affect poem 3738:**
- The ` _^` and `^^_^` patterns don't appear in the content

### Key Discovery

The **root cause appears to be upstream of our code**:

| Poem | After Tag Strip | After Leading Strip | Golden? |
|------|-----------------|---------------------|---------|
| 0078 | 1026 chars      | 1024 chars          | ✓ Yes   |
| 3738 | 1024 chars      | 1022 chars          | ✗ No    |

Both poems have 2 leading newlines stripped (correct behavior). The difference is that the golden poem's raw HTML contains 2 more characters of actual content.

If the user typed 1024 characters for poem 3738 but the raw HTML only produces 1024 chars *including* the structural leading `\n\n`, then the actual content is only 1022. The 2 missing characters were never in the export.

### Remaining Hypotheses

**H1: Mastodon strips trailing whitespace before storage/export**
- User typed "or " with trailing space(s)
- Mastodon's character counter included them
- Mastodon's HTML export doesn't include them
- We can't recover characters that don't exist in the data

**H2: Unknown bug in our pipeline (needs more investigation)**
- Could there be additional processing between extraction and final count?
- Does `process_fediverse_content()` modify anything unexpectedly?
- Is there a different code path for poems with more paragraphs?

## Suggested Next Steps

1. **Verify H1 by testing Mastodon directly:**
   - Post a test to tech.lgbt ending with "test " (trailing space)
   - Export account data
   - Check if trailing space is preserved in outbox.json

2. **If H1 confirmed (Mastodon strips trailing whitespace):**
   - This is not a bug in our code
   - Options: tolerance, documentation, or near-golden category

3. **If H1 disproven (trailing space IS preserved in Mastodon):**
   - Our pipeline has an undiscovered bug
   - Need to trace the exact flow for a test poem with known trailing space

4. **Alternative investigation:**
   - Find a golden poem that ends with a space
   - Compare its processing to poem 3738
   - Determine what's different

## Related Files

- `scripts/extract-fediverse.lua:434-452` - `clean_html()` function
- `scripts/extract-fediverse.lua:495-521` - `generate_poem_metadata()` function
- `scripts/extract-fediverse.lua:455-477` - `process_fediverse_content()` function

## Related Issues

- Issue 4-003: Fix character counting methodology for fediverse golden poems (COMPLETED)
- Issue 6-032: Fix BR tag variants in HTML cleaning
- Issue 7-002: Clean up run.sh output (contains golden poem analysis)

---

**ISSUE STATUS: OPEN - INVESTIGATION IN PROGRESS**

**Created**: 2026-02-18

**Priority**: Medium (affects user expectation of golden poem detection)

**Reported by**: User investigation of poem 3738
