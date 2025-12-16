# Theme Analysis System

## Overview

This system performs comprehensive thematic analysis of the poetry/text corpus using distributed Claude Code sessions. It splits the large corpus into manageable chunks, analyzes each piece in parallel, then consolidates the results into a unified theme taxonomy for generative art creation.

## Goals

### Primary Objectives
1. **Comprehensive Theme Extraction** - Identify all major themes present in the ~550k word corpus
2. **Scalable Analysis** - Process large documents efficiently using parallel Claude Code sessions  
3. **Artistic Integration** - Generate themes specifically designed for procedural/generative art systems
4. **Cost-Effective Processing** - Use local Claude Code instead of expensive API calls

### Analysis Targets
- **Theme Identification** - Discover 15-20 primary themes with descriptions
- **Visual Mapping** - Define artistic representations (colors, patterns, movements) for each theme
- **Distribution Analysis** - Understand theme prevalence across the corpus
- **Keyword Extraction** - Build vocabulary for theme recognition and embedding systems
- **Art Function Design** - Provide specific guidance for procedural art generation

## System Architecture

### Phase 1: Document Splitting
```
input/compiled.txt (550k words, 6487 poems)
        ↓
    split_corpus.lua
        ↓
theme-analysis/slices/slice_001.txt ... slice_040.txt
```

### Phase 2: Parallel Analysis  
```
4 Concurrent Claude Code Sessions
        ↓
slice_001.txt → analysis_001.analysis
slice_002.txt → analysis_002.analysis
    ... (continuing until all 40 slices processed)
        ↓
theme-analysis/analyses/ (40 analysis files)
```

### Phase 3: Consolidation
```
All 40 analysis files
        ↓
    Claude Code Consolidation Session
        ↓
final_theme_taxonomy.md
```

## File Structure

```
theme-analysis/
├── README.md (this file)
├── slices/
│   ├── slice_001.txt
│   ├── slice_002.txt
│   └── ... (40 total slices)
├── analyses/
│   ├── analysis_001.analysis
│   ├── analysis_002.analysis
│   └── ... (40 analysis files)
├── final_theme_taxonomy.md
├── split_corpus.lua
├── analyze_parallel.lua
└── consolidate_analyses.lua
```

## Scripts

### `split-corpus.lua`
- Splits `input/compiled.txt` into 40 balanced slices on poem boundaries
- Ensures splits happen at poem headers ("> file:") not mid-poem
- Distributes poems evenly across slices with remainder handling
- Creates target of ~162 poems per slice (~13-14k words each)
- Includes verification to ensure no poems are lost during splitting
- Outputs to `theme-analysis/slices/slice_XXX.txt` with progress reporting

### `analyze.lua` 
- Advanced theme analysis system with multiple processing modes:
  - **Parallel Mode (Default)** - Configurable workers (1-16, default 4)
  - **Sequential Mode** - One slice at a time with extended timeouts
  - **Progress Persistence** - Saves state and resumes on interruption  
  - **Graceful Shutdown** - Press 'q' or Ctrl+C to quit safely
  - **Error Handling** - Detailed failure reporting and retry mechanisms
  - **Analysis Refinement** - Improve existing analyses heuristically
- Supports `--restart`, `--refine`, `--skip`, and `--parallel=N` flags
- Real-time progress display with spinner animation
- Automatic load balancing and worker management

### `consolidate-analyses.lua`
- 3-pass iterative consolidation system using Claude Opus model:
  - **Pass 1** - Extract 10 core themes with detailed specifications
  - **Pass 2** - Expand to 20 themes in pyramid structure (includes all Tier 1)
  - **Pass 3** - Complete 40 themes with specializations (includes all Tier 2)
- **Resume Capability** - Automatically detects existing passes and continues
- **Pyramid Structure** - Each tier doubles in size while encompassing previous tiers
- **Quality Validation** - Ensures theme lineage and proper hierarchical structure
- Outputs: `final-theme-taxonomy-1.md`, `final-theme-taxonomy-2.md`, `final-theme-taxonomy-3.md`
- Supports `--restart` flag to force fresh consolidation

## Analysis Prompts

### Individual Slice Analysis
Each slice receives this analysis prompt:
```
Analyze this poetry/text corpus slice for thematic content. Identify:

1. **Dominant Themes** (3-8 themes in this slice)
2. **Key Concepts** (important words/phrases for each theme)  
3. **Emotional Tone** (mood, intensity, style)
4. **Artistic Qualities** (visual/aesthetic suggestions)
5. **Unique Elements** (distinctive characteristics)

Focus on themes that could translate to generative art:
- Visual patterns, colors, movements
- Geometric or organic forms  
- Emotional/atmospheric qualities
- Symbolic representations

Provide concrete, actionable descriptions for art generation.
```

### Consolidation Analysis  
The final consolidation prompt:
```
Review these 40 individual theme analyses and create a unified theme taxonomy:

1. **Merge Similar Themes** - Combine related concepts
2. **Rank by Prevalence** - Estimate distribution across corpus
3. **Design Art Functions** - Specify visual representations
4. **Create Implementation Guide** - Technical recommendations
5. **Build Keyword Dictionary** - Terms for each theme

Output format:
- Theme name (single word, lowercase)
- Description (2-3 sentences)  
- Keywords (10-15 terms)
- Visual representation (colors, patterns, movement)
- Prevalence estimate (percentage)
- Art function suggestions (specific algorithms/techniques)
```

## Expected Outcomes

### Theme Taxonomy
- **15-20 primary themes** with clear artistic mappings
- **Keyword vocabularies** for embedding-based recognition
- **Visual specifications** (colors, patterns, movements, shapes)
- **Distribution data** showing theme prevalence
- **Implementation roadmap** for generative art integration

### Art System Integration
- Update `compile-pdf-ai.lua` with new theme system
- Create new procedural art functions for each theme
- Enhance embedding similarity matching
- Improve visual coherence across PDF pages

## Usage

1. **Split the corpus:**
   ```bash
   luajit theme-analysis/split-corpus.lua
   ```

2. **Run theme analysis:**
   ```bash
   # Start fresh parallel analysis (default 4 workers)
   luajit theme-analysis/analyze.lua --restart
   
   # Parallel analysis with 8 workers
   luajit theme-analysis/analyze.lua --parallel 8 --restart
   
   # Sequential analysis
   luajit theme-analysis/analyze.lua --sequential --restart
   
   # Resume interrupted analysis
   luajit theme-analysis/analyze.lua --skip
   
   # Refine existing analyses
   luajit theme-analysis/analyze.lua --refine
   
   # Interactive mode (prompts for options)
   luajit theme-analysis/analyze.lua
   ```

3. **Consolidate results:**
   ```bash
   luajit theme-analysis/consolidate-analyses.lua
   
   # Or force restart all passes
   luajit theme-analysis/consolidate-analyses.lua --restart
   ```

4. **Review output:**
   ```bash
   # Review final consolidated taxonomy (40 themes)
   cat theme-analysis/final-theme-taxonomy-3.md
   
   # Or review individual passes
   cat theme-analysis/final-theme-taxonomy-1.md  # 10 core themes
   cat theme-analysis/final-theme-taxonomy-2.md  # 20 extended themes
   ```

## Processing Time

- **Phase 1 (Splitting):** ~10 seconds
- **Phase 2 (Analysis):** ~20-30 minutes (4 parallel workers)  
- **Phase 3 (Consolidation):** ~15-30 minutes (3-pass system)
- **Total:** ~45-75 minutes for complete 3-tier taxonomy

## Technical Notes

- Each slice contains ~162 poems (6487 total ÷ 40 slices)
- **Theme analysis uses LuaJIT** - Enables sub-second timing with luasocket
- **PDF generation uses lua5.2** - Required for libharu/LuaHPDF compatibility
- Claude Code sessions are spawned as separate processes
- Progress tracking via file system monitoring with resumable sessions
- Automatic cleanup of temporary files
- Error recovery and retry logic for failed analyses
- Process isolation prevents memory issues with large corpus
- Interactive mode available when no command-line arguments provided

## Next Steps

1. Run the complete 3-phase analysis pipeline
2. Review the 3-tier theme taxonomy (40 total themes in pyramid structure)
3. Update the PDF generation system with new theme hierarchy
4. Create corresponding generative art functions for each tier
5. Test the enhanced system with sample outputs
6. Iterate and improve based on visual results

## Progress Tracking Files

- `analysis_progress.json` - Parallel mode progress (processed slices, failed analyses)
- `sequential_progress.json` - Sequential mode progress (current index, completion status)
- Both files enable seamless resumption of interrupted analysis sessions