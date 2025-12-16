# Modular Architecture for AI-Stuff Projects

## Vision

Create a unified ecosystem where all projects in `/home/ritz/programming/ai-stuff/` can be seamlessly integrated as libraries or modules while maintaining their individual functionality and extractability.

## Core Principles

### 1. Radical Incorporation
Projects integrate deeply, sharing state, data structures, and functionality. Not just loose coupling, but meaningful cross-pollination of capabilities.

### 2. Extractability
Each module remains fully functional when removed from the integrated system. No hard dependencies that break standalone operation.

### 3. Convenience
Standard APIs and templates make integration straightforward. Developers can focus on unique functionality rather than integration boilerplate.

### 4. Template-Driven
Patterns established by the adroit/progress-ii integration serve as templates for incorporating other projects.

## Architecture Overview

```
/home/ritz/programming/ai-stuff/
├── libs/                           # Shared libraries
│   ├── common/                     # Core utilities
│   ├── integration/                # Integration framework
│   └── templates/                  # Module templates
├── adroit/                         # RPG character generator
├── progress-ii/                    # Terminal adventure game
├── [other-projects]/               # Future integrated projects
└── unified-launcher/               # Optional: unified entry point
```

## Integration Framework Components

### Module Registration System
```c
// Module interface definition
typedef struct Module {
    char* name;
    char* version;
    char** dependencies;
    int (*init)(ModuleConfig* config);
    int (*cleanup)(void);
    void* (*get_api)(const char* api_name);
} Module;

// Registration function each module implements
Module* register_module(void);
```

### Shared State Management
- **Global State Store**: Key-value store for cross-module data
- **Event System**: Pub/sub for module communication
- **Configuration Hierarchy**: Global → Project → Module configs
- **Unified Save System**: Coordinated state persistence

### Data Exchange Formats
- **JSON**: Human-readable, debuggable, bash-compatible
- **Binary**: Performance-critical operations
- **Message Queue**: Asynchronous module communication
- **Shared Memory**: Real-time data sharing

## Integration Patterns

### Pattern 1: C Program + Bash Scripts (Adroit + Progress-II)
```c
// C program calls bash scripts
char* result = execute_bash_module("progress-ii", "adventure", character_json);
Character* updated_char = parse_adventure_result(result);

// Bash scripts read/write JSON state
cat character.json | jq '.stats.strength' # Read C data
echo '{"equipment": ["sword", "shield"]}' > equipment.json # Write to C
```

### Pattern 2: Data-Driven Integration
- Modules communicate through standardized data files
- File watchers trigger updates between modules
- Git-based versioning for state rollback (progress-ii style)
- Atomic file operations prevent corruption

### Pattern 3: API-Based Integration
```c
// Module provides API
AdroitAPI* api = (AdroitAPI*)get_module_api("adroit");
Character* char = api->create_character();

// Progress-II integration
ProgressAPI* prog_api = (ProgressAPI*)get_module_api("progress-ii");
prog_api->start_adventure(char->stats);
```

## Benefits of This Architecture

### For Developers
- **Rapid Prototyping**: New projects bootstrap with existing components
- **Code Reuse**: Common functionality shared across projects
- **Testing**: Modules can be tested in isolation or integration
- **Maintenance**: Bug fixes propagate to all using projects

### For Users
- **Unified Experience**: Seamless transitions between different project features
- **Data Portability**: Character data, progress, and state work across projects
- **Extensibility**: Easy to add new capabilities by integrating more projects
- **Flexibility**: Can use projects standalone or integrated

### For the Ecosystem
- **Innovation**: Cross-project feature combinations create emergent capabilities
- **Documentation**: Shared patterns and templates improve overall quality
- **Community**: Standard interfaces enable third-party module development
- **Evolution**: Architecture supports natural growth and experimentation

## Implementation Strategy

### Phase 2A: Foundation
1. Create shared library structure
2. Implement core utilities (logging, config, serialization)
3. Design module interface specification
4. Create integration templates

### Phase 2B: Reference Integration
1. Integrate adroit and progress-ii using template system
2. Demonstrate key integration patterns
3. Document lessons learned
4. Refine template based on real usage

### Phase 2C: Ecosystem Expansion
1. Apply templates to integrate other ai-stuff projects
2. Create unified launcher/interface
3. Implement advanced features (hot-reloading, distributed modules)
4. Establish community contribution guidelines

## Success Metrics

- **Template Effectiveness**: Time to integrate new project < 4 hours
- **Extractability**: Any module can be removed without breaking others
- **Performance**: Integration overhead < 10% of standalone performance
- **Developer Experience**: Clear documentation, minimal boilerplate
- **User Experience**: Seamless cross-project workflows