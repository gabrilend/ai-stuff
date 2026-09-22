# Issue 023: Create Project Listing Utility

## Current Behavior

There is no standardized way to get a list of project names or paths from the repository. Different scripts and systems need to discover projects manually using ad-hoc methods, leading to inconsistent results and duplication of discovery logic across various tools.

### Current Issues
- No central utility for project discovery and listing
- Inconsistent project identification across different scripts
- No standardized way to exclude non-project directories (like `issues/`, `scripts/`, etc.)
- No flexible output format for different use cases
- No way to get inverse listings (non-project directories)

## Intended Behavior

Create a comprehensive project listing utility that:
1. **Project Discovery**: Systematically identify actual project directories
2. **Exclusion Management**: Maintain a clear list of non-project directories to exclude
3. **Flexible Output**: Support multiple output formats (names only, absolute paths, relative paths)
4. **Inverse Listing**: Option to list non-project directories instead
5. **Integration Ready**: Designed for use by other scripts and systems

## Suggested Implementation Steps

### 1. Create Non-Project Exclusion Configuration
```bash
# -- {{{ define_non_project_directories
function define_non_project_directories() {
    # Directories that are part of repository but NOT projects:
    # - Repository management: issues/, scripts/, docs/
    # - Build artifacts: build/, target/, dist/
    # - Library dependencies: libs/, node_modules/
    # - Tool directories: tools/, .git/, .claude/
    # - Backup/archive: backup/, old/, archive/
}
# }}}
```

### 2. Project Identification Logic
```bash
# -- {{{ identify_project_directories
function identify_project_directories() {
    local base_dir="$1"
    
    # Project indicators (in priority order):
    # - Has src/ directory
    # - Has individual issue tracking (issues/phase-*)
    # - Has project-specific configuration (Cargo.toml, package.json, Makefile)
    # - Has dedicated documentation (README.md in project root)
    # - Has project-specific .gitignore
}
# }}}
```

### 3. Flexible Output Format System
```bash
# -- {{{ format_project_output
function format_project_output() {
    local projects="$1"
    local format="$2"
    
    case "$format" in
        "names") output_project_names ;;
        "abs-paths") output_absolute_paths ;;
        "rel-paths") output_relative_paths ;;
        "json") output_json_format ;;
        "csv") output_csv_format ;;
        "lines") output_line_separated ;;
    esac
}
# }}}
```

### 4. Command Line Interface Design
```bash
#!/bin/bash
# scripts/list-projects.sh
DIR="${1:-/home/ritz/programming/ai-stuff}"

# Usage:
# list-projects.sh [OPTIONS] [DIRECTORY]
# 
# Options:
#   --names          Return project names only (default)
#   --abs-paths      Return absolute paths
#   --rel-paths      Return relative paths
#   --inverse        Return non-project directories instead
#   --format FORMAT  Output format: names|abs-paths|rel-paths|json|csv|lines
#   --include-libs   Include library directories (normally excluded)
#   --help           Show help message
```

### 5. Integration with Other Scripts
```bash
# -- {{{ get_projects_for_script
function get_projects_for_script() {
    local calling_script="$1"
    local output_format="$2"
    
    # Provide standardized project listing for:
    # - Git branching system (Issue 005)
    # - Ticket distribution system (Issue 018)
    # - Repository management scripts
    # - Maintenance utilities
}
# }}}
```

### 6. Validation and Testing
```bash
# -- {{{ validate_project_listing
function validate_project_listing() {
    # Verify all detected projects are actual projects
    # Check that no real projects are excluded
    # Validate exclusion list accuracy
    # Test different output formats
}
# }}}
```

## Implementation Details

### Non-Project Directory Configuration
```ini
# config/non-project-directories.conf
[repository_management]
directories=issues,scripts,docs,.git,.claude,llm-transcripts

[build_artifacts]
directories=build,target,dist,out,bin

[dependencies]
directories=libs,node_modules,vendor,external

[tools_and_utilities]
directories=tools,utils,scripts/lib,scripts/config

[backup_and_archive]
directories=backup,backups,old,archive,tmp,temp

[documentation]
directories=docs,documentation,guides

[special_cases]
# Project-specific exclusions that don't fit other categories
directories=.operations,.canaries,.storage_*
```

### Project Detection Algorithm
```bash
# -- {{{ detect_project_characteristics
function detect_project_characteristics() {
    local dir_path="$1"
    local score=0
    
    # Strong project indicators (+high score)
    [[ -d "$dir_path/src" ]] && score=$((score + 50))
    [[ -d "$dir_path/issues" ]] && score=$((score + 40))
    [[ -f "$dir_path/Cargo.toml" ]] && score=$((score + 30))
    [[ -f "$dir_path/package.json" ]] && score=$((score + 30))
    [[ -f "$dir_path/Makefile" ]] && score=$((score + 25))
    
    # Moderate project indicators (+medium score)
    [[ -f "$dir_path/.gitignore" ]] && score=$((score + 20))
    [[ -f "$dir_path/README.md" ]] && score=$((score + 15))
    [[ -d "$dir_path/docs" ]] && score=$((score + 10))
    
    # Project threshold
    [[ $score -ge 50 ]] && return 0 || return 1
}
# }}}
```

### Output Format Implementations
```bash
# -- {{{ output_project_names
function output_project_names() {
    local projects=("$@")
    for project in "${projects[@]}"; do
        basename "$project"
    done
}
# }}}

# -- {{{ output_absolute_paths
function output_absolute_paths() {
    local projects=("$@")
    for project in "${projects[@]}"; do
        realpath "$project"
    done
}
# }}}

# -- {{{ output_json_format
function output_json_format() {
    local projects=("$@")
    echo "{"
    echo "  \"projects\": ["
    local first=true
    for project in "${projects[@]}"; do
        [[ "$first" == "false" ]] && echo ","
        echo -n "    {\"name\": \"$(basename "$project")\", \"path\": \"$(realpath "$project")\"}"
        first=false
    done
    echo ""
    echo "  ]"
    echo "}"
}
# }}}
```

### Integration Interface
```bash
# -- {{{ get_project_list_for_integration
function get_project_list_for_integration() {
    local format="${1:-names}"
    local base_dir="${2:-$DIR}"
    
    # Discover all projects
    local discovered_projects=()
    while IFS= read -r -d '' dir; do
        if is_project_directory "$dir" && ! is_excluded_directory "$dir"; then
            discovered_projects+=("$dir")
        fi
    done < <(find "$base_dir" -maxdepth 1 -type d -print0)
    
    # Format output as requested
    format_project_output "${discovered_projects[@]}" "$format"
}
# }}}

# -- {{{ is_excluded_directory
function is_excluded_directory() {
    local dir_path="$1"
    local dir_name
    dir_name=$(basename "$dir_path")
    
    # Check against exclusion configuration
    local excluded_patterns=(
        "issues" "scripts" "docs" ".git" ".claude" "llm-transcripts"
        "build" "target" "dist" "out" "bin"
        "libs" "node_modules" "vendor" "external"
        "tools" "utils" "backup" "backups" "old" "archive" "tmp" "temp"
    )
    
    for pattern in "${excluded_patterns[@]}"; do
        [[ "$dir_name" == $pattern ]] && return 0
        [[ "$dir_name" == .storage_* ]] && return 0
        [[ "$dir_name" == .*_operations* ]] && return 0
    done
    
    return 1
}
# }}}
```

### Command Line Interface
```bash
# -- {{{ main
function main() {
    local output_format="names"
    local base_directory="$DIR"
    local inverse_mode=false
    local include_libs=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --names)
                output_format="names"
                shift
                ;;
            --abs-paths)
                output_format="abs-paths"
                shift
                ;;
            --rel-paths)
                output_format="rel-paths"
                shift
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            --inverse)
                inverse_mode=true
                shift
                ;;
            --include-libs)
                include_libs=true
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
                base_directory="$1"
                shift
                ;;
        esac
    done
    
    if [[ "$inverse_mode" == "true" ]]; then
        get_non_project_directories "$output_format" "$base_directory"
    else
        get_project_list_for_integration "$output_format" "$base_directory"
    fi
}
# }}}
```

### Interactive Mode
```bash
# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Project Listing Utility ==="
    echo "1. List project names"
    echo "2. List project absolute paths"
    echo "3. List non-project directories"
    echo "4. Export project list (JSON)"
    echo "5. Validate project detection"
    echo "6. Configure exclusions"
    
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1) get_project_list_for_integration "names" ;;
        2) get_project_list_for_integration "abs-paths" ;;
        3) get_non_project_directories "names" ;;
        4) get_project_list_for_integration "json" ;;
        5) validate_project_detection ;;
        6) configure_exclusions_interactive ;;
    esac
}
# }}}
```

## Related Documents
- `005-configure-branch-isolation.md` - Uses project listing for branch management
- `018-create-project-discovery-system.md` - Shares project detection logic
- Repository management scripts across the system

## Tools Required
- Directory traversal and analysis
- Configuration file management
- Multiple output format generation
- Interactive interface implementation
- Validation and testing utilities

## Metadata
- **Priority**: Medium-High
- **Complexity**: Medium
- **Estimated Time**: 1.5-2 hours
- **Dependencies**: None (foundational utility)
- **Impact**: Standardization, integration support, consistency

## Success Criteria
- Accurate identification of project vs non-project directories
- Flexible output formats support different integration needs
- Exclusion configuration prevents false positives
- Inverse mode correctly identifies non-project directories
- Integration interface supports other scripts and systems
- Interactive mode provides user-friendly project management
- Command line interface follows CLAUDE.md conventions
- Utility ready for integration across repository management systems