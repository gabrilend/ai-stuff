# Table of Contents

## Project Documentation Tree

```
translation-layer-wow-chat-city-of-chat/
|
+-- notes/
|   +-- vision                    # Original project vision
|
+-- docs/
|   +-- table-of-contents.md      # This file
|   +-- roadmap.md                # 6-phase development plan
|   +-- architecture.md           # System design overview
|   +-- translation-philosophy.md # Core translation concept
|   |
|   +-- [Phase 1] wow-protocol.md       # (planned)
|   +-- [Phase 2] coh-protocol.md       # (planned)
|   +-- [Phase 3] protocol-mapping.md   # (planned)
|   +-- [Phase 6] transcriber-design.md # (planned)
|
+-- issues/
|   +-- phase-1-progress.md       # Research WoW Protocol
|   +-- 101-*.md                  # Phase 1 issues
|   |
|   +-- phase-2-progress.md       # Research CoH Protocol
|   +-- 201-*.md                  # Phase 2 issues
|   |
|   +-- phase-3-progress.md       # Protocol Mapping Matrix
|   +-- 301-*.md                  # Phase 3 issues
|   |
|   +-- phase-4-progress.md       # Translatable Data Types
|   +-- 401-*.md                  # Phase 4 issues
|   |
|   +-- phase-5-progress.md       # Packet Visualizer
|   +-- 501-*.md                  # Phase 5 issues
|   |
|   +-- phase-6-progress.md       # Transcriber Engine
|   +-- 601-*.md                  # Phase 6 issues
|   |
|   +-- completed/
|       +-- demos/                # Phase completion demos
|
+-- src/
|   +-- types/                    # (planned) Data structures
|   +-- transcriber/              # (planned) Core engine
|   +-- demos/                    # (planned) Visualizers
|
+-- assets/
|   +-- samples/                  # (planned) Packet samples
|   +-- cache/                    # (planned) Translation cache
|
+-- libs/                         # External dependencies
+-- tmp/                          # Project-specific temp files
+-- pictures/                     # Concept art and references
```

---

## Phases Overview

| Phase | Name | Status |
|-------|------|--------|
| 1 | Research WoW Protocol | Pending |
| 2 | Research CoH Protocol | Pending |
| 3 | Protocol Mapping Matrix | Pending |
| 4 | Translatable Data Types | Pending |
| 5 | Packet Visualizer | Pending |
| 6 | Transcriber Engine with Caching | Pending |

---

## Document Index

| Document | Purpose | Status |
|----------|---------|--------|
| `notes/vision` | Original creative vision | Complete |
| `docs/roadmap.md` | Development phases | Complete |
| `docs/architecture.md` | System design | Complete |
| `docs/translation-philosophy.md` | How translation works | Complete |
| `docs/wow-protocol.md` | WoW protocol details | Phase 1 |
| `docs/coh-protocol.md` | CoH protocol details | Phase 2 |
| `docs/protocol-mapping.md` | Translation mappings | Phase 3 |

---

## Issue Naming Convention

Format: `{PHASE}{ID}-{description}.md`

- `101-*` = Phase 1, Issue 01
- `102-*` = Phase 1, Issue 02
- `201-*` = Phase 2, Issue 01
- `601-*` = Phase 6, Issue 01
- `101a-*` = Phase 1, Issue 01, Sub-task A
