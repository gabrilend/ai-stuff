# Integration Template Guide

## Overview

This template provides a standardized approach for incorporating existing projects from `/home/ritz/programming/ai-stuff/` into the unified modular system. Follow this guide to ensure radical incorporation while maintaining extractability and convenience.

## Template Checklist

### Pre-Integration Analysis
- [ ] **Project Assessment**
  - [ ] Identify core functionality and unique value proposition
  - [ ] Map existing data structures and interfaces
  - [ ] Document current dependencies and build requirements
  - [ ] Assess integration complexity and potential benefits

- [ ] **Data Flow Analysis**
  - [ ] Identify input/output data formats
  - [ ] Map state management patterns
  - [ ] Document configuration requirements
  - [ ] Assess real-time vs. batch processing needs

### Module Structure Setup
- [ ] **Directory Organization**
  ```
  project-name/
  ├── src/                    # Original source code
  ├── libs/                   # Project-specific libraries
  ├── integration/            # Integration code
  │   ├── module.c/.h         # Module interface implementation
  │   ├── bridge.c/.h         # Language/format bridges
  │   └── config.ini          # Integration configuration
  ├── docs/
  │   ├── integration.md      # Integration documentation
  │   └── api.md             # Module API reference
  └── tests/
      ├── standalone/         # Original project tests
      └── integration/        # Integration tests
  ```

- [ ] **Module Interface Implementation**
  ```c
  // integration/module.c
  #include "../../libs/common/module.h"
  #include "../../libs/common/logging.h"
  
  static ProjectAPI project_api;
  static bool initialized = false;
  
  Module* register_module(void) {
      static Module module = {
          .name = "project-name",
          .version = "1.0.0",
          .dependencies = {"common", NULL},
          .init = project_init,
          .cleanup = project_cleanup,
          .get_api = project_get_api
      };
      return &module;
  }
  ```

### Data Integration
- [ ] **Serialization Implementation**
  - [ ] Implement JSON export/import for core data structures
  - [ ] Create binary serialization for performance-critical data
  - [ ] Design schema versioning for backward compatibility
  - [ ] Add validation for data integrity

- [ ] **State Synchronization**
  - [ ] Implement state export functions
  - [ ] Create state import with conflict resolution
  - [ ] Add state change notification system
  - [ ] Design rollback/undo capabilities

### Bridge Implementation
- [ ] **Language Bridges** (if needed)
  ```c
  // For bash script projects
  char* execute_script_command(const char* script, const char* args);
  int parse_script_output(const char* output, void* result_struct);
  
  // For Lua projects  
  LuaResult* call_lua_function(LuaContext* ctx, const char* func, const char** args, int count);
  
  // For other languages
  // Implement appropriate bridge functions
  ```

- [ ] **Configuration Bridge**
  ```ini
  # integration/config.ini
  [module]
  name = project-name
  type = bash-script  # or c-program, python-script, etc.
  
  [paths]
  executable = ./src/main-script.sh
  state_dir = ./state
  config_file = ./config/settings.ini
  
  [integration]
  data_format = json
  update_frequency = on-demand  # or realtime, periodic
  dependencies = common,logging
  ```

### API Design
- [ ] **External API Definition**
  ```c
  // integration/api.h
  typedef struct ProjectAPI {
      // Core functionality
      int (*start)(const char* config);
      int (*stop)(void);
      
      // Data access
      char* (*export_state)(void);
      int (*import_state)(const char* data);
      
      // Integration points
      void (*on_data_update)(DataUpdateCallback callback);
      int (*process_external_command)(const char* command, void* args);
  } ProjectAPI;
  ```

- [ ] **Event System Integration**
  ```c
  // Register for global events
  register_event_handler("character_created", on_character_created);
  register_event_handler("adventure_completed", on_adventure_completed);
  
  // Emit events for other modules
  emit_event("equipment_updated", equipment_json);
  emit_event("state_changed", state_diff_json);
  ```

### Testing Strategy
- [ ] **Standalone Tests**
  - [ ] Verify original functionality still works
  - [ ] Test module in isolation
  - [ ] Validate data serialization round-trips
  - [ ] Test configuration handling

- [ ] **Integration Tests**
  - [ ] Test module loading/unloading
  - [ ] Verify cross-module communication
  - [ ] Test state synchronization
  - [ ] Validate event handling

- [ ] **End-to-End Tests**
  - [ ] Test complete workflows using multiple modules
  - [ ] Verify data consistency across modules
  - [ ] Test error handling and recovery
  - [ ] Performance testing with integration overhead

### Documentation Requirements
- [ ] **Integration Documentation**
  - [ ] API reference with examples
  - [ ] Configuration options and defaults
  - [ ] Event types and data formats
  - [ ] Troubleshooting guide

- [ ] **Developer Guide**
  - [ ] How to build and test the module
  - [ ] How to extend or modify functionality
  - [ ] Integration points for future enhancements
  - [ ] Performance optimization tips

## Example: Adroit + Progress-II Integration

### Analysis Phase
**Adroit**: C program, character generation, stats management
**Progress-II**: Bash scripts, LLM-driven adventures, filesystem state

**Integration Opportunities**:
- Character stats influence adventure outcomes
- Adventure results generate equipment/experience
- Shared character progression system

### Implementation
```c
// adroit/integration/module.c
Module* register_adroit_module(void) {
    // Character creation and management API
}

// progress-ii/integration/module.c  
Module* register_progress_ii_module(void) {
    // Adventure system API
}

// Shared integration
start_adventure(character_stats) -> adventure_result
apply_adventure_result(adventure_result) -> updated_character
```

### Data Flow
```json
// Character state (JSON)
{
    "stats": {"str": 15, "dex": 12, "honor": 8},
    "equipment": ["sword", "leather_armor"],
    "experience": 150
}

// Adventure input
{
    "character": {...},
    "scenario": "dungeon_exploration",
    "context": {...}
}

// Adventure result
{
    "outcome": "success",
    "stat_changes": {"str": +1, "honor": -1},
    "equipment_found": ["magic_ring"],
    "experience_gained": 25,
    "narrative": "You discovered..."
}
```

## Best Practices

### Radical Incorporation
- Share actual data structures, not just interfaces
- Enable deep customization through module interactions
- Create emergent behaviors from module combinations
- Design for bidirectional data flow

### Extractability
- Never modify original project source code directly
- Keep integration code in separate directories
- Maintain original build systems and entry points
- Test standalone functionality regularly

### Convenience
- Provide sensible defaults for all configuration
- Create helper functions for common integration patterns
- Generate boilerplate code automatically where possible
- Document common pitfalls and solutions

### Performance
- Minimize data copying between modules
- Use shared memory for real-time interactions
- Cache expensive operations
- Profile integration overhead and optimize hotpaths

## Template Evolution

This template will evolve based on real-world integration experiences. Key areas for improvement:

1. **Automation**: Tools to generate integration boilerplate
2. **Performance**: Optimize common integration patterns
3. **Debugging**: Better tools for diagnosing integration issues
4. **Documentation**: More examples and common patterns
5. **Testing**: Automated integration test generation