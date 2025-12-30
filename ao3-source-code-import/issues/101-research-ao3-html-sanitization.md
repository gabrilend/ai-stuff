# 101: Research AO3 HTML Sanitization Rules

## Status
- [ ] Not started

## Current Behavior

Unknown. Need to determine what HTML tags and attributes AO3 allows, strips, or transforms when content is submitted.

## Intended Behavior

Have a complete documented list of:
- Allowed HTML tags (especially `<pre>`, `<code>`, `<span>`)
- Allowed attributes (class, style, id)
- Stripped or transformed elements
- Character encoding requirements
- Maximum content length limits

## Suggested Implementation Steps

1. Review AO3 FAQ and documentation for formatting guidelines
2. Create test uploads with various HTML structures
3. Compare submitted HTML to rendered output
4. Document all transformations observed
5. Create ao3-format-spec.md with findings

## Related Documents

- docs/ao3-format-spec.md (to be created)
- AO3 FAQ: https://archiveofourown.org/faq

## Notes

Code preservation requires knowing exactly what survives the sanitizer. Particularly important: does `<pre>` preserve whitespace? Are syntax highlighting classes stripped?
