# ao3-source-code-import Progress

## Overview

Archive source code repositories to AO3 for preservation. Code as literature.

## Phase Summary

| Phase | Description | Issues | Status |
|-------|-------------|--------|--------|
| 1 | Research & Specification | 101-104 | Not started |
| 2 | Source Code Reader | 201-205 | Not started |
| 3 | HTML Formatter | 301-304 | Not started |
| 4 | AO3 Interface | 401-403 | Not started |
| 5 | Version Management | 501-502 | Not started |
| 6 | Integration & CLI | 601-603 | Not started |

## Current Focus

Phase 1: Research AO3's requirements before building anything.

## Issue Breakdown

### Phase 1: Research & Specification
- [ ] 101 - Research AO3 HTML sanitization rules
- [ ] 102 - Research AO3 authentication methods
- [ ] 103 - Research work creation form structure
- [ ] 104 - Document rate limits and ToS

### Phase 2: Source Code Reader
- [ ] 201 - Build directory scanner
- [ ] 202 - Build file content reader
- [ ] 203 - Build git log extractor
- [ ] 204 - Build project metadata parser
- [ ] 205 - Include LLM transcripts

### Phase 3: HTML Formatter
- [ ] 301 - Design chapter organization strategy
- [ ] 302 - Build code-to-HTML converter
- [ ] 303 - Build markdown-to-HTML converter
- [ ] 304 - Build work metadata generator

### Phase 4: AO3 Interface
- [ ] 401 - Implement AO3 session authentication
- [ ] 402 - Implement work creation
- [ ] 403 - Implement chapter upload

### Phase 5: Version Management
- [ ] 501 - Implement version tracking
- [ ] 502 - Implement deprecation workflow

### Phase 6: Integration & CLI
- [ ] 601 - Build main CLI interface
- [ ] 602 - Create run script
- [ ] 603 - Phase 6 integration test

## Milestones

1. **Research Complete**: All Phase 1 issues done, specs documented
2. **Reader Works**: Can read and parse world-edit-to-execute
3. **HTML Output**: Can generate valid archive HTML locally
4. **Upload Works**: Can create a work on AO3
5. **Full Pipeline**: One command archives a project
6. **Self-Archive**: ao3-source-code-import archived on AO3

## Notes

- Primary target: world-edit-to-execute
- Secondary target: ao3-source-code-import (self-archive)
- Transcripts included via scripts/backup-conversations + claude-conversation-exporter.sh
