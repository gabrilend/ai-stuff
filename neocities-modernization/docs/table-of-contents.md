# Documentation Table of Contents

## Neocities Poetry Modernization Project

This document provides a hierarchical view of all project documentation.
`scripts/check-table-of-contents` reports any path below that no longer exists
and any file in `docs/` or `notes/` that is not listed here.

### 📖 Core Documentation
- `/docs/project-overview.md` - Complete project overview and technical specifications
- `/docs/roadmap.md` - Project phases and milestone tracking
- `/notes/vision` - Original project vision and requirements

### 🧭 Phases
Phases group the work by kind of functionality, not by time; a low-numbered
phase can still have open issues. Each phase's progress file lists its issues
and what they add up to. Live done/open counts per phase come from
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`.
Issue files themselves live in `/issues/` (open) and `/issues/completed/`.
- `/issues/1-progress.md` - Phase 1: foundation and data preparation
- `/issues/2-progress.md` - Phase 2: similarity engine development
- `/issues/3-progress.md` - Phase 3: core HTML generation and golden features
- `/issues/4-progress.md` - Phase 4: data integrity and infrastructure
- `/issues/5-progress.md` - Phase 5: flat HTML generation and design consistency
- `/issues/6-progress.md` - Phase 6: image integration and chronological enhancements
- `/issues/7-progress.md` - Phase 7: stabilization and polish
- `/issues/8-progress.md` - Phase 8: website completion
- `/issues/9-progress.md` - Phase 9: GPU acceleration
- `/issues/10-progress.md` - Phase 10: developer experience and tooling
- `/issues/11-progress.md` - Phase 11: advanced exploration
- `/issues/12-progress.md` - Phase 12: experimental AI features
- `/issues/13-progress.md` - Phase 13: audio-visual generation from the embedding space
- `/issues/14-progress.md` - Phase 14: narrative tapestry, from spindle to woven cloth
- `/issues/15-progress.md` - Phase 15: chromatic encoding, text as colour
- `/issues/16-progress.md` - Phase 16: network media, Android as source, WiFi as bridge
- `/issues/17-progress.md` - Phase 17: embedding manipulation and interactive tools

### 🏆 Phase Completion Documentation
- `/docs/phase-1-completion-summary.md` - Phase 1 foundation and data preparation results
- `/docs/phase-2-completion-summary.md` - Phase 2 similarity engine development results

### 🕰️ Process and Reading
Documents about HOW the work happened, rather than what it produced. Kept because
the reasoning behind a decision decays faster than the decision, and because some
of what the code does is only visible from outside it.
- `/notes/development-cadence-aug-7-through-9-2026` - The shape of three days:
  message timing and silences, the three registers the work is spoken in, and a
  reading of the words that meant two things (the copula that became a
  directory, the dry run that was wet, the bar too wide to reach its own start)
- `/notes/session-summary-2026-01-12.md` - What one January session built: the
  hope-card PDF export's first phase and the incremental-centroid design
- `/notes/ooouuuaaeeem` - A poem: a greenhouse made of questions
- `/docs/design-audit-report.md` - December 2025 audit of every issue for design consistency
- `/docs/issue-consolidation-summary.md` - December 2025 consolidation of the issue set

### 🔧 Technical Guides
- `/docs/config-reference.md` - Every section of config.lua, generated from its own comments, plus how-to recipes
- `/docs/data-flow-architecture.md` - Complete data flow architecture and seven-stage pipeline documentation
- `/docs/words-pdf-integration.md` - Integration guide for words-pdf PDF generation system
- `/docs/centroids-for-hope-cards.md` - Using centroid system for semantic hope card selection
- `/docs/hope-card-pdf-export-design.md` - Design of the printable hope-card PDF export (Issue 6-012)
- `/docs/hope-card-pdf-export-phase-1-report.md` - What the hope-card export's first phase built (Issue 6-012)
- `/docs/incremental-centroid-updates-design.md` - The unwind-and-recalculate algorithm for adding poems without a full rebuild (Issue 10-009)
- `/docs/effil-usage-patterns.md` - **Comprehensive guide to effil threading library: usage patterns, antipatterns, and performance characteristics**
- `/docs/effil-vs-compute-shader-feasibility.md` - Feasibility analysis comparing effil threading vs GPU compute shaders for diversity pre-computation
- `/docs/research-2d-embeddings.md` - Research analysis of dimensionality reduction (768D → 2D) for visualization
- `/docs/research-tuple-embeddings.md` - Research analysis of tuple-based embeddings (768 × 2D coordinate pairs)
- `/docs/similarity-algorithms-research-report.md` - Detailed similarity algorithm research with recommendations
- `/docs/similarity-algorithm-research.md` - Comprehensive research analysis of 12 similarity algorithms for poetry embeddings
- `/docs/similarity-matrix-generation-guide.md` - Technical documentation for similarity calculations
- `/docs/delta-guide.md` - Copy of the monorepo's shared-tooling guide for project maintainers (canonical copy lives in delta-version)
- `/docs/Your URL Is Your State.html` - A saved article, kept as reference
  - `/docs/Your URL Is Your State_files/` - Its supporting files

### 🚨 Critical Path Documents
- `/issues/will-not-implement/CRITICAL-PATH-SIMILAR.md` - Critical path for generating similarity-based navigation pages (retired 2026-10-25)
- `/issues/will-not-implement/CRITICAL-PATH-DIFFERENT.md` - Critical path for generating diversity-based navigation pages (retired 2026-10-25)

### 🎯 Source Documentation
- `/src/main.lua` - Interactive project management interface
- `/src/poem-extractor.lua` - Multi-category poem extraction system
- `/src/poem-validator.lua` - Data validation and quality analysis
- `/src/similarity-engine.lua` - The embedding generator behind stage 6 (its CPU similarity half is retired; Issue 10-060)
- `/src/flat-html-generator.lua` - The generator that builds the site's pages

### 📚 Utilities and Libraries
- `/libs/utils.lua` - Common utility functions and file operations
- `/libs/inference-server-config.lua` - Which inference server and model a run uses (`run.sh --server`, `inference_servers` in config.lua)
- `/libs/text-formatter.lua` - Shared text formatting for whitespace preservation (Issue 8-056)
  and line wrapping measured in visible columns rather than bytes (Issue 10-021)
  - `/libs/text-formatter.info.md` - Its public surface, and why width means ink
- `/libs/text-chunking.info.md` - Splitting long poems for embedding, and recombining them
- `/libs/ask-for-value.info.md` - How a program run on its own asks for a value it was not given (Issue 10-065a)

### 🗂️ Assets and Data
- `/assets/poems.json` - Complete poem dataset (count: `scripts/validate-pipeline-data`)
- `/assets/embeddings/` - Per-model embedding storage directory structure

### 🛠️ Scripts and Tools
- `/run.sh` - Main project runner with interactive mode support
- `/phase-demo.sh` - Phase demonstration script selector
- `/generate-embeddings.sh` - Comprehensive embedding generation CLI
- `/scripts/audit-config-keys.info.md` - Lists config.lua settings nothing reads
- `/scripts/generate-config-reference.info.md` - Builds the config reference from config.lua
- `/scripts/audit-orphan-files.info.md` - Lists source files nothing uses
- `/scripts/check-table-of-contents.info.md` - Checks this page against the files it lists

### 📝 Notes
- `/notes/` - Project planning and vision documents, raw ideas, and reference images
  - `/notes/next-steps` - An idea: TTS audio over drum and bass, read in the author's voice
  - `/notes/golden-poem-example` - What the golden poem frame looks like
  - `/notes/HTML-file-format.png` - Reference image of the page layout
  - `/notes/boost-post-image-style.png` - Reference image of a boosted post's style

---

## Document Maintenance

### Adding New Documents
When creating new documentation:
1. Add the document to the appropriate section above
2. Use the format: `[path] - [brief description]`
3. Run `scripts/check-table-of-contents`; it must report no findings

### Document Categories
- **Core Documentation**: High-level project information
- **Phases**: One progress file per phase, each listing its issues
- **Phase Documentation**: Completion summaries and milestone reports
- **Process and Reading**: How the work happened, and writing kept for its own sake
- **Technical Guides**: Implementation and usage documentation
- **Source Documentation**: Code files with embedded documentation
- **Utilities**: Supporting tools and library documentation
- **Assets**: Data files and generated content
- **Scripts**: Executable tools and automation
- **Notes**: Planning documents, raw ideas and reference material
