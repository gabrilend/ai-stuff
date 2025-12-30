# 205: Include LLM Transcripts in Archive

## Status
- [ ] Not started

## Current Behavior

No transcript inclusion exists.

## Intended Behavior

The archive should include LLM conversation transcripts that document the development process. These are the conversations between human and AI that produced the code.

A Lua module that:
- Detects existing transcript exports in the target project
- Runs transcript backup/export if needed (via scripts tools)
- Parses exported transcripts into structured data
- Formats transcripts as chapters/appendices for the archive
- Preserves the collaborative authorship record

## Transcript Tools Location

```
/home/ritz/programming/ai-stuff/scripts/backup-conversations
/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh
```

## Suggested Implementation Steps

1. Create src/transcript-reader.lua
2. Detect llm-transcripts/ directory in target project
3. If missing or stale, shell out to backup-conversations and claude-conversation-exporter.sh
4. Parse exported transcript files (markdown format)
5. Structure as "Development Log" chapters
6. Include in archive after source code chapters

## Integration with Run Script

Any bash run script should:
1. Call backup-conversations for the target project first
2. Call claude-conversation-exporter.sh with appropriate verbosity
3. Then proceed with the archive generation

Example:
```bash
#!/bin/bash
# ao3-source-code-import run script
# Generates AO3-compatible archive from source repository

DIR="${1:-/home/ritz/programming/ai-stuff/world-edit-to-execute}"
SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"

# Update transcripts before archiving
"${SCRIPTS_DIR}/backup-conversations" "${DIR}"
"${SCRIPTS_DIR}/claude-conversation-exporter.sh" -v4 "${DIR}"

# Then run the archive generator
luajit src/main.lua "${DIR}"
```

## Related Documents

- 201-build-directory-scanner.md
- 204-build-project-metadata-parser.md
- /home/ritz/programming/ai-stuff/scripts/issues/009-batch-transcript-backup-with-tui.md

## Notes

The transcripts are the "making of" documentary. Code is the film, transcripts are the behind-the-scenes. Both belong in the archive.

Nature's demand: preserve not just the artifact, but the process that made it.
