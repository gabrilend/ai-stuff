#!/bin/bash

# run.sh - Main orchestrator for neocities-modernization pipeline
#
# Runs the complete poem processing pipeline from input files to generated HTML.
# Supports selective stage execution via CLI flags, with stages running in
# pipeline order regardless of argument order.
#
# The full pipeline has 10 stages:
#   1. Update Words     - Sync input files from words repository
#   2. Extract          - Extract content from backup archives
#   3. Parse            - Generate poems.json from sources
#   4. Validate         - Validate poem data
#   5. Catalog Images   - Generate image-catalog.json
#   6. Embeddings       - Generate poem embeddings via Ollama (~2-3 hours)
#   7. Similarity       - Build similarity matrix (~30 min)
#   8. Diversity        - Pre-compute diversity cache (~42 hours)
#   9. Generate HTML    - Generate website HTML pages
#  10. Generate Index   - Generate numeric similarity index
#
# By default (--all), runs stages 1-5 and 9-10 (skips expensive embedding stages).
# Use --full to run all 10 stages including embedding generation.
#
# Usage: ./run.sh [FLAGS] [PROJECT_DIR]

# {{{ setup_dir_path
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

# {{{ TUI Library
# Source TUI library for interactive mode with command preview
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
TUI_AVAILABLE=false
if [[ -f "${LIBS_DIR}/lua-menu.sh" ]] && command -v luajit &>/dev/null; then
    source "${LIBS_DIR}/lua-menu.sh"
    TUI_AVAILABLE=true
fi
# }}}

# {{{ show_help
show_help() {
    cat << 'EOF'
Usage: ./run.sh [FLAGS] [PROJECT_DIR]

Runs the poem processing pipeline. Without stage flags, runs fast stages only.
With stage flags, runs only the specified stages in pipeline order.

Pipeline Stages (run in order, multiple can be specified):
  --update-words        Stage 1:  Sync input files from words repository
  --extract             Stage 2:  Extract content from backup archives
  --parse               Stage 3:  Parse poems from JSON sources into poems.json
  --validate            Stage 4:  Run poem validation
  --catalog-images      Stage 5:  Catalog images from input directories
  --generate-embeddings Stage 6:  Generate embeddings via Ollama (~2-3 hours)
  --generate-similarity Stage 7:  Build similarity matrix (~30 min)
  --generate-diversity  Stage 8:  Pre-compute diversity cache (~42 hours)
  --generate-html       Stage 9:  Generate website HTML pages
  --generate-index      Stage 10: Generate numeric similarity index

Stage Groups:
  --all               Run stages 1-5, 9-10 (default - skips expensive stages)
  --full              Run ALL stages 1-10 including embeddings (~45 hours total)

Stage Configuration:
  --threads N         Thread count for parallel operations (default: 4)
  --force             Force regeneration even if files are fresh
  --force-stage N     Force regenerate specific stage only (1-10)
  --model NAME        Embedding model name (default: qwen3-embedding:4b)

Pagination (HTML Generation):
  --pages N           Pages per poem (default: from config, 1)
  --poems-per-page N  Poems per page for similar/different (default: 200)
  --chrono-per-page N Poems per page for chronological (default: 500)

Word Cloud:
  --wordcloud-all     Include all words (ignore max_words limit)
  --wordcloud-words N Number of words in word cloud (default: 200)
  --wordcloud-poems N Poems per word-cloud page (default: 50)

Extraction Options:
  --include-boosts    Include fediverse boosts/reblogs in extraction

External Files (Issue 10-003b):
  --list-external     List configured external file sources
  --sync-only NAME    Sync only the specified external source

Ollama Server (Issue 10-017):
  --ollama NAME       Use specific Ollama server from config.lua
  --model NAME        Override embedding model (default from server config)
  --list-ollama       List available Ollama servers and exit

Output Control:
  --quiet             Suppress progress messages
  --verbose           Show detailed progress
  --dry-run           Show what would be executed without running
  --cpu-only          Force CPU execution (disable GPU acceleration)
  --low-priority      Run compute-heavy stages at lower OS priority (nice -n 10)
                      Keeps desktop/terminal responsive during long operations

Interactive Mode:
  -I, --interactive   Launch TUI for interactive selection (with command preview)

Directory Options:
  --dir PATH          Assets directory (where poems.json etc. are stored)
  --output PATH       Output directory (default: output/)

Other:
  -h, --help          Show this help message

Examples:
  ./run.sh                              # Run fast stages (1-5, 9-10)
  ./run.sh --full                       # Run ALL stages including embeddings
  ./run.sh --generate-html              # Only regenerate HTML
  ./run.sh --generate-embeddings        # Only generate embeddings
  ./run.sh --parse --generate-html      # Parse then generate HTML
  ./run.sh --generate-html --threads 8  # HTML with 8 threads
  ./run.sh --generate-html --pages 5    # Generate top 500 poems per file
  ./run.sh --all --dry-run              # Preview what would run
  ./run.sh -I                           # Interactive TUI mode

Notes:
  - Stages 6-8 are expensive and excluded from --all by default
  - Stage 6 (embeddings) requires Ollama running with embedding model
  - Stage 8 (diversity) takes ~42 hours but is a one-time cost
  - Once stages 6-8 complete, subsequent runs use cached data
EOF
}
# }}}

# {{{ Parse command line arguments
DIR=""
ASSETS_DIR=""
OUTPUT_DIR=""
INTERACTIVE=false

# Stage flags (boolean)
UPDATE_WORDS=false
EXTRACT=false
PARSE=false
VALIDATE=false
CATALOG_IMAGES=false
GENERATE_EMBEDDINGS=false
GENERATE_SIMILARITY=false
GENERATE_DIVERSITY=false
GENERATE_HTML=false
GENERATE_INDEX=false

# Config flags
THREADS=""
FORCE=false
# Issue 10-016: Per-stage force flags
FORCE_STAGE_1=false
FORCE_STAGE_2=false
FORCE_STAGE_3=false
FORCE_STAGE_4=false
FORCE_STAGE_5=false
FORCE_STAGE_6=false
FORCE_STAGE_7=false
FORCE_STAGE_8=false
FORCE_STAGE_9=false
FORCE_STAGE_10=false
QUIET=false
VERBOSE=false
DRY_RUN=false
CPU_ONLY=false
# Issue 10-028: Lower process priority for UI responsiveness
LOW_PRIORITY=false
MODEL_NAME="qwen3-embedding:4b"
# Issue 8-022: Pagination settings for HTML generation
PAGES=""
POEMS_PER_PAGE=""

# Issue 8-043: Word cloud configuration
WORDCLOUD_ALL=false
WORDCLOUD_WORDS=""
# Issue 8-050d: Poems per word-cloud page
WORDCLOUD_POEMS=""

# Issue 8-011: Fediverse boost inclusion (extraction stage)
INCLUDE_BOOSTS=false

# Issue 10-003b: External file management
LIST_EXTERNAL=false
SYNC_ONLY=""

# Issue 10-017: Ollama server configuration
OLLAMA_SERVER=""
LIST_OLLAMA=false

