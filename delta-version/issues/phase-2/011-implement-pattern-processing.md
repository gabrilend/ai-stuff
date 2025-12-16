# Issue 011: Implement Pattern Processing

## Current Behavior

The strategy for unifying `.gitignore` patterns has been designed (Issue 010), but there is no implementation for processing the discovered patterns according to this strategy. Raw pattern data needs to be transformed into the organized, conflict-resolved unified format.

## Intended Behavior

Implement the core pattern processing engine that:
1. **Pattern Parsing**: Extract and normalize patterns from discovered files
2. **Conflict Resolution**: Apply the designed strategy to resolve pattern conflicts
3. **Deduplication**: Remove redundant and duplicate patterns efficiently  
4. **Categorization**: Group patterns according to the designed structure
5. **Attribution Tracking**: Maintain source information for each pattern

## Suggested Implementation Steps

### 1. Pattern Parsing Engine
```bash
# -- {{{ parse_patterns
function parse_patterns() {
    local gitignore_file="$1"
    
    # Remove comments and empty lines
    # Normalize whitespace
    # Extract actual ignore patterns
    # Classify pattern type (file, directory, glob, etc.)
}
# }}}
```

### 2. Pattern Normalization
```bash
# -- {{{ normalize_pattern
function normalize_pattern() {
    local pattern="$1"
    
    # Standardize path separators
    # Remove redundant wildcards
    # Canonicalize directory patterns
    # Handle negation patterns consistently
}
# }}}
```

### 3. Conflict Resolution Engine
```bash
# -- {{{ resolve_conflicts
function resolve_conflicts() {
    local pattern_list="$1"
    
    # Apply precedence rules from strategy
    # Handle negation conflicts (!pattern vs pattern)
    # Resolve scope conflicts (broad vs specific)
    # Generate conflict resolution log
}
# }}}
```

### 4. Pattern Categorization
```bash
# -- {{{ categorize_patterns
function categorize_patterns() {
    local normalized_patterns="$1"
    
    # Match against known pattern categories
    # Assign to universal, build, language, or project-specific groups
    # Handle patterns that match multiple categories
    # Create category-specific pattern lists
}
# }}}
```

### 5. Deduplication and Optimization
```bash
# -- {{{ deduplicate_patterns
function deduplicate_patterns() {
    local categorized_patterns="$1"
    
    # Remove exact duplicates
    # Merge functionally equivalent patterns
    # Optimize pattern order for efficiency
    # Remove patterns subsumed by broader rules
}
# }}}
```

### 6. Attribution and Metadata Tracking
```bash
# -- {{{ track_attribution
function track_attribution() {
    local pattern="$1"
    local source_file="$2"
    
    # Record which project contributed the pattern
    # Track conflict resolution decisions
    # Maintain pattern modification history
    # Generate attribution comments
}
# }}}
```

## Implementation Details

### Pattern Processing Pipeline
```bash
#!/bin/bash
DIR="${1:-/home/ritz/programming/ai-stuff}"

# -- {{{ process_all_patterns
function process_all_patterns() {
    local discovered_files="$1"
    
    # Stage 1: Parse and normalize all patterns
    for file in $discovered_files; do
        parse_patterns "$file"
        normalize_pattern "$pattern"
    done
    
    # Stage 2: Resolve conflicts and deduplicate
    resolve_conflicts "$all_patterns"
    deduplicate_patterns "$resolved_patterns"
    
    # Stage 3: Categorize and attribute
    categorize_patterns "$deduplicated_patterns"
    track_attribution "$final_patterns"
}
# }}}
```

### Conflict Resolution Implementation
```bash
# -- {{{ apply_precedence_rules
function apply_precedence_rules() {
    local conflicting_patterns="$1"
    
    # Security patterns (highest precedence)
    if [[ "$pattern" =~ \.(key|pem|p12|pfx)$ ]]; then
        precedence="security"
        action="always_ignore"
    fi
    
    # Critical build artifacts
    if [[ "$pattern" =~ \.(o|exe|so|dylib)$ ]]; then
        precedence="build"
        action="always_ignore"
    fi
    
    # Project-specific requirements
    if is_project_specific "$pattern"; then
        precedence="project"
        action="most_restrictive_wins"
    fi
}
# }}}
```

### Pattern Categorization Logic
```bash
# -- {{{ classify_pattern_type
function classify_pattern_type() {
    local pattern="$1"
    
    # Build artifacts
    if [[ "$pattern" =~ \.(o|obj|exe|dll|so|dylib)$ ]] || 
       [[ "$pattern" =~ ^(build|target|dist|out)/ ]]; then
        echo "build_artifacts"
        return
    fi
    
    # IDE files
    if [[ "$pattern" =~ ^\.vscode/ ]] || 
       [[ "$pattern" =~ \.(swp|swo)$ ]] ||
       [[ "$pattern" =~ ^\.idea/ ]]; then
        echo "ide_files"
        return
    fi
    
    # Language specific
    if [[ "$pattern" =~ ^node_modules/ ]] ||
       [[ "$pattern" =~ ^__pycache__/ ]] ||
       [[ "$pattern" =~ \.pyc$ ]]; then
        echo "language_specific"
        return
    fi
    
    # Default to project specific
    echo "project_specific"
}
# }}}
```

### Attribution Data Structure
```bash
# Pattern attribution format
declare -A pattern_attribution
pattern_attribution["*.o"]="source:multiple,category:build_artifacts,conflicts:none"
pattern_attribution[".vscode/"]="source:handheld-office+risc-v-university,category:ide_files,conflicts:none"
pattern_attribution["save_*.dat"]="source:adroit,category:project_specific,conflicts:none"
```

## Related Documents
- `009-discover-and-analyze-gitignore-files.md` - Provides input patterns
- `010-design-unification-strategy.md` - Provides processing strategy
- `012-generate-unified-gitignore.md` - Uses processed patterns
- `002-gitignore-unification-script.md` - Parent ticket

## Tools Required
- Advanced bash string processing
- Pattern matching and regular expressions
- Data structure manipulation (associative arrays)
- Conflict resolution algorithms

## Metadata
- **Priority**: High
- **Complexity**: High
- **Estimated Time**: 2-2.5 hours
- **Dependencies**: Issues 009, 010 (analysis and strategy)
- **Impact**: Core functionality of gitignore unification

## Success Criteria
- All discovered patterns processed and normalized
- Conflicts resolved according to designed strategy
- Patterns categorized and deduplicated effectively
- Attribution information preserved throughout processing
- Processing engine handles edge cases robustly
- Output ready for unified `.gitignore` generation
- Performance acceptable for 40+ input files