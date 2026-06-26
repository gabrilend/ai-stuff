# Project Roadmap

## Phase 1: Foundation and Data Preparation ✅ **COMPLETED**
**Duration**: Completed November 2025
**Goal**: Set up infrastructure and extract source data
**Issues Location**: `issues/completed/phase-1/`

### Deliverables: ✅
- ✅ Poem extraction system from words.pdf
- ✅ Ollama embedding service configuration  
- ✅ Data validation and cleaning pipeline
- ✅ Basic project structure and utilities
- ✅ Port configuration standardization

### Key Milestones: ✅
1. ✅ Successfully extract individual poems from source material
2. ✅ Establish working Ollama connection with embedding models
3. ✅ Generate embeddings for test poems
4. ✅ Validate poem parsing accuracy

**Completed Issues:** (see `issues/completed/phase-1/`)
- `001-setup-poem-extraction-system.md`
- `002-configure-ollama-embedding-service.md`
- `003-implement-data-validation-pipeline.md`
- `004-create-project-utilities-and-scripts.md`
- `005-standardize-ollama-port-configuration.md`

## Phase 2: Similarity Engine Development ✅ **COMPLETED**
**Duration**: Completed November 2025  
**Goal**: Build core similarity calculation system and embedding generation
**Issues Location**: `issues/completed/phase-2/`

### Deliverables: ✅
- ✅ Complete embedding generation system for all poems
- ✅ Incremental caching system with smart detection
- ✅ Robust error handling and network resilience
- ✅ Per-model embedding storage isolation
- ✅ Interactive bash script with real-time monitoring
- ✅ Cache management and flush operations
- ✅ Similarity matrix calculation system

### Key Milestones: ✅
1. ✅ Generate embeddings for all poems with incremental processing
2. ✅ Implement robust caching and validation systems
3. ✅ Create network error tolerance and retry mechanisms
4. ✅ Establish per-model storage for different embedding models
5. ✅ Build comprehensive CLI tools for embedding management

**Completed Issues:** (see `issues/completed/phase-2/`)
- `003-design-similarity-engine-architecture.md`
- `004-implement-incremental-embedding-caching-system.md`
- `005-always-retry-failed-embedding-entries.md`
- `006-implement-network-error-timeout-termination.md`
- `007-implement-cache-flush-option.md`
- `008-implement-per-model-embedding-storage.md`
- `009-fix-progress-bar-and-graceful-termination.md` (completed)

## Phase 3: Core HTML Generation & Golden Features ✅ **COMPLETED**
**Duration**: December 2025 (Completed)
**Goal**: Essential static site generation with core poem browsing and golden features
**Issues Location**: `issues/completed/phase-3/`

### Deliverables: ✅
- ✅ HTML template system for poem pages
- ✅ Similarity-based poem recommendation engine
- ✅ Hierarchical URL structure generator
- ✅ Responsive web design for mobile/desktop
- ✅ JavaScript-free static HTML implementation
- ✅ Golden poem identification and collection pages
- ✅ Static file organization for deployment

### Key Milestones: ✅
1. ✅ Generate individual poem HTML pages with similarity links
2. ✅ Implement clean, hierarchical URL structure
3. ✅ Create navigation system between related poems
4. ✅ Build responsive, accessible web interface
5. ✅ Organize static files for neocities deployment
6. ✅ Implement golden poem features with fediverse optimization
7. ✅ Remove all JavaScript dependencies for pure static HTML

**Completed Issues:** (see `issues/completed/phase-3/`)
- `001a-create-html-template-system.md`
- `001b-implement-url-structure-design.md`
- `001c-build-similarity-navigation.md`
- `001d-responsive-design-implementation.md`
- `005a-implement-golden-poem-similarity-bonus.md`
- `005b-create-golden-poem-visual-indicators.md`
- `005c-build-golden-poem-collection-pages.md`
- `006-remove-javascript-dependencies-from-static-html.md`
- `009-generate-embedding-based-similarity-and-diversity-lists.md`

