-- {{{ Asset Path Configuration
-- Configurable storage location for generated assets (embeddings, poems.json, etc.)
--
-- Override with CLI argument: lua src/main.lua --dir ~/your/assets/path
-- (Note: ~ means "wherever", not home directory)
--
-- This ONLY affects generated/output assets:
--   poems.json              - Extracted poem data
--   validation-report.json  - Validation results
--   image-catalog.json      - Image metadata
--   embeddings/             - Per-model embedding vectors and similarity matrices
--
-- Input files (input/fediverse/, input/messages/, etc.) are NOT affected.
-- }}}

return {
    -- Primary storage location for generated assets
    -- Default: project's assets/ directory
    assets_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization/assets"
}
