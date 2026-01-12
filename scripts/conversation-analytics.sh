#!/usr/bin/env bash
# conversation-analytics.sh - Analytical transcript processing with data notebooks
#
# Generates alternative views of conversation data emphasizing:
# - Statistical patterns and metrics
# - Tabulated data sheets
# - ASCII charts and graphs
# - Analogical explanations
# - Sequential data flows

# -- {{{ Script Directory and Path Setup
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MONOREPO_ROOT="$(dirname "$DIR")"
DELTA_VERSION_DIR="${MONOREPO_ROOT}/delta-version"
# }}}

# -- {{{ Configuration Variables
OUTPUT_FORMAT="notebook"  # notebook, spreadsheet, graphical, statistical, analogical
PROCESS_ALL=false
DRY_RUN=false
TARGET_PROJECT=""
INCLUDE_CHARTS=true
INCLUDE_ANALOGIES=true
INCLUDE_STATISTICS=true
# }}}

# -- {{{ Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
# }}}

# -- {{{ Logging Functions
log() {
    echo -e "${CYAN}[ANALYTICS]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<EOF
Usage: conversation-analytics.sh [OPTIONS] [PROJECT]

Generate analytical notebooks and data visualizations from conversation transcripts.
Emphasizes patterns, metrics, and alternative explanatory formats.

OPTIONS:
    -a, --all               Process all projects
    -f, --format FORMAT     Output format: notebook|spreadsheet|graphical|statistical|analogical
    -n, --dry-run           Show what would be analyzed
    --no-charts             Disable ASCII chart generation
    --no-analogies          Disable analogical explanations
    --no-statistics         Disable statistical summaries
    -h, --help              Show this help

OUTPUT FORMATS:
    notebook      - Organized data notebook with all analysis types (default)
    spreadsheet   - Tabulated CSV-style data sheets
    graphical     - ASCII charts and visual representations
    statistical   - Numbers, metrics, and statistical summaries
    analogical    - Pattern explanations using analogies and metaphors

EXAMPLES:
    # Generate full notebook for project
    conversation-analytics.sh handheld-office

    # Create graphical view only
    conversation-analytics.sh --format graphical handheld-office

    # Statistical analysis of all projects
    conversation-analytics.sh --all --format statistical

    # Spreadsheet export
    conversation-analytics.sh --format spreadsheet delta-version > data.csv

EOF
}
# }}}

# -- {{{ parse_arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                PROCESS_ALL=true
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-charts)
                INCLUDE_CHARTS=false
                shift
                ;;
            --no-analogies)
                INCLUDE_ANALOGIES=false
                shift
                ;;
            --no-statistics)
                INCLUDE_STATISTICS=false
                shift
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                TARGET_PROJECT="$1"
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ extract_conversation_metadata
# Extract basic metadata from a conversation file
extract_conversation_metadata() {
    local conv_file="$1"

    local total_lines
    total_lines=$(wc -l < "$conv_file" 2>/dev/null || echo 0)

    local user_messages
    user_messages=$(grep -c "^### User" "$conv_file" 2>/dev/null || echo 0)

    local assistant_messages
    assistant_messages=$(grep -c "^### Assistant" "$conv_file" 2>/dev/null || echo 0)

    local code_blocks
    code_blocks=$(grep -c '```' "$conv_file" 2>/dev/null || echo 0)
    code_blocks=$((code_blocks / 2))  # Divide by 2 for opening/closing pairs

    local word_count
    word_count=$(wc -w < "$conv_file" 2>/dev/null || echo 0)

    local char_count
    char_count=$(wc -c < "$conv_file" 2>/dev/null || echo 0)

    # Ensure all values are numeric (fallback to 0)
    total_lines=${total_lines:-0}
    user_messages=${user_messages:-0}
    assistant_messages=${assistant_messages:-0}
    code_blocks=${code_blocks:-0}
    word_count=${word_count:-0}
    char_count=${char_count:-0}

    echo "$total_lines|$user_messages|$assistant_messages|$code_blocks|$word_count|$char_count"
}
# }}}

