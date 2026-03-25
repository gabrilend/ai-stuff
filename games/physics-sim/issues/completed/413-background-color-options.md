# 413 - Background Color Options

## Status: Complete

## Depends on

112 (Compile-time config system) - for config file integration. ✓

## Problem

The background color is currently hardcoded. Users should be able to choose from several preset background colors via config file or command line flag.

## Implementation

Added compile-time background color selection via config.txt:

1. Added `BACKGROUND_COLOR=0` option to config.txt
   - Index-based selection: 0=slate (default), 1=black, 2=tan, etc.

2. Added color lookup tables in source files:
   - `src/001-main.c` - Game background color
   - `src/030-editor-main.c` - Standalone editor background
   - `src/032-editor-app.c` - Editor app background

3. Color presets implemented:
   | Index | Name | RGB | Description |
   |-------|------|-----|-------------|
   | 0 | slate | (30, 35, 45) | Default dark gray-blue |
   | 1 | black | (0, 0, 0) | Pure black |
   | 2 | tan | (180, 160, 130) | Light brown/wood tone |
   | 3 | felt | (25, 50, 35) | Dark green (pool table) |
   | 4 | navy | (15, 25, 50) | Deep navy blue |
   | 5 | plum | (40, 25, 45) | Dark purple/indigo |
   | 6 | charcoal | (35, 35, 35) | Neutral dark gray |
   | 7 | mahogany | (60, 30, 25) | Dark reddish-brown wood |

## Usage

To change background color:
1. Edit `config.txt` and change `BACKGROUND_COLOR=0` to desired index
2. Run `scripts/generate-config.sh` to regenerate header
3. Recompile

Example: For pool table green: `BACKGROUND_COLOR=3`

## Files Modified

- `config.txt` - Added BACKGROUND_COLOR option
- `src/000-config.h` - Auto-generated with BACKGROUND_COLOR define
- `src/001-main.c` - Added BG_COLORS lookup table
- `src/030-editor-main.c` - Added BG_COLORS lookup table
- `src/032-editor-app.c` - Added BG_COLORS lookup table

## Future Work

- Command line flag override (`--background=felt`)
- String-based selection in config (`BACKGROUND_COLOR=felt`)
- In-game options menu
- Per-board background color override

## Notes

- Uses compile-time config for simplicity
- All three entry points (game, editor main, editor app) share same color table
- Invalid index values fall back to slate (index 0)
