# Issue 020: Adroit Integration Planning

## Current Behavior
- Progress-II exists as standalone bash-based terminal game concept
- Adroit project has completed Phase 2 with modular integration framework
- No connection between projects despite designed integration interfaces

## Intended Behavior
- Progress-II integrates with adroit's modular architecture
- Shared functionality leverages adroit's common libraries
- Character data flows between adroit's RPG mechanics and progress-ii adventures
- Bash command generation enhanced by adroit's C-based performance optimizations

## Suggested Implementation Steps

### Prerequisites
1. **Complete Progress-II Phase 1 Core Implementation**
   - Issues 001-010 must be functional before integration
   - Basic terminal interface, state management, and AI bash generation working
   - Git integration save/load system operational

2. **Integration Architecture Analysis**
   - Review adroit's `/libs/integration/bash_bridge.h` interfaces
   - Study progress-ii specific integration functions already designed
   - Understand module loading and template system

### Integration Implementation
1. **Adopt Adroit's Shared Library System**
   - Migrate progress-ii configuration to adroit's config system
   - Replace local logging with unified logging framework
   - Use common serialization for character data

2. **Implement Progress-II as Adroit Module**
   - Create progress-ii module using template system
   - Register with adroit's module loader
   - Expose progress-ii APIs through module interface

3. **Cross-Project Data Flow**
   - Character data synchronization between projects
   - State management coordination
   - Event system integration for real-time updates

4. **Enhanced Functionality**
   - Use adroit's C performance for computationally intensive operations
   - Leverage bash bridge for seamless script execution
   - Implement shared adventure scenarios using both systems

## Priority
**Medium** - Dependent on Progress-II Phase 1 completion

## Estimated Effort
15-20 hours (after Progress-II Phase 1 complete)

## Dependencies
- **Critical**: Progress-II Issues 001-010 (Phase 1) completion
- Adroit Phase 2 completion ✅ (already done)
- Understanding of modular integration architecture

## Integration Benefits
### For Progress-II
- Professional C-based foundation
- Enhanced performance for complex operations
- Unified configuration and logging systems
- Access to adroit's RPG stat systems

### For Adroit
- AI-generated bash command capabilities
- Dynamic adventure narrative system
- Git-based time travel mechanics
- Filesystem-based state persistence

### Combined Features
- **Enhanced Character Creation**: AI-generated equipment procurement using bash oneliners
- **Dynamic Adventures**: Stat-based narrative events with LLM enhancement
- **Unified Save System**: Character data shared between RPG mechanics and adventures
- **Performance Optimization**: C-based computation with bash flexibility

## Integration Timeline
```
Phase 1: Progress-II Foundation (Current Focus)
├── Complete Issues 001-010
├── Functional bash generation
└── Working save/load system

Phase 2: Integration Preparation
├── Study adroit integration interfaces
├── Plan data structure compatibility
└── Design module integration approach

Phase 3: Integration Implementation
├── Module template instantiation
├── Cross-project data flow
├── Enhanced feature development
└── Integration testing and validation
```

## Related Documents
- [Adroit Issue 007: Modular Integration Architecture](../../../../../../home/ritz/programming/ai-stuff/adroit/src/issues/phase-2/007-design-modular-integration-architecture.md)
- [Adroit Issue 009: Shared Library System](../../../../../../home/ritz/programming/ai-stuff/adroit/src/issues/phase-2/009-create-shared-library-system.md)
- [Progress-II Roadmap](../docs/roadmap.md)
- [Progress-II Technical Architecture](../docs/technical-architecture.md)

## Success Criteria
- Progress-II functions as adroit module without losing standalone capability
- Character data synchronizes seamlessly between projects
- AI bash generation performance improves through C integration
- Integration template demonstrates reusability for future ai-stuff projects

## Notes
- Integration is designed to be "radically incorporative" yet "extractable"
- Adroit's integration framework was specifically built with progress-ii in mind
- This integration serves as reference implementation for future ai-stuff ecosystem expansion