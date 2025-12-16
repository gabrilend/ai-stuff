# Issue 012: Generate Unified Gitignore

## Current Behavior

The pattern processing engine (Issue 011) has processed all discovered `.gitignore` patterns and resolved conflicts, but there is no system to generate the actual unified `.gitignore` file. The processed data needs to be formatted and written to create the final repository-level ignore file.

## Intended Behavior

Create the unified `.gitignore` file generation system that:
1. **Template Application**: Apply processed patterns to the designed template structure
2. **Formatted Output**: Generate well-organized, readable `.gitignore` file
3. **Documentation Integration**: Include comments, attribution, and explanations
4. **Backup Management**: Safely handle existing `.gitignore` files
5. **Validation**: Ensure generated file is syntactically correct and functional

## Suggested Implementation Steps

### 1. Template Rendering Engine
```bash
# -- {{{ render_gitignore_template
function render_gitignore_template() {
    local processed_patterns="$1"
    local output_file="$2"
    
    write_file_header
    write_universal_section
    write_build_artifacts_section
    write_language_sections
    write_project_sections
    write_maintenance_footer
}
# }}}
```

### 2. Section Generation Functions
```bash
# -- {{{ write_universal_section
function write_universal_section() {
    echo "# ============================================================================="
    echo "# OS and IDE Files (Universal)"
    echo "# ============================================================================="
    
    # Process patterns categorized as universal
    # Add attribution comments
    # Ensure proper formatting
}
# }}}
```

### 3. Attribution Comment Generation
```bash
# -- {{{ generate_attribution_comment
function generate_attribution_comment() {
    local pattern="$1"
    local sources="$2"
    
    if [[ $(echo "$sources" | wc -w) -gt 1 ]]; then
        echo "# Used by: $(echo "$sources" | tr ' ' ', ')"
    else
        echo "# From: $sources"
    fi
}
# }}}
```

### 4. Backup and Safety Management
```bash
# -- {{{ backup_existing_gitignore
function backup_existing_gitignore() {
    local gitignore_path="$1"
    
    if [[ -f "$gitignore_path" ]]; then
        local backup_path="${gitignore_path}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$gitignore_path" "$backup_path"
        echo "Existing .gitignore backed up to: $backup_path"
    fi
}
# }}}
```

### 5. File Validation
```bash
# -- {{{ validate_gitignore
function validate_gitignore() {
    local gitignore_file="$1"
    
    # Check for syntax errors
    # Verify patterns are properly formatted
    # Test against sample files
    # Ensure no critical files are ignored
}
# }}}
```

### 6. Generation Report
```bash
# -- {{{ generate_report
function generate_report() {
    local output_file="$1"
    local pattern_count="$2"
    
    echo "UNIFIED .gitignore GENERATION REPORT"
    echo "===================================="
    echo "Output file: $output_file"
    echo "Total patterns: $pattern_count"
    echo "Conflicts resolved: $conflicts_resolved"
    echo "Sources processed: $source_count"
}
# }}}
```

## Implementation Details

### File Structure Template
```gitignore
# =============================================================================
# UNIFIED .gitignore 
# Auto-generated from project-specific .gitignore files
# Generation Date: $(date)
# Source Projects: adroit, progress-ii, risc-v-university, magic-rumble, handheld-office
# =============================================================================

# =============================================================================
# Operating System Files
# =============================================================================
.DS_Store              # macOS (multiple projects)
Thumbs.db              # Windows (multiple projects) 
*.tmp                  # Temporary files (universal)

# =============================================================================  
# IDE and Editor Files
# =============================================================================
.vscode/               # VS Code (handheld-office, risc-v-university)
.idea/                 # IntelliJ (detected in multiple projects)
*.swp                  # Vim swap files (universal)

# =============================================================================
# Build Artifacts and Dependencies  
# =============================================================================
*.o                    # C object files (multiple projects)
*.exe                  # Windows executables (multiple projects)
target/                # Rust build directory (handheld-office)
build/                 # Generic build directory (multiple projects)

# =============================================================================
# Project-Specific Patterns
# =============================================================================

# adroit/ - Character system project
save_*.dat             # Game save files
character_cache/       # Character data cache

# progress-ii/ - Terminal game
game_state.json        # Runtime game state
player_data/           # Player data directory

# [Additional project sections...]

# =============================================================================
# Maintenance Information
# =============================================================================
# This file was auto-generated by the gitignore unification script
# To update: run scripts/generate-unified-gitignore.sh
# Manual edits may be overwritten during regeneration
# Last updated: $(date)
```

### Pattern Formatting Functions
```bash
# -- {{{ format_pattern_line
function format_pattern_line() {
    local pattern="$1"
    local comment="$2"
    local width=20
    
    printf "%-${width}s # %s\n" "$pattern" "$comment"
}
# }}}
```

### Integration with Processing Pipeline
```bash
# -- {{{ main_generation_flow
function main_generation_flow() {
    local processed_patterns="$1"
    local output_path="${2:-/home/ritz/programming/ai-stuff/.gitignore}"
    
    # Safety backup
    backup_existing_gitignore "$output_path"
    
    # Generate new file
    render_gitignore_template "$processed_patterns" "$output_path"
    
    # Validate result
    validate_gitignore "$output_path"
    
    # Generate report
    generate_report "$output_path" "$pattern_count"
}
# }}}
```

## Related Documents
- `011-implement-pattern-processing.md` - Provides processed pattern data
- `013-implement-validation-and-testing.md` - Tests generated file
- `002-gitignore-unification-script.md` - Parent ticket

## Tools Required
- File I/O and template processing
- Text formatting and alignment
- Backup file management
- Git integration for validation

## Metadata
- **Priority**: High
- **Complexity**: Medium
- **Estimated Time**: 1-1.5 hours
- **Dependencies**: Issue 011 (pattern processing)
- **Impact**: Final deliverable of gitignore unification

## Success Criteria
- Unified `.gitignore` file generated successfully
- Well-organized structure with clear sections
- Attribution comments provide pattern source information
- Existing `.gitignore` safely backed up before replacement
- Generated file passes validation tests
- Generation report documents process and results
- File ready for integration with git repository setup