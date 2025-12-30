# 303: Build Markdown-to-HTML Converter

## Status
- [ ] Not started

## Current Behavior

No markdown conversion exists.

## Intended Behavior

A Lua module that:
- Converts markdown files to AO3-compatible HTML
- Handles headers, lists, links, code blocks
- Preserves emphasis (bold, italic)
- Converts markdown tables if possible
- Falls back to plain text for unsupported syntax

## Suggested Implementation Steps

1. Create src/markdown-html.lua
2. Implement header conversion (# -> h1, ## -> h2, etc.)
3. Implement list conversion (ul/ol)
4. Implement link conversion
5. Implement code block conversion (uses 302)
6. Implement emphasis conversion
7. Test against AO3 allowed tags from 101

## Related Documents

- 101-research-ao3-html-sanitization.md
- 302-build-code-to-html-converter.md
- docs/ao3-format-spec.md

## Notes

README and vision files are markdown. They become the work summary and author's notes. Must look good.