## Phase 4: Data Integrity & Infrastructure Improvements 📊 **COMPLETED**
**Duration**: December 2025 (Completed)
**Goal**: Fix data quality issues and improve infrastructure foundation
**Issues Location**: `issues/completed/phase-4/`

### Deliverables: ✅
- ✅ Fixed character counting methodology for accurate golden poem identification
- ✅ Verified cross-category ID mapping for data integrity
- ✅ Per-model similarity matrix generation for multi-model support

### Key Milestones: ✅
1. ✅ Resolve golden poem identification accuracy (target ~100 poems)
2. ✅ Validate cross-category poem ID mapping integrity
3. ✅ Implement per-model similarity matrix support

**Completed Issues:** (see `issues/completed/phase-4/`)
- `002-implement-per-model-similarity-matrix-generation.md`
- `003-fix-character-counting-methodology-for-fediverse-golden-poems.md`
- `004-verify-and-resolve-cross-category-id-mapping.md`

## Phase 5: Advanced Discovery & Optimization ✅ **COMPLETED**
**Duration**: December 2025 (Completed)
**Goal**: Advanced exploration features and system optimization

### Deliverables:
- Dual system implementation: simple similarity ranking + progressive centroid-based diversity chaining
- Comprehensive similarity algorithm research and implementation
- Similarity validation and testing framework
- Performance optimization for dual system generation (13,680+ files)
- Advanced browsing interfaces with complementary exploration modes

### Key Milestones:
1. Implement dual system: simple similarity ranking + progressive centroid-based diversity chaining
2. Research and implement 10+ similarity algorithms with comparative analysis
3. Build comprehensive validation framework for similarity data integrity
4. Create advanced discovery interfaces supporting both similarity and diversity exploration modes
5. Optimize performance for dual system generation and algorithm selection based on validation results

**Active Issues:**
- `007-replace-random-browsing-with-static-diverse-selection.md`
- `008-implement-dual-system-precached-pages.md` (revised for similarity + diversity dual system)
- `008a-implement-diversity-chaining-algorithm.md` (requires update for centroid approach)
- `008b-generate-mass-diversity-pages.md` (now includes dual system generation)
- `008c-create-diversity-discovery-interface.md` (now includes dual navigation)
- `010a-create-modular-similarity-calculator.md`
- `010b-implement-validation-framework.md`
- `010c-generate-validation-reports.md`
- `011a-research-similarity-algorithms.md`
- `013-implement-flat-html-compiled-txt-recreation.md` (moved from Phase 4)
- `014-implement-similarity-link-navigation.md` (moved from Phase 4)
- Plus additional sub-issues for complete algorithm implementation

## Phase 6: Visual Content & User Experience Enhancements ✅ **COMPLETED**
**Duration**: December 2025 (Completed)
**Goal**: Enhanced user experience with visual content and accessibility features

### Deliverables: ✅
- ✅ Image integration system with media attachment cataloging
- ✅ Scripts directory fully integrated into pipeline
- ✅ Privacy and anonymization systems working
- ✅ CSS-free HTML generation complete

**Completed Issues:** (see `issues/completed/`)
- `6-026b-adapt-output-format-for-html-generation.md`
- `6-028-replace-css-with-hard-coded-html-generation.md`

## Phase 7: Stabilization and Polish ✅ **COMPLETED**
**Duration**: December 2025 (Completed)
**Goal**: Eliminate warnings, errors, and fallbacks from the pipeline

### Deliverables: ✅
- ✅ Zero warnings during pipeline execution
- ✅ Zero errors during pipeline execution
- ✅ Clean, minimal output with relative paths
- ✅ Accurate validation statistics (431 golden poems)
- ✅ Robust handling of edge cases

**Completed Issues:** (see `issues/completed/`)
- `7-001-fix-run-sh-warnings-and-errors.md`
- `7-002-clean-up-run-sh-output.md`

## Phase 8: Website Completion 🔄 **CURRENT**
**Duration**: December 2025 (In Progress)
**Goal**: Complete website generation pipeline for full deployment

