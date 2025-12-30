# 202: Build File Content Reader

## Status
- [ ] Not started

## Current Behavior

No file content reader exists.

## Intended Behavior

A Lua module that:
- Reads file contents given a path
- Detects file encoding
- Handles binary vs text detection
- Returns content with metadata (line count, char count)
- Handles large files gracefully (streaming or chunking)

## Suggested Implementation Steps

1. Create src/reader.lua
2. Implement basic file reading with io.open
3. Add binary detection (check for null bytes)
4. Calculate content statistics
5. Add encoding normalization (ensure UTF-8)
6. Implement size limits / chunking for large files

## Related Documents

- 201-build-directory-scanner.md

## Notes

For code archives, most files will be plain text. Binary files (images, compiled) should be noted but likely excluded from the archive text.
