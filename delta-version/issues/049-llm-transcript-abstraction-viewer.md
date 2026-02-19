# Issue 049: LLM Transcript Abstraction Viewer

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-11
**Related**: Issue 035f (Local LLM Integration), Issue 040g (Transcript Analysis Memory)

---

## Current Behavior

LLM transcripts in `llm-transcripts/` directories are stored as raw conversation summaries with varying levels of detail. Currently:

- Transcripts are only viewable in their original form
- No mechanism exists to view conversations at different levels of abstraction
- Detail levels (mentioned as 5 existing levels) don't have abstraction-level counterparts
- Multiple transcript files exist independently without unified navigation
- No processing pipeline to condense or expand transcript content using local LLM

The current transcript format includes user requests and assistant responses in chronological order, but lacks:
- High-level architectural overviews showing data flows and system design
- Low-level implementation details with code explanations
- Medium-level feature summaries showing how components interact

---

## Intended Behavior

A comprehensive transcript processing tool that transforms raw LLM conversation logs into multi-layered documentation viewable at different abstraction and detail levels.

### Core Dimensions

**Abstraction Levels** (how zoomed-out the perspective is):

| Level | Focus | Example Content |
|-------|-------|-----------------|
| **High** | System architecture, data flows, input/output relationships, roadmaps, feature lists | "The authentication module receives credentials from the form handler and validates against the user store" |
| **Medium** | Feature descriptions, component interactions, workflow explanations | "The login function checks password hash, creates session token, and redirects to dashboard" |
| **Low** | Implementation specifics, code patterns, unique problem solutions, artful designs | "Using a dispatch table instead of switch statements reduced lookup time by 40%" |

**Detail Levels** (how much content is retained):

| Level | Retention | Description |
|-------|-----------|-------------|
| **1 (Minimal)** | ~10% | Only major decisions and outcomes |
| **2 (Summary)** | ~25% | Key discussions and turning points |
| **3 (Standard)** | ~50% | Main conversation flow with context |
| **4 (Detailed)** | ~75% | Most content except repetition/noise |
| **5 (Full)** | 100% | Original transcript (input only, never modified) |

### Processing Pipeline

```
[Original Transcripts] --> [Phase 1: Detail Filtering] --> [Phase 2: Abstraction Transform] --> [Output Files]
                                     |                              |
                                     v                              v
                          Remove sections by          Describe remaining content
                          detail level config         at target abstraction level
```

**Phase 1: Detail Filtering**
- Identify sections of the transcript that are/aren't useful
- Remove verbose debugging sessions, repeated attempts, tangential discussions
- Keep decision points, implementation milestones, architectural choices
- Lower detail levels = more aggressive filtering

**Phase 2: Abstraction Transformation**
- Transform remaining content to match target abstraction level
- High abstraction: Convert code discussions to data flow descriptions
- Medium abstraction: Balance technical detail with conceptual explanations
- Low abstraction: Preserve code examples, add explanatory annotations

### Output Structure

```
llm-transcripts/
  FULL-TRANSCRIPT-EXPORT.md           # Original (detail 5, read-only)
  generated/
    high-abstraction/
      detail-1-minimal.md             # System overview, major decisions
      detail-2-summary.md             # Architecture with key rationale
      detail-3-standard.md            # Feature flows with context
    medium-abstraction/
      detail-1-minimal.md             # Feature list with interactions
      detail-2-summary.md             # Component descriptions
      detail-3-standard.md            # Implementation discussions
    low-abstraction/
      detail-1-minimal.md             # Key code patterns only
      detail-2-summary.md             # Code with brief explanations
      detail-3-standard.md            # Code with detailed analysis
```

### Unified Chapter Structure

All generated files should have:
- Consistent chapter breakmarks (`===== Chapter N: Title =====`)
- Read-order sequencing (chronological or logical flow)
- Cross-references between related sections
- Table of contents at document start
- Page/section numbers for future PDF export compatibility

---

## Sub-Issues

This issue is broken into the following sub-issues:

| Issue | Title | Description |
|-------|-------|-------------|
| **049a** | Detail Level Filtering | LLM-assisted identification and removal of sections based on detail level |
| **049b** | Abstraction Level Transformation | Convert filtered content to target abstraction level |
| **049c** | Chapter Segmentation and Interleaving | Unify multiple transcript files with consistent structure |
| **049d** | Ollama Processing Pipeline | Integration with local Ollama for LLM processing |

---

## Suggested Implementation Steps

### 1. Create Script Skeleton

```lua
#!/usr/bin/env luajit
-- transcript-abstractor.lua - Transform LLM transcripts to different abstraction/detail levels
--
-- Processes raw conversation logs through a two-phase pipeline:
-- 1. Detail filtering: Remove sections based on configured detail level
-- 2. Abstraction transform: Describe remaining content at target abstraction level
--
-- Uses local Ollama LLM for intelligent content analysis and transformation.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
if arg[1] and arg[1]:match("^%-%-dir=") then
    DIR = arg[1]:match("^%-%-dir=(.+)$")
    table.remove(arg, 1)
end
-- }}}

-- {{{ Configuration
local config = {
    input_dir = DIR .. "/llm-transcripts",
    output_dir = DIR .. "/llm-transcripts/generated",
    abstraction = "medium",  -- high, medium, low
    detail = 3,              -- 1-5 (5 = full/no filtering)
    ollama_model = "llama3",
    ollama_host = "localhost",
    ollama_port = 11434,
}
-- }}}
```

### 2. Implement Sub-Issue Dependencies

