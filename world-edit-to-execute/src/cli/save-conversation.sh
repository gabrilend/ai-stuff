#!/bin/bash
# save-conversation.sh
#
# Exports the current or recent Claude conversation and saves it with a
# topic tag for future reference. Creates entries that can be added to
# CLAUDE.md for easy lookup like "here's where we discussed X".
#
# Usage:
#   ./save-conversation.sh "frame-encoding-discussion"
#   ./save-conversation.sh "pathfinding-as-dna" -v3
#   ./save-conversation.sh --list
#   ./save-conversation.sh --add-to-claude "frame-encoding-discussion"

# {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/world-edit-to-execute}"
EXPORTER="/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh"
CONV_DIR="${DIR}/notes/conversations"
CLAUDE_MD="${DIR}/CLAUDE.md"
PROJECT_NAME="world-edit-to-execute"
# }}}

# {{{ show_help
show_help() {
    cat << 'EOF'
save-conversation.sh - Save Claude conversations with topic tags

USAGE:
    save-conversation.sh <topic-tag> [options]
    save-conversation.sh --list
    save-conversation.sh --add-to-claude <topic-tag>
    save-conversation.sh --current <topic-tag>

ARGUMENTS:
    <topic-tag>     Short descriptive name (e.g., "frame-encoding", "astar-dna")

OPTIONS:
    -v0 to -v5      Verbosity level (default: -v2)
    --minimal       Alias for -v0
    --verbose       Alias for -v3
    --complete      Alias for -v4
    --list          List saved conversations
    --add-to-claude Add reference entry to CLAUDE.md
    --current       Export the most recent (current) conversation
    -h, --help      Show this help

EXAMPLES:
    # Save current conversation with topic tag
    ./save-conversation.sh "frame-encoding-discussion"

    # Save with verbose output
    ./save-conversation.sh "dna-pathfinding" -v3

    # List all saved conversations
    ./save-conversation.sh --list

    # Add reference to CLAUDE.md
    ./save-conversation.sh --add-to-claude "frame-encoding-discussion"

OUTPUT:
    Saves to: notes/conversations/YYYY-MM-DD-<topic-tag>.md

    Reference format for CLAUDE.md:
    - [Frame Encoding Discussion](notes/conversations/2025-12-30-frame-encoding-discussion.md)
      Discussed: quadrant-based vector encoding, LUT operations, DNA analogy
EOF
}
# }}}

# {{{ ensure_dir
ensure_dir() {
    if [[ ! -d "${CONV_DIR}" ]]; then
        mkdir -p "${CONV_DIR}"
        echo "Created: ${CONV_DIR}"
    fi
}
# }}}

