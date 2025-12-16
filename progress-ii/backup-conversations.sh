#!/bin/bash
# backup-conversations.sh - Convert claude conversation logs to colorful markdown

# Hard-coded directory path (can be overridden by argument)
DIR="/mnt/mtwo/programming/ai-stuff/progress-ii"

# Color definitions for terminal output
declare -A COLORS=(
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[1;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["WHITE"]='\033[1;37m'
    ["BOLD"]='\033[1m'
    ["DIM"]='\033[2m'
    ["ITALIC"]='\033[3m'
    ["UNDERLINE"]='\033[4m'
    ["RESET"]='\033[0m'
)

# {{{ show_usage
show_usage() {
    echo "Usage: $0 [project_dir] [options]"
    echo ""
    echo "Options:"
    echo "  -i, --input FILE       Input conversation file/directory"
    echo "  -o, --output FILE      Output markdown file"
    echo "  -t, --text             Generate plain text version"
    echo "  -p, --print            Print to terminal with colors"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/project -i conversation.log -o backup.md"
    echo "  $0 -i conversation.log -p"
    echo "  $0 -i conversation.log -o backup.md -t"
}
# }}}

# {{{ parse_arguments
parse_arguments() {
    INPUT_FILE=""
    OUTPUT_FILE=""
    GENERATE_TEXT=false
    PRINT_TERMINAL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -t|--text)
                GENERATE_TEXT=true
                shift
                ;;
            -p|--print)
                PRINT_TERMINAL=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$INPUT_FILE" ]]; then
        echo "Error: Input file required (-i/--input)"
        show_usage
        exit 1
    fi
}
# }}}

# {{{ colorize_text
colorize_text() {
    local text="$1"
    local color="$2"
    echo -e "${COLORS[$color]}${text}${COLORS[RESET]}"
}
# }}}

# {{{ extract_file_references
extract_file_references() {
    local conversation_file="$1"
    local output_array_name="$2"
    local -n file_array=$output_array_name
    
    # Extract file paths from conversation logs
    # Look for common patterns like "file_path:line_number" or file operations
    while IFS= read -r line; do
        # Match file paths with extensions
        if [[ $line =~ [[:space:]]([^[:space:]]+\.[a-zA-Z]{1,4})(:[0-9]+)? ]]; then
            local filepath="${BASH_REMATCH[1]}"
            if [[ -f "$DIR/$filepath" || -f "$filepath" ]]; then
                file_array["$filepath"]=1
            fi
        fi
        
        # Match absolute paths
        if [[ $line =~ /[^[:space:]]+\.[a-zA-Z]{1,4} ]]; then
            local filepath="${BASH_REMATCH[0]}"
            if [[ -f "$filepath" ]]; then
                file_array["$filepath"]=1
            fi
        fi
    done < "$conversation_file"
}
# }}}

# {{{ generate_markdown_header
generate_markdown_header() {
    local conversation_file="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local file_count="$2"
    
    cat << EOF
# 🤖 Claude Conversation Backup

**Generated:** $timestamp  
**Source:** $conversation_file  
**Referenced Files:** $file_count  
**Project:** $(basename "$DIR")

---

## 📝 Conversation Flow

EOF
}
# }}}

# {{{ generate_file_contents_section
generate_file_contents_section() {
    local -n file_contents_refs=$1
    
    echo ""
    echo "## 📁 Referenced File Contents"
    echo ""
    
    for filepath in "${!file_contents_refs[@]}"; do
        local full_path
        if [[ -f "$DIR/$filepath" ]]; then
            full_path="$DIR/$filepath"
        elif [[ -f "$filepath" ]]; then
            full_path="$filepath"
        else
            continue
        fi
        
        echo "### 📄 \`$filepath\`"
        echo ""
        echo "\`\`\`$(get_file_language "$filepath")"
        cat "$full_path"
        echo ""
        echo "\`\`\`"
        echo ""
    done
}
# }}}

# {{{ get_file_language
get_file_language() {
    local filepath="$1"
    local extension="${filepath##*.}"
    
    case "$extension" in
        "sh"|"bash") echo "bash" ;;
        "py") echo "python" ;;
        "js") echo "javascript" ;;
        "ts") echo "typescript" ;;
        "md") echo "markdown" ;;
        "json") echo "json" ;;
        "yaml"|"yml") echo "yaml" ;;
        "toml") echo "toml" ;;
        "txt") echo "text" ;;
        *) echo "text" ;;
    esac
}
# }}}

