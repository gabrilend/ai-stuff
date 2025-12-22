# 8-014: Configurable Asset Storage Paths

## Status: IN PROGRESS
## Priority: HIGH
## Created: 2025-12-21

---

## Scope

**ONLY affects generated/output assets** — files created by normal project operation:
- `assets/poems.json` - Extracted poem data
- `assets/validation-report.json` - Validation results
- `assets/image-catalog.json` - Image metadata
- `assets/embeddings/` - Per-model embedding vectors and similarity matrices

**Does NOT affect input files** — source data stays in project:
- `input/fediverse/` - Mastodon archive extracts
- `input/messages/` - Message extracts
- `input/notes/` - Note extracts
- `input/images/` - Source images

---

## Current Behavior

Asset paths are hardcoded throughout 19+ source files:
- Most files use `DIR .. "/assets/..."` pattern
- Some files (similarity engines) use bare `"assets/..."` relative paths
- No way to configure asset storage location externally
- Frequent writes to embeddings/similarity data wear out M.2 SSD

Hardcoded references found in:
- `libs/utils.lua` - `get_project_paths()` returns hardcoded `assets` subdirectory
- `src/main.lua` - 6 asset references
- `src/similarity-engine.lua` - 12 references, 2 bare relative paths
- `src/similarity-engine-parallel.lua` - 8 references, 3 bare relative paths
- Plus 15+ other files

---

## Intended Behavior

1. **Config file** (`config/asset-paths.lua`) defines the assets root path
2. **CLI override** (`--dir ~/path`) takes precedence over config
3. **Fail-fast** with helpful error message if path is inaccessible
4. All asset references use centralized functions from `utils.lua`

### Config File Format
```lua
-- config/asset-paths.lua
return {
    assets_root = "/mnt/hdd/neocities-assets"
}
```

### Error Message Format
```
Error: Assets directory not found: /path/here

Fix: supply path via --dir ~/your/assets/path

Expected structure:
  ~/your/assets/path/
    poems.json
    embeddings/
      EmbeddingGemma_latest/
        embeddings.json
```

---

## Suggested Implementation Steps

### Phase 1: Infrastructure
- [x] Create this issue file
- [x] Create `config/asset-paths.lua` with default path
- [x] Add asset config functions to `libs/utils.lua`:
  - `M.parse_assets_dir(args)` - Parse `--dir` from CLI
  - `M.load_asset_config()` - Load config file
  - `M.get_assets_root(cli_args)` - Priority: CLI > config > error
  - `M.asset_path(relative)` - Build full path to asset
  - `M.embeddings_dir(model_name)` - Get embeddings directory
  - `M.similarities_dir(model_name)` - Get similarities directory

### Phase 2: Core Files
- [x] Update `src/main.lua`
- [x] Update `src/poem-extractor.lua`
- [x] Update `src/poem-validator.lua`

### Phase 3: Similarity Engines (Critical)
- [x] Update `src/similarity-engine.lua` - fixed 2 bare relative paths
- [x] Update `src/similarity-engine-parallel.lua` - fixed 3 bare relative paths

### Phase 4: Other Processors
- [x] Update `src/flat-html-generator.lua`
- [x] Update `src/image-manager.lua`
- [x] Update `src/semantic-color-calculator.lua`
- [x] Update `src/regenerate-clean-site.lua`

### Phase 5: HTML Generators
- [x] Update `src/html-generator/template-engine.lua`
- [x] Update `src/html-generator/golden-collection-generator.lua`

### Phase 6: Test/Demo Files
- [x] Update `demos/4-demo.lua`, `demos/5-demo.lua`, `demos/6-demo.lua`
- [ ] Update `src/test-*.lua` files (optional - test files)
- [ ] Update `src/run-validation*.lua` files (optional - test files)

### Phase 7: Shell Scripts
- [x] Update `run.sh` to pass `--dir`
- [x] Update `generate-embeddings.sh`
- [ ] Update `phase-demo.sh` (optional)

### Phase 8: Test & Complete
- [x] Test default config (existing location)
- [x] Test config file override
- [x] Test CLI override
- [x] Test missing directory (fail-fast)
- [ ] Test interactive and non-interactive modes
- [x] Commit changes

---

## Related Documents
- `docs/roadmap.md` - Phase 8 objectives
- `libs/utils.lua` - Central utility module
- `config/input-sources.json` - Existing config pattern (JSON)

---

## Notes

- The `~` symbol in `--dir ~/path` means "wherever" (user convention), not home directory
- Bare relative paths in similarity engines are a bug that gets fixed by this work
- No fallback behavior - fail fast with clear instructions per CLAUDE.md guidelines
