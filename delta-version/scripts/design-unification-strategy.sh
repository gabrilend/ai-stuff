#!/bin/bash
# Gitignore unification strategy design utility for Delta-Version repository management
# Analyzes conflicts, designs resolution strategies, and prepares unification templates

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
STRATEGY_DIR="${DIR}/delta-version/assets"

# -- {{{ load_pattern_analysis
function load_pattern_analysis() {
    local analysis_file="$STRATEGY_DIR/pattern-classification.conf"
    
    if [[ ! -f "$analysis_file" ]]; then
        echo "Error: Pattern analysis file not found. Run analyze-gitignore.sh first." >&2
        exit 1
    fi
    
    echo "Loading pattern analysis from: $analysis_file"
}
# }}}

# -- {{{ identify_pattern_conflicts
function identify_pattern_conflicts() {
    echo "=== PATTERN CONFLICT ANALYSIS ==="
    echo
    
    local gitignore_files
    readarray -t gitignore_files < <(find "$DIR" -name ".gitignore" -type f)
    
    declare -A all_patterns
    declare -A pattern_sources
    local conflicts_found=0
    
    # Collect all patterns with their sources
    for file in "${gitignore_files[@]}"; do
        local project_name
        project_name=$(dirname "$file" | sed "s|$DIR/||" | cut -d'/' -f1)
        
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            [[ "$pattern" =~ ^#.*$ ]] && continue
            
            if [[ -n "${all_patterns["$pattern"]}" ]]; then
                all_patterns["$pattern"]=$((${all_patterns["$pattern"]} + 1))
                pattern_sources["$pattern"]+=" | $project_name"
            else
                all_patterns["$pattern"]=1
                pattern_sources["$pattern"]="$project_name"
            fi
        done < <(grep -v '^#' "$file" | grep -v '^$')
    done
    
    echo "POTENTIAL CONFLICTS:"
    
    # Look for negation conflicts
    for pattern in "${!all_patterns[@]}"; do
        # Check for negation patterns
        if [[ "$pattern" =~ ^! ]]; then
            local base_pattern="${pattern#!}"
            if [[ -n "${all_patterns["$base_pattern"]}" ]]; then
                echo "  CONFLICT: '$base_pattern' vs '$pattern'"
                echo "    Sources: ${pattern_sources["$base_pattern"]} | ${pattern_sources["$pattern"]}"
                conflicts_found=$((conflicts_found + 1))
            fi
        fi
        
        # Check for directory vs file conflicts
        if [[ "$pattern" =~ /$ ]]; then
            local file_pattern="${pattern%/}"
            if [[ -n "${all_patterns["$file_pattern"]}" ]]; then
                echo "  CONFLICT: '$file_pattern' vs '$pattern'"
                echo "    Sources: ${pattern_sources["$file_pattern"]} | ${pattern_sources["$pattern"]}"
                conflicts_found=$((conflicts_found + 1))
            fi
        fi
    done
    
    if [[ $conflicts_found -eq 0 ]]; then
        echo "  No direct pattern conflicts detected"
    fi
    
    echo
    echo "DUPLICATE PATTERNS:"
    for pattern in "${!all_patterns[@]}"; do
        if [[ ${all_patterns["$pattern"]} -gt 1 ]]; then
            echo "  '$pattern' appears ${all_patterns["$pattern"]} times in: ${pattern_sources["$pattern"]}"
        fi
    done | head -10
    
    echo
}
# }}}

# -- {{{ categorize_patterns_by_priority
function categorize_patterns_by_priority() {
    echo "=== PATTERN PRIORITY CATEGORIZATION ==="
    echo
    
    declare -A security_patterns
    declare -A critical_build_patterns
    declare -A universal_patterns
    declare -A project_patterns
    
    local classification_file="$STRATEGY_DIR/pattern-classification.conf"
    local current_category=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            current_category="${line#[}"
            current_category="${current_category%]}"
        elif [[ -n "$line" && ! "$line" =~ ^# ]]; then
            case "$current_category" in
                "build_artifacts")
                    critical_build_patterns["$line"]=1
                    ;;
                "ide_files"|"os_specific")
                    universal_patterns["$line"]=1
                    ;;
                "project_specific")
                    # Check if it's security-related
                    if [[ "$line" =~ \.(key|pem|p12|crt)$ ]] || \
                       [[ "$line" =~ (secret|password|credential|\.env) ]] || \
                       [[ "$line" =~ (\.ssh|\.aws|\.gpg) ]]; then
                        security_patterns["$line"]=1
                    else
                        project_patterns["$line"]=1
                    fi
                    ;;
            esac
        fi
    done < "$classification_file"
    
    echo "SECURITY PATTERNS (Highest Priority): ${#security_patterns[@]}"
    for pattern in "${!security_patterns[@]}"; do
        echo "  $pattern"
    done | head -5
    [[ ${#security_patterns[@]} -gt 5 ]] && echo "  ... and $((${#security_patterns[@]} - 5)) more"
    echo
    
    echo "CRITICAL BUILD PATTERNS: ${#critical_build_patterns[@]}"
    for pattern in "${!critical_build_patterns[@]}"; do
        echo "  $pattern"
    done | head -5
    [[ ${#critical_build_patterns[@]} -gt 5 ]] && echo "  ... and $((${#critical_build_patterns[@]} - 5)) more"
    echo
    
    echo "UNIVERSAL PATTERNS: ${#universal_patterns[@]}"
    for pattern in "${!universal_patterns[@]}"; do
        echo "  $pattern"
    done | head -5
    [[ ${#universal_patterns[@]} -gt 5 ]] && echo "  ... and $((${#universal_patterns[@]} - 5)) more"
    echo
    
    echo "PROJECT-SPECIFIC PATTERNS: ${#project_patterns[@]}"
    echo
}
# }}}

# -- {{{ design_unified_structure
function design_unified_structure() {
    echo "=== UNIFIED STRUCTURE DESIGN ==="
    echo
    
    cat > "$STRATEGY_DIR/unified-gitignore-template.txt" << 'EOF'
# =============================================================================
# UNIFIED .gitignore for AI Projects Repository
# Auto-generated by Delta-Version Unification System
# Generated: ${TIMESTAMP}
# Source Files: ${SOURCE_COUNT} .gitignore files (${MAIN_PROJECT_COUNT} main projects, ${DEPENDENCY_COUNT} dependencies)
# Total Patterns: ${TOTAL_PATTERNS} (after deduplication and conflict resolution)
# =============================================================================

# =============================================================================
# SECURITY PATTERNS (Highest Priority)
# Never ignore these patterns - they protect sensitive data
# =============================================================================
${SECURITY_PATTERNS}

# =============================================================================
# OPERATING SYSTEM FILES (Universal)
# Cross-platform OS-generated files that should always be ignored
# Sources: ${OS_SOURCE_COUNT} files | Patterns: ${OS_PATTERN_COUNT} unique
# =============================================================================
${OS_PATTERNS}

# =============================================================================
# IDE AND EDITOR FILES (Universal)
# Development environment artifacts and configuration files
# Sources: ${IDE_SOURCE_COUNT} files | Patterns: ${IDE_PATTERN_COUNT} unique
# =============================================================================
${IDE_PATTERNS}

# =============================================================================
# BUILD SYSTEM ARTIFACTS (Universal)
# Compiled code, build outputs, and intermediate files
# Sources: ${BUILD_SOURCE_COUNT} files | Patterns: ${BUILD_PATTERN_COUNT} unique
# =============================================================================
${BUILD_PATTERNS}

# =============================================================================
# LANGUAGE-SPECIFIC PATTERNS (Universal)
# Runtime artifacts and package manager generated files
# Sources: ${LANG_SOURCE_COUNT} files | Patterns: ${LANG_PATTERN_COUNT} unique
# =============================================================================
${LANGUAGE_PATTERNS}

# =============================================================================
# LOGS AND TEMPORARY FILES (Universal)
# Runtime logs, cache files, and temporary artifacts
# Sources: ${LOG_SOURCE_COUNT} files | Patterns: ${LOG_PATTERN_COUNT} unique
# =============================================================================
${LOG_PATTERNS}

# =============================================================================
# PROJECT-SPECIFIC PATTERNS
# Custom ignore patterns for individual projects in the repository
# =============================================================================

${PROJECT_SECTIONS}

# =============================================================================
# DEPENDENCY LIBRARY PATTERNS (Reference Only)
# External library patterns documented for troubleshooting
# Note: Most dependency patterns are not included in main ignore rules
# =============================================================================
${DEPENDENCY_PATTERNS}

# =============================================================================
# PATTERN CONFLICTS AND RESOLUTIONS
# Documentation of conflicts found and resolution strategies applied
# =============================================================================
${CONFLICT_RESOLUTIONS}

# =============================================================================
# End of unified .gitignore
# =============================================================================
EOF
    
    echo "Unified structure template created: $STRATEGY_DIR/unified-gitignore-template.txt"
    echo
}
# }}}

# -- {{{ generate_conflict_resolution_rules
function generate_conflict_resolution_rules() {
    echo "=== CONFLICT RESOLUTION RULES ==="
    echo
    
    cat > "$STRATEGY_DIR/conflict-resolution-rules.md" << 'EOF'
# Conflict Resolution Rules for Gitignore Unification

## Rule Hierarchy (Highest to Lowest Priority)

### 1. Security Patterns
- **Rule**: Never ignore security-sensitive files
- **Examples**: `*.key`, `*.pem`, `.env`, `secrets.json`
- **Resolution**: Always include, never override

### 2. Critical Build Artifacts
- **Rule**: Always ignore compiled/generated files
- **Examples**: `*.o`, `*.exe`, `target/`, `build/`
- **Resolution**: Include in universal section

### 3. Project-Specific Requirements
- **Rule**: Most restrictive pattern wins
- **Example**: If Project A needs `logs/` ignored but Project B needs `logs/important/` tracked
- **Resolution**: Use `logs/*` + `!logs/important/`

### 4. Universal Patterns
- **Rule**: Broad applicability patterns
- **Examples**: `.DS_Store`, `.vscode/`, `Thumbs.db`
- **Resolution**: Include in universal sections

### 5. Library Dependencies
- **Rule**: Lowest precedence, document only
- **Resolution**: Reference section only unless needed for main projects

## Specific Conflict Types

### Negation Conflicts
```
Pattern: *.log
Negation: !important.log
Resolution: Include both in order - negation overrides general rule
```

### Directory vs File Conflicts
```
File pattern: build
Directory pattern: build/
Resolution: Use directory pattern (build/) - more specific
```

### Scope Conflicts
```
Local: node_modules/
Recursive: **/node_modules/
Resolution: Use recursive pattern - covers all cases
```

### Specificity Conflicts
```
General: *.tmp
Specific: cache.tmp
Resolution: Keep general pattern only - specific is redundant
```

## Implementation Notes

- Apply rules in hierarchy order
- Document all resolution decisions
- Maintain attribution for troubleshooting
- Test resolved patterns against project files
EOF
    
    echo "Conflict resolution rules created: $STRATEGY_DIR/conflict-resolution-rules.md"
    echo
}
# }}}

# -- {{{ create_attribution_system
function create_attribution_system() {
    echo "=== ATTRIBUTION SYSTEM DESIGN ==="
    echo
    
    cat > "$STRATEGY_DIR/attribution-format.md" << 'EOF'
# Pattern Attribution System

## Attribution Format

### Standard Format
```gitignore
pattern_name           # Source: project-name (reason if applicable)
```

### Multiple Sources
```gitignore
pattern_name           # Universal (count sources)
```

### Conflict Resolution
```gitignore
pattern_name           # Resolution: explanation
!exception_pattern     # Conflict resolution for project-x
```

## Examples

### OS Patterns
```gitignore
.DS_Store              # Universal (macOS - 12 sources)
Thumbs.db              # Universal (Windows - 8 sources)
```

### Build Patterns
```gitignore
*.o                    # Universal (C compilation - 12 sources)
target/                # Source: handheld-office (Rust builds)
```

### Project Patterns
```gitignore
# Project: adroit (Character system)
save_*.dat             # Game save files
character_cache/       # Character data cache

# Project: console-demakes (Gameboy development)
*.gb                   # ROM files
tools/rgbds/           # Build tools
```

### Conflict Resolutions
```gitignore
*.log                  # Universal (multiple sources)
!debug.log             # Resolution: console-demakes needs debug logs
```

## Implementation Guidelines

1. Keep comments concise but informative
2. Group related patterns together
3. Use consistent formatting
4. Include rationale for non-obvious patterns
5. Document all conflict resolution decisions
EOF
    
    echo "Attribution system format created: $STRATEGY_DIR/attribution-format.md"
    echo
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Gitignore Unification Strategy Design ==="
    echo "1. Analyze pattern conflicts"
    echo "2. Categorize patterns by priority"
    echo "3. Design unified structure template"
    echo "4. Generate conflict resolution rules"
    echo "5. Create attribution system"
    echo "6. Run full strategy design"
    
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1) identify_pattern_conflicts ;;
        2) categorize_patterns_by_priority ;;
        3) design_unified_structure ;;
        4) generate_conflict_resolution_rules ;;
        5) create_attribution_system ;;
        6) 
            echo "Running complete strategy design..."
            echo
            identify_pattern_conflicts
            categorize_patterns_by_priority
            design_unified_structure
            generate_conflict_resolution_rules
            create_attribution_system
            echo "Strategy design complete. Check $STRATEGY_DIR/ for generated files."
            ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: design-unification-strategy.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --conflicts      Analyze pattern conflicts"
    echo "  --categorize     Categorize patterns by priority"
    echo "  --structure      Design unified structure template"
    echo "  --rules          Generate conflict resolution rules"
    echo "  --attribution    Create attribution system format"
    echo "  --full           Run complete strategy design"
    echo "  -I, --interactive Interactive mode"
    echo "  --help           Show this help message"
    echo
    echo "Examples:"
    echo "  design-unification-strategy.sh --conflicts"
    echo "  design-unification-strategy.sh --full"
    echo "  design-unification-strategy.sh -I"
}
# }}}

# -- {{{ main
function main() {
    local mode="conflicts"
    
    # Create strategy directory if it doesn't exist
    mkdir -p "$STRATEGY_DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --conflicts)
                mode="conflicts"
                shift
                ;;
            --categorize)
                mode="categorize"
                shift
                ;;
            --structure)
                mode="structure"
                shift
                ;;
            --rules)
                mode="rules"
                shift
                ;;
            --attribution)
                mode="attribution"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            -I|--interactive)
                run_interactive_mode
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    load_pattern_analysis
    
    case $mode in
        conflicts) identify_pattern_conflicts ;;
        categorize) categorize_patterns_by_priority ;;
        structure) design_unified_structure ;;
        rules) generate_conflict_resolution_rules ;;
        attribution) create_attribution_system ;;
        full)
            echo "Running complete unification strategy design..."
            echo
            identify_pattern_conflicts
            categorize_patterns_by_priority  
            design_unified_structure
            generate_conflict_resolution_rules
            create_attribution_system
            echo
            echo "Strategy design complete. Files generated in $STRATEGY_DIR/"
            ;;
    esac
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi