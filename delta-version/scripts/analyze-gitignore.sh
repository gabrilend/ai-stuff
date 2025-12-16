#!/bin/bash
# Gitignore discovery and analysis utility for Delta-Version repository management
# Systematically discovers, categorizes, and analyzes .gitignore patterns across the repository

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
ANALYSIS_OUTPUT_DIR="${DIR}/delta-version/assets"

# -- {{{ discover_gitignore_files
function discover_gitignore_files() {
    find "$DIR" -name ".gitignore" -type f
}
# }}}

# -- {{{ categorize_by_location
function categorize_by_location() {
    local files=("$@")
    
    echo "=== FILE CATEGORIZATION BY LOCATION ==="
    echo
    
    echo "MAIN PROJECT GITIGNORE FILES:"
    for file in "${files[@]}"; do
        # Check if file is in a main project directory (not in libs/, tools/, etc.)
        if [[ ! "$file" =~ /libs/ ]] && [[ ! "$file" =~ /tools/ ]] && [[ ! "$file" =~ /external/ ]] && [[ ! "$file" =~ /vendor/ ]]; then
            # Use project listing utility to check if parent directory is a project
            local parent_dir
            parent_dir=$(dirname "$file")
            if "$DIR/delta-version/scripts/list-projects.sh" --format abs-paths | grep -q "$parent_dir"; then
                echo "  $file"
            fi
        fi
    done
    echo
    
    echo "LIBRARY/DEPENDENCY GITIGNORE FILES:"
    for file in "${files[@]}"; do
        if [[ "$file" =~ /libs/ ]] || [[ "$file" =~ /external/ ]] || [[ "$file" =~ /vendor/ ]] || [[ "$file" =~ /node_modules/ ]]; then
            echo "  $file"
        fi
    done
    echo
    
    echo "TOOL/SDK GITIGNORE FILES:"
    for file in "${files[@]}"; do
        if [[ "$file" =~ /tools/ ]] || [[ "$file" =~ /sdk/ ]] || [[ "$file" =~ emsdk ]]; then
            echo "  $file"
        fi
    done
    echo
}
# }}}

