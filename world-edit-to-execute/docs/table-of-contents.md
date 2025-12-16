# World Edit to Execute - Documentation

## Table of Contents

```
./
├── CLAUDE.md                   Project instructions for Claude Code
│
docs/
├── table-of-contents.md       (this file)
├── roadmap.md                  Project phases and milestones
├── formats/                    File format specifications
│   ├── mpq-archive.md          MPQ archive format (with HM3W wrapper)
│   ├── w3i-map-info.md         Map info file format
│   ├── wts-trigger-strings.md  Trigger string table format
│   └── w3e-terrain.md          Terrain/tileset data format
│
src/
├── cli/
│   └── issue-splitter.sh → /home/ritz/programming/ai-stuff/scripts/issue-splitter.sh
│
notes/
├── vision                      Core project vision and philosophy
│
issues/
├── progress.md                 Overall phase progress tracking
├── 001-fix-issue-splitter-output-handling.md
├── 002-add-streaming-queue-to-issue-splitter.md
├── 003-execute-analysis-recommendations.md
├── 004-redesign-interactive-mode-interface.md
├── 101-research-wc3-file-formats.md
├── 102-implement-mpq-archive-parser.md
├── 102a-parse-mpq-header.md
├── 102b-parse-mpq-hash-table.md
├── 102c-parse-mpq-block-table.md
├── 102d-implement-file-extraction.md
├── 103-parse-war3map-w3i.md
├── 104-parse-war3map-wts.md
├── 105-parse-war3map-w3e.md
├── 106-design-internal-data-structures.md
├── 107-build-cli-metadata-dump-tool.md
├── 108-phase-1-integration-test.md
├── completed/                  Completed issue archive
│   └── demos/                  Phase completion demonstrations
```

---

## Document Index

### Core Documents

| Document | Location | Description |
|----------|----------|-------------|
| CLAUDE.md | ./CLAUDE.md | Project instructions for Claude Code |
| Vision | notes/vision | Project philosophy, legal basis, and goals |
| Roadmap | docs/roadmap.md | Phased development plan |
| Progress | issues/progress.md | Current phase status |

### Tools

| Tool | Location | Description |
|------|----------|-------------|
| issue-splitter.sh | src/cli/issue-splitter.sh (symlink) | Issue analysis, sub-issue creation, auto-implementation |
| TUI library | /home/ritz/.../scripts/libs/ | Shared terminal UI (checkbox, menu, input) |

### Phase 0 Issues (Tooling) - **COMPLETED**

| Issue | Description | Status |
|-------|-------------|--------|
| 001 | Fix issue-splitter output handling | **Completed** |
| 002 | Add streaming queue to issue-splitter | **Completed** |
| 002a | Add queue infrastructure | **Completed** |
| 002b | Add producer function | **Completed** |
| 002c | Add streamer process | **Completed** |
| 002d | Add parallel processing loop | **Completed** |
| 002e | Add streaming config flags | **Completed** |
| 003 | Execute analysis recommendations | **Completed** |
| 004 | Redesign interactive mode interface | **Completed** |
| 004a | Create TUI core library | **Completed** |
| 004b | Implement checkbox component | **Completed** |
| 004c | Implement multistate toggle | **Completed** |
| 004d | Implement input components | **Completed** |
| 004e | Build menu navigation system | **Completed** |
| 004f | Integrate TUI into issue-splitter | **Completed** |
| 005 | Migrate TUI library to shared libs | **Completed** |
| 006 | Rename analysis sections for promoted roots | **Completed** |
| 007 | Add auto-implement via Claude CLI | **Completed** |

### Phase 1 Issues (File Format Parsing)

| Issue | Description | Status |
|-------|-------------|--------|
| 101 | Research WC3 file formats | **Completed** |
| 102 | Implement MPQ archive parser | **Completed** |
| 102a | Parse MPQ header structure | **Completed** |
| 102b | Parse MPQ hash table | **Completed** |
| 102c | Parse MPQ block table | **Completed** |
| 102d | Implement file extraction | **Completed** |
| 103 | Parse war3map.w3i (map info) | Pending |
| 104 | Parse war3map.wts (trigger strings) | Pending |
| 105 | Parse war3map.w3e (terrain) | Pending |
| 106 | Design internal data structures | Pending |
| 107 | Build CLI metadata dump tool | Pending |
| 108 | Phase 1 integration test | Pending |

### Technical Documentation

| Document | Description | Status |
|----------|-------------|--------|
| mpq-archive.md | MPQ archive format with HM3W wrapper, encryption, compression | Created |
| w3i-map-info.md | Map info: metadata, players, forces, fog settings | Created |
| wts-trigger-strings.md | Trigger string table format and TRIGSTR resolution | Created |
| w3e-terrain.md | Terrain: tilepoints, height maps, textures, cliffs | Created |

### Guides

(To be added as development progresses)

- Getting Started
- Creating Asset Packs
- Writing Lua Scripts
- Contributing
