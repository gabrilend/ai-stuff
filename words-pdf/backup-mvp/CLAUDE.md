# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Lua-based PDF generation system that converts compiled text files (poetry/text) into formatted PDF documents. The main application reads text files separated by dash delimiters and generates multi-column PDF layouts using the Haru PDF library via Lua bindings.

## Development Commands

### Building and Running
- `./run` - Main execution script that:
  - Sets up library paths for libharu
  - Runs the main Lua script with input from `input/compiled.txt`
  - Requires lua5.2 to be installed

### Dependencies
- `lua5.2` - Required Lua interpreter
- libharu (Haru Free PDF Library) - Located in `libs/libharu-RELEASE_2_3_0/`
- LuaHPDF bindings - Located in `libs/luahpdf/`

### Building LuaHPDF (if needed)
```bash
cd libs/luahpdf
make
```

## Architecture

### Main Components

1. **compile-pdf.lua** - Main application script (362 lines)
   - `load_file()` - Parses input text file, splits on 80-dash delimiters
   - `build_book()` - Layouts poems into pages with left/right columns
   - `build_pdf()` - Generates PDF using libharu with A4 pages, Courier font
   - `build_color()` - AI-powered color assignment (currently disabled)

2. **Input Processing**
   - Reads from `input/compiled.txt` (~101k lines, ~6487 poem sections)
   - Poems separated by lines of exactly 80 dashes
   - Text organized into two-column layout with max 90 lines per page

3. **PDF Generation**
   - Two-column layout on A4 pages
   - Courier font, size 6pt
   - Automatic page breaks and column flow
   - Support for long poems spanning multiple pages/columns

### Libraries
- `libs/luahpdf/` - Lua bindings for Haru PDF library
- `libs/libharu-RELEASE_2_3_0/` - Core PDF generation library
- `libs/fuzzy-computing.lua` - AI model integration (for color assignment)

### Key Constants
- `MAX_LINES_PER_PAGE = 90`
- `MAX_CHAR_PER_LINE = 80`
- Font: Courier, 6pt
- Page format: A4 Portrait

## File Structure
- `input/` - Contains source text files
- `output/` - Generated PDF output directory
- `backups/` - Backup files
- `libs/` - External libraries and dependencies