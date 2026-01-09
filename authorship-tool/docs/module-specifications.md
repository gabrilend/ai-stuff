# Module Specifications

## Overview

Each module is a self-contained sub-project within the libs/ directory. Modules communicate through well-defined interfaces and can be developed, tested, and deployed independently.

## Module: Document Organizer

**Purpose**: Read, parse, and organize authored content into structured formats

**Input**: Raw text files, notes, story fragments
**Output**: Structured document metadata, categorization, relationships

**Key Functions**:
- Parse various text formats
- Extract metadata (characters, locations, objects, events)
- Build initial semantic graph
- Categorize content by type and theme

**Dependencies**: None (foundation module)

---

## Module: Question Generator

**Purpose**: Generate targeted questions to help authors fill in story details

**Input**: Analyzed documents, identified gaps in content
**Output**: Quiz/worksheet format text documents with fill-in-the-blank questions

**Key Functions**:
- Identify missing details (sensory, motivational, contextual)
- Generate natural language questions
- Format as text-based worksheets
- Prioritize questions by importance to story progression

**Question Categories**:
- Physical descriptions (hair color, scent, texture)
- Character motivations ("why did he feel that way?")
- Plot progression ("where was she planning on going?")
- Sensory details (how it smelled, sounded, felt)
- Contextual information (time, location, relationships)

**Dependencies**: Document Organizer

---

## Module: Style Analyzer

**Purpose**: Evaluate writing style and suggest improvements

**Input**: Authored text, style patterns database
**Output**: Highlighted sections, improvement suggestions with examples

**Key Functions**:
- Identify awkward or inconsistent phrasing
- Extract author's existing style patterns
- Suggest rephrasing using author's own syntax
- Detect overly rigid or flat writing
- Generate cohesion reports

**Analysis Metrics**:
- Sentence structure variety
- Word choice consistency
- Rhythm and flow
- Stylistic fingerprints
- Rigidity vs. flexibility balance

**Dependencies**: Document Organizer

---

## Module: Semantic Mapper

**Purpose**: Create and maintain semantic web of story elements

**Input**: Extracted entities, relationships, context
**Output**: Queryable knowledge graph, similarity reports

**Key Functions**:
- Build relationship graph (characters, objects, locations, events)
- Calculate semantic similarity scores
- Track object appearances and movements
- Answer queries ("where did we last see this amulet?")
- Generate relationship timelines

**Graph Entities**:
- Characters (with attributes, relationships, appearances)
- Objects (descriptions, locations, ownership)
- Locations (characteristics, events)
- Events (participants, timing, significance)

**Dependencies**: Document Organizer

---

## Module: Image Generator

**Purpose**: Generate visual representations of described elements

**Input**: Text descriptions of objects, scenery, characters
**Output**: Generated images, similarity reports

**Key Functions**:
- Extract visual descriptions from text
- Generate images using local models
- Calculate visual similarity between generated images
- Link images to semantic graph
- Generate comparative reports

**Image Categories**:
- Scenery and backgrounds
- Magic items and artifacts
- Emphasized objects
- Character portraits (optional)

**Dependencies**: Document Organizer, Semantic Mapper

---

## Module: Poetry Engine

**Purpose**: Generate character-focused poetry for contextual enhancement

**Input**: Character information, relationships, story context
**Output**: Character poems stored in context metadata

**Key Functions**:
- Analyze character traits and arcs
- Generate thematically appropriate poetry
- Store poems in character context (hidden from default view)
- Make poems available on-demand to author
- Maintain "classy and discrete" presentation

**Poetry Themes**:
- Character development arcs
- Relationships and interactions
- Internal conflicts
- Character-specific motifs

**Dependencies**: Document Organizer, Semantic Mapper

---

## Module: Mini-Game Engine

**Purpose**: Create interactive games representing character struggles

**Input**: Character challenges, plot conflicts, story context
**Output**: Playable mini-games with graphics and audio

**Key Functions**:
- Identify character struggles suitable for gamification
- Generate simple, focused game mechanics
- Render stick figure animations and geometric graphics
- Generate contextual chiptune music and sound effects
- Reuse mechanics across different games (one at a time)

**Visual Style**:
- Lines and geometric shapes
- Stick figures with separately animated joints
- Vibrant/neon colors on dark backgrounds (black, dark teal, pale brown)
- Minimalist, high-contrast aesthetic

**Audio System**:
- AI-generated chiptune music
- Context-aware (scene, characters, recent author activity)
- Simple sound effects
- Dynamic adaptation to gameplay

**Mechanical Design**:
- Each game focuses on one closely integrated mechanic set
- Subsequent games reuse individual mechanics, not entire sets
- Progressive complexity based on story progression

**Dependencies**: Document Organizer, Semantic Mapper

---

## Module: Feedback Integrator

**Purpose**: Analyze author responses and suggest content integration

**Input**: Completed worksheets/quizzes, original text
**Output**: Integration suggestions with justifications

**Key Functions**:
- Parse author responses to generated questions
- Identify appropriate integration points in existing text
- Suggest specific implementation phrases
- Justify suggestions with examples from existing text
- Present recommendations in tiered vimfolds
- Support interactive approval workflow (spacebar/click/swipe)

**Integration Strategy**:
- Highlight choice moments for new details
- Provide implementation phrases matching author's style
- Show relevant examples from existing text
- Organize suggestions in progressive disclosure tiers
- Enable iterative refinement

**Dependencies**: Document Organizer, Question Generator, Style Analyzer

---

## Module: Orchestration Layer

**Purpose**: Coordinate module interactions and workflow management

**Input**: User commands, workflow state
**Output**: Coordinated module execution, integrated results

**Key Functions**:
- Load and initialize modules
- Manage data flow between modules
- Coordinate analysis pipeline
- Handle user interaction routing
- Manage persistent state

**Workflow Coordination**:
- Trigger analysis when documents change
- Queue question generation based on gaps
- Coordinate image generation requests
- Manage game creation pipeline
- Handle feedback integration workflow

**Dependencies**: All modules

---

## Inter-Module Communication

### Data Format
Modules exchange data using Lua tables with well-defined schemas

### Event System
Modules can subscribe to events from other modules (document updated, entity discovered, etc.)

### State Management
Shared state managed through orchestration layer with clear ownership boundaries

### Error Handling
Each module handles its own errors and reports status to orchestration layer
