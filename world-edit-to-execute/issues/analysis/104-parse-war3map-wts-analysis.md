## Analysis: Issue 104 - Parse war3map.wts

**Recommendation: Do NOT split this issue.**

### Rationale

This issue is already appropriately scoped for several reasons:

1. **Simple text format** - Unlike binary formats like MPQ or W3I, the WTS format is human-readable text with a straightforward structure (`STRING <id> { content }`). The parsing logic is fundamentally simple.

2. **Cohesive functionality** - The parser and the StringTable/resolver are tightly coupled. The resolver only makes sense with the parser, and testing one requires the other. Splitting them would create artificial boundaries.

3. **Small implementation footprint** - The entire implementation is approximately:
   - ~30 lines for the core parser
   - ~30 lines for the StringTable class
   - ~50 lines for edge case handling and tests
   
   This is a single-file, single-session implementation.

4. **No complex dependencies between parts** - Unlike issue 102 (MPQ) which has distinct phases (header parsing → hash tables → file extraction → compression), the WTS parser is essentially one operation with refinements.

5. **Linear workflow** - The implementation steps naturally flow together and share context. Switching between sub-issues would add overhead without benefit.

### If You Did Want to Split (Not Recommended)

For completeness, here's how it *could* be split, though I advise against it:

| ID | Name | Description | Dependencies |
|----|------|-------------|--------------|
| 104a | basic-wts-parser | Core STRING/content extraction | None |
| 104b | wts-edge-cases | Encoding, comments, escaped braces | 104a |
| 104c | trigstr-resolver | TRIGSTR_xxx replacement function | 104a |

But this creates 3 issues for what amounts to ~100 lines of code, which is excessive.

### Summary

Keep issue 104 as a single atomic issue. It's well-defined, appropriately sized (estimated 2-4 hours of work), and splitting it would add process overhead without improving manageability. The issue notes themselves acknowledge this: "The wts parser is simple but critical."
