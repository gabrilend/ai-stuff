# Issue 002-MASTER: Gitignore Unification Script (BROKEN DOWN)

## Current Behavior

The `/home/ritz/programming/ai-stuff/` directory contains multiple individual `.gitignore` files scattered across project directories and library dependencies:

### Main Project .gitignore Files
- `/console-demakes/.gitignore`
- `/handheld-office/.gitignore` 
- `/words-pdf/.gitignore`
- `/progress-ii/.gitignore`
- `/progress-ii/game-state/.gitignore`
- `/adroit/.gitignore`

### Library Dependency .gitignore Files
- External libraries in `libs/c/raylib/`, `libs/lua/effil*`
- Game development tools in `console-demakes/tools/rgbds/`
- PDF generation libraries in `words-pdf/libs/`
- Emscripten SDK in `games/gameboy-color-rpg/libs/emsdk/`
- Sol2 Lua bindings in multiple locations

### Current State Issues
- No unified `.gitignore` at repository root
- Potential conflicts between different ignore patterns
- Risk of committing files that should be ignored
- Difficulty maintaining consistent ignore rules across projects

## Intended Behavior

Create an automated script that:

1. **Aggregates Rules**: Collects all ignore patterns from individual project `.gitignore` files
2. **Deduplicates**: Removes duplicate entries and conflicting patterns  
3. **Organizes**: Structures the unified `.gitignore` with clear sections for different project types
4. **Preserves Context**: Maintains comments indicating which project contributed each rule
5. **Validates**: Ensures no critical files are accidentally ignored
6. **Updates**: Can be re-run when individual project `.gitignore` files change

## BREAKDOWN NOTICE

**This issue has been broken down into individual implementation issues:**

- **Issue 009**: Discover and Analyze Gitignore Files
- **Issue 010**: Design Unification Strategy  
- **Issue 011**: Implement Pattern Processing
- **Issue 012**: Generate Unified Gitignore
- **Issue 013**: Implement Validation and Testing
- **Issue 014**: Create Maintenance Utilities
- **Issue 015**: Integration and Workflow Setup

**Recommended Implementation Order:**
1. Issue 009 (Discover and Analyze Gitignore Files)
2. Issue 010 (Design Unification Strategy)
3. Issue 011 (Implement Pattern Processing)
4. Issue 012 (Generate Unified Gitignore)
5. Issue 013 (Implement Validation and Testing)
6. Issue 014 (Create Maintenance Utilities)
7. Issue 015 (Integration and Workflow Setup)

## Original Implementation Steps (Reference)

### 1. Script Architecture Design → Issue 015
### 2. Discovery Phase → Issue 009
### 3. Pattern Processing → Issue 011
### 4. Template Generation → Issue 012
### 5. Validation and Safety → Issue 013
### 6. Integration Features → Issue 015
### 7. Maintenance Utilities → Issue 014

## Implementation Details

### Script Requirements
- Must run from any directory using hardcoded `${DIR}` path
- Support vimfold structure for function organization
- Include interactive mode with index-based selection
- Provide both headless and interactive execution modes

### File Structure
```
/home/ritz/programming/ai-stuff/
├── scripts/
│   └── generate-unified-gitignore.sh
├── .gitignore (generated)
└── .gitignore.template (optional template)
```

### Integration Points
- Called during git repository initialization (Issue 001)
- Can be triggered manually when project `.gitignore` files change
- Integrated into project maintenance workflows

## Related Documents
- `001-comprehensive-git-repository-setup.md` - Parent task requiring unified gitignore
- Individual project documentation explaining ignore requirements
- Git workflow documentation

## Tools Required
- Bash scripting capabilities
- Text processing utilities (grep, awk, sort, uniq)
- Git integration for validation
- File system traversal tools

## Metadata
- **Priority**: High (prerequisite for Issue 001)
- **Complexity**: Medium
- **Estimated Time**: 1-2 hours
- **Dependencies**: Issue 001 (git repository setup)
- **Impact**: Repository cleanliness, development workflow

## Success Criteria
- Unified `.gitignore` file created at repository root
- All relevant patterns from individual projects included
- No essential files accidentally ignored
- Script can be re-run safely without conflicts
- Clear documentation of pattern sources and purpose