# -- {{{ extract_patterns
function extract_patterns() {
    local gitignore_file="$1"
    
    # Extract non-comment, non-empty lines
    grep -v '^#' "$gitignore_file" | grep -v '^$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
# }}}

# -- {{{ classify_pattern
function classify_pattern() {
    local pattern="$1"
    
    # Build artifacts
    if [[ "$pattern" =~ \.(o|exe|so|dylib|a|lib|dll|obj)$ ]] || \
       [[ "$pattern" =~ ^(build|target|dist|out|bin)/?$ ]] || \
       [[ "$pattern" =~ \.build$ ]]; then
        echo "build_artifacts"
        return
    fi
    
    # IDE files
    if [[ "$pattern" =~ \.(swp|swo|tmp)$ ]] || \
       [[ "$pattern" =~ ^(\.(vscode|idea|vim)|\.#)/ ]] || \
       [[ "$pattern" =~ (Session\.vim|tags)$ ]]; then
        echo "ide_files"
        return
    fi
    
    # Language specific
    if [[ "$pattern" =~ ^(node_modules|__pycache__|\.pytest_cache)/?$ ]] || \
       [[ "$pattern" =~ \.(pyc|pyo|class|jar)$ ]] || \
       [[ "$pattern" =~ ^(vendor|Cargo\.lock|package-lock\.json)/?$ ]]; then
        echo "language_specific"
        return
    fi
    
    # OS specific
    if [[ "$pattern" =~ ^(\.DS_Store|Thumbs\.db|desktop\.ini)$ ]] || \
       [[ "$pattern" =~ \.tmp$ ]]; then
        echo "os_specific"
        return
    fi
    
    # Version control
    if [[ "$pattern" =~ ^\.git ]] || [[ "$pattern" =~ \.(orig|rej)$ ]]; then
        echo "version_control"
        return
    fi
    
    # Logs and temp files
    if [[ "$pattern" =~ \.(log|logs)/?$ ]] || \
       [[ "$pattern" =~ ^(tmp|temp|cache)/?$ ]]; then
        echo "logs_temp"
        return
    fi
    
    # Default to project specific
    echo "project_specific"
}
# }}}

# -- {{{ analyze_patterns
function analyze_patterns() {
    local files=("$@")
    
    declare -A pattern_categories
    declare -A pattern_counts
    declare -A pattern_files
    local total_patterns=0
    
    echo "=== PATTERN ANALYSIS ==="
    echo
    
    # Process each gitignore file
    for file in "${files[@]}"; do
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            
            local category
            category=$(classify_pattern "$pattern")
            
            # Count patterns by category
            pattern_categories["$category"]=$((${pattern_categories["$category"]} + 1))
            
            # Track pattern frequency
            pattern_counts["$pattern"]=$((${pattern_counts["$pattern"]} + 1))
            
            # Track which files contain each pattern
            if [[ -z "${pattern_files["$pattern"]}" ]]; then
                pattern_files["$pattern"]="$file"
            else
                pattern_files["$pattern"]+=" | $file"
            fi
            
            total_patterns=$((total_patterns + 1))
        done < <(extract_patterns "$file")
    done
    
    echo "TOTAL PATTERNS FOUND: $total_patterns"
    echo
    
    echo "PATTERN CATEGORIES:"
    for category in "${!pattern_categories[@]}"; do
        echo "  $category: ${pattern_categories[$category]} patterns"
    done
    echo
    
    echo "MOST COMMON PATTERNS:"
    for pattern in "${!pattern_counts[@]}"; do
        if [[ ${pattern_counts["$pattern"]} -gt 1 ]]; then
            echo "  '$pattern' appears in ${pattern_counts["$pattern"]} files"
        fi
    done | sort -k4 -nr | head -10
    echo
    
    echo "POTENTIAL CONFLICTS:"
    # Look for negation patterns that might conflict
    for pattern in "${!pattern_counts[@]}"; do
        local negated_pattern="${pattern#!}"
        local positive_pattern="!$pattern"
        
        if [[ "$pattern" != "$negated_pattern" ]] && [[ -n "${pattern_counts["$negated_pattern"]}" ]]; then
            echo "  CONFLICT: '$pattern' and '$negated_pattern' both present"
        fi
    done
    echo
}
# }}}

# -- {{{ generate_detailed_report
function generate_detailed_report() {
    local files=("$@")
    
    echo "=== DETAILED ANALYSIS REPORT ===" > "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    echo "Generated: $(date)" >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    echo >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    
    echo "DISCOVERED FILES (${#files[@]} total):" >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    for file in "${files[@]}"; do
        echo "  $file" >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    done
    echo >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    
    # Redirect analysis output to file
    {
        categorize_by_location "${files[@]}"
        analyze_patterns "${files[@]}"
    } >> "$ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
    
    echo "DETAILED REPORT SAVED: $ANALYSIS_OUTPUT_DIR/gitignore-analysis-report.txt"
}
# }}}

# -- {{{ generate_pattern_database
function generate_pattern_database() {
    local files=("$@")
    
    declare -A category_patterns
    
    # Collect patterns by category
    for file in "${files[@]}"; do
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            
            local category
            category=$(classify_pattern "$pattern")
            
            if [[ -z "${category_patterns["$category"]}" ]]; then
                category_patterns["$category"]="$pattern"
            else
                category_patterns["$category"]+=$'\n'"$pattern"
            fi
        done < <(extract_patterns "$file")
    done
    
    # Generate configuration file
    echo "# Gitignore Pattern Classification Database" > "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
    echo "# Generated: $(date)" >> "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
    echo >> "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
    
    for category in "${!category_patterns[@]}"; do
        echo "[$category]" >> "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
        echo "${category_patterns["$category"]}" | sort -u >> "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
        echo >> "$ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
    done
    
    echo "PATTERN DATABASE SAVED: $ANALYSIS_OUTPUT_DIR/pattern-classification.conf"
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Gitignore Analysis Utility ==="
    echo "1. Discover all .gitignore files"
    echo "2. Analyze patterns by category"
    echo "3. Generate detailed report"
    echo "4. Create pattern database"
    echo "5. Full analysis (all steps)"
    
    read -p "Select option [1-5]: " choice
    
    local files
    readarray -t files < <(discover_gitignore_files)
    
    case $choice in
        1) 
            echo "DISCOVERED GITIGNORE FILES:"
            printf '%s\n' "${files[@]}"
            ;;
        2) analyze_patterns "${files[@]}" ;;
        3) generate_detailed_report "${files[@]}" ;;
        4) generate_pattern_database "${files[@]}" ;;
        5) 
            categorize_by_location "${files[@]}"
            analyze_patterns "${files[@]}"
            generate_detailed_report "${files[@]}"
            generate_pattern_database "${files[@]}"
            ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: analyze-gitignore.sh [OPTIONS] [DIRECTORY]"
    echo
    echo "Options:"
    echo "  --discover       List all .gitignore files"
    echo "  --analyze        Analyze patterns by category"
    echo "  --report         Generate detailed analysis report"
    echo "  --database       Create pattern classification database"
    echo "  --full           Run complete analysis"
    echo "  -I, --interactive Interactive mode"
    echo "  --help           Show this help message"
    echo
    echo "Examples:"
    echo "  analyze-gitignore.sh --discover"
    echo "  analyze-gitignore.sh --full"
    echo "  analyze-gitignore.sh -I"
}
# }}}

# -- {{{ main
function main() {
    local mode="discover"
    local base_directory="$DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --discover)
                mode="discover"
                shift
                ;;
            --analyze)
                mode="analyze"
                shift
                ;;
            --report)
                mode="report"
                shift
                ;;
            --database)
                mode="database"
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
                if [[ -d "$1" ]]; then
                    base_directory="$1"
                    DIR="$1"
                else
                    echo "Error: Directory '$1' does not exist" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Create output directory if it doesn't exist
    mkdir -p "$ANALYSIS_OUTPUT_DIR"
    
    local files
    readarray -t files < <(discover_gitignore_files)
    
    case $mode in
        discover)
            echo "DISCOVERED ${#files[@]} GITIGNORE FILES:"
            printf '%s\n' "${files[@]}"
            ;;
        analyze)
            analyze_patterns "${files[@]}"
            ;;
        report)
            generate_detailed_report "${files[@]}"
            ;;
        database)
            generate_pattern_database "${files[@]}"
            ;;
        full)
            echo "Running complete gitignore analysis..."
            echo
            categorize_by_location "${files[@]}"
            analyze_patterns "${files[@]}"
            generate_detailed_report "${files[@]}"
            generate_pattern_database "${files[@]}"
            echo
            echo "Analysis complete. Check $ANALYSIS_OUTPUT_DIR/ for generated files."
            ;;
    esac
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi