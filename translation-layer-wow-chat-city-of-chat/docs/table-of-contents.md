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
|   +-- roadmap.md                # 4-phase development plan
|   +-- architecture.md           # System design overview
|   |
|   +-- [Phase 1 - Protocol Research]
|   |   +-- wow-protocol.md       # (planned) WoW protocol analysis
|   |   +-- coh-protocol.md       # (planned) CoH protocol analysis
|   |   +-- protocol-mapping.md   # (planned) Cross-game mappings
|   |
|   +-- [Phase 2 - LLM Integration]
|   |   +-- llm-integration.md    # (planned) LLM system design
|   |
|   +-- [Phase 3 - Narrative System]
|       +-- narrative-system.md   # (planned) DM spirit design
|
+-- issues/
|   +-- phase-1-progress.md       # Phase 1 tracking
|   +-- 101-*.md                  # Phase 1 issues
|   +-- completed/
|       +-- demos/                # Phase completion demos
|
+-- src/
|   +-- protocol/                 # (planned) Packet parsing
|   +-- translation/              # (planned) Rule engine
|   +-- llm/                      # (planned) LLM integration
|   +-- narrative/                # (planned) DM spirit
|   +-- network/                  # (planned) Proxy layer
|
+-- libs/                         # External dependencies
+-- assets/                       # Game data, mappings
+-- tmp/                          # Project-specific temp files
```

---

## Document Index

| Document | Purpose | Status |
|----------|---------|--------|
| `notes/vision` | Original creative vision | Complete |
| `docs/roadmap.md` | Development phases | Complete |
| `docs/architecture.md` | System design | Complete |
| `docs/wow-protocol.md` | WoW protocol details | Phase 1 |
| `docs/coh-protocol.md` | CoH protocol details | Phase 1 |
| `docs/protocol-mapping.md` | Translation mappings | Phase 1 |
| `docs/llm-integration.md` | LLM system design | Phase 2 |
| `docs/narrative-system.md` | Narrative engine | Phase 3 |

---

## Issue Naming Convention

Format: `{PHASE}{ID}-{description}.md`

- `101-*` = Phase 1, Issue 01
- `102-*` = Phase 1, Issue 02
- `201-*` = Phase 2, Issue 01
- `101a-*` = Phase 1, Issue 01, Sub-task A