# -- {{{ generate_ascii_bar_chart
# Generate ASCII bar chart
generate_ascii_bar_chart() {
    local title="$1"
    shift
    local -a data=("$@")

    echo "┌─ $title"
    echo "│"

    # Find max value for scaling
    local max_val=0
    for entry in "${data[@]}"; do
        IFS='|' read -r label value <<< "$entry"
        ((value > max_val)) && max_val=$value
    done

    # Generate bars (scale to 50 chars max)
    for entry in "${data[@]}"; do
        IFS='|' read -r label value <<< "$entry"
        local bar_length=$((value * 50 / max_val))
        [[ $bar_length -eq 0 && $value -gt 0 ]] && bar_length=1

        printf "│ %-20s " "$label"
        printf '█%.0s' $(seq 1 $bar_length)
        printf " %d\n" "$value"
    done

    echo "└─────────────────────────────────────────────────────────────────────"
}
# }}}

# -- {{{ generate_conversation_flow_diagram
# Generate ASCII flow diagram showing conversation progression
generate_conversation_flow_diagram() {
    local user_count="$1"
    local assistant_count="$2"

    echo "┌─ Conversation Flow Diagram"
    echo "│"
    echo "│  Start"
    echo "│    │"

    local exchanges=$((user_count < assistant_count ? user_count : assistant_count))

    for ((i=1; i<=exchanges; i++)); do
        echo "│    ├─► User Request #$i"
        echo "│    │"
        echo "│    └─► Assistant Response #$i"
        echo "│       │"
    done

    if [[ $user_count -gt $assistant_count ]]; then
        echo "│       └─► [Pending: User Request #$((assistant_count + 1))]"
    fi

    echo "│"
    echo "│  End"
    echo "└─────────────────────────────────────────────────────────────────────"
}
# }}}

# -- {{{ generate_statistical_summary
# Generate statistical summary table
generate_statistical_summary() {
    local project_name="$1"
    local conv_count="$2"
    local total_lines="$3"
    local total_words="$4"
    local total_chars="$5"
    local total_code_blocks="$6"

    cat <<EOF
┌─ Statistical Summary: $project_name
│
│  Metric                          Value         Per Conversation
│  ───────────────────────────────────────────────────────────────
│  Total Conversations             $conv_count
│  Total Lines                     $total_lines         $((total_lines / (conv_count > 0 ? conv_count : 1)))
│  Total Words                     $total_words      $((total_words / (conv_count > 0 ? conv_count : 1)))
│  Total Characters                $total_chars    $((total_chars / (conv_count > 0 ? conv_count : 1)))
│  Code Blocks                     $total_code_blocks           $((total_code_blocks / (conv_count > 0 ? conv_count : 1)))
│
│  Derived Metrics:
│  Average Words per Line          $((total_words / (total_lines > 0 ? total_lines : 1)))
│  Characters per Word             $((total_chars / (total_words > 0 ? total_words : 1)))
│  Code Density (blocks/1k words)  $(((total_code_blocks * 1000) / (total_words > 0 ? total_words : 1)))
│
└─────────────────────────────────────────────────────────────────────
EOF
}
# }}}

# -- {{{ generate_data_table
# Generate spreadsheet-style data table
generate_data_table() {
    local project_name="$1"
    shift
    local -a conversations=("$@")

    echo "# Data Table: $project_name"
    echo ""
    echo "ConversationID,Lines,UserMsgs,AssistantMsgs,CodeBlocks,Words,Characters,WordsPerMsg,CharsPerWord"

    for conv_data in "${conversations[@]}"; do
        IFS='|' read -r conv_id lines user_msgs asst_msgs code_blocks words chars <<< "$conv_data"

        local total_msgs=$((user_msgs + asst_msgs))
        local words_per_msg=$((words / (total_msgs > 0 ? total_msgs : 1)))
        local chars_per_word=$((chars / (words > 0 ? words : 1)))

        echo "$conv_id,$lines,$user_msgs,$asst_msgs,$code_blocks,$words,$chars,$words_per_msg,$chars_per_word"
    done
}
# }}}

