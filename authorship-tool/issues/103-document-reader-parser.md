# Issue 103: Document Reader and Parser

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: High
**Created**: 2026-01-08

---

## Current Behavior

No document reading capability exists. The project needs to read and parse text documents from the input/ directory.

---

## Intended Behavior

The system should:
- Read text files from input/ directory
- Parse document content into structured format
- Extract basic metadata (filename, path, size, modification time)
- Support multiple text file formats (.txt, .md at minimum)
- Handle large files efficiently (streaming if needed)
- Detect document changes for re-processing
- Store parsed documents in memory with efficient access
- Provide document listing and retrieval functions

---

## Suggested Implementation Steps

1. Create `libs/document-reader/` module directory
2. Create `libs/document-reader/src/reader.lua` for file reading
3. Implement file discovery (scan input/ directory recursively)
4. Implement text file reading (handle UTF-8 encoding)
5. Create Document data structure (as per technical-design.md)
6. Implement metadata extraction
7. Create document storage/cache system
8. Implement file modification detection
9. Add support for .txt and .md formats
10. Handle large files (stream or paginate if > certain size)
11. Create `libs/document-reader/module.lua` with standard interface
12. Write tests with sample documents
13. Document functions in libs/document-reader/src/reader.info.md

---

## Related Documents

- docs/technical-design.md (Document Representation section)
- docs/module-specifications.md (Document Organizer - reading portion)
- docs/roadmap.md (Phase 1)

---

## Implementation Notes

**Document Structure**:
```lua
Document = {
    path = "/full/path/to/file.txt",
    content = "raw text content",
    metadata = {
        created = timestamp,
        modified = timestamp,
        size_bytes = number,
        format = "txt" | "md"
    }
}
```

**File Discovery**:
- Start from input/ directory
- Recursively scan subdirectories
- Filter for supported extensions
- Store relative paths for portability

**Performance Considerations**:
- For files > 1MB, consider streaming or lazy loading
- Cache file modification times to avoid re-reading unchanged files
- Use efficient string handling (avoid repeated concatenation)

---

## Testing Criteria

- [ ] Discovers all text files in input/
- [ ] Reads .txt files correctly
- [ ] Reads .md files correctly
- [ ] Extracts metadata accurately
- [ ] Handles large files (> 1MB) efficiently
- [ ] Detects file modifications
- [ ] Returns documents in structured format
- [ ] Handles UTF-8 encoding correctly
- [ ] Errors gracefully on invalid files

---

## Dependencies

- 101 (module loading framework)

---

## Blocks

- Phase 1 demo (needs document reading to display)
- 104 (configuration may specify document locations)