# {{{ list_conversations
list_conversations() {
    ensure_dir
    echo "Saved conversations in ${CONV_DIR}:"
    echo ""

    if [[ -z "$(ls -A "${CONV_DIR}" 2>/dev/null)" ]]; then
        echo "  (none yet)"
        return
    fi

    for file in "${CONV_DIR}"/*.md; do
        [[ -f "$file" ]] || continue
        basename "$file" .md
        # Extract first heading if present
        head -5 "$file" | grep -m1 "^#" | sed 's/^/    /'
    done
}
# }}}

# {{{ get_current_conversation
get_current_conversation() {
    # Find the most recently modified conversation file
    local project_dir="${HOME}/.claude/projects/-mnt-mtwo-programming-ai-stuff-world-edit-to-execute"

    if [[ ! -d "$project_dir" ]]; then
        echo "Error: Project directory not found" >&2
        return 1
    fi

    # Get most recent .jsonl file
    ls -t "${project_dir}"/*.jsonl 2>/dev/null | head -1
}
# }}}

# {{{ export_conversation
export_conversation() {
    local topic="$1"
    local verbosity="${2:--v2}"
    local conv_id="$3"

    ensure_dir

    local date_stamp=$(date +%Y-%m-%d)
    local output_file="${CONV_DIR}/${date_stamp}-${topic}.md"

    echo "Exporting conversation..."
    echo "  Topic: ${topic}"
    echo "  Verbosity: ${verbosity}"
    echo "  Output: ${output_file}"
    echo ""

    # If no conv_id specified, use the most recent
    if [[ -z "$conv_id" ]]; then
        local recent_file=$(get_current_conversation)
        if [[ -n "$recent_file" ]]; then
            conv_id=$(basename "$recent_file" .jsonl)
            echo "  Using most recent: ${conv_id:0:8}..."
        fi
    fi

    # Create header
    cat > "$output_file" << EOF
# Conversation: ${topic}

**Date:** ${date_stamp}
**Project:** ${PROJECT_NAME}
**Conversation ID:** ${conv_id:-unknown}

---

EOF

    # Export using the exporter
    if [[ -x "$EXPORTER" ]]; then
        "$EXPORTER" "$verbosity" "$PROJECT_NAME" "$conv_id" >> "$output_file" 2>&1
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            echo "Saved to: ${output_file}"
            echo ""
            echo "To add to CLAUDE.md, run:"
            echo "  $0 --add-to-claude \"${topic}\""
        else
            echo "Warning: Exporter returned code ${exit_code}"
            echo "Partial output may be in: ${output_file}"
        fi
    else
        echo "Error: Exporter not found at ${EXPORTER}" >&2
        echo "Creating placeholder file..."
        echo "(Exporter not available - manual export needed)" >> "$output_file"
    fi

    echo ""
    echo "Reference entry for CLAUDE.md:"
    echo ""
    generate_reference "$topic" "$date_stamp"
}
# }}}

# {{{ generate_reference
generate_reference() {
    local topic="$1"
    local date_stamp="${2:-$(date +%Y-%m-%d)}"

    # Convert topic to title case
    local title=$(echo "$topic" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

    cat << EOF
- [${title}](notes/conversations/${date_stamp}-${topic}.md)
  Date: ${date_stamp}
  Topics: (add summary here)
EOF
}
# }}}

# {{{ add_to_claude_md
add_to_claude_md() {
    local topic="$1"
    local date_stamp=$(date +%Y-%m-%d)
    local conv_file="${CONV_DIR}/${date_stamp}-${topic}.md"

    if [[ ! -f "$conv_file" ]]; then
        echo "Error: Conversation file not found: ${conv_file}" >&2
        echo "Run first: $0 \"${topic}\""
        return 1
    fi

    # Check if reference section exists in CLAUDE.md
    if ! grep -q "## Reference Conversations" "$CLAUDE_MD" 2>/dev/null; then
        echo "" >> "$CLAUDE_MD"
        echo "## Reference Conversations" >> "$CLAUDE_MD"
        echo "" >> "$CLAUDE_MD"
        echo "Saved discussions for future reference:" >> "$CLAUDE_MD"
        echo "" >> "$CLAUDE_MD"
    fi

    # Add reference entry
    local title=$(echo "$topic" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    echo "- [${title}](notes/conversations/${date_stamp}-${topic}.md) - ${date_stamp}" >> "$CLAUDE_MD"

    echo "Added reference to ${CLAUDE_MD}"
    echo ""
    echo "Entry added:"
    echo "  - [${title}](notes/conversations/${date_stamp}-${topic}.md) - ${date_stamp}"
}
# }}}

# {{{ main
main() {
    local topic=""
    local verbosity="-v2"
    local action="export"
    local conv_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --list)
                list_conversations
                exit 0
                ;;
            --add-to-claude)
                action="add"
                shift
                topic="$1"
                ;;
            --current)
                shift
                topic="$1"
                # conv_id will be auto-detected
                ;;
            -v[0-5])
                verbosity="$1"
                ;;
            --minimal)
                verbosity="-v0"
                ;;
            --verbose)
                verbosity="-v3"
                ;;
            --complete)
                verbosity="-v4"
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$topic" ]]; then
                    topic="$1"
                else
                    conv_id="$1"
                fi
                ;;
        esac
        shift
    done

    # Validate
    if [[ -z "$topic" ]]; then
        echo "Error: Topic tag required" >&2
        echo "Usage: $0 <topic-tag> [options]" >&2
        echo "       $0 --help for more info" >&2
        exit 1
    fi

    # Sanitize topic (lowercase, dashes only)
    topic=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd 'a-z0-9-')

    case "$action" in
        export)
            export_conversation "$topic" "$verbosity" "$conv_id"
            ;;
        add)
            add_to_claude_md "$topic"
            ;;
    esac
}
# }}}

main "$@"
