# Input Directory

This directory contains files that the Authorship Tool reads as input.

## Contents

### Configuration
- `config.lua` - Your configuration file (copy from config.lua.example)
- `config.lua.example` - Sample configuration with all available options

### Documents
Place your story files, notes, and other writing here. The tool will:
- Scan this directory for supported file formats (.txt, .md)
- Recursively search subdirectories (if configured)
- Analyze and organize your content

### Supported Formats
- `.txt` - Plain text files
- `.md` - Markdown files

## Usage

1. Copy `config.lua.example` to `config.lua`
2. Customize configuration as needed
3. Place your writing files in this directory
4. Run the Authorship Tool - it will automatically discover your files

## Organization

You can organize your files in subdirectories as you like:
```
input/
├── config.lua
├── stories/
│   ├── chapter1.txt
│   └── chapter2.txt
├── notes/
│   └── character-ideas.md
└── drafts/
    └── scene-rough-draft.txt
```

The tool will find and process all files regardless of subdirectory structure.
