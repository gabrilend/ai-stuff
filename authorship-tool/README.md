# Authorship Tool

A modular creative writing assistant designed to help authors organize, analyze, and develop their written works.

## Overview

The Authorship Tool provides multiple integrated capabilities:
- **Document Organization**: Automatically organize and categorize your writing
- **Semantic Analysis**: Build relationship graphs of characters, objects, and events
- **Interactive Feedback**: Answer targeted questions to fill in story details
- **Style Analysis**: Get feedback on writing style and consistency
- **Visual Generation**: Create images of described objects and scenes
- **Character Development**: Poetry and mini-games based on your characters
- **Integration Assistance**: Suggestions for incorporating feedback into your work

## Project Status

**Current Phase**: Phase 1 - Foundation & Core Infrastructure

The project is currently in initial development, establishing the foundational infrastructure.

## Project Structure

```
authorship-tool/
├── docs/              # Documentation
├── notes/             # Design notes and vision
├── src/               # Core orchestration code
├── libs/              # Modular sub-projects
├── assets/            # Shared resources
├── issues/            # Issue tracking and progress
├── input/             # Your documents and configuration
├── output/            # Generated content
└── tmp/               # Logs and temporary files
```

## Quick Start

1. Place your writing in the `input/` directory
2. Copy `input/config.lua.example` to `input/config.lua` and customize
3. Run the tool: `./authorship-tool` (once Phase 1 is complete)

## Development

### Running Phase Demos

```bash
./run-demo.sh
```

Select a phase number to see a demonstration of completed functionality.

### Documentation

- `docs/architecture-overview.md` - System architecture
- `docs/module-specifications.md` - Module details
- `docs/technical-design.md` - Implementation guide
- `docs/roadmap.md` - Development roadmap
- `docs/table-of-contents.md` - Documentation index

### Current Phase Issues

Phase 1 issues can be found in the `issues/` directory:
- 101: Module Loading Framework
- 102: Basic TUI Framework
- 103: Document Reader and Parser
- 104: Configuration System
- 105: Logging and Error Reporting
- 106: File-Based Persistence
- 107: Phase 1 Demo

Progress tracked in `issues/phase-1-progress.md`

## Technology

- **Language**: Lua (LuaJIT compatible)
- **UI**: Terminal-based (TUI)
- **Storage**: File-based persistence
- **AI**: Local models for generation tasks

## Design Philosophy

- **Modular Architecture**: Each capability is a self-contained module
- **Separation of Concerns**: Data generation separate from presentation
- **Human-Readable Output**: All files are text-based and greppable
- **Fail Loudly**: Clear errors preferred over silent fallbacks
- **Progressive Disclosure**: Information presented in tiered vimfolds

## Contributing

See individual issue files for specific implementation tasks. Each issue includes:
- Current behavior
- Intended behavior
- Suggested implementation steps
- Testing criteria

## License

[License information to be added]

## Vision

For the complete project vision, see `notes/vision`.
