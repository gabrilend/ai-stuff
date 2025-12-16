#!/bin/bash
# Gitignore pattern processing engine for Delta-Version repository management
# Implements the unification strategy to process, resolve conflicts, and categorize patterns

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
ASSETS_DIR="${DIR}/delta-version/assets"

# Pattern processing data structures
declare -A all_patterns           # pattern -> count
declare -A pattern_sources        # pattern -> source_files
declare -A pattern_categories     # pattern -> category
declare -A pattern_attribution   # pattern -> attribution_info
declare -A conflict_resolutions   # pattern -> resolution_info

# -- {{{ parse_patterns
function parse_patterns() {
    local gitignore_file="$1"
    local source_name
    source_name=$(get_source_name "$gitignore_file")
    
    echo "Processing patterns from: $source_name"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Normalize whitespace
        local pattern
        pattern=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$pattern" ]] && continue
        
        # Store pattern with source tracking
        if [[ -n "${all_patterns["$pattern"]}" ]]; then
            all_patterns["$pattern"]=$((${all_patterns["$pattern"]} + 1))
            pattern_sources["$pattern"]+=" | $source_name"
        else
            all_patterns["$pattern"]=1
            pattern_sources["$pattern"]="$source_name"
        fi
        
    done < "$gitignore_file"
}
# }}}

# -- {{{ get_source_name
function get_source_name() {
    local file_path="$1"
    local relative_path
    relative_path=$(echo "$file_path" | sed "s|$DIR/||")
    
    # Determine source type and name
    if [[ "$relative_path" =~ ^libs/ ]] || [[ "$relative_path" =~ /libs/ ]]; then
        echo "lib:$(echo "$relative_path" | cut -d'/' -f1-2)"
    elif [[ "$relative_path" =~ /tools/ ]] || [[ "$relative_path" =~ emsdk ]]; then
        echo "tool:$(echo "$relative_path" | cut -d'/' -f1)"
    else
        # Main project
        echo "proj:$(echo "$relative_path" | cut -d'/' -f1)"
    fi
}
# }}}

# -- {{{ normalize_pattern
function normalize_pattern() {
    local pattern="$1"
    
    # Remove redundant path separators
    pattern=$(echo "$pattern" | sed 's|///*|/|g')
    
    # Standardize directory indicators
    if [[ "$pattern" =~ ^.*[^/]$ ]] && [[ -d "$DIR/$pattern" ]] 2>/dev/null; then
        pattern="$pattern/"
    fi
    
    # Handle Windows path separators
    pattern=$(echo "$pattern" | sed 's|\\|/|g')
    
    echo "$pattern"
}
# }}}

# -- {{{ classify_pattern_type
function classify_pattern_type() {
    local pattern="$1"
    
    # Security patterns (highest priority)
    if [[ "$pattern" =~ \.(key|pem|p12|pfx|crt)$ ]] || \
       [[ "$pattern" =~ (secret|password|credential|\.env) ]] || \
       [[ "$pattern" =~ (\.ssh|\.aws|\.gpg) ]]; then
        echo "security"
        return
    fi
    
    # Build artifacts
    if [[ "$pattern" =~ \.(o|obj|exe|dll|so|dylib|a|lib)$ ]] || \
       [[ "$pattern" =~ ^(build|target|dist|out|bin)/?$ ]] || \
       [[ "$pattern" =~ \.(build|compilation)$ ]]; then
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

# -- {{{ categorize_patterns
function categorize_patterns() {
    echo "=== CATEGORIZING PATTERNS ==="
    
    for pattern in "${!all_patterns[@]}"; do
        local normalized_pattern
        normalized_pattern=$(normalize_pattern "$pattern")
        
        local category
        category=$(classify_pattern_type "$normalized_pattern")
        
        pattern_categories["$pattern"]="$category"
    done
    
    # Report categorization results
    declare -A category_counts
    for category in "${pattern_categories[@]}"; do
        category_counts["$category"]=$((${category_counts["$category"]} + 1))
    done
    
    echo "CATEGORIZATION RESULTS:"
    for category in "${!category_counts[@]}"; do
        echo "  $category: ${category_counts[$category]} patterns"
    done
    echo
}
# }}}

# -- {{{ detect_and_resolve_conflicts
function detect_and_resolve_conflicts() {
    echo "=== DETECTING AND RESOLVING CONFLICTS ==="
    
    local conflicts_found=0
    
    for pattern in "${!all_patterns[@]}"; do
        # Check for negation conflicts
        if [[ "$pattern" =~ ^! ]]; then
            local base_pattern="${pattern#!}"
            if [[ -n "${all_patterns["$base_pattern"]}" ]]; then
                echo "CONFLICT: Negation conflict"
                echo "  Base: '$base_pattern' (${pattern_sources["$base_pattern"]})"
                echo "  Negation: '$pattern' (${pattern_sources["$pattern"]})"
                
                # Resolution: Keep both, negation takes precedence
                conflict_resolutions["$base_pattern"]="kept_with_negation"
                conflict_resolutions["$pattern"]="negation_override"
                echo "  Resolution: Keep both patterns, negation overrides base"
                conflicts_found=$((conflicts_found + 1))
                echo
            fi
        fi
        
        # Check for directory vs file conflicts
        if [[ "$pattern" =~ /$ ]]; then
            local file_pattern="${pattern%/}"
            if [[ -n "${all_patterns["$file_pattern"]}" ]]; then
                echo "CONFLICT: Directory vs file"
                echo "  File: '$file_pattern' (${pattern_sources["$file_pattern"]})"
                echo "  Directory: '$pattern' (${pattern_sources["$pattern"]})"
                
                # Resolution: Use directory pattern (more specific)
                conflict_resolutions["$file_pattern"]="superseded_by_directory"
                conflict_resolutions["$pattern"]="directory_preferred"
                echo "  Resolution: Use directory pattern (more specific)"
                conflicts_found=$((conflicts_found + 1))
                echo
            fi
        fi
        
        # Check for scope conflicts (local vs recursive)
        if [[ ! "$pattern" =~ \*\*/ ]]; then
            local recursive_pattern="**/$pattern"
            if [[ -n "${all_patterns["$recursive_pattern"]}" ]]; then
                echo "CONFLICT: Scope conflict"
                echo "  Local: '$pattern' (${pattern_sources["$pattern"]})"
                echo "  Recursive: '$recursive_pattern' (${pattern_sources["$recursive_pattern"]})"
                
                # Resolution: Use recursive pattern (broader coverage)
                conflict_resolutions["$pattern"]="superseded_by_recursive"
                conflict_resolutions["$recursive_pattern"]="recursive_preferred"
                echo "  Resolution: Use recursive pattern (broader coverage)"
                conflicts_found=$((conflicts_found + 1))
                echo
            fi
        fi
    done
    
    echo "CONFLICTS DETECTED: $conflicts_found"
    echo
}
# }}}

# -- {{{ deduplicate_patterns
function deduplicate_patterns() {
    echo "=== DEDUPLICATING PATTERNS ==="
    
    declare -A final_patterns
    local removed_count=0
    
    for pattern in "${!all_patterns[@]}"; do
        local resolution="${conflict_resolutions["$pattern"]}"
        
        # Skip patterns that were superseded in conflict resolution
        if [[ "$resolution" =~ (superseded|removed) ]]; then
            echo "REMOVED: '$pattern' - $resolution"
            removed_count=$((removed_count + 1))
            continue
        fi
        
        # Check for functional equivalence
        local equivalent_found=false
        for final_pattern in "${!final_patterns[@]}"; do
            if are_functionally_equivalent "$pattern" "$final_pattern"; then
                echo "DUPLICATE: '$pattern' equivalent to '$final_pattern'"
                # Merge source attribution
                pattern_sources["$final_pattern"]+=" | ${pattern_sources["$pattern"]}"
                equivalent_found=true
                removed_count=$((removed_count + 1))
                break
            fi
        done
        
        if [[ "$equivalent_found" == "false" ]]; then
            final_patterns["$pattern"]=1
        fi
    done
    
    echo "DEDUPLICATION RESULTS:"
    echo "  Original patterns: ${#all_patterns[@]}"
    echo "  Removed duplicates/conflicts: $removed_count"
    echo "  Final patterns: ${#final_patterns[@]}"
    echo
    
    # Update all_patterns to contain only final patterns
    all_patterns=()
    for pattern in "${!final_patterns[@]}"; do
        all_patterns["$pattern"]=1
    done
}
# }}}

# -- {{{ are_functionally_equivalent
function are_functionally_equivalent() {
    local pattern1="$1"
    local pattern2="$2"
    
    # Remove leading/trailing whitespace and normalize
    pattern1=$(echo "$pattern1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    pattern2=$(echo "$pattern2" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Exact match
    [[ "$pattern1" == "$pattern2" ]] && return 0
    
    # Directory vs no-directory equivalence
    if [[ "$pattern1/" == "$pattern2" ]] || [[ "$pattern1" == "$pattern2/" ]]; then
        return 0
    fi
    
    # Check if one is a redundant version of the other
    if [[ "$pattern1" == "*.$pattern2" ]] || [[ "$pattern2" == "*.$pattern1" ]]; then
        return 0
    fi
    
    return 1
}
# }}}

# -- {{{ generate_attribution_info
function generate_attribution_info() {
    echo "=== GENERATING ATTRIBUTION INFO ==="
    
    for pattern in "${!all_patterns[@]}"; do
        local sources="${pattern_sources["$pattern"]}"
        local category="${pattern_categories["$pattern"]}"
        local resolution="${conflict_resolutions["$pattern"]}"
        
        # Count unique sources
        local source_count
        source_count=$(echo "$sources" | tr '|' '\n' | sort -u | wc -l)
        
        # Generate attribution string
        local attribution=""
        if [[ $source_count -gt 3 ]]; then
            attribution="Universal ($source_count sources)"
        elif [[ $source_count -gt 1 ]]; then
            attribution="Multiple ($(echo "$sources" | sed 's/ | /, /g'))"
        else
            attribution="Source: $sources"
        fi
        
        # Add category and resolution info
        if [[ -n "$resolution" ]]; then
            attribution="$attribution | Resolution: $resolution"
        fi
        
        pattern_attribution["$pattern"]="$attribution | Category: $category"
    done
    
    echo "Attribution generated for ${#pattern_attribution[@]} patterns"
    echo
}
# }}}

# -- {{{ export_processed_patterns
function export_processed_patterns() {
    local output_file="$ASSETS_DIR/processed-patterns.json"
    
    echo "=== EXPORTING PROCESSED PATTERNS ==="
    
    {
        echo "{"
        echo "  \"metadata\": {"
        echo "    \"generated\": \"$(date)\","
        echo "    \"total_patterns\": ${#all_patterns[@]},"
        echo "    \"conflicts_resolved\": $(grep -c "Resolution:" <<< "${conflict_resolutions[*]}" || echo "0")"
        echo "  },"
        echo "  \"categories\": {"
        
        # Export by category
        local first_category=true
        for category in security build_artifacts ide_files language_specific os_specific version_control logs_temp project_specific; do
            [[ "$first_category" == "false" ]] && echo ","
            echo "    \"$category\": ["
            
            local first_pattern=true
            for pattern in "${!pattern_categories[@]}"; do
                if [[ "${pattern_categories["$pattern"]}" == "$category" ]]; then
                    [[ "$first_pattern" == "false" ]] && echo ","
                    echo "      {"
                    echo "        \"pattern\": \"$pattern\","
                    echo "        \"attribution\": \"${pattern_attribution["$pattern"]}\","
                    echo "        \"sources\": \"${pattern_sources["$pattern"]}\""
                    echo "      }"
                    first_pattern=false
                fi
            done
            
            echo "    ]"
            first_category=false
        done
        
        echo "  }"
        echo "}"
    } > "$output_file"
    
    echo "Processed patterns exported to: $output_file"
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Gitignore Pattern Processing Engine ==="
    echo "1. Process all patterns"
    echo "2. Show categorization results"
    echo "3. Show conflict resolution"
    echo "4. Show deduplication results"
    echo "5. Export processed patterns"
    echo "6. Run full processing pipeline"
    
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1) process_all_discovered_patterns ;;
        2) categorize_patterns ;;
        3) detect_and_resolve_conflicts ;;
        4) deduplicate_patterns ;;
        5) export_processed_patterns ;;
        6) run_full_pipeline ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ process_all_discovered_patterns
