# Issue 049c: Chapter Segmentation and Interleaving

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-11
**Parent**: Issue 049 (LLM Transcript Abstraction Viewer)
**Dependencies**: Issue 049b (Abstraction Level Transformation)

---

## Current Behavior

Multiple LLM transcript files exist independently in `llm-transcripts/`:
- Individual session summaries (e.g., `38621f31-f527-46a7-b3e4-c1ac06a43381_summary.md`)
- Agent summaries (e.g., `agent-a5b3a5a_summary.md`)
- Combined export (`FULL-TRANSCRIPT-EXPORT.md`)

These files:
- Have no consistent chapter structure
- Cannot be read as a unified narrative
- Overlap in time (parallel development sessions)
- Have different formats (some more detailed than others)

When transformed to different abstraction levels, the output is per-file without any cross-file organization or narrative coherence.

---

## Intended Behavior

A chapter organization system that:
1. Analyzes multiple transformed transcript files
2. Identifies thematic groupings and temporal relationships
3. Creates unified chapter structure with consistent breakmarks
4. Interleaves content from parallel conversations where appropriate
5. Generates a coherent, readable document with proper navigation

### Chapter Structure

```
================================================================================
                              CHAPTER 1: Project Setup
================================================================================

Section 1.1: Repository Initialization
[Content from session 38621f31, exchanges 1-5]

Section 1.2: Branch Configuration
[Content from session ba58f437, exchanges 1-3]

Section 1.3: Initial Issue Creation
[Content from session 38621f31, exchanges 6-10]
[Interleaved with agent-a5b3a5a parallel work]

================================================================================
                           CHAPTER 2: Core Development
================================================================================
...
```

### Breakmark Format

Per CLAUDE.md and README TOC generator conventions:
```
================================================================================
                              CHAPTER N: Title
================================================================================

----------------------- Section N.M: Subtitle -----------------------
```

The 80-character width with centered titles matches existing conventions.

### Interleaving Logic

Multiple concurrent sessions should be interleaved based on:

| Strategy | Use When | Example |
|----------|----------|---------|
| **Chronological** | Sessions have clear timestamps | Session A 10:00, Session B 10:30 → A, B, A, B... |
| **Thematic** | Sessions discuss related topics | Both sessions discuss "authentication" → group together |
| **Dependency** | One session references another's work | Session B uses code from Session A → A before B |
| **Isolated** | Sessions are unrelated | Keep as separate chapters |

---

## Suggested Implementation Steps

### 1. Chapter Detection

```lua
-- {{{ detect_chapter_boundaries
-- Uses LLM to identify where chapter breaks should occur
local function detect_chapter_boundaries(sections, ollama_client)
    local prompt = [[
Analyze these transcript sections and identify natural chapter boundaries.

A new chapter should start when:
- A major new feature or component is introduced
- The focus shifts to a different subsystem
- A significant milestone is reached
- The development phase changes (e.g., from design to implementation)

Sections:
---
%s
---

Return a JSON array of chapter breaks:
[
  {"after_section": 0, "title": "Project Initialization"},
  {"after_section": 5, "title": "Core Component Development"},
  ...
]
]]

    local sections_summary = summarize_sections_for_prompt(sections)
    local response = ollama_client:generate(string.format(prompt, sections_summary))

    return parse_chapter_breaks(response)
end
-- }}}
```

### 2. Multi-File Analysis

```lua
-- {{{ analyze_transcript_files
-- Analyzes multiple transcript files for interleaving decisions
local function analyze_transcript_files(file_paths)
    local analyses = {}

    for _, path in ipairs(file_paths) do
        local content = read_file(path)
        analyses[path] = {
            path = path,
            filename = path:match("([^/]+)$"),
            sections = parse_sections(content),
            timestamps = extract_timestamps(content),
            topics = extract_topics(content),
            referenced_files = extract_file_references(content),
        }
    end

    return analyses
end
-- }}}

-- {{{ determine_interleave_strategy
-- Decides how to combine multiple transcript files
local function determine_interleave_strategy(analyses, ollama_client)
    -- Check for explicit temporal ordering
    local has_timestamps = all_have_timestamps(analyses)
    if has_timestamps then
        return "chronological", build_chronological_order(analyses)
    end

    -- Check for thematic overlap
    local topic_overlap = calculate_topic_overlap(analyses)
    if topic_overlap > 0.5 then
        return "thematic", build_thematic_order(analyses, ollama_client)
    end

    -- Check for dependencies
    local dependencies = detect_cross_references(analyses)
    if #dependencies > 0 then
        return "dependency", build_dependency_order(analyses, dependencies)
    end

    -- Default: keep isolated
    return "isolated", build_isolated_chapters(analyses)
end
-- }}}
```

### 3. Chapter Assembly

```lua
-- {{{ assemble_chapters
-- Combines sections into chapters with proper structure
local function assemble_chapters(sections, chapter_breaks, metadata)
    local chapters = {}
    local current_chapter = {
        number = 1,
        title = chapter_breaks[1] and chapter_breaks[1].title or "Introduction",
        sections = {},
    }

    for i, section in ipairs(sections) do
        -- Check if new chapter should start
        for _, break_point in ipairs(chapter_breaks) do
            if break_point.after_section == i - 1 then
                -- Save current chapter
                if #current_chapter.sections > 0 then
                    table.insert(chapters, current_chapter)
                end
                -- Start new chapter
                current_chapter = {
                    number = #chapters + 2,
                    title = break_point.title,
                    sections = {},
                }
                break
            end
        end

        table.insert(current_chapter.sections, section)
    end

    -- Save final chapter
    if #current_chapter.sections > 0 then
        table.insert(chapters, current_chapter)
    end

    return chapters
end
-- }}}
```

### 4. Document Formatting

```lua
-- {{{ format_chapter_header
-- Generates the 80-character centered chapter header
local function format_chapter_header(chapter_number, title)
    local header_text = string.format("CHAPTER %d: %s", chapter_number, title:upper())
    local padding = math.floor((80 - #header_text) / 2)
    local centered = string.rep(" ", padding) .. header_text

    return string.format([[
================================================================================
%s
================================================================================

]], centered)
end
-- }}}

-- {{{ format_section_header
-- Generates section divider with centered subtitle
local function format_section_header(chapter_num, section_num, title)
    local header_text = string.format("Section %d.%d: %s", chapter_num, section_num, title)
    local dashes_total = 80 - #header_text - 2  -- -2 for spaces around title
    local dashes_left = math.floor(dashes_total / 2)
    local dashes_right = dashes_total - dashes_left

    return string.format("\n%s %s %s\n\n",
        string.rep("-", dashes_left),
        header_text,
        string.rep("-", dashes_right)
    )
end
-- }}}
```

### 5. Table of Contents Generation

```lua
-- {{{ generate_table_of_contents
-- Creates navigable TOC at document start
local function generate_table_of_contents(chapters)
    local toc = {"# Table of Contents\n\n"}

    for _, chapter in ipairs(chapters) do
        table.insert(toc, string.format("## Chapter %d: %s\n",
            chapter.number, chapter.title))

        for j, section in ipairs(chapter.sections) do
            local section_title = section.title or string.format("Section %d.%d", chapter.number, j)
            table.insert(toc, string.format("  - %d.%d [%s](#section-%d-%d)\n",
                chapter.number, j, section_title, chapter.number, j))
        end
        table.insert(toc, "\n")
    end

    return table.concat(toc)
end
-- }}}
```

### 6. Cross-Reference System

```lua
-- {{{ add_cross_references
-- Inserts cross-references between related sections
local function add_cross_references(chapters, analyses)
    for _, chapter in ipairs(chapters) do
        for _, section in ipairs(chapter.sections) do
            -- Find references to other sections
            local refs = find_related_sections(section, chapters, analyses)

            if #refs > 0 then
                section.cross_refs = refs
                section.content = section.content .. format_cross_refs(refs)
            end
        end
    end

    return chapters
end
-- }}}

-- {{{ format_cross_refs
local function format_cross_refs(refs)
    if #refs == 0 then return "" end

    local lines = {"\n\n*Related sections:*"}
    for _, ref in ipairs(refs) do
        table.insert(lines, string.format("- See [Section %d.%d](#section-%d-%d): %s",
            ref.chapter, ref.section, ref.chapter, ref.section, ref.title))
    end

    return table.concat(lines, "\n")
end
-- }}}
```

---

## CLI Interface

```bash
# Organize a single transformed file into chapters
./scripts/chapter-organizer.lua transformed-output.md

# Interleave multiple files
./scripts/chapter-organizer.lua --interleave transcripts/*.md

# Preview chapter structure without generating output
./scripts/chapter-organizer.lua --preview transcripts/

# Force specific interleave strategy
./scripts/chapter-organizer.lua --strategy=chronological transcripts/*.md
```

---

## File Locations

- **Script**: `delta-version/scripts/libs/chapter-organizer.lua`
- **Templates**: `delta-version/config/chapter-templates.lua`
- **Output**: Final organized documents in `llm-transcripts/generated/`

---

## Acceptance Criteria

- [ ] Chapter boundaries are detected at logical transition points
- [ ] Multiple transcript files can be interleaved into single document
- [ ] Chapter headers use 80-character centered format
- [ ] Section headers are properly numbered (N.M format)
- [ ] Table of contents links to all chapters and sections
- [ ] Cross-references connect related content
- [ ] Chronological, thematic, dependency, and isolated strategies work
- [ ] Output is readable as a continuous narrative
- [ ] Page/section numbers support future PDF export

---

## Technical Notes

### Interleaving Heuristics

The interleaving decision should be conservative - when in doubt, keep content isolated rather than risk confusing readers with out-of-context interleaving.

### Chapter Sizing

Aim for chapters of 3-10 sections each. If the LLM suggests too few chapters, prompt again requesting finer granularity. If too many, request consolidation.

### Markdown Anchors

Section anchors should be consistent across regeneration:
- Use `section-{chapter}-{section}` format
- Ensure uniqueness within document
- Avoid special characters that break anchor links

### Preservation of Source Attribution

Each section should indicate its source file for traceability:
```markdown
<!-- Source: 38621f31-f527-46a7-b3e4-c1ac06a43381_summary.md, lines 45-78 -->
```

---

## Related

- Issue 049b: Provides transformed content for organization
- Issue 049: Main issue defining overall structure
- Issue 047: README TOC generator (similar formatting patterns)
