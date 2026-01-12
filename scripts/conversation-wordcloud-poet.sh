#!/usr/bin/env bash
# conversation-wordcloud-poet.sh - Word cloud analysis and poetry generation
#
# Generates word clouds from conversations, identifies rare/unique words,
# and creates poetry about them using local Ollama LLM.

# -- {{{ Script Directory and Path Setup
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MONOREPO_ROOT="$(dirname "$DIR")"
DELTA_VERSION_DIR="${MONOREPO_ROOT}/delta-version"
# }}}

# -- {{{ Configuration Variables
TARGET_PROJECT=""
PROCESS_ALL=false
TOP_N_WORDS=50
MIN_WORD_LENGTH=4
OLLAMA_MODEL="llama3.2:latest"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_CONTEXT_SIZE=4096
GENERATE_POEMS=true
WORD_REPETITION_MODE=true
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
    echo -e "${CYAN}[WORDCLOUD]${NC} $*"
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

poem() {
    echo -e "${MAGENTA}[POEM]${NC} $*"
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<EOF
Usage: conversation-wordcloud-poet.sh [OPTIONS] [PROJECT]

Generate word clouds from conversation transcripts and create poetry about
rare/unique words using Ollama.

OPTIONS:
    -a, --all                Process all projects
    -n, --top-words N        Number of top words to show (default: 50)
    -m, --model MODEL        Ollama model to use (default: llama3.2:latest)
    --ollama-host HOST       Ollama host URL (default: http://localhost:11434)
                             Can also set OLLAMA_HOST environment variable
    --min-length N           Minimum word length (default: 4)
    --no-poems               Skip poem generation
    --no-repetition          Use counts instead of word repetition
    -h, --help               Show this help

EXAMPLES:
    # Generate word cloud with poetry for project
    conversation-wordcloud-poet.sh handheld-office

    # Analyze all projects
    conversation-wordcloud-poet.sh --all

    # Use specific model with top 100 words
    conversation-wordcloud-poet.sh --model llama3.2:3b --top-words 100 delta-version

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
            -n|--top-words)
                TOP_N_WORDS="$2"
                shift 2
                ;;
            -m|--model)
                OLLAMA_MODEL="$2"
                shift 2
                ;;
            --ollama-host)
                OLLAMA_HOST="$2"
                shift 2
                ;;
            --min-length)
                MIN_WORD_LENGTH="$2"
                shift 2
                ;;
            --no-poems)
                GENERATE_POEMS=false
                shift
                ;;
            --no-repetition)
                WORD_REPETITION_MODE=false
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

