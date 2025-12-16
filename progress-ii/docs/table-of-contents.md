# Progress-II Documentation Table of Contents

## Core Documentation
```
docs/
├── table-of-contents.md          # This document
├── roadmap.md                     # 6-phase development roadmap
├── game-overview.md               # Complete game mechanics and concepts
└── technical-architecture.md      # System design and implementation details
```

## Project Planning
```
issues/
├── CLAUDE.md                      # Project configuration guide and status
└── 020-adroit-integration-planning.md  # Integration planning with adroit project
```

## Current Phase 1 Issues
```
issues/phase-1/
├── 001-012                        # Original phase 1 development issues
├── 013-missing-unit-header-dependency         # Adroit unit.h header missing
├── 014-lua-integration-function-declarations  # Lua bridge function declaration errors  
└── 015-unused-variables-compilation-warnings  # Code quality and compilation warnings
```

## Vision and Foundation
```
notes/
└── vision                         # Core game concept and philosophical foundation
```

## Implementation Structure
```
src/                              # Core implementation files (pending Phase 1)
├── (terminal interface)          # Issue 001
├── (state management)             # Issue 002
├── (git integration)              # Issue 003
└── (AI command generation)        # Issue 004

libs/                             # Utility libraries and modules
├── (character systems)           # Issue 005
├── (configuration management)    # Issue 006
└── (testing framework)           # Issue 007
```

## Project State Files
```
game-state/                       # Runtime game state storage
backups/                         # Conversation and development backups
assets/                          # Game assets and resources
```

## Development Lifecycle Tracking
```
issues/completed/                 # Completed issues and phase demos (future)
├── phase-1/                     # Phase 1 completion artifacts
├── phase-2/                     # Phase 2 completion artifacts
└── ...                          # Subsequent phases
```

## Integration Documentation
- **Adroit Integration**: See `/home/ritz/programming/ai-stuff/adroit/src/issues/phase-2/` for completed integration framework
- **Module Template**: Available in adroit's `/libs/templates/` directory
- **Shared Libraries**: Common utilities in adroit's `/libs/common/` system

## Document Maintenance Notes
- All new documents must be added to this table of contents
- Issue completion updates this structure automatically
- Integration documentation spans both projects
- Phase completion adds demonstration artifacts to the tree structure