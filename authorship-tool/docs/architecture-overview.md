# Architecture Overview

## Project Purpose

The Authorship Tool is a modular creative writing assistant designed to help authors organize, analyze, and develop their written works. The system provides multiple integrated capabilities including document analysis, semantic relationship mapping, interactive feedback generation, visual content generation, and character development tools.

## Core Philosophy

The tool operates on the principle of modular, library-style organization where each major capability exists as its own sub-project. The parent "authorship-tool" project serves as an orchestration layer for coordinating these modules and managing the overall development process.

## High-Level Architecture

```
authorship-tool/
├── src/           # Orchestration layer and integration code
├── libs/          # Sub-project modules (each self-contained)
├── docs/          # Project documentation
├── notes/         # Design notes and vision documents
├── assets/        # Shared assets and resources
└── issues/        # Issue tracking and phase management
```

## Module Architecture

Each module within libs/ operates as an independent sub-project with:
- Its own source code and dependencies
- Clear interface boundaries for integration
- Modular design allowing use in isolation or composition
- Self-contained testing and validation

## Data Flow Pattern

1. **Input Stage**: Authors provide raw creative content (stories, descriptions, notes)
2. **Analysis Stage**: Content is parsed, analyzed for relationships, style, and gaps
3. **Generation Stage**: Questions, quizzes, images, and feedback are generated
4. **Integration Stage**: Author responses are analyzed and integrated back into content
5. **Output Stage**: Enhanced content and metadata are provided back to the author

## Core Capabilities

### Document Organization & Analysis
Reads and organizes authored documents, analyzing structure, themes, and relationships.

### Interactive Question Generation
Generates targeted questions to help authors fill in story details, character motivations, and sensory descriptions.

### Style Analysis & Feedback
Evaluates writing style consistency, highlights awkward phrasing, offers improvements using the author's own style patterns.

### Semantic Relationship Mapping
Creates a knowledge graph of characters, objects, locations, and events with similarity scoring and cross-referencing.

### Visual Content Generation
Generates images for described objects, scenery, and key items using local image generation capabilities.

### Character Development Tools
- Poetry generation for character development (hidden in context)
- Mini-games representing character struggles
- Relationship tracking and analysis

### Feedback Integration System
Provides tiered, progressive disclosure of implementation suggestions with justification from existing text.

## Technical Approach

### Language Selection
Primary implementation language: Lua (LuaJIT compatible syntax)
Rationale: Performance, embeddability, simplicity

### UI Paradigm
- TUI (Terminal User Interface) for primary interaction
- Geometric/stick figure graphics for mini-games
- Dark backgrounds (black, dark teal) with vibrant/neon colors
- Text-based worksheets and quizzes

### AI Integration Points
- Content analysis and question generation
- Style evaluation and improvement suggestions
- Image generation (local models)
- Audio/music generation for mini-games
- Semantic similarity scoring

## Separation of Concerns

The architecture maintains strict separation between:
- **Data Generation**: Analysis, question creation, image generation
- **Data Presentation**: UI rendering, formatting, user interaction
- **Data Storage**: Persistent storage of content and metadata
- **Integration Logic**: Orchestration of modules and data flow

This separation enables isolated testing, easier debugging, and flexible composition of capabilities.