# Track if any stage flag was explicitly set
STAGE_FLAG_SET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -I|--interactive)
            INTERACTIVE=true
            shift
            ;;
        --dir)
            ASSETS_DIR="$2"
            shift 2
            ;;
        --dir=*)
            ASSETS_DIR="${1#*=}"
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --threads=*)
            THREADS="${1#*=}"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        # Issue 10-016: Per-stage force regeneration (space-separated format)
        --force-stage)
            stage_num="$2"
            case "$stage_num" in
                1) FORCE_STAGE_1=true ;;
                2) FORCE_STAGE_2=true ;;
                3) FORCE_STAGE_3=true ;;
                4) FORCE_STAGE_4=true ;;
                5) FORCE_STAGE_5=true ;;
                6) FORCE_STAGE_6=true ;;
                7) FORCE_STAGE_7=true ;;
                8) FORCE_STAGE_8=true ;;
                9) FORCE_STAGE_9=true ;;
                10) FORCE_STAGE_10=true ;;
                *)
                    echo "ERROR: Invalid stage number: $stage_num (valid: 1-10)" >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        # Issue 10-016: Per-stage force regeneration (= format for backward compatibility)
        --force-stage=*)
            stage_num="${1#*=}"
            case "$stage_num" in
                1) FORCE_STAGE_1=true ;;
                2) FORCE_STAGE_2=true ;;
                3) FORCE_STAGE_3=true ;;
                4) FORCE_STAGE_4=true ;;
                5) FORCE_STAGE_5=true ;;
                6) FORCE_STAGE_6=true ;;
                7) FORCE_STAGE_7=true ;;
                8) FORCE_STAGE_8=true ;;
                9) FORCE_STAGE_9=true ;;
                10) FORCE_STAGE_10=true ;;
                *)
                    echo "ERROR: Invalid stage number: $stage_num (valid: 1-10)" >&2
                    exit 1
                    ;;
            esac
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --cpu-only)
            CPU_ONLY=true
            shift
            ;;
        # Issue 10-028: Lower process priority for UI responsiveness
        --low-priority)
            LOW_PRIORITY=true
            shift
            ;;
        --model)
            MODEL_NAME="$2"
            shift 2
            ;;
        --model=*)
            MODEL_NAME="${1#*=}"
            shift
            ;;
        # Issue 8-022: Pagination flags for HTML generation
        --pages)
            PAGES="$2"
            shift 2
            ;;
        --pages=*)
            PAGES="${1#*=}"
            shift
            ;;
        --poems-per-page)
            POEMS_PER_PAGE="$2"
            shift 2
            ;;
        --poems-per-page=*)
            POEMS_PER_PAGE="${1#*=}"
            shift
            ;;
        --chrono-per-page)
            CHRONO_PER_PAGE="$2"
            shift 2
            ;;
        --chrono-per-page=*)
            CHRONO_PER_PAGE="${1#*=}"
            shift
            ;;
        # Issue 8-043: Word cloud configuration
        --wordcloud-all)
            WORDCLOUD_ALL=true
            shift
            ;;
        --wordcloud-words)
            WORDCLOUD_WORDS="$2"
            shift 2
            ;;
        --wordcloud-words=*)
            WORDCLOUD_WORDS="${1#*=}"
            shift
            ;;
        # Issue 8-050d: Poems per word-cloud page
        --wordcloud-poems)
            WORDCLOUD_POEMS="$2"
            shift 2
            ;;
        --wordcloud-poems=*)
            WORDCLOUD_POEMS="${1#*=}"
            shift
            ;;
        # Issue 8-011: Fediverse boost inclusion
        --include-boosts)
            INCLUDE_BOOSTS=true
            shift
            ;;
        # Issue 10-003b: External file management
        --list-external)
            LIST_EXTERNAL=true
            shift
            ;;
        --sync-only)
            SYNC_ONLY="$2"
            shift 2
            ;;
        --sync-only=*)
            SYNC_ONLY="${1#*=}"
            shift
            ;;
        # Issue 10-017: Ollama server configuration
        --ollama)
            OLLAMA_SERVER="$2"
            shift 2
            ;;
        --ollama=*)
            OLLAMA_SERVER="${1#*=}"
            shift
            ;;
        --list-ollama)
            LIST_OLLAMA=true
            shift
            ;;
        # Stage flags
        --update-words)
            UPDATE_WORDS=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --extract)
            EXTRACT=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --parse)
            PARSE=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --validate)
            VALIDATE=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --catalog-images)
            CATALOG_IMAGES=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-embeddings)
            GENERATE_EMBEDDINGS=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-similarity)
            GENERATE_SIMILARITY=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-diversity)
            GENERATE_DIVERSITY=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-html)
            GENERATE_HTML=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-index)
            GENERATE_INDEX=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --all)
            # Fast stages only (1-5, 9-10) - skips expensive embedding stages
            UPDATE_WORDS=true
            EXTRACT=true
            PARSE=true
            VALIDATE=true
            CATALOG_IMAGES=true
            GENERATE_HTML=true
            GENERATE_INDEX=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --full)
            # ALL stages including expensive embedding generation (1-10)
            UPDATE_WORDS=true
            EXTRACT=true
            PARSE=true
            VALIDATE=true
            CATALOG_IMAGES=true
            GENERATE_EMBEDDINGS=true
            GENERATE_SIMILARITY=true
            GENERATE_DIVERSITY=true
            GENERATE_HTML=true
            GENERATE_INDEX=true
            STAGE_FLAG_SET=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# If no stage flags were specified, run fast stages only (backward compatible)
# This is equivalent to --all (stages 1-5, 9-10)
if ! $STAGE_FLAG_SET; then
    UPDATE_WORDS=true
    EXTRACT=true
    PARSE=true
    VALIDATE=true
    CATALOG_IMAGES=true
    # Skipping expensive stages 6-8 by default (use --full for all)
    GENERATE_HTML=true
    GENERATE_INDEX=true
fi

# Issue 8-032: Convert FORCE to Lua boolean for passing to Lua functions
if $FORCE; then
    FORCE_LUA="true"
else
    FORCE_LUA="false"
fi

# Issue 10-028: Set up nice prefix for low priority execution
# When enabled, heavy operations run at nice level 10 (lower priority)
# This keeps the desktop/terminal responsive during long pipeline runs
NICE_PREFIX=""
if $LOW_PRIORITY; then
    NICE_PREFIX="nice -n 10"
fi
# }}}

# {{{ Setup directories
DIR=$(setup_dir_path "$DIR")

# Build arguments for Lua scripts
ASSETS_ARG=""
if [ -n "$ASSETS_DIR" ]; then
    ASSETS_ARG="--dir $ASSETS_DIR"
fi

# Ensure we're in the right directory
cd "$DIR" || {
    echo "Error: Could not access directory $DIR" >&2
    exit 1
}
# }}}

# {{{ Issue 10-003b: Handle external file commands (immediate actions)
if $LIST_EXTERNAL; then
    "$DIR/scripts/sync-external-files" --list
    exit 0
fi

if [ -n "$SYNC_ONLY" ]; then
    "$DIR/scripts/sync-external-files" "$SYNC_ONLY"
    exit $?
fi
# }}}

# {{{ Issue 10-017: Handle Ollama server commands (immediate actions)
if $LIST_OLLAMA; then
    luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local ollama = require('ollama-config')
        ollama.list_servers()
    "
    exit 0
fi
# }}}

