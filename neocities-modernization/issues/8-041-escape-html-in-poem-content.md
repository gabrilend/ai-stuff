# Issue 8-041: Escape HTML Characters in Poem Content

## Priority
High

## Current Behavior

Poem content containing HTML-like characters (`<`, `>`, `&`) is inserted directly into the generated HTML without escaping. This causes the browser to interpret poem content as actual HTML markup.

**Example from chronological-01.html (line ~1655):**

A poem contains literal HTML source code as its content:
```
 <span id="L42" class="LineNr">42 </span>Under a big tree, with me
 </pre>          ← Browser interprets this as closing the ACTUAL <pre> block
 </body>         ← Browser thinks the body ended
 </html>         ← Browser thinks the document ended
 <!-- vim: set foldmethod=manual : -->
┌─────────┐      ← Everything after renders as regular HTML, not preformatted
```

**Observed effects:**
- Content after the unescaped `</pre>` renders with default HTML styling (proportional font)
- This appears as different "zoom level" compared to preformatted content
- Background color and spacing change because `<pre>` formatting is lost
- The remaining ~18,000 lines of chronological-01.html render incorrectly

## Intended Behavior

All poem content should be HTML-escaped before insertion into the generated HTML:
- `<` → `&lt;`
- `>` → `&gt;`
- `&` → `&amp;`

This preserves the visual appearance of the original content (including HTML source code, code snippets, or any text containing these characters) while preventing browser interpretation.

**After fix:**
```html
 &lt;span id="L42" class="LineNr"&gt;42 &lt;/span&gt;Under a big tree, with me
 &lt;/pre&gt;
 &lt;/body&gt;
 &lt;/html&gt;
 &lt;!-- vim: set foldmethod=manual : --&gt;
```

The browser displays the literal text `</pre>` instead of interpreting it as markup.

## Technical Analysis

### Affected Files

The bug is in `src/flat-html-generator.lua`. Poem content is inserted without escaping in multiple locations where poem text is formatted for HTML output.

### HTML Escaping Function

Create or use an escaping function:
```lua
-- {{{ html_escape
local function html_escape(str)
    if not str then return "" end
    return str:gsub("&", "&amp;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
end
-- }}}
```

**Important:** The order matters - `&` must be escaped first, otherwise `&lt;` becomes `&amp;lt;`.

### Where to Apply Escaping

Escaping should be applied to poem **content** only, not to:
- Generated HTML structure (navigation boxes, progress bars)
- Link URLs (already handled separately)
- Attributes we control (aria-label, etc.)

Key locations to investigate:
- `format_content_with_warnings()` - processes poem text
- `apply_golden_poem_formatting()` - golden poem content
- Any function that inserts `poem.content` into HTML

## Suggested Implementation Steps

1. **Create `html_escape()` function**:
   ```lua
   local function html_escape(str)
       if not str then return "" end
       return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
   end
   ```

2. **Find all poem content insertion points**:
   - Search for `poem.content` or `content` being inserted into HTML
   - Search for string concatenation with poem text

3. **Apply escaping at content entry points**:
   - Escape early, at the point where raw poem content first enters the HTML generation
   - This ensures all downstream formatting receives safe content

4. **Preserve intentional HTML** (if any):
   - If any poems intentionally contain HTML that should render (unlikely), document exceptions
   - Current policy: all poem content should display as literal text

5. **Test with problematic poems**:
   - Regenerate chronological-01.html
   - Verify the HTML-containing poem displays correctly
   - Verify all content after it renders in `<pre>` format
   - Check that `<` and `>` in other poems (code snippets, emoticons like `<3`) display correctly

6. **Verify no double-escaping**:
   - Ensure content isn't escaped multiple times
   - `&lt;` should not become `&amp;lt;`

## Test Cases

| Input | Expected Output (in HTML source) | Displayed |
|-------|----------------------------------|-----------|
| `</pre>` | `&lt;/pre&gt;` | `</pre>` |
| `<script>alert('xss')</script>` | `&lt;script&gt;...` | `<script>...` |
| `x < y && y > z` | `x &lt; y &amp;&amp; y &gt; z` | `x < y && y > z` |
| `<3` | `&lt;3` | `<3` |
| `&nbsp;` | `&amp;nbsp;` | `&nbsp;` |

## Security Note

This fix also prevents potential XSS (Cross-Site Scripting) vulnerabilities. While this is a static site generator, properly escaping user-generated content is a security best practice.

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation file
- `issues/8-037-fix-similar-different-box-alignment.md` - Related formatting issues

## Implementation Progress

### 2026-01-20: Core Implementation Complete

**Changes made to `src/flat-html-generator.lua`:**

1. **Added `escape_html()` function** (lines 1228-1240):
   ```lua
   local function escape_html(text)
       if not text then return "" end
       return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
   end
   ```

2. **Applied escaping in `format_content_with_warnings()`** (lines 1488-1496):
   - Escapes content BEFORE markdown formatting
   - Allows `*italics*` to become `<em>` while keeping literal `<>` escaped

3. **Applied escaping in effil worker thread** (lines 2703-2707):
   - Worker threads run in separate Lua state, can't access main functions
   - Added inline escaping: `content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")`

**Test results:**
- All 5 test cases from issue pass (unit test)
- Existing output shows proper escaping (chronological-01.html has balanced `<pre>` tags)
- Full regeneration validation pending next HTML generation run

**Pending:**
- [ ] Full regeneration and visual verification
- [ ] Test with browser to confirm rendering is fixed

## Metadata

- **Status**: Implementation Complete - Awaiting Validation
- **Created**: 2026-01-20
- **Phase**: 8 (Website Completion / HTML Generation)
- **Estimated Complexity**: Low (simple string replacement, but must find all insertion points)
- **Dependencies**: None
- **Affects**: All generated HTML files (chronological, similar, different)
- **Urgency**: High - currently breaks rendering of chronological-01.html
