# Issue 009: Discover and Analyze Gitignore Files

## Current Behavior

The project directory contains 40+ `.gitignore` files scattered across project directories and library dependencies, but there is no systematic inventory or analysis of these files. Without understanding the current ignore patterns, it's impossible to create an effective unified `.gitignore`.

### Current State
- `.gitignore` files exist in multiple project directories
- Library dependencies contain their own ignore patterns
- No central inventory of existing ignore rules
- No analysis of pattern conflicts or redundancy
- Unknown which patterns are project-specific vs. universal

## Intended Behavior

Create a comprehensive discovery and analysis system that:
1. **File Discovery**: Systematically locate all `.gitignore` files in the repository
2. **Content Analysis**: Parse and categorize ignore patterns by type and purpose
3. **Pattern Classification**: Distinguish between project-specific and universal patterns
4. **Conflict Detection**: Identify conflicting or contradictory ignore rules
5. **Usage Analysis**: Determine which patterns are actively needed vs. obsolete

## Suggested Implementation Steps

### 1. Automated Discovery
```bash
# -- {{{ discover_gitignore_files
function discover_gitignore_files() {
    find /home/ritz/programming/ai-stuff -name ".gitignore" -type f
}
# }}}
```

### 2. Content Extraction and Parsing
```bash
# -- {{{ parse_gitignore_content  
function parse_gitignore_content() {
    # Extract patterns from each file
    # Remove comments and empty lines
    # Normalize pattern format
}
# }}}
```

### 3. Pattern Classification System
- **Build Artifacts**: `*.o`, `*.exe`, `build/`, `target/`
- **IDE Files**: `.vscode/`, `*.swp`, `.idea/`
- **Language Specific**: `node_modules/`, `__pycache__/`, `*.pyc`
- **OS Specific**: `.DS_Store`, `Thumbs.db`, `*.tmp`
- **Project Specific**: Custom patterns unique to individual projects

### 4. Dependency vs. Project Separation
Distinguish between:
- **Main Project Files**: Ignore patterns from actual project directories
- **Library Dependencies**: Patterns from external libraries in `libs/` folders
- **Tool Dependencies**: Patterns from development tools and SDKs

### 5. Conflict and Redundancy Analysis
- Identify duplicate patterns across multiple files
- Detect conflicting rules (one file ignores, another includes)
- Find patterns that might be too broad or too specific

### 6. Generate Analysis Report
Create comprehensive report documenting:
- Total files discovered and their locations
- Pattern categories and frequency
- Potential conflicts requiring resolution
- Recommendations for unified patterns

## Implementation Details

### Discovery Script Structure
```bash
#!/bin/bash
DIR="${1:-/home/ritz/programming/ai-stuff}"

# -- {{{ main
function main() {
    discover_files
    analyze_patterns
    generate_report
}
# }}}
```

### Pattern Analysis Output
```
GITIGNORE ANALYSIS REPORT
========================

Files Discovered: 42
Main Projects: 6 files
Library Dependencies: 36 files

Pattern Categories:
- Build Artifacts: 15 unique patterns
- IDE Files: 8 unique patterns  
- Language Specific: 12 unique patterns
- OS Specific: 4 unique patterns
- Project Specific: 23 unique patterns

Conflicts Detected: 3
Redundant Patterns: 18
```

### Classification Database
```ini
# pattern-classification.conf
[build_artifacts]
patterns=*.o,*.exe,*.so,*.dylib,build/,target/,dist/

[ide_files] 
patterns=.vscode/,.idea/,*.swp,*.swo,.vim/

[language_specific]
patterns=node_modules/,__pycache__/,*.pyc,*.pyo,vendor/
```

## Related Documents
- `010-design-unification-strategy.md` - Uses analysis results
- `002-gitignore-unification-script.md` - Parent ticket

## Tools Required
- File system traversal and search
- Text parsing and pattern matching
- Configuration file handling
- Report generation utilities

## Metadata
- **Priority**: High
- **Complexity**: Medium
- **Estimated Time**: 1 hour
- **Dependencies**: None
- **Impact**: Foundation for unified gitignore creation

## Success Criteria
- All `.gitignore` files discovered and catalogued
- Patterns categorized by type and purpose
- Conflicts and redundancy identified
- Clear separation of project vs. dependency patterns
- Analysis report provides actionable insights
- Foundation ready for unification strategy design