# {{{ Logging functions
log_info() {
    if ! $QUIET; then
        echo "$1"
    fi
}

log_verbose() {
    if $VERBOSE; then
        echo "$1"
    fi
}

log_stage() {
    if ! $QUIET; then
        echo ""
        echo -e "${COLOR_MAGENTA}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}$1${COLOR_RESET}"
        echo -e "${COLOR_MAGENTA}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    fi
}

log_dry_run() {
    echo "[DRY-RUN] Would execute: $1"
}

# ANSI color codes for terminal output
# These add visual distinction to success/info/error messages
COLOR_GREEN="\033[92m"    # Bright green for success (✓, ✅)
COLOR_BLUE="\033[94m"     # Bright blue for info (ℹ️)
COLOR_RED="\033[91m"      # Bright red for errors (✗, ❌)
COLOR_YELLOW="\033[93m"   # Bright yellow for warnings (⚠️)
COLOR_MAGENTA="\033[95m"  # Bright magenta for stage delimiters
COLOR_RESET="\033[0m"     # Reset to default

# Colored symbol helpers
symbol_success() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
}

symbol_info() {
    echo -e "${COLOR_BLUE}$1${COLOR_RESET}"
}

symbol_error() {
    echo -e "${COLOR_RED}$1${COLOR_RESET}"
}

symbol_warning() {
    echo -e "${COLOR_YELLOW}$1${COLOR_RESET}"
}
# }}}

# {{{ Stage execution functions

# {{{ run_update_words
run_update_words() {
    log_stage "📁 Stage 1/10: Updating input files from words repository"

    # Issue 10-016: Check both global and per-stage force flags (Stage 1)
    local stage_force=$FORCE
    $FORCE_STAGE_1 && stage_force=true

    # Issue 7-003: Pass force flag to skip file preservation
    local force_flag=""
    if $stage_force; then
        force_flag="--force"
    fi

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update-words $force_flag"
        return 0
    fi

    "$DIR/scripts/update-words" $force_flag || {
        echo "Warning: Failed to update input files, continuing anyway..." >&2
    }
}
# }}}

# {{{ run_extract
run_extract() {
    log_stage "🔄 Stage 2/10: Extracting content from backup archives"

    # Issue 8-011: Build boost inclusion flag
    local boost_flag=""
    if $INCLUDE_BOOSTS; then
        boost_flag="--include-boosts"
    fi

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update $DIR $boost_flag"
        return 0
    fi

    "$DIR/scripts/update" "$DIR" $boost_flag || {
        echo "Error: Content extraction failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_parse
run_parse() {
    log_stage "📝 Stage 3/10: Parsing poems from JSON sources"

    # Issue 10-016: Check both global and per-stage force flags (Stage 3)
    local stage_force=$FORCE
    $FORCE_STAGE_3 && stage_force=true

    local force_arg=""
    if $stage_force; then
        force_arg="--force"
    fi

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --parse-only $force_arg $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --parse-only $force_arg $ASSETS_ARG || {
        echo "Error: Poem parsing failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_validate
run_validate() {
    log_stage "$(symbol_success "✓") Stage 4/10: Validating poem data"

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --validate-only $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --validate-only $ASSETS_ARG || {
        echo "Error: Poem validation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_catalog_images
# Issue 10-015a: Pass --verbose flag to show detailed image catalog statistics
run_catalog_images() {
    log_stage "🖼️ Stage 5/10: Cataloging images"

    # Build verbose argument if enabled
    local VERBOSE_ARG=""
    $VERBOSE && VERBOSE_ARG="--verbose"

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --catalog-only $VERBOSE_ARG $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --catalog-only $VERBOSE_ARG $ASSETS_ARG || {
        echo "Error: Image cataloging failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_embeddings
run_generate_embeddings() {
    log_stage "🧠 Stage 6/10: Generating embeddings via Ollama (~2-3 hours)"

    # Convert model name for directory (embeddinggemma:latest -> embeddinggemma_latest)
    local model_dir_name="${MODEL_NAME//:/_}"
    local embeddings_file="$DIR/assets/embeddings/$model_dir_name/embeddings.json"
    local poems_file="$DIR/assets/poems.json"

    # Issue 10-016: Check both global and per-stage force flags
    local stage_force=$FORCE
    $FORCE_STAGE_6 && stage_force=true

    # Freshness check: skip if embeddings.json newer than poems.json
    if ! $stage_force && [ -f "$embeddings_file" ] && [ -f "$poems_file" ]; then
        if [ "$embeddings_file" -nt "$poems_file" ]; then
            log_info "   ⏭️  Embeddings are fresh (newer than poems.json), skipping..."
            log_verbose "   embeddings: $(stat -c %Y "$embeddings_file" 2>/dev/null || echo 'N/A')"
            log_verbose "   poems.json: $(stat -c %Y "$poems_file" 2>/dev/null || echo 'N/A')"
            return 0
        fi
    fi

    local force_arg=""
    if $stage_force; then
        force_arg="--full-regen"
    else
        force_arg="--incremental"
    fi

    # Issue 10-017: Build Ollama server argument
    local ollama_arg=""
    if [ -n "$OLLAMA_SERVER" ]; then
        ollama_arg="--ollama=$OLLAMA_SERVER"
    fi

    if $DRY_RUN; then
        log_dry_run "$DIR/generate-embeddings.sh $force_arg --model=$MODEL_NAME $ollama_arg $DIR"
        log_dry_run "luajit $DIR/src/generate-word-pages.lua $DIR --embeddings-only"
        return 0
    fi

    if [ -n "$OLLAMA_SERVER" ]; then
        log_info "   Ollama Server: $OLLAMA_SERVER"
    fi
    log_info "   Model: $MODEL_NAME"
    log_info "   Output: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Mode: $(if $FORCE; then echo 'full regeneration'; else echo 'incremental (skip existing)'; fi)"

    # Issue 10-028: Apply low priority to expensive embedding generation
    $NICE_PREFIX "$DIR/generate-embeddings.sh" $force_arg --model="$MODEL_NAME" $ollama_arg "$DIR" || {
        echo "Error: Embedding generation failed" >&2
        echo "Make sure Ollama is running with the $MODEL_NAME model" >&2
        exit 1
    }

    # Issue 8-043b: Generate word embeddings (part of embedding stage)
    # Fix: Pass word cloud flags to embedding stage (was missing --all/--words flags)
    log_info "   Generating word embeddings for word cloud..."
    local wordcloud_args=""
    if $WORDCLOUD_ALL; then
        wordcloud_args="--all"
    elif [ -n "$WORDCLOUD_WORDS" ]; then
        wordcloud_args="--words $WORDCLOUD_WORDS"
    fi
    $NICE_PREFIX luajit "$DIR/src/generate-word-pages.lua" "$DIR" --embeddings-only $wordcloud_args || {
        echo "Warning: Word embedding generation failed, continuing..." >&2
    }
}
# }}}

# {{{ run_generate_semantic_colors
run_generate_semantic_colors() {
    # Regenerate poem_colors.json if stale or missing
    # This runs BEFORE similarity matrix generation (Stage 6.5)
    # Requires: embeddings.json, color_embeddings.json
    # Respects: --force (skip freshness check), --dry-run (show actions only)

    local model_dir_name="${MODEL_NAME//:/_}"

    # Paths match what generate-embeddings.sh writes (see run_generate_embeddings above).
    # The stray assets/embeddings/embeddings/ directory on disk is a stale leftover from
    # before the model-name subfolder convention; it is not the real output location.
    local embeddings_file="$DIR/assets/embeddings/$model_dir_name/embeddings.json"
    local poem_colors_file="$DIR/assets/embeddings/$model_dir_name/poem_colors.json"
    local color_embeddings_file="$DIR/assets/embeddings/$model_dir_name/color_embeddings.json"

    # Embeddings must exist first (exit early if not - prevents confusing errors)
    if [ ! -f "$embeddings_file" ]; then
        log_verbose "   Skipping semantic colors - embeddings not yet generated"
        return 0
    fi

    # Check if color embeddings exist (generated once, reused)
    if [ ! -f "$color_embeddings_file" ]; then
        log_stage "🎨 Stage 6.5/10: Generating color embeddings (one-time)"

        if $DRY_RUN; then
            log_dry_run "luajit semantic-color-calculator (generate color embeddings)"
            # Still need to skip poem colors generation in dry run
        else
            log_info "   $(symbol_warning "⚠️")  Color embeddings not found, generating via Ollama..."
            # Issue 10-003 migrated color_names from config/semantic-colors.json (now deleted)
            # into config.lua, loaded via libs/config-loader.lua. Errors here are loud rather
            # than silent so a missing config doesn't propagate downstream as a confusing
            # "Failed to load required data files" in the next stage.
            luajit -e "
                package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
                local calc = require('semantic-color-calculator')
                local utils = require('utils')
                utils.init_assets_root({'$DIR'})

                -- Mirror the --ollama selection pattern used elsewhere in run.sh
                -- (see the interactive TUI block below). If OLLAMA_SERVER is empty
                -- the module falls back to config.lua's default_ollama_server.
                -- The interactive flag is forwarded so that a typoed --ollama or
                -- --model triggers a 1/2 prompt only when the operator launched
                -- run.sh with -I; otherwise we hard-error.
                local ollama = require('ollama-config')
                ollama.set_project_root('$DIR')
                ollama.set_interactive_mode('$INTERACTIVE' == 'true')
                if '$OLLAMA_SERVER' ~= '' then
                    ollama.set_selected_server('$OLLAMA_SERVER')
                end

                local config = require('config-loader').load()
                if not config.color_names then
                    error('config.lua is missing color_names (Issue 10-003 migration)')
                end
                local embeddings = calc.generate_color_embeddings_using_ollama(config.color_names, '$MODEL_NAME')
                if not next(embeddings) then
                    error('Ollama returned no color embeddings')
                end
                local data = {embeddings = embeddings, generated_at = os.date('%Y-%m-%d %H:%M:%S'), model_name = '$MODEL_NAME'}
                utils.write_json_file('$color_embeddings_file', data)
                print('[INFO] Color embeddings saved: ' .. '$color_embeddings_file')
            " || {
                echo "Error: Color embedding generation failed" >&2
                exit 1
            }
        fi
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 6)
    local stage_force=$FORCE
    $FORCE_STAGE_6 && stage_force=true

    # Check freshness: poem_colors.json should be newer than embeddings.json
    # With --force or --force-stage 6: always regenerate regardless of freshness
    if ! $stage_force && [ -f "$poem_colors_file" ] && [ -f "$embeddings_file" ]; then
        if [ "$poem_colors_file" -nt "$embeddings_file" ]; then
            log_info "   ⏭️  Semantic colors are fresh (newer than embeddings), skipping..."
            return 0
        fi
        log_verbose "   poem_colors.json is stale (older than embeddings), regenerating..."
    elif $stage_force; then
        log_verbose "   --force specified, regenerating semantic colors..."
    fi

    log_stage "🎨 Stage 6b/10: Computing semantic colors (part of embeddings)"

    if $DRY_RUN; then
        log_dry_run "luajit semantic-color-calculator (poem colors regeneration)"
        return 0
    fi

    log_info "   Input: $embeddings_file"
    log_info "   Output: $poem_colors_file"

    # Regenerate poem colors using existing embeddings
    luajit -e "
        package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
        local calc = require('semantic-color-calculator')
        local utils = require('utils')
        utils.init_assets_root({'$DIR'})

        local poems_data = utils.read_json_file(utils.asset_path('poems.json'))
        local embeddings_data = utils.read_json_file('$embeddings_file')
        local color_embeddings_data = utils.read_json_file('$color_embeddings_file')

        if poems_data and embeddings_data and color_embeddings_data then
            calc.precompute_poem_colors(poems_data, embeddings_data, color_embeddings_data.embeddings, '$poem_colors_file')
        else
            error('Failed to load required data files')
        end
    " || {
        echo "Error: Semantic color generation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_similarity
run_generate_similarity() {
    # Determine execution method: GPU (default) or CPU (--cpu-only only)
    local use_gpu=false
    if ! $CPU_ONLY; then
        # GPU is required unless --cpu-only is specified
        if [ -f "$DIR/libs/vulkan-compute/build/libvkcompute.so" ]; then
            use_gpu=true
            log_stage "📊 Stage 7/10: Building similarity matrix with GPU (~5-10 min)"
        else
            echo "Error: GPU library not found: libs/vulkan-compute/build/libvkcompute.so" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Build GPU library: cd libs/vulkan-compute && make" >&2
            echo "  2. Use CPU instead: ./run.sh --generate-similarity --cpu-only" >&2
            echo "" >&2
            echo "Note: GPU acceleration is 6x faster (~5-10 min vs ~30 min)" >&2
            exit 1
        fi
    else
        log_stage "📊 Stage 7/10: Building similarity matrix with CPU (~30 min, --cpu-only)"
    fi

    # Convert model name for directory
    local model_dir_name="${MODEL_NAME//:/_}"
    local embeddings_file="$DIR/assets/embeddings/$model_dir_name/embeddings.json"

    # Check if embeddings exist
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: Embeddings file not found: $embeddings_file" >&2
        echo "Run --generate-embeddings first" >&2
        exit 1
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 7)
    local stage_force=$FORCE
    $FORCE_STAGE_7 && stage_force=true

    # Issue 8-033: Check for individual similarity files instead of monolithic matrix
    local similarities_dir="$DIR/assets/embeddings/$model_dir_name/similarities"
    local similarity_count=0
    if [ -d "$similarities_dir" ]; then
        similarity_count=$(find "$similarities_dir" -name "poem_*.json" 2>/dev/null | wc -l)
    fi

    # Freshness check: skip if we have all files and they're fresh
    if ! $stage_force && [ "$similarity_count" -ge 7797 ]; then
        # Check if any are older than embeddings (check newest file)
        local newest_similarity=$(find "$similarities_dir" -name "poem_*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
        if [ -n "$newest_similarity" ] && [ "$newest_similarity" -nt "$embeddings_file" ]; then
            log_info "   ⏭️  Similarity files are fresh ($similarity_count files newer than embeddings), skipping..."
            return 0
        fi
    fi

    local threads_arg=""
    if [ -n "$THREADS" ]; then
        threads_arg="--threads=$THREADS"
    fi

    if $DRY_RUN; then
        log_dry_run "luajit $DIR/src/similarity-engine.lua --generate-matrix $threads_arg $DIR"
        return 0
    fi

    log_info "   Input: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Output: assets/embeddings/$model_dir_name/similarities/*.json (individual files)"

    # Issue 10-016: Convert stage_force to Lua boolean for Lua function calls
    local stage_force_lua="false"
    $stage_force && stage_force_lua="true"

    if $use_gpu; then
        # GPU similarity generation using Vulkan compute shaders
        log_info "   Mode: GPU-accelerated (Vulkan)"

        # Pass threads value to GPU similarity (defaults to 8 if not specified)
        local default_threads=8
        local threads_to_use=${THREADS:-$default_threads}
        log_info "   CPU sorting threads: $threads_to_use"

        DIR="$DIR" luajit -e "
            package.path = '$DIR/?.lua;$DIR/?/init.lua;$DIR/libs/?.lua;' .. package.path
            local vk_sim = require('libs.vulkan-compute.lua.vk_similarity')
            -- Use TRUE parallel GPU computation (Issue 9-002 original design)
            local success = vk_sim.generate_similarity_matrix_gpu_parallel(
                '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
                '$MODEL_NAME',
                $stage_force_lua,
                $threads_to_use
            )
            if not success then
                print('[GPU SIMILARITY ERROR] GPU generation failed')
                print('Use --cpu-only to force CPU execution')
                os.exit(1)
            end
        " || {
            echo "Error: GPU similarity generation failed" >&2
            echo "Use --cpu-only flag to force CPU execution instead" >&2
            exit 1
        }
    else
        # CPU implementation (only when --cpu-only is explicitly specified)
        log_info "   Mode: CPU (multithreaded)"
        # Issue 8-033: Use parallel engine for individual files (not monolithic matrix)
        # Fixes table overflow error at ~68% when using calculate_full_similarity_matrix
        # Function: calculate_similarity_matrix_parallel(embeddings_file, model_name, sleep_duration, force_regenerate, requested_threads)
        local default_threads=8
        local threads_to_use=${THREADS:-$default_threads}

        luajit -e "
            package.path = '$DIR/?.lua;$DIR/?/init.lua;' .. package.path
            package.cpath = '/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so;' .. package.cpath
            local sim_parallel = require('src.similarity-engine-parallel')
            local sleep = 0.5
            local threads = $threads_to_use
            sim_parallel.calculate_similarity_matrix_parallel(
                '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
                '$MODEL_NAME',
                sleep,
                $stage_force_lua,
                threads
            )
        " || {
            echo "Error: Similarity matrix generation failed" >&2
            exit 1
        }
    fi

    # Note: Pre-sorted similarity rankings cache is now generated automatically
    # by the GPU similarity engine (in-RAM, no file re-reading needed)
}
# }}}

# {{{ run_generate_diversity
run_generate_diversity() {
    # Determine execution method: GPU (default) or CPU (--cpu-only only)
    local use_gpu=false
    if ! $CPU_ONLY; then
        # GPU is required unless --cpu-only is specified
        if [ -f "$DIR/libs/vulkan-compute/build/libvkcompute.so" ]; then
            use_gpu=true
            log_stage "🎲 Stage 8/10: Pre-computing diversity cache with GPU (~1 min)"
        else
            echo "Error: GPU library not found: libs/vulkan-compute/build/libvkcompute.so" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Build GPU library: cd libs/vulkan-compute && make" >&2
            echo "  2. Use CPU instead: ./run.sh --generate-diversity --cpu-only" >&2
            echo "" >&2
            echo "Note: GPU acceleration is 2,600× faster (~1 min vs ~42 hours)" >&2
            exit 1
        fi
    else
        log_stage "🎲 Stage 8/10: Pre-computing diversity cache with CPU (~42 hours, --cpu-only)"
    fi

    # Convert model name for directory
    local model_dir_name="${MODEL_NAME//:/_}"
    local cache_file="$DIR/assets/embeddings/$model_dir_name/diversity_cache.json"
    local embeddings_file="$DIR/assets/embeddings/$model_dir_name/embeddings.json"

    # Check if embeddings exist
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: Embeddings file not found: $embeddings_file" >&2
        echo "Run --generate-embeddings first" >&2
        exit 1
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 8)
    local stage_force=$FORCE
    $FORCE_STAGE_8 && stage_force=true

    # Freshness check: skip if cache newer than embeddings
    if ! $stage_force && [ -f "$cache_file" ]; then
        if [ "$cache_file" -nt "$embeddings_file" ]; then
            log_info "   ⏭️  Diversity cache is fresh (newer than embeddings), skipping..."
            return 0
        fi
    fi

    log_info "   Input: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Output: assets/embeddings/$model_dir_name/diversity_cache.json"

    if $use_gpu; then
        # GPU diversity generation using Vulkan compute shaders
        log_info "   Mode: GPU-accelerated (Vulkan)"

        if $DRY_RUN; then
            log_dry_run "$DIR/scripts/precompute-diversity-sequences-gpu $DIR"
            return 0
        fi

        # Issue 10-028: Apply low priority to expensive diversity generation
        # Export MODEL_NAME so the wrapper resolves the correct embeddings
        # directory (assets/embeddings/<model>/) when run.sh is what selected
        # the model. Without this the wrapper falls back to config.lua's
        # default, which is correct in most cases but loses the CLI override.
        MODEL_NAME="$MODEL_NAME" $NICE_PREFIX "$DIR/scripts/precompute-diversity-sequences-gpu" "$DIR" || {
            echo "Error: GPU diversity cache generation failed" >&2
            echo "Use --cpu-only flag to force CPU execution instead" >&2
            exit 1
        }
    else
        # CPU implementation (only when --cpu-only is explicitly specified)
        log_info "   Mode: CPU (effil-based)"
        log_info "   $(symbol_warning "⚠️")  This is a one-time cost (~42 hours). Results will be cached."

        # Issue 8-027: Build command with pagination flags
        if [ -n "$THREADS" ]; then
            export DIVERSITY_THREADS="$THREADS"
        fi

        local pagination_args=""
        if [ -n "$PAGES" ]; then
            pagination_args="$pagination_args --pages=$PAGES"
        fi
        if [ -n "$POEMS_PER_PAGE" ]; then
            pagination_args="$pagination_args --poems-per-page=$POEMS_PER_PAGE"
        fi

        if $DRY_RUN; then
            log_dry_run "luajit $DIR/scripts/precompute-diversity-sequences $DIR $pagination_args"
            return 0
        fi

        # Issue 10-028: Apply low priority to expensive CPU diversity generation
        $NICE_PREFIX luajit "$DIR/scripts/precompute-diversity-sequences" "$DIR" $pagination_args || {
            echo "Error: Diversity cache generation failed" >&2
            exit 1
        }
    fi
}
# }}}

# {{{ run_generate_html
run_generate_html() {
    log_stage "🌐 Stage 9/10: Generating website HTML"

    # Issue 10-016: Check both global and per-stage force flags (Stage 9)
    local stage_force=$FORCE
    $FORCE_STAGE_9 && stage_force=true

    # Issue 10-024: Clear output directories when forcing regeneration
    # This prevents stale files with obsolete poem_index values from persisting
    # after poem re-extraction changes the poem_index assignments
    if $stage_force; then
        log_info "   Clearing stale HTML files (--force)..."
        rm -f "$DIR/output/similar/"*.html 2>/dev/null
        rm -f "$DIR/output/different/"*.html 2>/dev/null
        rm -f "$DIR/output/chronological/"*.html 2>/dev/null
    fi

    local force_arg=""
    if $stage_force; then
        force_arg="--force"
    fi

    local threads_arg=""
    if [ -n "$THREADS" ]; then
        threads_arg="--threads $THREADS"
    fi

    # Issue 8-022: Pagination arguments
    local pages_arg=""
    if [ -n "$PAGES" ]; then
        pages_arg="--pages $PAGES"
    fi

    local poems_per_page_arg=""
    if [ -n "$POEMS_PER_PAGE" ]; then
        poems_per_page_arg="--poems-per-page $POEMS_PER_PAGE"
    fi

    local chrono_per_page_arg=""
    if [ -n "$CHRONO_PER_PAGE" ]; then
        chrono_per_page_arg="--chrono-per-page $CHRONO_PER_PAGE"
    fi

    # Issue 8-043: Word cloud arguments
    local wordcloud_all_arg=""
    if $WORDCLOUD_ALL; then
        wordcloud_all_arg="--all"
    fi

    local wordcloud_words_arg=""
    if [ -n "$WORDCLOUD_WORDS" ]; then
        wordcloud_words_arg="--words $WORDCLOUD_WORDS"
    fi

    # Issue 8-050d: Poems per word-cloud page
    local wordcloud_poems_arg=""
    if [ -n "$WORDCLOUD_POEMS" ]; then
        wordcloud_poems_arg="--poems-per-page $WORDCLOUD_POEMS"
    fi

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --html-only $force_arg $threads_arg $pages_arg $poems_per_page_arg $chrono_per_page_arg $ASSETS_ARG"
        log_dry_run "luajit $DIR/src/wordcloud-generator.lua $DIR $wordcloud_all_arg $wordcloud_words_arg"
        log_dry_run "luajit $DIR/src/generate-word-pages.lua $DIR --html-only $wordcloud_all_arg $wordcloud_words_arg $wordcloud_poems_arg"
        return 0
    fi

    # Issue 10-028: Apply low priority to HTML generation (parallel processing)
    $NICE_PREFIX luajit src/main.lua "$DIR" --html-only $force_arg $threads_arg $pages_arg $poems_per_page_arg $chrono_per_page_arg $ASSETS_ARG || {
        echo "Error: HTML generation failed" >&2
        exit 1
    }

    # Issue 8-043b: Generate word cloud pages (part of HTML stage)
    log_info "   Generating word cloud menu..."
    $NICE_PREFIX luajit "$DIR/src/wordcloud-generator.lua" "$DIR" $wordcloud_all_arg $wordcloud_words_arg || {
        echo "Warning: Word cloud menu generation failed, continuing..." >&2
    }

    log_info "   Generating word similarity pages..."
    $NICE_PREFIX luajit "$DIR/src/generate-word-pages.lua" "$DIR" --html-only $wordcloud_all_arg $wordcloud_words_arg $wordcloud_poems_arg || {
        echo "Warning: Word similarity page generation failed, continuing..." >&2
    }
}
# }}}

# {{{ run_generate_index
run_generate_index() {
    log_stage "🔢 Stage 10/10: Generating numeric similarity index"

    if $DRY_RUN; then
        log_dry_run "lua $DIR/scripts/generate-numeric-index $DIR $ASSETS_ARG"
        return 0
    fi

    lua "$DIR/scripts/generate-numeric-index" "$DIR" $ASSETS_ARG > /dev/null || {
        echo "Error: Numeric index generation failed" >&2
        exit 1
    }
}
# }}}

# }}}

# {{{ interactive_mode_tui
# TUI-based interactive mode with command preview
# Uses Lua menu library for stable rendering and real-time command preview
interactive_mode_tui() {
    if ! $TUI_AVAILABLE; then
        echo "ERROR: TUI library not available." >&2
        echo "Falling back to Lua-based interactive mode..." >&2
        luajit src/main.lua "$DIR" -I $ASSETS_ARG
        return $?
    fi

    # Initialize TUI
    if ! tui_init; then
        echo "ERROR: TUI initialization failed." >&2
        echo "Falling back to Lua-based interactive mode..." >&2
        luajit src/main.lua "$DIR" -I $ASSETS_ARG
        return $?
    fi

    # Build the menu
    menu_init
    menu_set_title "Neocities Pipeline" "Use j/k to navigate, space to toggle, Enter to run"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 1: Pipeline Stages (multi - can select multiple)
    # Each checkbox maps to a CLI flag for command preview
    # Issue 10-016: Force regeneration moved here with per-stage options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "stages" "multi" "Pipeline Stages (toggle stages to run)"

    # Issue 10-016: Global force regenerate option at top of stages
    menu_add_item "stages" "force" "Force regenerate ALL stages" "checkbox" "0" \
        "Force regeneration even if files are fresh" "" "--force"

    menu_add_item "stages" "update_words" "1. Update Words" "checkbox" "1" \
        "Sync input files from words repository" "" "--update-words"
    menu_add_item "stages" "force_update_words" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 1"

    menu_add_item "stages" "extract" "2. Extract" "checkbox" "1" \
        "Extract content from backup archives" "" "--extract"
    menu_add_item "stages" "force_extract" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 2"

    menu_add_item "stages" "parse" "3. Parse" "checkbox" "1" \
        "Parse poems from JSON sources into poems.json" "" "--parse"
    menu_add_item "stages" "force_parse" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 3"

    menu_add_item "stages" "validate" "4. Validate" "checkbox" "1" \
        "Run poem validation" "" "--validate"
    menu_add_item "stages" "force_validate" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 4"

    menu_add_item "stages" "catalog_images" "5. Catalog Images" "checkbox" "1" \
        "Catalog images from input directories" "" "--catalog-images"
    menu_add_item "stages" "force_catalog_images" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 5"

    menu_add_item "stages" "generate_embeddings" "6. Embeddings ⚠️" "checkbox" "0" \
        "Generate embeddings via Ollama (~2-3 hours)" "" "--generate-embeddings"
    menu_add_item "stages" "force_generate_embeddings" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 6"

    menu_add_item "stages" "generate_similarity" "7. Similarity ⚠️" "checkbox" "0" \
        "Build similarity matrix (~30 min)" "" "--generate-similarity"
    menu_add_item "stages" "force_generate_similarity" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 7"

    menu_add_item "stages" "generate_diversity" "8. Diversity ⚠️" "checkbox" "0" \
        "Pre-compute diversity cache (~42 hours)" "" "--generate-diversity"
    menu_add_item "stages" "force_generate_diversity" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 8"

    menu_add_item "stages" "generate_html" "9. Generate HTML" "checkbox" "1" \
        "Generate website HTML (chronological + similarity pages)" "" "--generate-html"
    menu_add_item "stages" "force_generate_html" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 9"

    menu_add_item "stages" "generate_index" "10. Generate Index" "checkbox" "1" \
        "Generate numeric similarity index" "" "--generate-index"
    menu_add_item "stages" "force_generate_index" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 10"

    # Issue 10-016: Dependencies - per-stage force options disabled when global force is checked
    # invert=true means: enable per-stage force when global force is NOT checked
    menu_add_dependency "force_update_words" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_extract" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_parse" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_validate" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_catalog_images" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_embeddings" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_similarity" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_diversity" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_html" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_index" "force" "1" "true" \
        "Disabled: global force is active" "orange"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Configuration Options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "config" "multi" "Configuration"
    # Issue 10-034: Orchestrator pattern enables parallel HTML with low memory
    # Main thread sends 80KB work slices instead of workers loading 700MB caches
    # Expected memory: ~2.5GB total (vs 14GB+ before fix)
    menu_add_item "config" "threads" "Thread Count" "flag" "4:8" \
        "Threads for HTML gen (orchestrator mode)" "" "--threads"
    # Issue 8-022: Pagination options for HTML generation
    menu_add_item "config" "pages" "Pages per Poem" "flag" ":2" \
        "Pages to generate per poem (default: from config, 1)" "" "--pages"
    menu_add_item "config" "poems_per_page" "Poems per Page" "flag" ":3" \
        "Poems per page for similar/different (default: 200)" "" "--poems-per-page"
    menu_add_item "config" "chrono_per_page" "Chrono per Page" "flag" ":3" \
        "Poems per page for chronological (default: 500)" "" "--chrono-per-page"
    # Issue 10-016: Force Regeneration moved to stages section
    menu_add_item "config" "dry_run" "Dry Run" "checkbox" "0" \
        "Show what would be executed without running" "" "--dry-run"
    menu_add_item "config" "verbose" "Verbose Output" "checkbox" "0" \
        "Show detailed progress information" "" "--verbose"
    menu_add_item "config" "include_boosts" "Include Boosts" "checkbox" "0" \
        "Include fediverse boosts/reblogs in extraction" "" "--include-boosts"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Word Cloud Configuration
    # Issue 8-043: Configurable word count with "all words" toggle
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "wordcloud" "multi" "Word Cloud Options"
    menu_add_item "wordcloud" "wordcloud_all" "All Words" "checkbox" "0" \
        "Include all words (disables word count limit)" "" "--wordcloud-all"
    menu_add_item "wordcloud" "wordcloud_words" "Word Count" "flag" "200:3" \
        "Maximum words in word cloud (default: 200)" "" "--wordcloud-words"
    # Issue 8-050d: Poems per word-cloud page
    menu_add_item "wordcloud" "wordcloud_poems" "Poems Per Page" "flag" "50:3" \
        "Poems per word-cloud similarity page (default: 50)" "" "--wordcloud-poems"
    # Dependency: Disable wordcloud_words when wordcloud_all is checked
    # invert=true means: enable wordcloud_words when wordcloud_all is NOT checked (value "1")
    menu_add_dependency "wordcloud_words" "wordcloud_all" "1" "true" \
        "Word count disabled when 'All Words' is checked"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 4: Command Preview (shows the command that will be executed)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "preview" "multi" "Command Preview"
    menu_add_item "preview" "cmd_preview" "" "text" "" \
        "The command that will be executed (press ~ to copy to clipboard)"

    # Configure command preview - links checkboxes to command string
    menu_set_command_config "./run.sh" "cmd_preview" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 5: Actions
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Selected Stages" "action" "" \
        "Execute the selected pipeline stages" ""

    # Run the menu loop
    while true; do
        if menu_run; then
            # User selected "run" - extract values and execute
            local update_words_val=$(menu_get_value "update_words")
            local extract_val=$(menu_get_value "extract")
            local parse_val=$(menu_get_value "parse")
            local validate_val=$(menu_get_value "validate")
            local catalog_val=$(menu_get_value "catalog_images")
            local embeddings_val=$(menu_get_value "generate_embeddings")
            local similarity_val=$(menu_get_value "generate_similarity")
            local diversity_val=$(menu_get_value "generate_diversity")
            local html_val=$(menu_get_value "generate_html")
            local index_val=$(menu_get_value "generate_index")
            local threads_val=$(menu_get_value "threads")
            # Issue 8-022: Get pagination values from TUI
            local pages_val=$(menu_get_value "pages")
            local poems_per_page_val=$(menu_get_value "poems_per_page")
            local chrono_per_page_val=$(menu_get_value "chrono_per_page")
            local force_val=$(menu_get_value "force")
            # Issue 10-016: Get per-stage force values from TUI
            local force_update_words_val=$(menu_get_value "force_update_words")
            local force_extract_val=$(menu_get_value "force_extract")
            local force_parse_val=$(menu_get_value "force_parse")
            local force_validate_val=$(menu_get_value "force_validate")
            local force_catalog_val=$(menu_get_value "force_catalog_images")
            local force_embeddings_val=$(menu_get_value "force_generate_embeddings")
            local force_similarity_val=$(menu_get_value "force_generate_similarity")
            local force_diversity_val=$(menu_get_value "force_generate_diversity")
            local force_html_val=$(menu_get_value "force_generate_html")
            local force_index_val=$(menu_get_value "force_generate_index")
            local dry_val=$(menu_get_value "dry_run")
            local verbose_val=$(menu_get_value "verbose")
            # Issue 8-011: Get boost inclusion value from TUI
            local include_boosts_val=$(menu_get_value "include_boosts")
            # Issue 8-043: Get wordcloud values from TUI
            local wordcloud_all_val=$(menu_get_value "wordcloud_all")
            local wordcloud_words_val=$(menu_get_value "wordcloud_words")
            # Issue 8-050d: Get poems per word-cloud page from TUI
            local wordcloud_poems_val=$(menu_get_value "wordcloud_poems")

            # Set global flags based on menu selection
            [[ "$update_words_val" == "1" ]] && UPDATE_WORDS=true || UPDATE_WORDS=false
            [[ "$extract_val" == "1" ]] && EXTRACT=true || EXTRACT=false
            [[ "$parse_val" == "1" ]] && PARSE=true || PARSE=false
            [[ "$validate_val" == "1" ]] && VALIDATE=true || VALIDATE=false
            [[ "$catalog_val" == "1" ]] && CATALOG_IMAGES=true || CATALOG_IMAGES=false
            [[ "$embeddings_val" == "1" ]] && GENERATE_EMBEDDINGS=true || GENERATE_EMBEDDINGS=false
            [[ "$similarity_val" == "1" ]] && GENERATE_SIMILARITY=true || GENERATE_SIMILARITY=false
            [[ "$diversity_val" == "1" ]] && GENERATE_DIVERSITY=true || GENERATE_DIVERSITY=false
            [[ "$html_val" == "1" ]] && GENERATE_HTML=true || GENERATE_HTML=false
            [[ "$index_val" == "1" ]] && GENERATE_INDEX=true || GENERATE_INDEX=false

            # Config flags
            [[ -n "$threads_val" && "$threads_val" != "0" ]] && THREADS="$threads_val"
            # Issue 8-022: Set pagination values from TUI
            [[ -n "$pages_val" && "$pages_val" != "0" ]] && PAGES="$pages_val"
            [[ -n "$poems_per_page_val" && "$poems_per_page_val" != "0" ]] && POEMS_PER_PAGE="$poems_per_page_val"
            [[ -n "$chrono_per_page_val" && "$chrono_per_page_val" != "0" ]] && CHRONO_PER_PAGE="$chrono_per_page_val"
            [[ "$force_val" == "1" ]] && FORCE=true || FORCE=false
            # Issue 10-016: Set per-stage force flags from TUI
            [[ "$force_update_words_val" == "1" ]] && FORCE_STAGE_1=true || FORCE_STAGE_1=false
            [[ "$force_extract_val" == "1" ]] && FORCE_STAGE_2=true || FORCE_STAGE_2=false
            [[ "$force_parse_val" == "1" ]] && FORCE_STAGE_3=true || FORCE_STAGE_3=false
            [[ "$force_validate_val" == "1" ]] && FORCE_STAGE_4=true || FORCE_STAGE_4=false
            [[ "$force_catalog_val" == "1" ]] && FORCE_STAGE_5=true || FORCE_STAGE_5=false
            [[ "$force_embeddings_val" == "1" ]] && FORCE_STAGE_6=true || FORCE_STAGE_6=false
            [[ "$force_similarity_val" == "1" ]] && FORCE_STAGE_7=true || FORCE_STAGE_7=false
            [[ "$force_diversity_val" == "1" ]] && FORCE_STAGE_8=true || FORCE_STAGE_8=false
            [[ "$force_html_val" == "1" ]] && FORCE_STAGE_9=true || FORCE_STAGE_9=false
            [[ "$force_index_val" == "1" ]] && FORCE_STAGE_10=true || FORCE_STAGE_10=false
            [[ "$dry_val" == "1" ]] && DRY_RUN=true || DRY_RUN=false
            [[ "$verbose_val" == "1" ]] && VERBOSE=true || VERBOSE=false
            # Issue 8-011: Set boost inclusion from TUI
            [[ "$include_boosts_val" == "1" ]] && INCLUDE_BOOSTS=true || INCLUDE_BOOSTS=false
            # Issue 8-043: Set wordcloud values from TUI
            [[ "$wordcloud_all_val" == "1" ]] && WORDCLOUD_ALL=true || WORDCLOUD_ALL=false
            [[ -n "$wordcloud_words_val" && "$wordcloud_words_val" != "0" ]] && WORDCLOUD_WORDS="$wordcloud_words_val"
            # Issue 8-050d: Set poems per word-cloud page from TUI
            [[ -n "$wordcloud_poems_val" && "$wordcloud_poems_val" != "0" ]] && WORDCLOUD_POEMS="$wordcloud_poems_val"

            # Check if at least one stage is selected
            if ! $UPDATE_WORDS && ! $EXTRACT && ! $PARSE && ! $VALIDATE && \
               ! $CATALOG_IMAGES && ! $GENERATE_EMBEDDINGS && ! $GENERATE_SIMILARITY && \
               ! $GENERATE_DIVERSITY && ! $GENERATE_HTML && ! $GENERATE_INDEX; then
                echo ""
                echo "No stages selected. Please select at least one stage to run."
                echo "Press Enter to continue..."
                read -r
                continue
            fi

            # Exit menu and run the pipeline
            menu_cleanup
            return 0
        else
            # User quit
            menu_cleanup
            echo "Goodbye!"
            exit 0
        fi
    done
}
# }}}

# {{{ Main execution

# Handle interactive mode
EXECUTED_COMMAND=""  # Store command for post-run display
if $INTERACTIVE; then
    log_info "🎛️ Launching interactive mode with command preview..."
    interactive_mode_tui
    # Save the command preview for display after execution
    EXECUTED_COMMAND=$(menu_get_value "cmd_preview")
    # After TUI, fall through to execute selected stages
fi

# Show what will be executed (in non-interactive or after TUI selection)
if $DRY_RUN || $VERBOSE; then
    echo "Pipeline stages to execute:"
    $UPDATE_WORDS && echo "  1.  update-words"
    $EXTRACT && echo "  2.  extract"
    $PARSE && echo "  3.  parse"
    $VALIDATE && echo "  4.  validate"
    $CATALOG_IMAGES && echo "  5.  catalog-images"
    $GENERATE_EMBEDDINGS && echo -e "  6.  generate-embeddings $(symbol_warning "⚠️") (~2-3 hours)"
    $GENERATE_SIMILARITY && echo -e "  7.  generate-similarity $(symbol_warning "⚠️") (~30 min)"
    $GENERATE_DIVERSITY && echo -e "  8.  generate-diversity $(symbol_warning "⚠️") (~42 hours)"
    $GENERATE_HTML && echo "  9.  generate-html"
    $GENERATE_INDEX && echo "  10. generate-index"
    echo ""
fi

# {{{ Issue 10-017: Validate Ollama server connectivity before embedding stages
if $GENERATE_EMBEDDINGS && ! $DRY_RUN; then
    log_info "Validating Ollama server connectivity..."
    VALIDATION_RESULT=$(luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local ollama = require('ollama-config')
        if '$OLLAMA_SERVER' ~= '' then
            ollama.set_selected_server('$OLLAMA_SERVER')
        end
        local server = ollama.get_selected_server()
        local ok, msg = ollama.validate_server(server)
        if ok then
            print('OK:' .. server.name .. ':' .. ollama.build_host_url(server))
        else
            print('FAIL:' .. server.name .. ':' .. msg)
        end
    " 2>&1)

    if [[ "$VALIDATION_RESULT" == OK:* ]]; then
        SERVER_NAME=$(echo "$VALIDATION_RESULT" | cut -d: -f2)
        SERVER_URL=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
        log_info "   ✓ Ollama server '$SERVER_NAME' is reachable at $SERVER_URL"
    else
        SERVER_NAME=$(echo "$VALIDATION_RESULT" | cut -d: -f2)
        ERROR_MSG=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
        echo -e "${RED}❌ ERROR: Cannot connect to Ollama server '$SERVER_NAME'${NC}" >&2
        echo -e "${RED}   $ERROR_MSG${NC}" >&2
        echo -e "${YELLOW}💡 Use --list-ollama to see available servers${NC}" >&2
        echo -e "${YELLOW}💡 Use --ollama=NAME to select a different server${NC}" >&2
        exit 1
    fi
fi
# }}}

# Execute stages in pipeline order (regardless of argument order)
$UPDATE_WORDS && run_update_words
$EXTRACT && run_extract
$PARSE && run_parse
$VALIDATE && run_validate
$CATALOG_IMAGES && run_catalog_images
$GENERATE_EMBEDDINGS && run_generate_embeddings
# Semantic colors are part of embedding generation (Stage 6.5)
# Only regenerate when embeddings are generated - HTML should use existing poem_colors.json
$GENERATE_EMBEDDINGS && run_generate_semantic_colors
$GENERATE_SIMILARITY && run_generate_similarity
$GENERATE_DIVERSITY && run_generate_diversity
$GENERATE_HTML && run_generate_html
$GENERATE_INDEX && run_generate_index

if ! $QUIET; then
    echo ""
    echo -e "$(symbol_success "✅") Pipeline completed successfully"

    # Print the executed command for easy re-running (copy-paste friendly)
    if [[ -n "$EXECUTED_COMMAND" ]]; then
        echo ""
        echo -e "$(symbol_info "📋") Command executed:"
        echo "  $EXECUTED_COMMAND"
    fi
fi
# }}}