# -- {{{ generate_analogical_explanation
# Generate analogical explanation of conversation patterns
generate_analogical_explanation() {
    local project_name="$1"
    local conv_count="$2"
    local avg_exchanges="$3"
    local total_code_blocks="$4"

    cat <<EOF
┌─ Analogical Analysis: $project_name
│
│  📚 The Library Analogy:
│  This project's conversations are like a library with $conv_count books.
│  Each book (conversation) contains an average of $avg_exchanges chapters
│  (exchange pairs), where the reader (user) and author (assistant)
│  collaborate on the narrative.
│
│  🔧 The Workshop Analogy:
│  Think of these conversations as $conv_count workshop sessions. In each
│  session, the apprentice asks questions and the master craftsperson
│  demonstrates techniques. The $total_code_blocks code blocks are like
│  blueprints and tool demonstrations shared during the session.
│
│  🎼 The Musical Composition Analogy:
│  Each conversation is a musical piece with user requests as the questions
│  posed by the melody, and assistant responses as the harmony that resolves
│  them. With $avg_exchanges average exchanges, these pieces have a moderate
│  complexity - neither simple etudes nor complex symphonies.
│
│  🌊 The River Flow Analogy:
│  Imagine each conversation as water flowing through a canyon. The user's
│  messages are tributaries joining the main flow, and the assistant's
│  responses are the river bed that shapes and guides the water's path.
│  The $conv_count conversations form a entire river system.
│
└─────────────────────────────────────────────────────────────────────
EOF
}
# }}}

# -- {{{ generate_notebook_format
# Generate complete data notebook
generate_notebook_format() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    local transcripts_dir="${project_dir}/llm-transcripts"

    if [[ ! -d "$transcripts_dir" ]]; then
        warn "No transcripts directory found at $transcripts_dir"
        return 1
    fi

    # Collect conversation data
    local -a conversations=()
    local conv_count=0
    local total_lines=0
    local total_user_msgs=0
    local total_asst_msgs=0
    local total_code_blocks=0
    local total_words=0
    local total_chars=0

    for conv_file in "$transcripts_dir"/*_summary.md; do
        [[ ! -f "$conv_file" ]] && continue

        local conv_id
        conv_id=$(basename "$conv_file" _summary.md)

        local metadata
        metadata=$(extract_conversation_metadata "$conv_file")

        IFS='|' read -r lines user_msgs asst_msgs code_blocks words chars <<< "$metadata"

        conversations+=("${conv_id}|${lines}|${user_msgs}|${asst_msgs}|${code_blocks}|${words}|${chars}")

        ((conv_count++))
        ((total_lines += lines))
        ((total_user_msgs += user_msgs))
        ((total_asst_msgs += asst_msgs))
        ((total_code_blocks += code_blocks))
        ((total_words += words))
        ((total_chars += chars))
    done

    if [[ $conv_count -eq 0 ]]; then
        warn "No conversations found in $transcripts_dir"
        return 1
    fi

    # Generate notebook
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "                  CONVERSATION ANALYTICS NOTEBOOK"
    echo "                        Project: $project_name"
    echo "                     Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""

    # Section 1: Statistical Summary
    if $INCLUDE_STATISTICS || [[ "$OUTPUT_FORMAT" == "notebook" ]]; then
        generate_statistical_summary "$project_name" "$conv_count" "$total_lines" \
            "$total_words" "$total_chars" "$total_code_blocks"
        echo ""
    fi

    # Section 2: Charts and Graphs
    if $INCLUDE_CHARTS || [[ "$OUTPUT_FORMAT" == "notebook" ]]; then
        # Message distribution chart
        local -a msg_data=(
            "User Messages|$total_user_msgs"
            "Assistant Messages|$total_asst_msgs"
        )
        generate_ascii_bar_chart "Message Distribution" "${msg_data[@]}"
        echo ""

        # Content type distribution
        local -a content_data=(
            "Total Lines|$total_lines"
            "Code Blocks|$total_code_blocks"
            "Text Words|$((total_words - code_blocks * 10))"
        )
        generate_ascii_bar_chart "Content Distribution" "${content_data[@]}"
        echo ""

        # Average conversation flow
        local avg_user=$((total_user_msgs / conv_count))
        local avg_asst=$((total_asst_msgs / conv_count))
        generate_conversation_flow_diagram "$avg_user" "$avg_asst"
        echo ""
    fi

    # Section 3: Analogical Explanations
    if $INCLUDE_ANALOGIES || [[ "$OUTPUT_FORMAT" == "notebook" ]]; then
        local avg_exchanges=$(((total_user_msgs + total_asst_msgs) / (conv_count * 2)))
        generate_analogical_explanation "$project_name" "$conv_count" "$avg_exchanges" "$total_code_blocks"
        echo ""
    fi

    # Section 4: Data Table
    echo "┌─ Detailed Conversation Data Table"
    echo "│"
    generate_data_table "$project_name" "${conversations[@]}" | sed 's/^/│  /'
    echo "│"
    echo "└─────────────────────────────────────────────────────────────────────"
    echo ""

    # Section 5: Pattern Analysis
    echo "┌─ Pattern Analysis"
    echo "│"
    echo "│  Conversation Rhythm Pattern:"
    local rhythm=""
    for ((i=0; i<conv_count && i<20; i++)); do
        IFS='|' read -r conv_id lines user_msgs asst_msgs code_blocks words chars <<< "${conversations[i]}"
        local total_msgs=$((user_msgs + asst_msgs))

        if [[ $total_msgs -lt 5 ]]; then
            rhythm+="·"
        elif [[ $total_msgs -lt 10 ]]; then
            rhythm+="▪"
        elif [[ $total_msgs -lt 20 ]]; then
            rhythm+="▫"
        else
            rhythm+="■"
        fi

        [[ $(((i+1) % 10)) -eq 0 ]] && rhythm+=" "
    done
    echo "│  $rhythm"
    echo "│"
    echo "│  Legend: · = brief (< 5 msgs)  ▪ = short (5-9)  ▫ = medium (10-19)  ■ = long (20+)"
    echo "│"
    echo "│  Complexity Score: $(((total_code_blocks * 10 + total_words / 100) / conv_count))/100"
    echo "│  Collaboration Index: $((total_user_msgs * 100 / (total_user_msgs + total_asst_msgs)))% user / $((total_asst_msgs * 100 / (total_user_msgs + total_asst_msgs)))% assistant"
    echo "│"
    echo "└─────────────────────────────────────────────────────────────────────"
    echo ""

    success "Analytics notebook generated for $project_name"
}
# }}}

# -- {{{ Main function
main() {
    log "Conversation Analytics - Initializing"
    echo ""

    parse_arguments "$@"

    # Validate format
    case "$OUTPUT_FORMAT" in
        notebook|spreadsheet|graphical|statistical|analogical)
            ;;
        *)
            error "Invalid format: $OUTPUT_FORMAT"
            show_help
            exit 1
            ;;
    esac

    # Determine target projects
    local -a projects=()

    if $PROCESS_ALL; then
        if [[ -x "${DELTA_VERSION_DIR}/scripts/list-projects.sh" ]]; then
            while IFS= read -r project_path; do
                [[ -z "$project_path" ]] && continue
                [[ -d "${project_path}/llm-transcripts" ]] && projects+=("$project_path")
            done < <("${DELTA_VERSION_DIR}/scripts/list-projects.sh" --abs-paths 2>/dev/null)
        else
            error "list-projects.sh not found"
            exit 1
        fi
    elif [[ -n "$TARGET_PROJECT" ]]; then
        # Try as absolute path first
        if [[ -d "$TARGET_PROJECT" ]]; then
            projects+=("$TARGET_PROJECT")
        # Try as project name in monorepo
        elif [[ -d "${MONOREPO_ROOT}/${TARGET_PROJECT}" ]]; then
            projects+=("${MONOREPO_ROOT}/${TARGET_PROJECT}")
        else
            error "Project not found: $TARGET_PROJECT"
            exit 1
        fi
    else
        error "Must specify --all or a project name"
        show_help
        exit 1
    fi

    if [[ ${#projects[@]} -eq 0 ]]; then
        warn "No projects with transcripts found"
        exit 0
    fi

    log "Found ${#projects[@]} projects with transcripts"
    echo ""

    # Process each project
    for project_dir in "${projects[@]}"; do
        local project_name
        project_name=$(basename "$project_dir")

        log "Analyzing: $project_name"

        if $DRY_RUN; then
            echo "  Would generate $OUTPUT_FORMAT format for $project_name"
            continue
        fi

        # Generate based on format
        case "$OUTPUT_FORMAT" in
            notebook)
                generate_notebook_format "$project_dir"
                ;;
            *)
                warn "Format '$OUTPUT_FORMAT' not yet fully implemented"
                generate_notebook_format "$project_dir"
                ;;
        esac

        echo ""
    done

    success "Analytics generation complete"
}
# }}}

# Run main
main "$@"
