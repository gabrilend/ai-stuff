# Progress-II Technical Architecture

## Core Technology Stack
- **Language**: Bash scripting with AI-generated one-liners
- **Version Control**: Git (integrated as gameplay mechanic)
- **Storage**: HDD-based filesystem operations
- **Interface**: Terminal/Command-line
- **AI Integration**: LLM for bash command generation and narrative responses

## Architecture Principles

### Filesystem as Game State
- All game state stored directly in filesystem
- Real-time persistence through file operations
- Directory structure represents game world organization
- File contents represent object and character states

### Git as Time Manipulation
- Every significant game state change creates a git commit
- Commits include both human-readable and serialized formats
- Branch-based parallel timeline support
- Rollback mechanics for "time rewind" gameplay

### AI-Driven Command Generation
- LLM generates context-appropriate bash one-liners
- Commands execute actual system operations
- AI maintains awareness of current game state through filesystem
- Dynamic problem-solving through command composition

## System Components

### Core Game Engine
- **State Manager**: Tracks all game variables and character stats
- **Command Processor**: Interfaces with AI for bash generation
- **Commit Handler**: Manages git operations and timeline mechanics
- **Event System**: Processes player actions and generates responses

### Logging System
Two-tier approach for different use cases:

#### Performance Mode (Serialized)
- Binary or structured data format
- Minimal file I/O overhead
- Machine-readable for rapid state reconstruction
- Optimized for runtime execution

#### Debug Mode (Human-Readable)
- Natural language descriptions of events
- LLM-compatible format for AI understanding
- Detailed context for debugging and development
- Git commit messages in English

### Storage Architecture

#### Directory Structure
```
game-state/
├── characters/
│   ├── maxine/
│   └── companions/
├── world/
│   ├── locations/
│   ├── items/
│   └── variables/
├── logs/
│   ├── serialized/
│   └── human-readable/
└── saves/
    └── checkpoints/
```

#### File Naming Conventions
- Timestamp-based for chronological ordering
- State-descriptive names for easy identification
- Git-friendly naming for version control integration

## AI Integration Points

### Command Generation
- Context-aware bash one-liner creation
- System state analysis for appropriate commands
- Error handling and alternative command suggestions
- Command validation before execution

### Narrative Generation
- Dynamic story responses based on player actions
- Character dialogue generation
- Environmental description creation
- Quest and event text generation

### Decision Making
- AI-driven NPC behavior
- Dynamic event branching
- Problem-solving scenario creation
- Adaptive difficulty based on player skill

## Performance Considerations

### HDD Optimization
- Sequential file operations preferred over random access
- Batch file operations where possible
- Minimize frequent small writes
- Implement write coalescing for rapid state changes

### Git Performance
- Shallow clones for timeline branches
- Periodic repository maintenance
- Compressed storage for large state files
- Efficient diff strategies for game state

### Memory Management
- Lazy loading of game world sections
- State caching for frequently accessed data
- Memory-mapped files for large datasets
- Garbage collection for unused state data

## Security and Safety

### Command Execution Safety
- Sandboxed execution environment
- Command whitelist/blacklist filtering
- Resource limitation enforcement
- User permission validation

### Data Integrity
- Checksums for critical game state
- Backup strategies for save corruption
- Recovery mechanisms for failed operations
- State validation on load/save

## Extensibility Design

### Plugin Architecture
- Modular event handlers
- Custom command generators
- External AI model integration
- User-defined game mechanics

### Configuration System
- Performance vs readability toggle
- AI model selection
- Storage location configuration
- Gameplay mechanic customization

## Development Tools

### Testing Framework
- Automated game state verification
- AI command generation testing
- Performance benchmarking tools
- Save/load integrity validation

### Debugging Tools
- State inspection utilities
- Command execution tracing
- Timeline visualization
- Performance profiling

## Deployment Considerations

### System Requirements
- HDD storage availability
- Git installation and configuration
- Terminal/shell environment
- AI model access (local or API)

### Installation Process
- Dependency verification
- Storage path configuration
- Git repository initialization
- Initial game state setup