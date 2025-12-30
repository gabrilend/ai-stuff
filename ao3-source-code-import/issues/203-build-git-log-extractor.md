# 203: Build Git Log Extractor

## Status
- [ ] Not started

## Current Behavior

No git history extraction exists.

## Intended Behavior

A Lua module that:
- Runs git log on the target repository
- Parses commit history (hash, author, date, message)
- Extracts relevant statistics (total commits, contributors)
- Formats history for inclusion in archive
- Can filter by date range or commit count

## Suggested Implementation Steps

1. Create src/git-extractor.lua
2. Implement git log command execution
3. Parse git log output into structured data
4. Add formatting functions for human-readable output
5. Implement filters (last N commits, date range)
6. Handle repos with no git (graceful failure)

## Related Documents

- 201-build-directory-scanner.md
- 202-build-file-reader.md

## Notes

Git log becomes the "publication history" of the code-as-literature. Each commit is an edition, each message is an author's note.
