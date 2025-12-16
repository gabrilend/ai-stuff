#!/bin/bash
# Poem Context Generator (Simple): Uses view-random script to collect random poems for LLM personalization

set -e

VIEW_RANDOM_SCRIPT="/home/ritz/words/view-random"

# {{{ print_usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  -s, --size SIZE: Target context window size in characters (required)"
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

# {{{ get_random_poem
# FIXME: please build in functionality to also instead take in a neocities-modernization context file
get_random_poem() {
    $VIEW_RANDOM_SCRIPT 2>/dev/null
}
# }}}

# {{{ collect_poems
collect_poems() {
    local target_size="$1"
    local temp_dir=$(mktemp -d)
    local total_length=0
    local attempts=0
    local max_attempts=100
    local poem_count=0
    
    while [[ $total_length -lt $target_size && $attempts -lt $max_attempts ]]; do
        ((attempts++))
        
        local poem_content
        poem_content=$(get_random_poem)
        
        if [[ -n "$poem_content" ]]; then
            local poem_length=${#poem_content}
            
            # Only add if it fits and adds meaningful content
            if [[ $((total_length + poem_length + 200)) -le $target_size && $poem_length -gt 50 ]]; then
                echo "$poem_content" > "$temp_dir/poem_$poem_count"
                ((poem_count++))
                total_length=$((total_length + poem_length + 200))
            fi
        fi
        
        # Small delay to avoid overwhelming the system
        sleep 0.1
    done
    
    echo "$temp_dir|$total_length|$poem_count"
}
# }}}

# {{{ format_output
format_output() {
    local temp_dir="$1"
    local poem_count="$2"
    
    echo "# Personal Context for LLM"
    echo
    
    for ((i=0; i<poem_count; i++)); do
        if [[ -f "$temp_dir/poem_$i" ]]; then
            echo "## Random Entry $((i+1))"
            cat "$temp_dir/poem_$i"
            echo
        fi
    done
}
# }}}

# {{{ main
main() {
    parse_args "$@"
    
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_mode
    fi
    
    if [[ -z "$CONTEXT_SIZE" ]]; then
        echo "Error: Context size must be specified with -s or use interactive mode with -I" >&2
        exit 1
    fi
    
    local result
    result=$(collect_poems "$CONTEXT_SIZE")
    
    local temp_dir=$(echo "$result" | cut -d'|' -f1)
    local total_length=$(echo "$result" | cut -d'|' -f2)
    local poem_count=$(echo "$result" | cut -d'|' -f3)
    
    if [[ "$poem_count" -eq 0 ]]; then
        echo "Error: No poems collected" >&2
        rm -rf "$temp_dir"
        exit 1
    fi
    
    format_output "$temp_dir" "$poem_count"
    
    # Output statistics to stderr
    echo "Collected $poem_count poems, total length: $total_length chars" >&2
    
    # Cleanup
    rm -rf "$temp_dir"
}
# }}}

main "$@"