# words-pdf Integration Guide

**Created**: 2026-01-12
**Related Issue**: 6-012 - Implement words-pdf Styled Export System

## Overview

This document describes how to use the words-pdf project to generate printable PDF "hope cards" from neocities-modernization poem data.

## Architecture

```
neocities-modernization                    words-pdf
===================                        =========

assets/poems.json
       |
       v
[Select & Filter Poems]
       |
       v
libs/hope-card-formatter.lua
       |
   (format as .txt)
       |
       v
  temp/hope-cards.txt  ────────────>  ./run pdf normal
                                            |
                                            v
                                       output.pdf
```

## Prerequisites

- **words-pdf project** installed at `/home/ritz/programming/ai-stuff/words-pdf/`
- **lua5.2** installed (required by words-pdf)
- **libharu** library (included in words-pdf/libs/)

## File Format

words-pdf expects plain text with poems separated by exactly 80 dashes:

```
First line of poem one
Second line
Third line
--------------------------------------------------------------------------------
First line of poem two
Another line
--------------------------------------------------------------------------------
```

## Using hope-card-formatter.lua

### Basic Usage

```lua
local formatter = require("hope-card-formatter")

-- Format poems to string
local poems = {
    {id = 1, content = "First poem\nSecond line"},
    {id = 2, content = "Another poem\nAnother line"}
}

local formatted_text = formatter.format_poems_to_string(poems)
print(formatted_text)
```

### Write to File

```lua
local success, err = formatter.write_to_file(poems, "temp/hope-cards.txt")
if not success then
    print("Error: " .. err)
end
```

### Generate Filename

```lua
local filename = formatter.generate_hope_card_filename(123, 200)
-- Returns: "hope-card-0123-200poems.txt"
```

## Invoking words-pdf

### Method 1: Direct Invocation

```bash
# From neocities-modernization directory
cd /home/ritz/programming/ai-stuff/words-pdf

# Set library path (required for libharu)
export LD_LIBRARY_PATH=/home/ritz/programming/ai-stuff/words-pdf/libs/libharu-RELEASE_2_3_0/build/src:$LD_LIBRARY_PATH

# Generate PDF
lua5.2 ./compile-pdf.lua \
    /home/ritz/programming/ai-stuff/words-pdf \
    /mnt/mtwo/programming/ai-stuff/neocities-modernization/temp/hope-cards.txt \
    normal

# PDF will be created at: /home/ritz/programming/ai-stuff/words-pdf/output.pdf
```

### Method 2: Using run Script

```bash
cd /home/ritz/programming/ai-stuff/words-pdf

# The run script handles library paths automatically
./run pdf normal

# Note: This expects input at ./input/compiled.txt
# You may need to symlink or copy your temp file there
```

### Method 3: Wrapper Script (Recommended)

Use the provided wrapper script (see below):

```bash
./scripts/generate-hope-card-pdf temp/hope-cards.txt output/hope-card-123.pdf
```

## CLI Arguments

**compile-pdf.lua** accepts three arguments:

1. **DIR**: Project directory (e.g., `/home/ritz/programming/ai-stuff/words-pdf`)
2. **FILE**: Input text file path (absolute or relative to DIR)
3. **ORDERING**: Poem ordering mode
   - `normal` - Original order (default)
   - `reverse` - Reverse chronological order
   - (Other modes may be available)

**compile-pdf-ai.lua** accepts the same arguments but includes AI-powered theme detection and coloring (currently disabled by default).

## PDF Output Specifications

- **Format**: A4 portrait
- **Font**: Courier, 5pt
- **Layout**: Two columns per page
- **Lines per column**: 155 lines max
- **Characters per line**: 80 chars max
- **Column gap**: 30 units
- **Margins**: Left=10, Right=10, Top=60, Bottom=0
- **Background**: Light purple tint for poem boxes (configurable)

## Output File Location

By default, words-pdf writes to:
- `./output.pdf` (normal ordering)
- `./output-reverse.pdf` (reverse ordering)

The file is created in the words-pdf project directory, not the input file's directory.

## Example: Complete Workflow

```bash
#!/bin/bash
# Generate hope card PDF for anchor poem 123

# 1. Create formatted text file (using Lua script)
luajit scripts/export-hope-cards --anchor=123 --limit=200 --output=temp/hope-card-123.txt

# 2. Generate PDF
cd /home/ritz/programming/ai-stuff/words-pdf
export LD_LIBRARY_PATH=./libs/libharu-RELEASE_2_3_0/build/src:$LD_LIBRARY_PATH
lua5.2 ./compile-pdf.lua \
    /home/ritz/programming/ai-stuff/words-pdf \
    /mnt/mtwo/programming/ai-stuff/neocities-modernization/temp/hope-card-123.txt \
    normal

# 3. Move PDF to neocities output directory
mv output.pdf /mnt/mtwo/programming/ai-stuff/neocities-modernization/output/hope-card-123.pdf

echo "✅ Generated: output/hope-card-123.pdf"
```

## Wrapper Script

Create `/scripts/generate-hope-card-pdf`:

```bash
#!/bin/bash
# Wrapper script to simplify words-pdf invocation from neocities-modernization

set -euo pipefail

INPUT_FILE="${1:?Usage: $0 <input.txt> [output.pdf]}"
OUTPUT_FILE="${2:-output/hope-card.pdf}"

WORDS_PDF_DIR="/home/ritz/programming/ai-stuff/words-pdf"
NEOCITIES_DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"

# Convert relative paths to absolute
if [[ ! "$INPUT_FILE" = /* ]]; then
    INPUT_FILE="${NEOCITIES_DIR}/${INPUT_FILE}"
fi

if [[ ! "$OUTPUT_FILE" = /* ]]; then
    OUTPUT_FILE="${NEOCITIES_DIR}/${OUTPUT_FILE}"
fi

echo "📝 Generating PDF from: $INPUT_FILE"
echo "📄 Output will be: $OUTPUT_FILE"

# Set up library path
export LD_LIBRARY_PATH="${WORDS_PDF_DIR}/libs/libharu-RELEASE_2_3_0/build/src:${LD_LIBRARY_PATH:-}"

# Generate PDF (output goes to words-pdf/output.pdf)
cd "${WORDS_PDF_DIR}"
lua5.2 ./compile-pdf.lua "${WORDS_PDF_DIR}" "${INPUT_FILE}" normal

# Move to desired location
mv "${WORDS_PDF_DIR}/output.pdf" "${OUTPUT_FILE}"

echo "✅ Generated: ${OUTPUT_FILE}"
```

## Troubleshooting

### Error: "cannot open shared object file"

This means libharu can't be found. Ensure LD_LIBRARY_PATH is set:

```bash
export LD_LIBRARY_PATH=/home/ritz/programming/ai-stuff/words-pdf/libs/libharu-RELEASE_2_3_0/build/src:$LD_LIBRARY_PATH
```

### Error: "FILE cannot be found"

The input file path is incorrect. Use absolute paths or ensure the path is relative to the words-pdf directory.

### Blank PDF or corrupted output

Check that:
- Input file has correct format (80-dash separators)
- No line exceeds 80 characters
- File encoding is UTF-8

### Theme/color issues

If using compile-pdf-ai.lua with themes enabled, ensure:
- Ollama is running (if using embeddings)
- Theme configuration files exist
- AI features are enabled in the script

## Testing

Run the hope-card-formatter test suite:

```bash
cd /mnt/mtwo/programming/ai-stuff/neocities-modernization
luajit libs/hope-card-formatter-test.lua
```

Expected output:
```
═══════════════════════════════════════════
  Tests run:    29
  Tests passed: 29
  Tests failed: 0
═══════════════════════════════════════════
✅ All tests passed!
```

## Next Steps

See Issue 6-012 for:
- Content filtering (hopeful vs darker poems)
- Batch generation for multiple anchor poems
- Integration with run.sh pipeline
- Enhanced theme support

---

*"from screens to hands, from bits to paper grain,*
*two hundred poems bound in hope's refrain."*
