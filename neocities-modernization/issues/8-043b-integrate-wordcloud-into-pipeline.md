# Issue 8-043b: Integrate Word Cloud Into Pipeline Stages

## Priority
Medium

## Current Behavior

The word cloud feature exists but is not integrated into the main pipeline:

1. `src/wordcloud-generator.lua` - Generates `wordcloud.html` (standalone)
2. `src/generate-word-pages.lua` - Generates word embeddings AND HTML pages in one step

**Problem**: `generate-word-pages.lua` generates embeddings on-the-fly during HTML page creation (lines 342-362), violating the separation of concerns:
- Stage 6 = Embedding generation (expensive, cached)
- Stage 9 = HTML generation (fast, uses cached data)

## Intended Behavior

### Pipeline Integration

1. **Stage 6 (Embeddings)**: Generate word embeddings via Ollama
   - Extract word list from poems
   - Generate embeddings for each word
   - Cache to `assets/embeddings/{model}/word_embeddings.json`

2. **Stage 9 (HTML)**: Generate word cloud HTML pages
   - Generate `wordcloud.html` (word cloud menu)
   - Generate `wordcloud/{word}.html` pages (word similarity pages)
   - Require embeddings to already exist

### Benefits

1. **Incremental updates**: Regenerate HTML without recomputing embeddings
2. **Cacheability**: Word embeddings persist across runs
3. **Consistency**: Same stage boundaries as poem embeddings
4. **Error isolation**: Embedding failures don't block HTML generation

## Suggested Implementation Steps

### 1. Add word embedding generation to Stage 6

Update `run_generate_embeddings()` in `run.sh` to also generate word embeddings:

```bash
# After poem embeddings, generate word embeddings
log_info "   Generating word embeddings..."
luajit src/generate-word-pages.lua "$DIR" --embeddings-only
```

### 2. Refactor generate-word-pages.lua

Add `--embeddings-only` mode that:
- Extracts word list from poems
- Generates embeddings for missing words
- Saves cache
- Does NOT generate HTML

Add `--html-only` mode that:
- Loads cached word embeddings
- Errors if embeddings missing (instead of generating on-the-fly)
- Generates HTML pages

### 3. Add wordcloud generators to Stage 9

Update `run_generate_html()` in `run.sh`:

```bash
# Generate word cloud pages
log_info "   Generating word cloud..."
luajit src/wordcloud-generator.lua "$DIR"
luajit src/generate-word-pages.lua "$DIR" --html-only
```

### 4. Add freshness checks

- Word embeddings should be regenerated if poems.json is newer
- HTML should be regenerated if embeddings are newer

## Related Documents

- Issue 8-043: Generate Semantic Word Cloud Page (parent issue)
- `src/generate-word-pages.lua` - Current mixed implementation
- `src/wordcloud-generator.lua` - Word cloud menu generator
- `run.sh` - Pipeline orchestration

## Implementation Progress: 2026-01-21

### Refactored generate-word-pages.lua

Added separate modes for embedding generation and HTML generation:

```lua
-- New functions:
M.generate_word_embeddings(options)  -- Stage 6: Expensive, calls Ollama
M.generate_word_html(options)        -- Stage 9: Fast, uses cached embeddings
M.generate_word_pages(options)       -- Backward compatible: both stages

-- CLI flags:
--embeddings-only   -- Run only embedding generation
--html-only         -- Run only HTML generation (requires embeddings)
(no flag)           -- Run both (backward compatible)
```

### Updated run.sh

**Stage 6 (Embeddings)**: After poem embeddings, generates word embeddings:
```bash
# In run_generate_embeddings()
log_info "   Generating word embeddings for word cloud..."
luajit "$DIR/src/generate-word-pages.lua" "$DIR" --embeddings-only
```

**Stage 9 (HTML)**: After main HTML, generates word cloud pages:
```bash
# In run_generate_html()
log_info "   Generating word cloud menu..."
luajit "$DIR/src/wordcloud-generator.lua" "$DIR"

log_info "   Generating word similarity pages..."
luajit "$DIR/src/generate-word-pages.lua" "$DIR" --html-only
```

### Pipeline Flow

```
Stage 6: Generate Embeddings
  ├── Poem embeddings (generate-embeddings.sh)
  ├── Semantic colors (semantic-color-calculator)
  └── Word embeddings (generate-word-pages.lua --embeddings-only)  ← NEW

Stage 9: Generate HTML
  ├── Main HTML (src/main.lua --html-only)
  ├── Word cloud menu (wordcloud-generator.lua)  ← NEW
  └── Word pages (generate-word-pages.lua --html-only)  ← NEW
```

## Metadata

- **Status**: Complete
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 8 (Website Completion)
- **Parent Issue**: 8-043