# {{{ process_conversation_content
process_conversation_content() {
    local conversation_file="$1"
    local is_color_output="$2"
    
    local in_code_block=false
    local code_language=""
    
    while IFS= read -r line; do
        # Detect code blocks
        if [[ $line =~ ^\`\`\`([a-zA-Z]*) ]]; then
            in_code_block=true
            code_language="${BASH_REMATCH[1]}"
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "CYAN"
            else
                echo "$line"
            fi
            continue
        elif [[ $line =~ ^\`\`\`$ ]]; then
            in_code_block=false
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "CYAN"
            else
                echo "$line"
            fi
            continue
        fi
        
        # Handle different content types
        if [[ "$in_code_block" == "true" ]]; then
            # Code content
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "GREEN"
            else
                echo "$line"
            fi
        elif [[ $line =~ ^#+[[:space:]] ]]; then
            # Headers
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "YELLOW"
            else
                echo "$line"
            fi
        elif [[ $line =~ ^\*\*.*\*\*$ ]]; then
            # Bold text
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "BOLD"
            else
                echo "$line"
            fi
        elif [[ $line =~ ^[[:space:]]*-[[:space:]] ]]; then
            # List items
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "BLUE"
            else
                echo "$line"
            fi
        else
            # Regular text
            if [[ "$is_color_output" == "true" ]]; then
                colorize_text "$line" "WHITE"
            else
                echo "$line"
            fi
        fi
    done < "$conversation_file"
}
# }}}

# {{{ generate_backup_markdown
generate_backup_markdown() {
    local conversation_file="$1"
    local output_file="$2"
    local generate_plain_text="$3"
    
    # Find referenced files
    declare -A file_refs
    extract_file_references "$conversation_file" "file_refs"
    local file_count=${#file_refs[@]}
    
    # Generate markdown content
    {
        if [[ "$generate_plain_text" == "false" ]]; then
            generate_markdown_header "$conversation_file" "$file_count"
            process_conversation_content "$conversation_file" "false"
            generate_file_contents_section file_refs
        else
            # Plain text version
            echo "CLAUDE CONVERSATION BACKUP"
            echo "========================="
            echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Source: $conversation_file"
            echo "Referenced Files: $file_count"
            echo "Project: $(basename "$DIR")"
            echo ""
            echo "CONVERSATION CONTENT"
            echo "==================="
            process_conversation_content "$conversation_file" "false"
            echo ""
            echo "REFERENCED FILES"
            echo "================"
            generate_file_contents_section file_refs
        fi
    } > "$output_file"
    
    echo "Generated backup: $output_file"
}
# }}}

# {{{ print_to_terminal
print_to_terminal() {
    local conversation_file="$1"
    
    # Find referenced files for count
    declare -A file_refs
    extract_file_references "$conversation_file" "file_refs"
    local file_count=${#file_refs[@]}
    
    # Print colorful header
    echo ""
    colorize_text "🤖 CLAUDE CONVERSATION BACKUP" "BOLD"
    echo ""
    colorize_text "Generated: $(date '+%Y-%m-%d %H:%M:%S')" "DIM"
    colorize_text "Source: $conversation_file" "DIM"
    colorize_text "Referenced Files: $file_count" "DIM"
    colorize_text "Project: $(basename "$DIR")" "DIM"
    echo ""
    colorize_text "📝 CONVERSATION FLOW" "YELLOW"
    colorize_text "===================" "YELLOW"
    echo ""
    
    # Process and display conversation with colors
    process_conversation_content "$conversation_file" "true"
    
    # Display file contents with colors
    echo ""
    colorize_text "📁 REFERENCED FILE CONTENTS" "YELLOW"
    colorize_text "===========================" "YELLOW"
    echo ""
    
    for filepath in "${!file_refs[@]}"; do
        local full_path
        if [[ -f "$DIR/$filepath" ]]; then
            full_path="$DIR/$filepath"
        elif [[ -f "$filepath" ]]; then
            full_path="$filepath"
        else
            continue
        fi
        
        colorize_text "📄 $filepath" "PURPLE"
        colorize_text "$(printf '%.0s-' {1..50})" "DIM"
        echo ""
        
        # Display file contents with syntax highlighting simulation
        while IFS= read -r line; do
            colorize_text "$line" "GREEN"
        done < "$full_path"
        echo ""
    done
}
# }}}

# {{{ main
main() {
    # Check if first argument is a directory path (starts with / and is a directory)
    if [[ "$1" =~ ^/ ]] && [[ -d "$1" ]]; then
        DIR="$1"
        shift
    fi
    
    parse_arguments "$@"
    
    # Validate input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Error: Input file '$INPUT_FILE' not found"
        exit 1
    fi
    
    # Convert to absolute path if relative
    if [[ ! "$INPUT_FILE" =~ ^/ ]]; then
        INPUT_FILE="$DIR/$INPUT_FILE"
    fi
    
    # Handle different output modes
    if [[ "$PRINT_TERMINAL" == "true" ]]; then
        print_to_terminal "$INPUT_FILE"
    elif [[ -n "$OUTPUT_FILE" ]]; then
        # Convert to absolute path if relative
        if [[ ! "$OUTPUT_FILE" =~ ^/ ]]; then
            OUTPUT_FILE="$DIR/$OUTPUT_FILE"
        fi
        generate_backup_markdown "$INPUT_FILE" "$OUTPUT_FILE" "$GENERATE_TEXT"
    else
        echo "Error: Either specify output file (-o) or terminal printing (-p)"
        show_usage
        exit 1
    fi
}
# }}}

# Run main function with all arguments
main "$@"