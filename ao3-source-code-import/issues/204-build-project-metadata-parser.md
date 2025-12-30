# 204: Build Project Metadata Parser

## Status
- [ ] Not started

## Current Behavior

No metadata extraction exists.

## Intended Behavior

A Lua module that:
- Reads README.md or notes/vision for project summary
- Extracts project name and description
- Identifies primary programming language
- Counts files, lines of code, etc.
- Builds a "work summary" from project documentation

## Suggested Implementation Steps

1. Create src/metadata.lua
2. Implement README/vision file detection and reading
3. Parse markdown to extract key sections
4. Calculate code statistics (loc, file count by type)
5. Generate structured metadata object
6. Create summary text generator for AO3 work summary

## Related Documents

- 201-build-directory-scanner.md
- 202-build-file-reader.md
- docs/code-to-html-spec.md

## Notes

The vision document becomes the "author's note." The README becomes the summary. Issue files become supplementary chapters or appendices.