### Deliverables:
- ✅ Integration of complete HTML generation into `run.sh`
- ✅ Rename "unique" to "different" for clarity
- ✅ Image integration (532 images with lazy loading)
- ✅ Freshness checking for extraction and generation
- ✅ Complete embeddings for all poems
- Similarity matrix generation (run `./scripts/validate-pipeline-data --quick` to check)
- Generation of all similarity-sorted pages (blocked by similarity matrix)
- Generation of all diversity-sorted pages (blocked by diversity cache)

### Key Milestones:
1. ✅ Rename "unique" terminology to "different" throughout codebase
2. ✅ Integrate `flat-html-generator.lua` into automated pipeline
3. ✅ Implement freshness checking (skip unchanged data)
4. ✅ Integrate images into HTML output
5. ✅ Complete embedding generation (7,797 poems)
6. 🔄 Calculate similarity matrix for all poems
7. ❌ Generate ~15,590 HTML files for complete website
8. ❌ Verify all navigation links are functional

**Active Issues:**
- `8-001-integrate-complete-html-generation-into-pipeline.md` (Steps 1-3 ✅, Step 4 pending)
- `8-002-implement-multithreaded-html-generation.md` (infrastructure ✅, full run pending)
- `8-012-implement-paginated-similarity-chapters.md`

**Completed Issues:**
- `8-003-remove-remaining-css-from-html-generation.md`
- `8-004-implement-embedding-validation-and-empty-poem-handling.md`
- `8-005-integrate-images-into-html-output.md`
- `8-006-fix-golden-poem-box-drawing-format.md`
- `8-007-add-box-drawing-borders-around-navigation-links.md`
- `8-008-implement-configurable-centroid-embedding-system.md`
- `8-009-project-cleanup-and-organization.md`
- `8-010-fix-note-filenames-in-generated-html.md`
- `8-013-implement-txt-export-functionality.md`
- `8-015-implement-zip-extraction-freshness-check.md`

## Deployment Readiness Assessment 📊

This section tracks progress toward deploying the complete website to Neocities.

> **To check current status:** Run `./scripts/validate-pipeline-data`
> **Quick check:** Run `./scripts/validate-pipeline-data --quick`

### Required Components

| Component | Description | Blocker? |
|-----------|-------------|----------|
| Poems corpus | Source poems from fediverse/messages/notes | No |
| Embeddings | 768-dim vectors for semantic similarity | No |
| Similarity matrix | Per-poem similarity rankings | Yes (if incomplete) |
| Diversity cache | Pre-computed diversity sequences | Optional |
| Similar pages | Per-poem HTML similarity pages | Blocked by matrix |
| Different pages | Per-poem HTML diversity pages | Blocked by cache |
| Chronological index | Main entry page | No |
| Word cloud (menu) | Site entry page; embeds the live poem index | No |
| Explore page | Discovery instructions | No |

### Expected Final Output

```
output/
├── index.html              (→ chronological.html)
├── chronological.html      (~12 MB, all poems)
├── wordcloud.html          (menu + embedded poem index)
├── explore.html            (~1 KB)
├── similar/
│   └── XXXX-NN.html        (per-poem similarity pages, paginated)
├── different/
│   └── XXXX-NN.html        (per-poem diversity pages, paginated)
└── input/media_attachments/ (images)

Run ./scripts/validate-pipeline-data to see actual generation progress.
```

### Deployment Pipeline Steps

**Step 1: Complete Embeddings**
- Tool: `./generate-embeddings.sh`
- Check status: `./scripts/validate-pipeline-data --quick | grep EMBEDDING`

**Step 2: Calculate Similarity Matrix**
- Tool: `lua src/similarity-engine-parallel.lua`
- Generates: Individual similarity JSON files per poem
- Check status: `./scripts/validate-pipeline-data --quick | grep SIMILARITY`

**Step 3: Pre-compute Diversity Cache** (optional, speeds up Step 4)
- Tool: `./scripts/precompute-diversity-sequences`
- Generates: `diversity_cache.json`
- Benefit: Reduces Step 4 from days → ~1 hour
- Check status: `./scripts/validate-pipeline-data --quick | grep DIVERSITY`

**Step 4: Generate All HTML Pages** (depends on Steps 1-2)
- Tool: `./scripts/generate-html-parallel`
- Generates: similar/ and different/ HTML pages
- Est. time WITH cache: ~1 hour
- Est. time WITHOUT cache: ~3 days

**Step 5: Deploy to Neocities**
- Deploy: `output/` directory contents
- Deploy: `input/media_attachments/` for images
- Total upload: ~95 GB

### Configuration Reference

**Pagination settings** (`config/input-sources.json`):
```json
{
  "pagination": {
    "poems_per_page": 100,
    "minimum_pages": 1,
    "generate_txt_exports": true
  }
}
```

**Generation script limits** (`scripts/generate-html-parallel`):
```lua
NUM_THREADS = 8           -- Parallel workers
DIVERSITY_LIMIT = 0       -- 0 = all poems (no limit)
USE_CACHE = true          -- Use pre-computed sequences
TEST_MODE = false         -- Set true for 10-page test
```

### Quick Commands for Full Deployment

```bash
# 1. Ensure Ollama is running with CUDA
./scripts/start-ollama-cuda.sh

# 2. Generate missing embeddings
./generate-embeddings.sh

# 3. Calculate similarity matrix
lua src/similarity-engine-parallel.lua

# 4. (Optional) Pre-compute diversity - runs 42 hours
./scripts/precompute-diversity-sequences &

# 5. Generate all HTML pages
./scripts/generate-html-parallel 8

# 6. Verify output
ls output/similar/ | wc -l    # Should be 7,793
ls output/different/ | wc -l  # Should be 7,793
```

### Estimated Total Time to Deployment

| Scenario | Embeddings | Similarity | Diversity Cache | HTML Gen | Total |
|----------|------------|------------|-----------------|----------|-------|
| **Fast path** (with cache) | 1 hour | 2 hours | 42 hours | 1 hour | ~46 hours |
| **Slow path** (no cache) | 1 hour | 2 hours | skip | 72 hours | ~75 hours |

---

## Phase 9: GPU Acceleration ✅ **COMPLETED**
**Goal**: Implement Vulkan compute infrastructure for vector-heavy operations

### Deliverables: ✅
- ✅ Vulkan compute infrastructure with reusable wrapper (`libs/vulkan-compute/`)
- ✅ GPU-accelerated diversity sequence generation
  (`scripts/precompute-diversity-sequences-gpu`)
- ✅ GPU-accelerated similarity rankings cache
  (`scripts/generate-similarity-rankings-cache`)
- ✅ LuaJIT FFI integration layer (`libs/vulkan-compute/lua/vk_compute.lua`)
- ✅ effil retained for HTML generation (orchestrator pattern in
  `src/flat-html-generator.lua`); Vulkan replaces it for the numeric
  heavy lifting, but the dependency itself is still used.

### Key Milestones: ✅
1. ✅ Set up Vulkan development environment
2. ✅ Implement core Vulkan compute wrapper
3. ✅ Create cosine distance and reduction shaders
4. ✅ Port diversity sequence generation to GPU
5. ✅ Port similarity matrix generation to GPU
6. ✅ Create Lua/C integration layer
7. ⏸️ effil dependency NOT removed — kept for the HTML-generation
   orchestrator path, which remains CPU-side per the analysis in
   `docs/effil-vs-compute-shader-feasibility.md`.

### Target Hardware:
- NVIDIA GTX 1080 Ti (3,584 CUDA cores, 11GB VRAM)
- 16 CPU threads available

