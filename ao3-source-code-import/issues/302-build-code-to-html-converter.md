# 302: Build Code-to-HTML Converter

## Status
- [ ] Not started

## Current Behavior

No HTML conversion exists.

## Intended Behavior

A Lua module that:
- Takes source code as input
- Outputs HTML that preserves formatting
- Uses <pre> or <code> blocks appropriately
- Escapes HTML entities in code (&lt;, &gt;, &amp;)
- Optionally adds line numbers
- Handles long lines gracefully

## Suggested Implementation Steps

1. Create src/html-formatter.lua
2. Implement HTML entity escaping
3. Wrap code in <pre><code> blocks
4. Add optional line numbering
5. Handle different file types (lua, md, txt)
6. Test output against AO3 sanitization findings from 101

## Code Example

Input:
```lua
local function hello()
    print("Hello <world>")
end
```

Output:
```html
<pre><code>local function hello()
    print("Hello &lt;world&gt;")
end</code></pre>
```

## Related Documents

- 101-research-ao3-html-sanitization.md
- docs/ao3-format-spec.md
- docs/code-to-html-spec.md

## Notes

Whitespace preservation is critical. Lua indentation must survive. Test thoroughly.