```
049d (Ollama Pipeline) --> 049a (Detail Filtering) --> 049b (Abstraction Transform)
                                                              |
                                                              v
                                                    049c (Chapter Segmentation)
```

049d should be implemented first as it provides the LLM infrastructure used by 049a and 049b.

### 3. CLI Interface

```bash
# Generate specific abstraction/detail combination
./scripts/transcript-abstractor.lua --abstraction=high --detail=2

# Generate all combinations
./scripts/transcript-abstractor.lua --generate-all

# Process specific transcript file
./scripts/transcript-abstractor.lua --input=llm-transcripts/38621f31.md --abstraction=low --detail=3

# Interactive mode with TUI
./scripts/transcript-abstractor.lua -I
```

### 4. LLM Prompt Templates

**Detail Filtering Prompt** (049a):
```
Analyze this transcript section. Classify each part as:
- ESSENTIAL: Major decisions, architectural choices, key outcomes
- USEFUL: Supporting context, relevant discussions
- VERBOSE: Debugging attempts, repeated explanations, tangential content
- NOISE: Greetings, confirmations, tool output dumps

Return a JSON array of sections with classifications.
```

**Abstraction Transform Prompt** (049b):
```
Transform this content to [HIGH/MEDIUM/LOW] abstraction level.

HIGH: Focus on system architecture and data flows. Describe WHAT components do and HOW they connect, not implementation details.
MEDIUM: Balance technical and conceptual. Show feature interactions and workflows.
LOW: Preserve implementation details. Explain code patterns and unique solutions.

Original: [content]
Transformed:
```

---

## CLI Options

```
Usage: transcript-abstractor.lua [OPTIONS] [INPUT...]

Transform LLM transcripts to different abstraction and detail levels.

OPTIONS:
    --abstraction=LEVEL   Target abstraction: high, medium, low (default: medium)
    --detail=N            Detail level 1-5, lower = more condensed (default: 3)
    --generate-all        Generate all abstraction/detail combinations
    --input=PATH          Specific transcript file or directory
    --output=PATH         Override output directory
    --ollama=HOST:PORT    Ollama server address (default: localhost:11434)
    --model=NAME          Ollama model to use (default: llama3)
    --dry-run             Show what would be processed without changes
    --dir=PATH            Override project directory
    -I                    Interactive TUI mode
    -h, --help            Show this help

EXAMPLES:
    transcript-abstractor.lua --abstraction=high --detail=1
        Generate minimal high-level overview

    transcript-abstractor.lua --generate-all
        Generate all 9 combinations (3 abstraction x 3 detail levels)

    transcript-abstractor.lua --input=llm-transcripts/*.md --abstraction=low
        Process specific files with low abstraction
```

---

## File Locations

- **Main Script**: `delta-version/scripts/transcript-abstractor.lua`
- **Shared Libraries**:
  - `delta-version/scripts/libs/transcript-parser.lua` - Parse transcript format
  - `delta-version/scripts/libs/ollama-client.lua` - Ollama API wrapper (may reuse from neocities)
- **Output**: `delta-version/llm-transcripts/generated/`
- **Config**: `delta-version/config/transcript-abstractor.lua`

---

## Acceptance Criteria

- [ ] Original transcripts remain unmodified (read-only input)
- [ ] Three abstraction levels (high, medium, low) produce distinct outputs
- [ ] Detail levels 1-3 produce progressively condensed content
- [ ] Generated files have unified chapter structure
- [ ] Multiple transcript files can be interleaved into coherent narrative
- [ ] Ollama integration works with configurable model/server
- [ ] CLI supports both batch and interactive modes
- [ ] All generated files include table of contents
- [ ] Cross-references between related sections work
- [ ] Uses vim folds per CLAUDE.md conventions

---

## Technical Notes

### Ollama Integration

Reuse patterns from existing implementations:
- `/home/ritz/programming/ai-stuff/neocities-modernization/libs/ollama-config.lua`
- `/home/ritz/programming/ai-stuff/neocities-modernization/src/ollama-manager.lua`

These provide server management, model selection, and API wrappers.

### Transcript Parsing

Current transcript format (from `*_summary.md` files):
```markdown
### User Request N
[content]

--------------------------------------------------------------------------------

### Assistant Response N
[content]
```

The parser should handle both individual summary files and the combined `FULL-TRANSCRIPT-EXPORT.md`.

### Separation of Concerns

Per CLAUDE.md guidelines:
1. **Data Generation**: LLM processing pipeline (phases 1 and 2)
2. **Data Viewing**: Output file generation and formatting

Keep these isolated to encapsulate errors in smaller areas.

---

## Metadata

- **Priority**: Medium
- **Complexity**: High
- **Dependencies**: Ollama installation and model availability
- **Related Projects**: neocities-modernization (Ollama patterns), words-pdf (transcript handling)

---

## Notes

This tool addresses a key challenge in LLM-assisted development: understanding past conversations at different granularity levels. A developer investigating a bug might need the low-abstraction, high-detail view to see exact code discussions, while a project manager reviewing progress might prefer high-abstraction, low-detail summaries.

The two-phase pipeline (detail filtering → abstraction transform) ensures that:
1. Irrelevant content is removed before transformation (reducing LLM token usage)
2. The abstraction transform operates on pre-filtered, relevant content
3. Each phase can be tested and validated independently

The unified chapter structure enables future enhancements like:
- PDF book generation with page numbers
- Hyperlinked HTML documentation
- Search/index functionality across all abstraction levels
