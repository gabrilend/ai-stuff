# Technical Design

## Technology Stack

### Core Language
**Lua (LuaJIT compatible)**
- Performance-oriented implementation
- Embeddable and lightweight
- Simple, clean syntax
- Strong table/metatable system for data structures
- FFI capabilities for native library integration

### UI Framework
**TUI (Terminal User Interface)**
- Text-based interaction for primary workflows
- Graphics rendering for mini-games
- Terminal memory direct access (blit character codes)
- Frame-based update system

### Data Storage
**File-based persistence**
- Plain text for documents and metadata
- Structured formats (JSON/Lua tables) for graphs and relationships
- Version control friendly
- Human-readable and greppable

### AI Integration
**Local models preferred**
- Image generation: Local diffusion models
- Text analysis: Local LLM or pattern-based analysis
- Audio generation: Local chiptune/synthesis libraries
- Minimizes external dependencies and latency

## Data Structures

### Document Representation
```lua
Document = {
    path = "/path/to/file.txt",
    content = "raw text content",
    metadata = {
        created = timestamp,
        modified = timestamp,
        author_tags = {"fantasy", "chapter-3"},
        analysis_version = "1.0"
    },
    entities = {
        -- Extracted characters, objects, locations
    },
    analysis = {
        -- Style metrics, gaps, relationships
    }
}
```

### Entity Graph Node
```lua
Entity = {
    id = "unique_id",
    type = "character" | "object" | "location" | "event",
    name = "Entity Name",
    attributes = {
        -- Type-specific attributes
        -- e.g., for character: age, appearance, personality
    },
    relationships = {
        -- Links to other entities
        {target_id = "other_id", type = "owns" | "knows" | "located_at", strength = 0.0-1.0}
    },
    appearances = {
        -- Document locations where entity appears
        {doc_path = "/path/to/doc.txt", line_number = 42, context = "surrounding text"}
    },
    metadata = {
        first_mention = timestamp,
        last_updated = timestamp,
        importance_score = 0.0-1.0
    }
}
```

### Semantic Graph
```lua
SemanticGraph = {
    nodes = {
        ["entity_id"] = Entity
    },
    edges = {
        -- Indexed by source_id for quick lookup
        ["entity_id"] = {
            {target = "other_id", type = "relationship_type", weight = 0.0-1.0}
        }
    },
    indices = {
        by_type = {
            character = {"id1", "id2"},
            object = {"id3", "id4"}
        },
        by_document = {
            ["/path/to/doc.txt"] = {"id1", "id3"}
        }
    }
}
```

### Question/Quiz Format
```lua
Worksheet = {
    id = "unique_id",
    document_ref = "/path/to/source.txt",
    generated = timestamp,
    questions = {
        {
            id = "q1",
            type = "fill_in_blank" | "short_answer" | "multiple_choice",
            category = "sensory" | "motivation" | "context",
            priority = 1-10,
            question_text = "How did the amulet smell when she first picked it up?",
            context = "surrounding text from document",
            related_entities = {"amulet_id", "character_id"},
            answer = nil  -- Filled in by author
        }
    },
    status = "pending" | "completed" | "integrated"
}
```

### Style Pattern
```lua
StylePattern = {
    author_id = "author_identifier",
    patterns = {
        sentence_structures = {
            {template = "pattern", frequency = count, examples = {"ex1", "ex2"}}
        },
        vocabulary = {
            word_frequencies = {["word"] = count},
            unique_phrases = {"phrase1", "phrase2"},
            metaphor_patterns = {"pattern1"}
        },
        rhythm = {
            avg_sentence_length = number,
            variance = number,
            paragraph_structure = "metrics"
        }
    },
    computed = timestamp
}
```

## System Architecture

### Initialization Flow
```
1. Load configuration from input/ directory
2. Initialize orchestration layer
3. Discover and load modules from libs/
4. Restore persistent state from previous session
5. Present main interface to user
```

### Analysis Pipeline
```
Document Change Detected
    ↓
Document Organizer: Parse and extract entities
    ↓
Semantic Mapper: Update graph relationships
    ↓
Style Analyzer: Compute style metrics
    ↓
Question Generator: Identify gaps, generate questions
    ↓
Image Generator: Queue image generation for new entities
    ↓
Poetry Engine: Update character poems if needed
    ↓
Save updated state
```

### Integration Pipeline
```
Author Completes Worksheet
    ↓
Feedback Integrator: Parse responses
    ↓
Feedback Integrator: Identify integration points
    ↓
Style Analyzer: Verify style compatibility
    ↓
Feedback Integrator: Generate suggestions
    ↓
Present to Author (tiered vimfolds)
    ↓
Author Accepts/Modifies (spacebar/click)
    ↓
Document Organizer: Update document
    ↓
Trigger Analysis Pipeline
```

## Module Interface Design

