# Issue 052: Update Ollama Connection Configuration

**Phase**: 0 - Tooling
**Status**: Open (REQUIRES VERBOSE CONFIRMATION)
**Priority**: Standard
**Created**: 2026-02-17
**Type**: Cross-Project Configuration Update

---

## ⚠️ CONFIRMATION REQUIRED

This issue affects multiple projects across the ai-stuff repository.
**No changes will be made until explicit user confirmation is received.**

### Confirmation Protocol
1. List all affected files with current values
2. Show proposed changes for each file
3. Query available Ollama models for selection
4. Research best embedding models for 32GB VRAM
5. Present complete change summary
6. **WAIT FOR USER APPROVAL** before any modifications

---

## Current Behavior

Ollama connection information is scattered across multiple projects with values:
- **Host/IP**: `192.168.0.115` (varies by project)
- **Port**: `11434` (typical default)
- **Models**: Various (EmbeddingGemma for embeddings, others for generation)

### Known Locations (to be discovered)
- `neocities-modernization/libs/ollama-config.lua`
- Other project configuration files (TBD via grep)

---

## Intended Behavior

Update all Ollama connection configuration to:
- **Host/IP**: `192.168.0.61`
- **Port**: `16180`
- **Generation Model**: TBD (best available for general text processing)
- **Embedding Model**: TBD (best available for 32GB VRAM)

### Model Selection Criteria
- **Generation Model**: General text processing, no tool-call requirement
- **Embedding Model**: High quality, can utilize 32GB VRAM (currently using EmbeddingGemma)

---

## Suggested Implementation Steps

### Phase 1: Discovery (No Changes)
1. [ ] Grep for `192.168.0.115` across all ai-stuff projects
2. [ ] Grep for common Ollama port patterns (11434, ollama)
3. [ ] Grep for model configuration (embedding, generation models)
4. [ ] Compile complete list of affected files

### Phase 2: Research (No Changes)
1. [ ] Query new Ollama endpoint for available models
2. [ ] Research best embedding models for 32GB VRAM
3. [ ] Compare current EmbeddingGemma with alternatives
4. [ ] Determine optimal models for each use case

### Phase 3: Present Changes (Await Confirmation)
1. [ ] Show each file with before/after diff preview
2. [ ] Summarize total changes (file count, line count)
3. [ ] **REQUIRE explicit "yes" confirmation**

### Phase 4: Apply Changes (Only After Confirmation)
1. [ ] Backup affected files (optional)
2. [ ] Apply changes using Edit tool
3. [ ] Verify changes with grep
4. [ ] Create commit with all changes

---

## Affected Files

### Discovered via grep (to be populated)
```
[Run grep for 192.168.0.115 to populate this list]
```

### Change Preview (to be populated)
```
[For each file, show:
  File: /path/to/file.lua
  Line X: OLD_VALUE → NEW_VALUE
]
```

---

## Model Research

### Available Models on 192.168.0.61:16180
```
[Query /api/tags to populate]
```

### Embedding Model Recommendations
```
[Research findings to populate]
```

---

## Acceptance Criteria

- [ ] All instances of old IP (192.168.0.115) replaced with new IP (192.168.0.61)
- [ ] All Ollama ports updated to 16180
- [ ] Generation model selected and configured
- [ ] Embedding model selected and configured
- [ ] User explicitly confirmed all changes before application
- [ ] Git commit created documenting the change

---

## Notes

This issue implements a "verbose confirmation" workflow:
- All changes are previewed before application
- User must explicitly approve the change set
- Changes are atomic (all or nothing)
- Full audit trail maintained in this issue file

---

## Related

- Issue 049d: Ollama Processing Pipeline (uses these connection settings)
- neocities-modernization: Primary user of Ollama for embeddings
