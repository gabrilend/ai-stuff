# Issue 018: Create Project Discovery System

## Current Behavior

The keyword processing engine can process templates (Issue 017), but there is no system to automatically discover which projects should receive distributed tickets. Manual specification of target projects is required, and there's no intelligence about which projects are relevant for specific types of tickets.

## Intended Behavior

Create an intelligent project discovery system that:
1. **Automatic Detection**: Identify all project directories in the repository
2. **Project Classification**: Distinguish between main projects and library dependencies
3. **Filtering Capabilities**: Support inclusion/exclusion criteria for ticket distribution
4. **Relevance Scoring**: Determine which projects are relevant for specific ticket types
5. **Configuration Support**: Allow custom project discovery rules via configuration

## Suggested Implementation Steps

### 1. Project Directory Detection
```bash
# -- {{{ discover_project_directories
function discover_project_directories() {
    local base_dir="$1"
    
    # Look for directories with project indicators
    # - src/ directories
    # - Individual .gitignore files
    # - Documentation files (README.md, etc.)
    # - Issue tracking directories
    # - Configuration files (Cargo.toml, package.json, etc.)
}
# }}}
```

### 2. Project Classification Engine
```bash
# -- {{{ classify_project_type
function classify_project_type() {
    local project_dir="$1"
    
    # Analyze project contents to determine:
    # - Programming language(s) used
    # - Project maturity (file count, structure)
    # - Development activity (git history if available)
    # - Project type (game, library, tool, documentation)
}
# }}}
```

### 3. Library vs Project Distinction
```bash
# -- {{{ is_main_project
function is_main_project() {
    local dir_path="$1"
    
    # Exclude library dependencies:
    # - Directories in libs/ folders
    # - External SDK directories (emsdk, etc.)
    # - Tool dependencies (rgbds, etc.)
    # - Backup or archive directories
    # 
    # Include main projects:
    # - Top-level project directories
    # - Active development directories
    # - Directories with issue tracking
}
# }}}
```

### 4. Relevance Scoring System
```bash
# -- {{{ calculate_project_relevance
function calculate_project_relevance() {
    local project_dir="$1"
    local ticket_type="$2"
    
    # Score factors:
    # - Language compatibility (for code style changes)
    # - Dependency usage (for library updates)
    # - Project activity level
    # - File structure similarity
    # - Explicit inclusion in ticket metadata
}
# }}}
```

### 5. Filtering and Selection Framework
```bash
# -- {{{ filter_projects
function filter_projects() {
    local discovered_projects="$1"
    local filter_criteria="$2"
    
    # Apply filters:
    # - Minimum relevance score
    # - Language type (lua, rust, c, etc.)
    # - Project size (file count thresholds)
    # - Activity level (recent modifications)
    # - Explicit include/exclude lists
}
# }}}
```

### 6. Configuration-Based Discovery
```bash
# -- {{{ load_discovery_config
function load_discovery_config() {
    local config_file="$1"
    
    # Load configuration for:
    # - Project indicator patterns
    # - Exclusion rules for libraries
    # - Relevance scoring weights
    # - Filter defaults
    # - Custom project classifications
}
# }}}
```

## Implementation Details

### Project Detection Patterns
```bash
# Project indicators (in order of priority)
PROJECT_INDICATORS=(
    "issues/phase-*"          # Issue tracking = main project
    "src/ AND docs/"          # Source + docs = main project  
    "Cargo.toml"              # Rust project
    "package.json"            # Node.js project
    "Makefile"                # Build system present
    ".gitignore"              # Individual git management
    "README.md"               # Documentation present
)

# Library exclusion patterns
LIBRARY_PATTERNS=(
    "*/libs/*"                # Library dependencies
    "*/tools/*"               # Development tools
    "*/backup*"               # Backup directories
    "*emsdk*"                 # External SDKs
    "*rgbds*"                 # Tool dependencies
    "*/node_modules/*"        # Package dependencies
)
```

### Project Classification Logic
```bash
# -- {{{ classify_project_language
function classify_project_language() {
    local project_dir="$1"
    
    declare -A lang_scores
    
    # Count files by extension
    lang_scores["lua"]=$(find "$project_dir" -name "*.lua" 2>/dev/null | wc -l)
    lang_scores["rust"]=$(find "$project_dir" -name "*.rs" 2>/dev/null | wc -l)
    lang_scores["c"]=$(find "$project_dir" -name "*.c" -o -name "*.h" 2>/dev/null | wc -l)
    lang_scores["js"]=$(find "$project_dir" -name "*.js" 2>/dev/null | wc -l)
    
    # Find dominant language
    local max_lang="unknown"
    local max_score=0
    
    for lang in "${!lang_scores[@]}"; do
        if [[ ${lang_scores[$lang]} -gt $max_score ]]; then
            max_score=${lang_scores[$lang]}
            max_lang="$lang"
        fi
    done
    
    echo "$max_lang"
}
# }}}
```

### Relevance Scoring Algorithm
```bash
# -- {{{ score_project_relevance
function score_project_relevance() {
    local project_dir="$1"
    local ticket_type="$2"
    
    local score=0
    
    # Base score for being a main project
    if is_main_project "$project_dir"; then
        score=$((score + 50))
    fi
    
    # Language relevance (for code style tickets)
    if [[ "$ticket_type" == "code_style" ]]; then
        local lang=$(classify_project_language "$project_dir")
        case "$TICKET_LANGUAGE" in
            "$lang") score=$((score + 30)) ;;
            "all") score=$((score + 20)) ;;
        esac
    fi
    
    # Activity level (recent modifications)
    local recent_files
    recent_files=$(find "$project_dir" -type f -mtime -30 2>/dev/null | wc -l)
    if [[ $recent_files -gt 0 ]]; then
        score=$((score + 10))
    fi
    
    # Project size (more files = more established)
    local file_count
    file_count=$(find "$project_dir" -type f 2>/dev/null | wc -l)
    if [[ $file_count -gt 10 ]]; then
        score=$((score + 15))
    fi
    
    echo "$score"
}
# }}}
```

### Discovery Configuration
```ini
# project-discovery.conf
[detection]
min_files=5
require_src_dir=false
require_readme=false

[exclusions]
library_patterns=*/libs/*,*/tools/*,*emsdk*,*rgbds*
backup_patterns=*/backup*,*/old*,*/.git
temp_patterns=*/tmp/*,*/temp/*

[relevance]
min_score=25
language_weight=30
activity_weight=10
size_weight=15

[ticket_types]
dependency_update=language,dependencies
code_style=language,file_count
organization=all_projects
build_system=build_files
```

### Project Discovery Report
```bash
# -- {{{ generate_discovery_report
function generate_discovery_report() {
    local discovered_projects="$1"
    
    cat <<EOF
PROJECT DISCOVERY REPORT
========================
Total directories scanned: $total_dirs
Main projects found: $main_project_count
Library dependencies excluded: $library_count

DISCOVERED PROJECTS:
$(echo "$discovered_projects" | while read -r project; do
    local score=$(score_project_relevance "$project" "general")
    local lang=$(classify_project_language "$project")
    printf "%-30s | Score: %3d | Language: %s\n" "$project" "$score" "$lang"
done)

EXCLUSIONS:
$(echo "$excluded_dirs" | head -5)
... and $((excluded_count - 5)) more
EOF
}
# }}}
```

## Related Documents
- `017-implement-keyword-processing-engine.md` - Used by discovery system
- `019-implement-ticket-distribution-engine.md` - Uses discovered projects
- `003-dynamic-ticket-distribution-system.md` - Parent ticket

## Tools Required
- File system traversal and analysis
- Pattern matching for project detection
- Configuration file processing
- Scoring and ranking algorithms
- Report generation utilities

## Metadata
- **Priority**: High
- **Complexity**: Medium-High
- **Estimated Time**: 1.5-2 hours
- **Dependencies**: Issue 017 (keyword processing engine)
- **Impact**: Automation and intelligence of ticket distribution

## Success Criteria
- Accurately identifies main projects vs library dependencies
- Project classification works for multiple languages
- Relevance scoring provides meaningful ranking
- Filtering supports various ticket distribution scenarios
- Configuration allows customization of discovery rules
- Discovery report provides clear project overview
- System handles edge cases (empty dirs, symlinks, etc.)
- Performance acceptable for large directory structures