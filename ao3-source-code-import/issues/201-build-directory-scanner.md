# 201: Build Directory Scanner

## Status
- [ ] Not started

## Current Behavior

No project reader exists.

## Intended Behavior

A Lua module that:
- Accepts a project root path
- Recursively scans all directories
- Returns structured list of all files with metadata
- Respects .gitignore patterns
- Filters by relevant file types (lua, md, txt, etc.)

## Suggested Implementation Steps

1. Create src/scanner.lua
2. Implement recursive directory walking using lfs or posix
3. Add .gitignore pattern parsing
4. Build file metadata extraction (path, size, mtime)
5. Return structured table of project contents
6. Add filtering options for file types

## Related Documents

- docs/code-to-html-spec.md

## Notes

Target repo structure (world-edit-to-execute):
- src/ - lua source files
- docs/ - documentation
- issues/ - issue tracking
- notes/ - project notes
- libs/ - dependencies