function process_all_discovered_patterns() {
    echo "=== PROCESSING ALL DISCOVERED PATTERNS ==="
    
    # Get list of gitignore files
    local gitignore_files
    readarray -t gitignore_files < <(find "$DIR" -name ".gitignore" -type f)
    
    echo "Processing ${#gitignore_files[@]} .gitignore files..."
    echo
    
    # Parse all patterns
    for file in "${gitignore_files[@]}"; do
        parse_patterns "$file"
    done
    
    echo
    echo "PARSING COMPLETE:"
    echo "  Total unique patterns discovered: ${#all_patterns[@]}"
    echo "  Files processed: ${#gitignore_files[@]}"
    echo
}
# }}}

# -- {{{ run_full_pipeline
function run_full_pipeline() {
    echo "=== RUNNING FULL PATTERN PROCESSING PIPELINE ==="
    echo
    
    # Stage 1: Parse all patterns
    process_all_discovered_patterns
    
    # Stage 2: Categorize patterns
    categorize_patterns
    
    # Stage 3: Detect and resolve conflicts
    detect_and_resolve_conflicts
    
    # Stage 4: Deduplicate patterns
    deduplicate_patterns
    
    # Stage 5: Generate attribution
    generate_attribution_info
    
    # Stage 6: Export results
    export_processed_patterns
    
    echo "=== PIPELINE COMPLETE ==="
    echo "Results available in: $ASSETS_DIR/processed-patterns.json"
    echo "Ready for unified .gitignore generation (Issue 012)"
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: process-gitignore-patterns.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --parse          Parse all discovered patterns"
    echo "  --categorize     Categorize patterns by type"
    echo "  --conflicts      Detect and resolve pattern conflicts"
    echo "  --deduplicate    Remove duplicate and redundant patterns"
    echo "  --export         Export processed patterns to JSON"
    echo "  --full           Run complete processing pipeline"
    echo "  -I, --interactive Interactive mode"
    echo "  --help           Show this help message"
    echo
    echo "Examples:"
    echo "  process-gitignore-patterns.sh --full"
    echo "  process-gitignore-patterns.sh --conflicts"
    echo "  process-gitignore-patterns.sh -I"
}
# }}}

# -- {{{ main
function main() {
    local mode="full"
    
    # Create assets directory if it doesn't exist
    mkdir -p "$ASSETS_DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parse)
                mode="parse"
                shift
                ;;
            --categorize)
                mode="categorize"
                shift
                ;;
            --conflicts)
                mode="conflicts"
                shift
                ;;
            --deduplicate)
                mode="deduplicate"
                shift
                ;;
            --export)
                mode="export"
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
    
    case $mode in
        parse) process_all_discovered_patterns ;;
        categorize) 
            process_all_discovered_patterns
            categorize_patterns
            ;;
        conflicts) 
            process_all_discovered_patterns
            categorize_patterns
            detect_and_resolve_conflicts
            ;;
        deduplicate)
            process_all_discovered_patterns
            categorize_patterns
            detect_and_resolve_conflicts
            deduplicate_patterns
            ;;
        export)
            process_all_discovered_patterns
            categorize_patterns
            detect_and_resolve_conflicts
            deduplicate_patterns
            generate_attribution_info
            export_processed_patterns
            ;;
        full) run_full_pipeline ;;
    esac
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi