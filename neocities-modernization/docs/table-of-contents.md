# Documentation Table of Contents

## Neocities Poetry Modernization Project

This document provides a hierarchical view of all project documentation.

### 📖 Core Documentation
- `/docs/project-overview.md` - Complete project overview and technical specifications
- `/docs/roadmap.md` - Project phases and milestone tracking
- `/notes/vision` - Original project vision and requirements

### 🏆 Phase Completion Documentation  
- `/PHASE-1-COMPLETION-SUMMARY.md` - Phase 1 foundation and data preparation results
- `/docs/phase-2-completion-summary.md` - Phase 2 similarity engine development results

### 🔧 Technical Guides
- `/docs/data-flow-architecture.md` - Complete data flow architecture and seven-stage pipeline documentation
- `/docs/effil-vs-compute-shader-feasibility.md` - Feasibility analysis comparing effil threading vs GPU compute shaders for diversity pre-computation
- `/docs/similarity-algorithms-research-report.md` - Detailed similarity algorithm research with recommendations
- `/docs/similarity-algorithm-research.md` - Comprehensive research analysis of 12 similarity algorithms for poetry embeddings
- `/docs/similarity-matrix-generation-guide.md` - Technical documentation for similarity calculations

### 📋 Issues and Progress Tracking
- `/issues/completed/phase-1/` - Completed Phase 1 issues (foundation and data preparation)
- `/issues/completed/phase-2/` - Completed Phase 2 issues (similarity engine development)
- `/issues/completed/phase-3/` - Completed Phase 3 issues (core HTML generation & golden features)
- `/issues/completed/phase-3/` - Completed Phase 3 issues (core HTML generation system)
  - `/issues/completed/phase-3/001-implement-html-generation-system.md` - Complete HTML generation system (original large issue - sub-issues completed)
  - `/issues/completed/phase-3/005-implement-enhanced-fediverse-golden-poems-prioritization.md` - Golden poem prioritization system (sub-issues completed)
  - `/issues/completed/phase-3/progress.md` - Phase 3 completion status and metrics
- `/issues/completed/phase-4/` - Completed Phase 4 issues (data integrity & infrastructure improvements)
  - `/issues/completed/phase-4/002-implement-per-model-similarity-matrix-generation.md` - Per-model similarity matrix generation
  - `/issues/completed/phase-4/003-fix-character-counting-methodology-for-fediverse-golden-poems.md` - Fixed character counting for golden poems
  - `/issues/completed/phase-4/004-verify-and-resolve-cross-category-id-mapping.md` - Cross-category ID mapping validation
- `/issues/phase-5/` - Phase 5 issues (advanced discovery & optimization) - CURRENT
  - `/issues/phase-5/002-implement-per-model-similarity-matrix-generation.md` - Multi-model similarity matrix support
  - `/issues/phase-5/003-fix-character-counting-methodology-for-fediverse-golden-poems.md` - Golden poem identification accuracy
  - `/issues/phase-5/004-verify-and-resolve-cross-category-id-mapping.md` - Data integrity validation
  - `/issues/phase-5/007-replace-random-browsing-with-static-diverse-selection.md` - Static diverse selection algorithms
  - `/issues/phase-5/008a-implement-diversity-chaining-algorithm.md` - Core maximum diversity algorithm
  - `/issues/phase-5/008b-generate-mass-diversity-pages.md` - Batch generation of 6,840+ diversity pages
  - `/issues/phase-5/008c-create-diversity-discovery-interface.md` - User interface for diversity exploration
  - `/issues/phase-5/010b-implement-validation-framework.md` - Similarity validation testing framework
  - `/issues/phase-5/010c-generate-validation-reports.md` - Comprehensive validation reporting system
  - `/issues/phase-5/015-refactor-golden-poem-system-remove-prioritization.md` - Remove golden poem prioritization, keep visual distinction
  - `/issues/phase-5/progress.md` - Phase 5 planning and progress tracking
- `/issues/completed/phase-5/` - Completed Phase 5 issues
  - `/issues/completed/phase-5/002-implement-per-model-similarity-matrix-generation.md` - Multi-model similarity matrix generation with comparison capabilities (COMPLETED)
  - `/issues/completed/phase-5/010a-create-modular-similarity-calculator.md` - Modular similarity calculator with 8 algorithms (COMPLETED)
  - `/issues/completed/phase-5/010b-implement-validation-framework.md` - Validation framework with error detection and reporting (COMPLETED)
  - `/issues/completed/phase-5/010c-generate-validation-reports.md` - Multi-format report generator with comparative analysis (COMPLETED)
  - `/issues/completed/phase-5/011a-research-similarity-algorithms.md` - Comprehensive research analysis of 12 similarity algorithms (COMPLETED)
  - `/issues/completed/phase-5/016-implement-full-similarity-matrix-storage.md` - Full similarity matrix storage for complete HTML generation support (COMPLETED)
- `/issues/phase-6/` - Phase 6 issues (visual content & user experience enhancements) - PLANNED
  - `/issues/phase-6/012-implement-words-pdf-styled-export-system.md` - PDF export with words-pdf styling
  - `/issues/phase-6/016-implement-content-warning-collapsible-system.md` - Content warning hide/show functionality
  - `/issues/phase-6/017-create-image-configuration-and-directory-management-system.md` - Image discovery and configuration
  - `/issues/phase-6/018-implement-image-alt-text-embedding-analysis.md` - Intelligent image alt-text analysis
  - `/issues/phase-6/019-implement-chronological-image-placement.md` - Temporal image ordering system
  - `/issues/phase-6/020-implement-similarity-based-image-placement.md` - Similarity-based image placement for related/different pages
  - `/issues/phase-6/021-implement-html-template-image-rendering.md` - HTML template image integration
  - `/issues/phase-6/022-implement-screen-reader-accessibility-for-separators.md` - Screen reader accessibility for 80-character separators
  - `/issues/phase-6/024-implement-visual-timeline-progress-with-semantic-colors.md` - Visual timeline progress indicators with semantic color coding
- `/issues/7-progress.md` - Phase 7 progress tracking (stabilization & polish) - COMPLETED
  - `/issues/7-001-fix-run-sh-warnings-and-errors.md` - Fix pipeline warnings, errors, and fallbacks
- `/issues/8-progress.md` - Phase 8 progress tracking (website completion) - CURRENT
- `/issues/9-progress.md` - Phase 9 progress tracking (GPU acceleration) - PLANNED
- `/issues/10-progress.md` - Phase 10 progress tracking (developer tooling) - CURRENT
- `/issues/11-progress.md` - Phase 11 progress tracking (advanced exploration) - PLANNED
  - `/issues/11-001-implement-journey-style-similar-navigation.md` - Chain-based similar navigation (closest to previous poem)
  - `/issues/11-002-implement-maze-based-exploration-system.md` - Dimension-extreme maze with user choice at intersections
  - `/issues/11-002a-build-dimension-extreme-index.md` - Pre-compute 768 dimension extremes per poem
  - `/issues/11-002b-implement-similarity-filtered-choice-selection.md` - Filter to 6 most similar exits
  - `/issues/11-002c-generate-maze-html-pages.md` - Generate maze/XXX.html pages
  - `/issues/11-002d-add-special-room-features.md` - Golden poems, landmarks, easter eggs
  - `/issues/11-003-maze-pipeline-integration.md` - Integrate maze into run.sh pipeline

### 🎯 Source Documentation
- `/src/main.lua` - Interactive project management interface
- `/src/poem-extractor.lua` - Multi-category poem extraction system
- `/src/poem-validator.lua` - Data validation and quality analysis
- `/src/ollama-manager.lua` - Embedding service management
- `/src/similarity-engine.lua` - Core similarity calculation engine

### 📚 Utilities and Libraries
- `/libs/utils.lua` - Common utility functions and file operations
- `/libs/ollama-config.lua` - Ollama service configuration management

### 🗂️ Assets and Data
- `/assets/poems.json` - Complete poem dataset (6,860+ poems)
- `/assets/validation-report.json` - Data quality analysis report
- `/assets/embeddings/` - Per-model embedding storage directory structure

### 🛠️ Scripts and Tools
- `/run.sh` - Main project runner with interactive mode support
- `/phase-demo.sh` - Phase demonstration script selector
- `/generate-embeddings.sh` - Comprehensive embedding generation CLI

### 📁 Project Configuration
- `/.claude/CLAUDE.md` - Project-specific coding standards and requirements
- `/notes/` - Project planning and vision documents

---

## Document Maintenance

**Last Updated**: December 25, 2025  
**Maintained By**: Project development team  
**Update Policy**: All new documents must be added to this table of contents

### Adding New Documents
When creating new documentation:
1. Add the document to the appropriate section above
2. Use the format: `[path] - [brief description]`
3. Maintain alphabetical order within sections
4. Update the "Last Updated" date

### Document Categories
- **Core Documentation**: High-level project information
- **Phase Documentation**: Completion summaries and milestone reports  
- **Technical Guides**: Implementation and usage documentation
- **Issues**: Problem tracking and resolution documentation
- **Source Documentation**: Code files with embedded documentation
- **Utilities**: Supporting tools and library documentation
- **Assets**: Data files and generated content
- **Scripts**: Executable tools and automation
- **Configuration**: Project setup and standards files