#!/bin/bash
# Poem Context Generator: Randomly selects and orders poems from compiled.txt to fit within a specified context window for LLM personalization

set -e

DIR="${1:-/mnt/mtwo/programming/ai-stuff/words-pdf/input}"
COMPILED_FILE="$DIR/compiled.txt"

# {{{ print_usage
print_usage() {
    echo "Usage: $0 [DIR] [OPTIONS]"
    echo "  DIR: Directory containing compiled.txt (default: $DIR)"
    echo "  -s, --size SIZE: Context window size in characters (required)"
    echo "  -I, --interactive: Interactive mode"
    echo "  -h, --help: Show this help"
}
# }}}

# {{{ parse_args
parse_args() {
    INTERACTIVE=false
    CONTEXT_SIZE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -s|--size)
                CONTEXT_SIZE="$2"
                if ! [[ "$CONTEXT_SIZE" =~ ^[0-9]+$ ]]; then
                    echo "Error: Invalid context size: $CONTEXT_SIZE" >&2
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Error: Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    COMPILED_FILE="$DIR/compiled.txt"
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    echo "Poem Context Generator - Interactive Mode"
    echo "1. Small context (8000 chars)"
    echo "2. Medium context (16000 chars)"
    echo "3. Large context (32000 chars)"
    echo "4. Custom size"
    echo -n "Enter selection (1-4): "
    
    read -r choice
    case $choice in
        1) CONTEXT_SIZE=8000 ;;
        2) CONTEXT_SIZE=16000 ;;
        3) CONTEXT_SIZE=32000 ;;
        4) 
            echo -n "Enter custom size: "
            read -r CONTEXT_SIZE
            if ! [[ "$CONTEXT_SIZE" =~ ^[0-9]+$ ]]; then
                echo "Error: Invalid size entered" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Invalid selection" >&2
            exit 1
            ;;
    esac
}
# }}}

# {{{ extract_poems
extract_poems() {
    local filepath="$1"
    local temp_dir=$(mktemp -d)
    local poem_index=0
    local current_poem=""
    local poem_title=""
    local in_poem=false
    local waiting_for_separator=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-\>\ file:\ (messages|fediverse|notes)/ ]]; then
            # Save previous poem if exists and has content
            if [[ "$in_poem" == true && -n "$current_poem" ]]; then
                # Only save if content has more than whitespace
                local trimmed_content=$(echo "$current_poem" | tr -d '[:space:]')
                if [[ ${#trimmed_content} -gt 20 ]]; then
                    local poem_length=${#current_poem}
                    echo "$poem_title|$poem_length|$current_poem" > "$temp_dir/poem_$poem_index"
                    ((poem_index++))
                fi
            fi
            
            # Start new poem
            poem_title=$(echo "$line" | sed 's/.*\/\([^/]*\)\.txt/\1/')
            current_poem=""
            in_poem=false
            waiting_for_separator=true
        elif [[ "$line" =~ ^-+$ ]] && [[ "$waiting_for_separator" == true ]]; then
            # Separator line after header - now we can start collecting content
            in_poem=true
            waiting_for_separator=false
        elif [[ "$in_poem" == true ]]; then
            # Skip empty lines at the beginning of poems
            if [[ -n "$current_poem" || ! "$line" =~ ^[[:space:]]*$ ]]; then
                if [[ -n "$current_poem" ]]; then
                    current_poem="$current_poem"$'\n'"$line"
                else
                    current_poem="$line"
                fi
            fi
        fi
    done < "$filepath"
    
    # Add last poem
    if [[ "$in_poem" == true && -n "$current_poem" ]]; then
        local trimmed_content=$(echo "$current_poem" | tr -d '[:space:]')
        if [[ ${#trimmed_content} -gt 20 ]]; then
            local poem_length=${#current_poem}
            echo "$poem_title|$poem_length|$current_poem" > "$temp_dir/poem_$poem_index"
        fi
    fi
    
    echo "$temp_dir"
}
# }}}

# {{{ select_poems_for_context
select_poems_for_context() {
    local temp_dir="$1"
    local target_size="$2"
    local selected_temp=$(mktemp -d)
    local total_length=0
    local selected_count=0
    
    # Shuffle and sort poems by length for better packing
    find "$temp_dir" -name "poem_*" | shuf | while read -r poem_file; do
        if [[ -f "$poem_file" ]]; then
            IFS='|' read -r title length content < "$poem_file"
            echo "$length|$title|$content"
        fi
    done | sort -n | while IFS='|' read -r length title content; do
        if (( total_length + length + 50 <= target_size )); then
            echo "$title|$length|$content" > "$selected_temp/selected_$selected_count"
            total_length=$((total_length + length + 50))
            selected_count=$((selected_count + 1))
            echo "$total_length" > "$selected_temp/total_length"
            echo "$selected_count" > "$selected_temp/count"
        fi
    done
    
    echo "$selected_temp"
}
# }}}

# {{{ format_output
format_output() {
    local selected_dir="$1"
    
    echo "# Personal Context for LLM"
    echo
    
    find "$selected_dir" -name "selected_*" | sort -V | while read -r selected_file; do
        if [[ -f "$selected_file" ]]; then
            IFS='|' read -r title length content < "$selected_file"
            echo "## $title"
            echo "$content"
            echo
        fi
    done
}
# }}}

# {{{ main
main() {
    # Set default DIR before parsing args
    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
        DIR="$1/input"
        shift
    else
        DIR="/mnt/mtwo/programming/ai-stuff/words-pdf/input"
    fi
    parse_args "$@"
    
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_mode
    fi
    
    if [[ -z "$CONTEXT_SIZE" ]]; then
        echo "Error: Context size must be specified with -s or use interactive mode with -I" >&2
        exit 1
    fi
    
    if [[ ! -f "$COMPILED_FILE" ]]; then
        echo "Error: Cannot find compiled.txt at $COMPILED_FILE" >&2
        exit 1
    fi
    
    local poems_dir
    poems_dir=$(extract_poems "$COMPILED_FILE")
    
    local poem_count
    poem_count=$(find "$poems_dir" -name "poem_*" | wc -l)
    if [[ "$poem_count" -eq 0 ]]; then
        echo "Error: No poems found in $COMPILED_FILE" >&2
        rm -rf "$poems_dir"
        exit 1
    fi
    
    local selected_dir
    selected_dir=$(select_poems_for_context "$poems_dir" "$CONTEXT_SIZE")
    
    local selected_count=0
    local total_length=0
    
    if [[ -f "$selected_dir/count" ]]; then
        selected_count=$(cat "$selected_dir/count")
    fi
    if [[ -f "$selected_dir/total_length" ]]; then
        total_length=$(cat "$selected_dir/total_length")
    fi
    
    if [[ "$selected_count" -eq 0 ]]; then
        echo "Error: No poems fit within the specified context size" >&2
        rm -rf "$poems_dir" "$selected_dir"
        exit 1
    fi
    
    format_output "$selected_dir"
    
    # Output statistics to stderr
    echo "Selected $selected_count poems, total length: $total_length chars" >&2
    
    # Cleanup
    rm -rf "$poems_dir" "$selected_dir"
}
# }}}

main "$@"