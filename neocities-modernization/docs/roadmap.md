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
- Integration of complete HTML generation into `run.sh`
- Generation of all similarity-sorted pages (similar/XXX.html)
- Generation of all diversity-sorted pages (different/XXX.html)
- Rename "unique" to "different" for clarity
- Functional navigation between all pages

### Key Milestones:
1. Rename "unique" terminology to "different" throughout codebase
2. Integrate `flat-html-generator.lua` into automated pipeline
3. Generate ~12,000 HTML files for complete website
4. Verify all navigation links are functional
5. Optimize generation time if needed

**Active Issues:**
- `8-001-integrate-complete-html-generation-into-pipeline.md`
- `8-002-implement-multithreaded-html-generation.md`

**Completed Issues:**
- `8-003-remove-remaining-css-from-html-generation.md`
- `8-004-implement-embedding-validation-and-empty-poem-handling.md`

## Phase 9: GPU Acceleration 📋 **PLANNED**
**Duration**: TBD
**Goal**: Implement Vulkan compute infrastructure for vector-heavy operations

### Deliverables:
- Vulkan compute infrastructure with reusable wrapper
- GPU-accelerated diversity sequence generation
- GPU-accelerated similarity matrix calculation
- LuaJIT FFI integration layer
- Removal of effil dependency

### Key Milestones:
1. Set up Vulkan development environment
2. Implement core Vulkan compute wrapper
3. Create cosine distance and reduction shaders
4. Port diversity sequence generation to GPU
5. Port similarity matrix generation to GPU
6. Create Lua/C integration layer
7. Remove effil dependency

### Target Hardware:
- NVIDIA GTX 1080 Ti (3,584 CUDA cores, 11GB VRAM)
- 16 CPU threads available

### Performance Targets:
- Diversity sequence: 25s → 4-8s per sequence
- Similarity matrix: Hours → Minutes

**Issues:**
- `9-001-implement-vulkan-compute-infrastructure.md` (with sub-issues a-f)
- `9-002-port-similarity-matrix-to-vulkan.md` (with sub-issues)

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