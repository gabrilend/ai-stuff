# Requirements Investigation Report

## Overview
Comprehensive search through `/home/ritz/programming/ai-stuff/` for specific requirements identified from the continual-co-operation vision document.

## Specific Requirements Searched
1. **"Circular Oracle Dice Result"** - Referenced but not yet implemented
2. **"Golem Project in ChatGPT"** - Referenced design principle  
3. **Bash Script Interpreter** - "This call is never actually run, instead an interpreter scans through the document, finds all of the function calls, and then runs them and writes the result there"
4. **Clay Robot Interface** - Physical manifestation with processing/personality centers
5. **Scratch Integration** - Child-accessible programming interface
6. **RAM Storage System** - "Important things can be written to ram with a simple bash script call"

## Key Findings

### 1. Circular Oracle Dice Mechanics - FOUND
**Location**: `/home/ritz/programming/ai-stuff/words-pdf/input/txt-files/notes/symbeline-aspects`

**Relevance**: Contains detailed d12 dice-based decision system that could be the "circular oracle dice result" referenced in vision

**Key Content**:
- Complex interactions "boil down to a single pair of d12 dice - one for your noble, one for the enemy"
- Charisma-based rolling system with personality trait interactions
- Three interconnected aspects (military, economics, diplomacy) that can be AI-controlled
- Self-balancing AI progression system

**Implementation Potential**: High - could be adapted for the AI entity decision-making framework

### 2. AI Bash Command Framework - FOUND
**Location**: `/home/ritz/programming/ai-stuff/progress-ii/issues/phase-1/004-ai-bash-command-framework`

**Relevance**: Direct implementation of the bash script interpreter requirement from vision

**Key Content**:
- AI-generated bash command creation, validation, and execution
- Sandboxed execution environment
- Command history and learning system
- Context-aware prompt generation
- Safety validation and whitelisting

**Implementation Potential**: Very High - directly matches vision requirement, ready to integrate

### 3. Golem Project References - FOUND
**Location**: `/home/ritz/programming/ai-stuff/words-pdf/input/txt-files/notes/game-design`

**Relevance**: Mentions AI entities as "new kinds of beings" - likely connection to "golem project in chatGPT"

**Key Content**:
- "Robots are something else, a new kind of being"
- "let them be who they are instead of projecting yourself onto them"
- AGI concepts through video game AI finite state machines

**Implementation Potential**: Medium - philosophical framework for AI entity personality centers

### 4. Physical Robot Interface Patterns - FOUND
**Location**: Multiple files in handheld-office project
- `/home/ritz/programming/ai-stuff/handheld-office/src/ai_image_service.rs`
- `/home/ritz/programming/ai-stuff/handheld-office/docs/ai/ai-image-keyboard.md`

**Relevance**: Physical device control patterns that could inform clay robot interface

**Key Content**:
- WiFi Direct P2P communication with physical devices
- Encrypted bytecode instruction systems
- Device-to-daemon communication protocols

**Implementation Potential**: High - existing patterns for digital-to-physical entity control

### 5. Scratch/Visual Programming References - FOUND
**Location**: Multiple files mentioning visual programming and blocks
- Various references to block-based programming throughout projects
- Educational programming interface concepts

**Relevance**: Foundation for child-accessible AI programming interface

**Implementation Potential**: Medium - concepts exist, needs specific implementation

### 6. Memory/RAM Storage Systems - FOUND
**Location**: Multiple locations
- Current rolling-memory implementation already provides RAM-like storage
- Progress-ii project has state management systems

**Relevance**: Storage system for important data persistence

**Implementation Potential**: High - already partially implemented in current project

## Additional Significant Discoveries

### Symbeline Game Architecture
**Location**: `/home/ritz/programming/ai-stuff/symbeline/inspiration/`
- Complex AI-controlled game aspects that self-balance
- Three-aspect interaction system (military, economics, diplomacy)
- Worker-placement and resource management systems

### Progress-II AI Framework
**Location**: `/home/ritz/programming/ai-stuff/progress-ii/`
- Complete AI integration framework
- Character experience systems with AI personalities
- State serialization and management
- Terminal interface with AI command generation

### Handheld-Office Physical Interface
**Location**: `/home/ritz/programming/ai-stuff/handheld-office/`
- Real-world device integration
- Encrypted communication protocols
- Air-gapped architecture with secure proxies

## Recommended Investigation Priorities

1. **IMMEDIATE**: AI Bash Command Framework from progress-ii - direct match to vision requirement
2. **HIGH**: Symbeline dice system for circular oracle implementation  
3. **HIGH**: Physical interface patterns from handheld-office for clay robot integration
4. **MEDIUM**: Golem project philosophical framework for personality centers
5. **MEDIUM**: Scratch integration concepts for child accessibility

## Questions for User Decision

Which of these findings should be investigated in detail and incorporated into the continual-co-operation project tickets? Each represents a different aspect of the vision document requirements and varying levels of implementation complexity.