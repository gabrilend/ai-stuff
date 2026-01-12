# Issue 6-012 Design Document: words-pdf Styled Export System for Hope Cards

**Created**: 2026-01-12
**Status**: Design Phase

## words-pdf System Analysis

### Discovered Architecture

**Project Location**: `/home/ritz/programming/ai-stuff/words-pdf/`

**Core Components**:
1. **compile-pdf.lua** - Main PDF generator (362+ lines)
2. **libharu** - PDF generation library (`libs/libharu-RELEASE_2_3_0/`)
3. **luahpdf** - Lua bindings for libharu (`libs/luahpdf/`)

**Input Format**:
```
First line of poem
Second line of poem
Third line of poem
--------------------------------------------------------------------------------
Next poem starts
Another line
--------------------------------------------------------------------------------
```
- Poems separated by exactly 80 dashes
- No special formatting needed
- Plain text input

**PDF Styling**:
- **Font**: Courier, 5pt
- **Layout**: Two columns per page
- **Page**: A4 portrait
- **Margins**: Left=10, Right=10, Top=60, Bottom=0
- **Lines per column**: 155 lines max
- **Column gap**: 30 units
- **Background**: Light purple (0.9, 0.7, 1.0) for poem areas

**Advanced Features**:
- Three-tier theme system for visual art (optional)
- Chronological ordering by timestamps
- Box drawing characters for poem borders
- Color-coded backgrounds (currently disabled)

### Key Discovery: Simple Integration Path

The words-pdf system accepts **plain text files** with 80-dash separators. This means:
- ✅ No complex PDF API needed
- ✅ Can reuse existing neocities poem data
- ✅ Just need to format poems as text
- ✅ words-pdf handles all PDF generation

## Integration Architecture

### Data Flow

```
Neocities Project                  words-pdf Project
================                   =================

assets/poems.json
       |
       v
[Poem Selection Filter]
       |
   (hopeful poems only)
       |
       v
[Format Converter]
       |
   (add 80-dash separators)
       |
       v
  temp/hope-cards.txt  ----------> input/hope-cards.txt
                                          |
                                          v
                                    compile-pdf.lua
                                          |
                                          v
                                    output/hope-cards.pdf
```

### Step-by-Step Process

**Step 1: Select Poems from Similar/Different Pages**
```lua
-- For each anchor poem with a similar/different page:
-- 1. Load the similarity-sorted poem list
-- 2. Select top N poems (e.g., 200 for printable size)
-- 3. Apply content filter (hopeful vs darker)
-- 4. Add to export list
```

**Step 2: Content Filtering**
```lua
-- Filter poems based on keywords/themes:
hopeful_keywords = {
  "hope", "love", "light", "joy", "peace",
  "beauty", "wonder", "grace", "healing", "friend"
}

darker_keywords = {
  "death", "blood", "rage", "hate", "destroy",
  "kill", "pain", "suffer", "nightmare", "insano"
}

function is_hopeful_poem(poem_text)
  -- Count hopeful vs darker keywords
  -- Return true if hopeful score > darker score
end
```

**Step 3: Format for words-pdf**
```lua
function export_to_wordspdf_format(poems, output_file)
  local file = io.open(output_file, "w")

  for _, poem in ipairs(poems) do
    -- Write poem lines
    for _, line in ipairs(poem.lines) do
      file:write(line .. "\n")
    end

    -- Write 80-dash separator
    file:write(string.rep("-", 80) .. "\n")
  end

  file:close()
end
```

**Step 4: Generate PDF**
```bash
# Run words-pdf compiler
cd /home/ritz/programming/ai-stuff/words-pdf
./run . temp/hope-cards.txt normal
```

## Implementation Plan

### Phase 1: Basic Export Script

Create `/scripts/export-hope-cards` that:
- Reads poems from similar/different pages
- Applies simple keyword filtering
- Outputs to words-pdf format

**Files to Create**:
- `scripts/export-hope-cards` - Main export script
- `libs/content-filter.lua` - Hopeful/darker classification
- `libs/wordspdf-adapter.lua` - Format conversion utilities

**Estimated Time**: 2-3 days

### Phase 2: Enhanced Filtering

Improve content filtering with:
- Embedding-based similarity to "hopeful" reference poems
- Manual curation interface (CLI tool to mark poems)
- Configurable filter thresholds

