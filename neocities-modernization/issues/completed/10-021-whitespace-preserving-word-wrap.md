# Issue 10-021: Whitespace-Preserving Word Wrap for Poems

## Priority
High (content readability)

## Current Behavior

After Issue 8-056, poem content preserves all whitespace (leading spaces, indentation,
multi-space runs). However, lines longer than 80 characters now extend beyond the page
boundary, causing horizontal overflow.

This is visible on chronological pages where poems containing long URLs push content
far to the right.

### Example

A poem line like:
```
   Here is a link: https://www.reddit.com/r/antiwork/comments/n5g17c/remote_revolution/gx1itp0?utm_source=share&utm_medium=web2x&context=3
```

Currently renders as one 140+ character line, overflowing the 80-char content area.

## Intended Behavior

Long lines should wrap at word boundaries while **preserving leading whitespace**:

```
   Here is a link:
   https://www.reddit.com/r/antiwork/comments/n5g17c/remote_revolution/gx1itp
   0?utm_source=share&utm_medium=web2x&context=3
```

Key requirements:
1. **Leading whitespace preserved**: If a line starts with 3 spaces, all wrapped
   continuations also start with 3 spaces (or configurable indent)
2. **Interior whitespace preserved**: Multi-space runs within words stay intact
3. **Paragraph breaks preserved**: Empty lines remain empty
4. **Long words broken**: URLs or other strings exceeding line width get character-broken
5. **Short lines unchanged**: Lines <= 80 **visible columns** pass through unmodified
6. **Width means ink, not bytes**: a line arrives here already HTML-escaped and
   markdown-formatted. `<em>` and `</em>` are nine bytes of nothing; `&amp;` is
   five bytes showing one ampersand; an em dash is three bytes showing one dash.
   Every measurement counts what the reader sees.

### Why requirement 6 is here

The wrapper first shipped counting bytes, and the note "too-harsh" showed what
that costs. One line ran 78 visible columns and contained a single emphasized
word; the emphasis tags took it to 87 bytes, so the wrapper spent nine columns of
an 80-column budget on ink that does not exist and pushed the line's last two
words onto a row of their own. Two lines below it, a line of 80 visible columns
with no markup measured 80 bytes and stayed whole. Same page, same margin, two
different answers -- which is the shape of a measurement bug rather than a
layout one. The same arithmetic would have clipped any line carrying an escaped
ampersand or a curly quote near the margin.

## Root Cause

Issue 8-056 disabled word wrapping entirely to fix whitespace destruction. The old
`wrap_single_line_80_chars` function used `%S+` splitting which collapsed all whitespace.

The fix was too aggressive - we need wrapping that RESPECTS whitespace, not no wrapping.

## Suggested Implementation

### Step 1: Add `wrap_preserving_indent` to text-formatter.lua

Split the line into leading whitespace and a remainder, then walk the remainder
word by word with the pattern `(%S+)(%s*)`, which captures each word together
with the spaces that follow it -- that pairing is what keeps multi-space runs
alive, and it is the whole lesson of 8-056. Accumulate words onto a line until
the next one would not fit; flush, and start again with the leading whitespace
prepended so continuations sit under their parent.

Every "would it fit" question is answered by `calculate_visible_width`, which
already existed in this module for the golden-poem box padding. Ask it about the
whole line before deciding whether to wrap at all, about each word-plus-spaces
segment while accumulating, and about a word before deciding it is too long to
ever fit. Never use `#` on a string here except to ask whether anything is
buffered at all.

Measuring each word on its own is only safe because the tags markdown emits
carry no spaces: emphasis spanning two words arrives as `<em>two` and
`words</em>`, and each half strips its own tag cleanly. An `<a href="...">`
anchor DOES carry a space and would be split down the middle -- which is why
link text goes through `wrap_external_url` instead. State that contract in the
comments; it is the kind of thing that gets broken by someone adding a feature
two years later.

### Step 2: Add `slice_by_visible_width` for the long-word path