### Standard Module Interface
```lua
Module = {
    -- Module metadata
    name = "module-name",
    version = "1.0.0",
    dependencies = {"dependency-1", "dependency-2"},

    -- Lifecycle hooks
    init = function(config) end,
    shutdown = function() end,

    -- Core functionality
    process = function(input_data)
        return output_data
    end,

    -- Event handlers
    on_event = function(event_type, event_data) end,

    -- State management
    get_state = function() return state_table end,
    restore_state = function(state_table) end
}
```

### Event System
```lua
-- Event types
Events = {
    DOCUMENT_CHANGED = "document_changed",
    ENTITY_DISCOVERED = "entity_discovered",
    WORKSHEET_COMPLETED = "worksheet_completed",
    IMAGE_GENERATED = "image_generated",
    -- etc.
}

-- Event dispatcher
EventDispatcher = {
    subscribers = {},
    subscribe = function(event_type, callback) end,
    publish = function(event_type, event_data) end
}
```

## TUI Implementation

### Screen Layout
```
┌─────────────────────────────────────────────────────┐
│ Authorship Tool v1.0          [Documents] [Analyze]│
├─────────────────────────────────────────────────────┤
│                                                     │
│  [Main Content Area]                                │
│  - Document viewer/editor                           │
│  - Worksheet display                                │
│  - Analysis results                                 │
│  - Game rendering                                   │
│                                                     │
│                                                     │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Status: Ready | Pending: 3 worksheets              │
└─────────────────────────────────────────────────────┘
```

### Rendering System
- Blit character codes directly to TTY memory
- Frame-based update (maintain dirty regions)
- Separate data model from display logic
- Register-based architecture for display locations

### Input Handling
- Keyboard-driven primary interaction
- Spacebar for acceptance/progression
- Vim-style navigation where appropriate
- Mouse support for games (optional)

## Vimfold Strategy

### Progressive Disclosure Hierarchy
```
Level 0: Summary headline
  Level 1: Key points
    Level 2: Detailed explanation
      Level 3: Examples and justification
        Level 4: Full context and alternatives
```

### Implementation
- Use fold markers in generated text files
- TUI displays with expand/collapse capability
- Function definitions use vimfolds per coding standards
- Comments indicate function names for fold identification

## Dispatch Tables

### Function Dispatching
```lua
-- Prefer dispatch tables over if-else chains
local action_handlers = {
    ["analyze"] = handle_analyze,
    ["generate_questions"] = handle_questions,
    ["integrate_feedback"] = handle_integration,
}

local function dispatch_action(action_type, data)
    local handler = action_handlers[action_type]
    if handler then
        return handler(data)
    else
        error("Unknown action: " .. action_type)
    end
end
```

## Error Handling Strategy

### Module-Level Errors
- Each module handles its own errors
- Reports status to orchestration layer
- Prefer breaking/error messages over silent fallbacks
- Create issue tickets for fallback usage

### User-Facing Errors
- Clear, actionable error messages
- Preserve user work even on error
- Log errors to project tmp/ directory
- Never silently fail or lose user input

## Performance Considerations

### Incremental Processing
- Process document changes incrementally
- Cache analysis results
- Lazy-load images and heavy resources
- Update only affected portions of semantic graph

### Memory Management
- Stream large documents rather than loading entirely
- Unload inactive modules
- Garbage collect unused entities periodically
- Monitor memory usage and warn on excessive use

### I/O Optimization
- Batch file operations
- Async image generation
- Background processing for non-critical tasks
- Debounce rapid document changes

## Testing Strategy

### Unit Tests
- Test individual module functions in isolation
- Mock dependencies using test doubles
- Verify data structure contracts

### Integration Tests
- Test module interactions
- Verify event system functionality
- Validate pipeline workflows

### Phase Demos
- Create comprehensive demo at end of each phase
- Demonstrate new capabilities combined with previous
- Runnable via simple bash script
- Visual/statistical output preferred over descriptions

## Directory Structure Standards

### Project Layout
```
authorship-tool/
├── docs/              # Documentation
├── notes/             # Design notes, vision
├── src/               # Orchestration layer source
├── libs/              # Module sub-projects
│   ├── document-organizer/
│   │   ├── src/
│   │   ├── tests/
│   │   └── module.lua
│   ├── question-generator/
│   └── ...
├── assets/            # Shared resources
├── issues/            # Issue tracking
│   ├── completed/
│   │   └── demos/
│   └── phase-N-progress.md
├── tmp/               # Project-specific temporary files
└── input/             # User input files
```

### File Naming
- Use dash-separated lowercase names
- Clear, descriptive names
- Include version/phase in filenames where relevant
- Use .info.md for function documentation

## Comment Standards

### Source Code Comments
- Explain WHY, not WHAT
- Document reasoning for design choices
- Mark FIXME with explanation and signature if needed
- Include vimfold markers for function definitions
- Add data format notes where relevant

### Function Documentation
```lua
-- {{{ local function process_document
-- Processes a single document through the analysis pipeline
-- Expects: document_path (string), options (table)
-- Returns: analysis_result (table) or nil, error_message (string)
local function process_document(document_path, options)
    -- Implementation
end
-- }}}
```