**Files to Update**:
- `libs/content-filter.lua` - Add embedding-based filtering
- `config/hope-card-filters.json` - Configuration file

**Estimated Time**: 2-3 days

### Phase 3: Batch Generation

Support generating multiple PDFs:
- One PDF per anchor poem (200 similar poems each)
- Categorized PDFs (by theme, by date, etc.)
- Custom poem selections

**Files to Create**:
- `scripts/batch-export-hope-cards` - Batch processor
- `config/hope-card-configs.json` - Batch configurations

**Estimated Time**: 1-2 days

### Phase 4: Integration with Pipeline

Add to `run.sh`:
- Optional hope card generation step
- Automatic filtering and export
- Progress tracking

**Files to Update**:
- `run.sh` - Add hope card export step
- `docs/table-of-contents.md` - Document new scripts

**Estimated Time**: 1 day

**Total Estimated Time**: 6-9 days

## File Specifications

### Script: `scripts/export-hope-cards`

```lua
#!/usr/bin/env luajit

-- Export hope cards to words-pdf format
-- Usage: ./scripts/export-hope-cards [OPTIONS]
--   --anchor=<id>      Export similar poems from this anchor
--   --limit=<n>        Max poems per card (default: 200)
--   --output=<file>    Output file (default: temp/hope-cards.txt)
--   --filter=<level>   Filter level: none|basic|strict (default: basic)

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path

local utils = require("utils")
local filter = require("content-filter")
local adapter = require("wordspdf-adapter")
local dkjson = require("dkjson")

-- Parse command line args
local anchor_id = nil
local limit = 200
local output_file = "temp/hope-cards.txt"
local filter_level = "basic"

for i = 1, #arg do
  -- Parse flags...
end

-- Load poems
local poems_file = DIR .. "/assets/poems.json"
local poems = utils.read_json_file(poems_file)

-- Load similarity rankings for anchor
local similar_file = string.format(
  "%s/assets/similarity/%s.json",
  DIR, anchor_id
)
local similar_data = utils.read_json_file(similar_file)

-- Select and filter poems
local selected_poems = {}
for _, sim_entry in ipairs(similar_data.sorted) do
  if #selected_poems >= limit then break end

  local poem_id = sim_entry.poem_id
  local poem = poems[poem_id]

  if poem and filter.is_hopeful(poem, filter_level) then
    table.insert(selected_poems, poem)
  end
end

-- Format and export
adapter.export_to_wordspdf(selected_poems, output_file)

print(string.format("✅ Exported %d poems to %s",
  #selected_poems, output_file))
print("📝 Generate PDF with:")
print("   cd /home/ritz/programming/ai-stuff/words-pdf")
print("   ./run . " .. output_file .. " normal")
```

### Library: `libs/content-filter.lua`

```lua
-- Content filtering for hope cards
-- Classifies poems as hopeful vs darker

local M = {}

M.hopeful_keywords = {
  "hope", "love", "light", "joy", "peace", "beauty",
  "wonder", "grace", "healing", "friend", "magic",
  "dream", "star", "bloom", "gentle", "warm"
}

M.darker_keywords = {
  "death", "blood", "rage", "hate", "destroy", "kill",
  "pain", "suffer", "nightmare", "insano", "scream",
  "terror", "despair", "void", "decay", "chaos"
}

-- {{{ function M.is_hopeful
function M.is_hopeful(poem, filter_level)
  filter_level = filter_level or "basic"

  if filter_level == "none" then
    return true
  end

  -- Combine all poem text
  local text = ""
  for _, line in ipairs(poem.lines or {}) do
    text = text .. " " .. line:lower()
  end

  -- Count keyword matches
  local hopeful_count = 0
  local darker_count = 0

  for _, keyword in ipairs(M.hopeful_keywords) do
    if text:find(keyword, 1, true) then
      hopeful_count = hopeful_count + 1
    end
  end

  for _, keyword in ipairs(M.darker_keywords) do
    if text:find(keyword, 1, true) then
      darker_count = darker_count + 1
    end
  end

  -- Decision based on filter level
  if filter_level == "basic" then
    -- Allow if hopeful >= darker
    return hopeful_count >= darker_count
  elseif filter_level == "strict" then
    -- Require hopeful > darker AND at least one hopeful keyword
    return hopeful_count > darker_count and hopeful_count > 0
  end

  return true
end
-- }}}

return M
```