### Achieved Performance:
- Diversity sequence: ~42 hours CPU → ~58 seconds GPU (per
  `scripts/precompute-diversity-sequences-gpu`'s preamble: 2,600× speedup)
- Similarity rankings cache: produced in single-digit minutes via GPU

### Issues:
- `9-001-implement-vulkan-compute-infrastructure.md` (with sub-issues a–g)
- `9-002-port-similarity-matrix-to-vulkan.md` (with sub-issue a)
- `9-003-port-diversity-sequences-to-vulkan.md` (with sub-issue a)
- `9-005-gpu-output-architecture.md` (with sub-issue b)

## Phase 11: Advanced Exploration 📋 **PLANNED**
**Duration**: TBD
**Goal**: Innovative navigation systems with user agency

### Deliverables:
- Journey-style similar navigation (chain-based, not origin-based)
- k-nearest-neighbors graph infrastructure
- Maze-based exploration with user choice at intersections
- Four complementary navigation modes

### Key Milestones:
1. Implement journey-style algorithm (closest to previous, not origin)
2. Build k-NN graph (each poem → 6 nearest neighbors)
3. Generate spanning tree mazes from k-NN graph
4. Create maze HTML pages with intersection choices
5. Integrate all four modes into poem headers

### Navigation Mode Comparison:
| Mode | Algorithm | User Agency |
|------|-----------|-------------|
| Similar | Closest to origin | None |
| Journey | Closest to previous | None |
| Different | Farthest from centroid | None |
| **Maze** | k-NN graph + spanning tree | **Choose at intersections** |

**Issues:**
- `11-001-implement-journey-style-similar-navigation.md`
- `11-002-implement-maze-based-exploration-system.md`

## Phase 13: Audio-Visual Generation 📋 **PLANNED**
**Duration**: TBD
**Goal**: Transform embedding data into audio and visual experiences via TTS and stable diffusion

### Deliverables:
- Text-to-speech engine integrated into the Lua pipeline
- Flopsopoly generation algorithm (frequency-weighted centroid-expansion word sequences)
- Hypnotic TTS trance track from word-cloud vocabulary
- Stable diffusion visual sequence with diameter-based context windowing
- Manifest files for audio-visual synchronization

### Key Concepts:
- **Flopsopoly of Verbrases**: A word pool where each word appears N times (N = font size), ordered by progressive centroid expansion for maximum diversity with self-regulating duplicate spacing
- **Diameter-Based Context**: Image prompts use N/2 words forward and N/2 backward from current position
- **Local Inference**: Both TTS and stable diffusion run locally (no cloud APIs)

### Key Milestones:
1. Research and select TTS engine (local, Lua-compatible)
2. Implement flopsopoly generation from word-cloud data
3. Generate hypnotic trance audio track
4. Integrate local stable diffusion API
5. Generate visual sequence with diameter-based context prompts
6. Produce synchronized audio-visual manifest

### Target Hardware:
- CPU: TTS engine execution
- GPU: Stable diffusion inference (local instance, IP:port configurable)
- Storage: Audio files, generated images (~1.5GB for full sequence)

**Issues:**
- `13-001-research-and-implement-tts-engine.md`
- `13-002-generate-tts-hypnotic-trance-from-wordcloud-flopsopoly.md`
- `13-003-generate-stable-diffusion-visuals-from-flopsopoly.md`
- `13-004-assemble-video-from-tts-audio-and-generated-images.md`

---

## Future Phases (Planned)

### Visual Content Enhancement
- Complete image integration with intelligent placement
- Content warning collapsible system for user safety
- Words-PDF styled export system with graphical formatting
- Multi-format export capabilities (.txt and .pdf downloads)

### Accessibility Enhancement
- Enhanced accessibility and visual presentation
- Alt-text embedding analysis for intelligent image placement

## Project Success Criteria:
- All poems from words.pdf successfully processed ✅
- Similarity recommendations feel accurate and useful ✅
- Fast loading static HTML pages ✅
- Clean, hierarchical URL structure ✅
- Seamless integration with existing website ✅
- Advanced discovery features for content exploration 🔄
- Visual content integration enhances user experience 📋
- Accessibility features support diverse user needs 📋
- Export capabilities provide flexible content access 📋