A word too long to ever fit a line (a URL) has to be cut mid-word, and the cut
has to land between characters. Walk the string one display unit at a time: a
complete `<...>` tag is swallowed whole for zero columns, an entity matching
`&#?%w+;` whole for one, a UTF-8 sequence (identified from its lead byte) whole
for one, anything else one byte for one column. Return the two pieces. Slicing
at a byte offset instead is what would cut `<em>` into `<e` and `m>`.

### Step 3: Update `format_poem_content`

Have it add its one-space left pad and then call `wrap_preserving_indent` per
line, rather than inserting lines directly.

### Step 4: Test with affected poems

1. Poems with long URLs (chronological pages)
2. Poems with artistic indentation (notes category)
3. Poems with paragraph breaks
4. Golden poems (ensure border alignment still works)
5. Poems with emphasis, escaped ampersands, or non-ASCII punctuation sitting
   within a few columns of the margin -- the cases where bytes and columns
   disagree, and the only ones that can tell the two measurements apart

## Related Documents

- `issues/completed/8-056-preserve-whitespace-in-poem-rendering.md` - Previous fix
- `issues/completed/4-003-fix-character-counting-methodology-for-fediverse-golden-poems.md`
  - Where the emphasis tags that this wrapper has to see through come from
- `libs/text-formatter.lua` - Shared formatting module
- `libs/text-formatter.info.md` - Its public surface and the width rule
- `libs/text-formatter-test.lua` - Guards the width rule, carrying the
  "too-harsh" line as the regression case
- `src/flat-html-generator.lua` - Main/worker thread formatting

## Metadata

- **Status**: Completed
- **Created**: 2026-01-30
- **Completed**: 2026-01-30
- **Phase**: 10 (Developer Experience & Tooling)
- **Estimated Complexity**: Medium
- **Dependencies**: Extends 8-056 work

## Completion Notes

### Changes Made

1. **Added `wrap_preserving_indent()` to `libs/text-formatter.lua`**
   - Wraps lines at word boundaries while preserving leading whitespace
   - Continuation lines inherit original line's indentation
   - Very long words (URLs) get character-broken when they exceed available width
   - Lines <= max_width pass through unchanged

2. **Updated `format_poem_content()` in `libs/text-formatter.lua`**
   - Now calls `wrap_preserving_indent()` for each line
   - Maintains 1-space left padding for all lines
   - Optional max_width parameter (default 80)

3. **Updated `format_content_with_warnings()` in `src/flat-html-generator.lua`**
   - Main thread path was NOT using text-formatter module (had inline implementation)
   - Fixed line splitting: was using `[^\n]+` which skipped empty lines (paragraph breaks lost)
   - Now uses `text_formatter.format_poem_lines()` to preserve empty lines
   - Now uses `text_formatter.wrap_preserving_indent()` for wrapping

### Test Results

```
=== Test: format_poem_content with long URL ===
1 | short line|       #11
2 | |                 #1  (empty line preserved)
3 | Here is a long URL:|  #20
4 | https://www.reddit.com/r/antiwork/.../gx1itp0?utm|  #80 (broken)
5 | _source=share&utm_medium=web2x&context=3|         #41
6 | |                 #1  (empty line preserved)
7 |    artistic indent|   #19 (3-space indent preserved)
```

### Lessons Learned

The key insight from 8-056 was correct: `%S+` pattern destroys whitespace structure.
The solution is to split on word boundaries `(%S+)(%s*)` which captures both the word
AND its trailing whitespace. By processing the remainder (after capturing leading
whitespace), we preserve the original indentation on all wrapped lines.

The second lesson arrived later, from a reader noticing two lines of one note
disagree about where the margin is. A wrapper sits downstream of escaping and
markdown, so the string it holds is not the text anyone will read -- it is that
text wearing markup. `#string` answers a question about storage; the wrapper is
asking a question about ink. The module already knew the difference (it had
`calculate_visible_width` for box padding) and the wrapper simply never asked.
Where a module holds two ways to measure the same thing, expect the newer code
to reach for the wrong one.