### Library: `libs/wordspdf-adapter.lua`

```lua
-- Adapter for words-pdf format
-- Converts neocities poems to words-pdf input format

local M = {}

-- {{{ function M.export_to_wordspdf
function M.export_to_wordspdf(poems, output_file)
  local file = io.open(output_file, "w")
  if not file then
    error("Cannot open output file: " .. output_file)
  end

  for i, poem in ipairs(poems) do
    -- Write poem metadata as comment (optional)
    file:write(string.format("-- Poem %d: %s\n",
      poem.id or i,
      poem.title or "Untitled"
    ))

    -- Write poem lines
    local lines = poem.lines or poem.content:gmatch("[^\n]+")
    for line in lines do
      -- Ensure line doesn't exceed 80 chars
      local trimmed = M.wrap_line(line, 80)
      for _, wrapped_line in ipairs(trimmed) do
        file:write(wrapped_line .. "\n")
      end
    end

    -- Write 80-dash separator
    file:write(string.rep("-", 80) .. "\n")
  end

  file:close()
end
-- }}}

-- {{{ function M.wrap_line
function M.wrap_line(line, max_width)
  -- Simple word wrapping for lines > max_width
  if #line <= max_width then
    return {line}
  end

  local wrapped = {}
  local current = ""

  for word in line:gmatch("%S+") do
    if #current + #word + 1 <= max_width then
      current = current .. (current == "" and "" or " ") .. word
    else
      table.insert(wrapped, current)
      current = word
    end
  end

  if current ~= "" then
    table.insert(wrapped, current)
  end

  return wrapped
end
-- }}}

return M
```

## Success Criteria

- [ ] Export script successfully converts neocities poems to words-pdf format
- [ ] Content filter identifies hopeful vs darker poems with >80% accuracy
- [ ] Generated PDFs use words-pdf styling (Courier font, two-column layout)
- [ ] Can generate ~200-poem "hope cards" suitable for printing
- [ ] Batch processing supports multiple anchor poems
- [ ] Documentation for users to generate their own hope cards

## Example Usage

```bash
# Export hope card for anchor poem 123
./scripts/export-hope-cards --anchor=123 --limit=200 --filter=strict

# Generate the PDF
cd /home/ritz/programming/ai-stuff/words-pdf
./run . /mnt/mtwo/programming/ai-stuff/neocities-modernization/temp/hope-cards.txt normal

# Result: output.pdf with 200 hopeful poems in words-pdf style
```

## Using Centroids for Hope Card Selection

**IMPORTANT DISCOVERY**: The project already has a centroid system (`assets/centroids.json`) that provides a superior alternative to keyword filtering!

See `docs/centroids-for-hope-cards.md` for full details.

### Quick Overview

Instead of filtering poems by keywords, you can:
1. Define a "hope" centroid with positive keywords
2. Generate centroid embedding via `src/centroid-generator.lua`
3. Rank all poems by similarity to the "hope" centroid
4. Top N poems are naturally the most hopeful!

**Advantage**: Semantic understanding rather than simple keyword matching.

**Example centroid** (already added to `assets/centroids.json`):
```json
{
  "name": "hope",
  "keywords": [
    "light at the end of the tunnel",
    "things will get better",
    "you are not alone",
    "this too shall pass",
    ...
  ]
}
```

### Updated Workflow

```bash
# 1. Generate centroid embeddings
lua src/centroid-generator.lua

# 2. Export poems ranked by hope centroid
./scripts/export-hope-cards --from-centroid=hope --limit=200

# 3. Generate PDF
./scripts/generate-hope-card-pdf temp/hope-cards.txt output/hope-cards.pdf
```

## Future Enhancements

- **Centroid-based selection**: Use similarity to "hope" centroid (see above)
- **Multiple themes**: Generate different PDFs (gentle-hope, fierce-hope, comfort)
- **Manual curation**: CLI tool to review and mark poems
- **Theme integration**: Use words-pdf three-tier theme system for colors
- **Custom covers**: Add title pages with artwork
- **Print optimization**: Duplex printing support, binding margins

---

*"from screens to hands, from bits to paper grain,*
*two hundred poems bound in hope's refrain."*