# -- {{{ generate_word_frequencies
# Generate word frequency map from transcript files
generate_word_frequencies() {
    local transcripts_dir="$1"
    local output_file="$2"

    # Combine all summary files, extract words, count frequencies
    cat "$transcripts_dir"/*_summary.md 2>/dev/null | \
        tr '[:upper:]' '[:lower:]' | \
        grep -oE '\b[a-z]{'"${MIN_WORD_LENGTH}"',}\b' | \
        sort | uniq -c | sort -rn > "$output_file"
}
# }}}

# -- {{{ display_word_cloud
# Display word cloud with visual formatting
display_word_cloud() {
    local freq_file="$1"
    local title="$2"
    local top_n="${3:-$TOP_N_WORDS}"

    echo "┌─ Word Cloud: $title"
    echo "│"

    local line_num=0
    while IFS= read -r line && [[ $line_num -lt $top_n ]]; do
        local count=$(echo "$line" | awk '{print $1}')
        local word=$(echo "$line" | awk '{print $2}')

        # Skip common programming words and articles
        if [[ "$word" =~ ^(the|and|for|are|with|this|that|from|have|been|will|would|could|should|there|their|what|when|where|which|while|your|some|into|than|then|them|these|those|make|made|only|over|such|take|must|more|most|many|much|very|just|like|also|back|even|well|down|only|right|left|here|both|each|find|give|hand|high|keep|last|long|made|main|next|open|part|same|seem|show|side|take|tell|turn|used|want|work|year|call|come|feel|find|give|good|hand|help|here|hold|keep|know|last|left|life|live|long|look|make|mean|move|need|next|open|over|part|play|pull|push|read|real|said|same|seem|self|show|side|soon|stay|stop|sure|take|tell|than|that|them|then|they|this|time|true|turn|type|used|very|want|well|were|what|when|will|with|word|work|your)$ ]]; then
            continue
        fi

        # Create visual bar based on count (scale to fit)
        local bar_length=$((count / 10))
        [[ $bar_length -gt 50 ]] && bar_length=50
        [[ $bar_length -eq 0 ]] && bar_length=1

        printf "│ %-20s " "$word"
        printf '▓%.0s' $(seq 1 $bar_length)
        printf " %d\n" "$count"

        ((line_num++))
    done < "$freq_file"

    echo "└─────────────────────────────────────────────────────────────────────"
}
# }}}

# -- {{{ find_rare_words
# Find words that appear very rarely across all conversations
find_rare_words() {
    local freq_file="$1"
    local rarity_threshold="${2:-3}"

    # Words that appear only 1-3 times are considered rare
    awk -v threshold="$rarity_threshold" '$1 <= threshold && $1 > 0 {print $2}' "$freq_file"
}
# }}}

# -- {{{ extract_context_for_word
# Extract surrounding context for a word from transcript files
extract_context_for_word() {
    local word="$1"
    local transcripts_dir="$2"
    local context_lines=2

    # Find occurrences of word and extract context
    grep -i -B "$context_lines" -A "$context_lines" "\b$word\b" \
        "$transcripts_dir"/*_summary.md 2>/dev/null | head -20
}
# }}}

# -- {{{ build_ollama_prompt
# Build prompt for Ollama with repeated words and context
build_ollama_prompt() {
    local project_name="$1"
    local -a rare_words=("${@:2}")
    local transcripts_dir="$3"

    local prompt="You are a poet contemplating the unique words found in the development history of the '$project_name' project.\n\n"
    prompt+="These rare words appeared only a few times across all conversations, making them special:\n\n"

    # Add rare words with repetition (instead of counts)
    for word in "${rare_words[@]}"; do
        # Get count from frequency file
        local count=$(grep -w "^[[:space:]]*[0-9]* $word\$" /tmp/wordfreq-$$.txt 2>/dev/null | awk '{print $1}')
        [[ -z "$count" ]] && count=1

        # Repeat word 'count' times
        if $WORD_REPETITION_MODE; then
            for ((i=0; i<count; i++)); do
                prompt+="$word "
            done
            prompt+="\n"
        else
            prompt+="$word ($count times)\n"
        fi
    done

    prompt+="\n"
    prompt+="Here are snippets of context where these words appeared:\n\n"

    # Add context for a few words (limited by context size)
    local context_words=0
    for word in "${rare_words[@]}"; do
        [[ $context_words -ge 5 ]] && break

        local context
        context=$(extract_context_for_word "$word" "$transcripts_dir")

        if [[ -n "$context" ]]; then
            prompt+="--- Context for '$word' ---\n"
            prompt+="$context\n\n"
            ((context_words++))
        fi
    done

    prompt+="Write a short poem (8-12 lines) that captures the essence of this project through these unique words.\n"
    prompt+="Focus on the technical journey, the rare concepts, and what makes this project special.\n"

    echo -e "$prompt"
}
# }}}

# -- {{{ generate_poem_with_ollama
# Call Ollama to generate poem
generate_poem_with_ollama() {
    local prompt="$1"

    # Check if ollama is available
    if ! command -v ollama &>/dev/null; then
        warn "Ollama not found. Install from https://ollama.ai"
        return 1
    fi

    # Check if model is available
    if ! OLLAMA_HOST="$OLLAMA_HOST" ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
        warn "Model $OLLAMA_MODEL not found at $OLLAMA_HOST. Pulling..."
        OLLAMA_HOST="$OLLAMA_HOST" ollama pull "$OLLAMA_MODEL"
    fi

    log "Generating poem with $OLLAMA_MODEL at $OLLAMA_HOST..."

    # Call Ollama with custom host
    local poem
    poem=$(echo -e "$prompt" | OLLAMA_HOST="$OLLAMA_HOST" ollama run "$OLLAMA_MODEL" 2>/dev/null)

    if [[ -n "$poem" ]]; then
        echo "$poem"
        return 0
    else
        error "Failed to generate poem"
        return 1
    fi
}
# }}}

# -- {{{ process_project
# Process a single project
process_project() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    local transcripts_dir="${project_dir}/llm-transcripts"

    if [[ ! -d "$transcripts_dir" ]]; then
        warn "No transcripts directory: $project_dir"
        return 1
    fi

    log "Processing: $project_name"

    # Generate word frequencies
    local freq_file="/tmp/wordfreq-$$.txt"
    generate_word_frequencies "$transcripts_dir" "$freq_file"

    if [[ ! -s "$freq_file" ]]; then
        warn "No words extracted from $project_name"
        return 1
    fi

    # Determine output file
    local output_file="${transcripts_dir}/_wordcloud.md"

    # Generate output to file
    {
        # Display word cloud
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "                    WORD CLOUD ANALYSIS"
        echo "                      Project: $project_name"
        echo "═══════════════════════════════════════════════════════════════════════"
        echo ""

        display_word_cloud "$freq_file" "$project_name" "$TOP_N_WORDS"
        echo ""

        # Find rare words
        local -a rare_words
        mapfile -t rare_words < <(find_rare_words "$freq_file" 3 | head -20)

        if [[ ${#rare_words[@]} -gt 0 ]]; then
            echo "┌─ Rare & Unique Words (appearing 1-3 times)"
            echo "│"
            for word in "${rare_words[@]}"; do
                echo "│  • $word"
            done
            echo "└─────────────────────────────────────────────────────────────────────"
            echo ""

            # Generate poem if enabled
            if $GENERATE_POEMS; then
                echo "┌─ Poetry About the Unique Words"
                echo "│"

                local prompt
                prompt=$(build_ollama_prompt "$project_name" "${rare_words[@]}" "$transcripts_dir")

                local poem
                if poem=$(generate_poem_with_ollama "$prompt"); then
                    # Format poem with indentation
                    echo "$poem" | sed 's/^/│  /'
                else
                    echo "│  [Poem generation failed]"
                fi

                echo "│"
                echo "└─────────────────────────────────────────────────────────────────────"
                echo ""
            fi
        else
            echo "No rare words found (all words appear frequently)"
        fi
    } > "$output_file"

    # Cleanup
    rm -f "$freq_file"

    if [[ -f "$output_file" ]]; then
        success "Word cloud saved to: $output_file"
    else
        error "Failed to generate word cloud for $project_name"
    fi
}
# }}}

# -- {{{ Main function
main() {
    log "Word Cloud Poet - Initializing"
    echo ""

    parse_arguments "$@"

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
        if [[ -d "$TARGET_PROJECT" ]]; then
            projects+=("$TARGET_PROJECT")
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
        process_project "$project_dir"
        echo ""
        echo ""
    done

    success "Word cloud poetry generation complete"
}
# }}}

# Run main
main "$@"
