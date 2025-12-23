#!/bin/bash

# run.sh - Main orchestrator for neocities-modernization pipeline
#
# Runs the complete poem processing pipeline from input files to generated HTML.
# Supports selective stage execution via CLI flags, with stages running in
# pipeline order regardless of argument order.
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

Runs the poem processing pipeline. Without stage flags, runs all stages.
With stage flags, runs only the specified stages in pipeline order.

Pipeline Stages (run in order, multiple can be specified):
  --update-words      Sync input files from words repository
  --extract           Extract content from backup archives
  --parse             Parse poems from JSON sources into poems.json
  --validate          Run poem validation
  --catalog-images    Catalog images from input directories
  --generate-html     Generate website HTML (chronological + similarity pages)
  --generate-index    Generate numeric similarity index
  --all               Run all stages (default when no stages specified)

Stage Configuration:
  --threads N         Thread count for parallel HTML generation (default: 4)
  --force             Force regeneration even if files are fresh

Output Control:
  --quiet             Suppress progress messages
  --verbose           Show detailed progress
  --dry-run           Show what would be executed without running

Interactive Mode:
  -I, --interactive   Launch TUI for interactive selection (with command preview)

Directory Options:
  --dir PATH          Assets directory (where poems.json etc. are stored)
  --output PATH       Output directory (default: output/)

Other:
  -h, --help          Show this help message

Examples:
  ./run.sh                           # Run all stages
  ./run.sh --generate-html           # Only regenerate HTML
  ./run.sh --validate --generate-html  # Validate then generate HTML
  ./run.sh --generate-html --threads 8 --force  # Force HTML with 8 threads
  ./run.sh --all --dry-run           # Preview what would run
  ./run.sh -I                        # Interactive TUI mode with command preview
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
GENERATE_HTML=false
GENERATE_INDEX=false

# Config flags
THREADS=""
FORCE=false
QUIET=false
VERBOSE=false
DRY_RUN=false

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

# If no stage flags were specified, run all stages (backward compatible)
if ! $STAGE_FLAG_SET; then
    UPDATE_WORDS=true
    EXTRACT=true
    PARSE=true
    VALIDATE=true
    CATALOG_IMAGES=true
    GENERATE_HTML=true
    GENERATE_INDEX=true
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
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  $1"
        echo "═══════════════════════════════════════════════════════════════════"
    fi
}

log_dry_run() {
    echo "[DRY-RUN] Would execute: $1"
}
# }}}

# {{{ Stage execution functions

# {{{ run_update_words
run_update_words() {
    log_stage "📁 Stage 1/7: Updating input files from words repository"

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update-words"
        return 0
    fi

    "$DIR/scripts/update-words" || {
        echo "Warning: Failed to update input files, continuing anyway..." >&2
    }
}
# }}}

# {{{ run_extract
run_extract() {
    log_stage "🔄 Stage 2/7: Extracting content from backup archives"

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update $DIR"
        return 0
    fi

    "$DIR/scripts/update" "$DIR" || {
        echo "Error: Content extraction failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_parse
run_parse() {
    log_stage "📝 Stage 3/7: Parsing poems from JSON sources"

    local force_arg=""
    if $FORCE; then
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
    log_stage "✓ Stage 4/7: Validating poem data"

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
run_catalog_images() {
    log_stage "🖼️ Stage 5/7: Cataloging images"

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --catalog-only $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --catalog-only $ASSETS_ARG || {
        echo "Error: Image cataloging failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_html
run_generate_html() {
    log_stage "🌐 Stage 6/7: Generating website HTML"

    local force_arg=""
    if $FORCE; then
        force_arg="--force"
    fi

    local threads_arg=""
    if [ -n "$THREADS" ]; then
        threads_arg="--threads $THREADS"
    fi

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --html-only $force_arg $threads_arg $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --html-only $force_arg $threads_arg $ASSETS_ARG || {
        echo "Error: HTML generation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_index
run_generate_index() {
    log_stage "🔢 Stage 7/7: Generating numeric similarity index"

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
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "stages" "multi" "Pipeline Stages (toggle stages to run)"
    menu_add_item "stages" "update_words" "1. Update Words" "checkbox" "1" \
        "Sync input files from words repository" "1" "--update-words"
    menu_add_item "stages" "extract" "2. Extract" "checkbox" "1" \
        "Extract content from backup archives" "2" "--extract"
    menu_add_item "stages" "parse" "3. Parse" "checkbox" "1" \
        "Parse poems from JSON sources into poems.json" "3" "--parse"
    menu_add_item "stages" "validate" "4. Validate" "checkbox" "1" \
        "Run poem validation" "4" "--validate"
    menu_add_item "stages" "catalog_images" "5. Catalog Images" "checkbox" "1" \
        "Catalog images from input directories" "5" "--catalog-images"
    menu_add_item "stages" "generate_html" "6. Generate HTML" "checkbox" "1" \
        "Generate website HTML (chronological + similarity pages)" "6" "--generate-html"
    menu_add_item "stages" "generate_index" "7. Generate Index" "checkbox" "1" \
        "Generate numeric similarity index" "7" "--generate-index"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Configuration Options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "config" "multi" "Configuration"
    menu_add_item "config" "threads" "Thread Count" "flag" "4:2" \
        "Thread count for parallel HTML generation (type 1-16)" "t" "--threads"
    menu_add_item "config" "force" "Force Regeneration" "checkbox" "0" \
        "Force regeneration even if files are fresh" "f" "--force"
    menu_add_item "config" "dry_run" "Dry Run" "checkbox" "0" \
        "Show what would be executed without running" "d" "--dry-run"
    menu_add_item "config" "verbose" "Verbose Output" "checkbox" "0" \
        "Show detailed progress information" "v" "--verbose"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Command Preview (shows the command that will be executed)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "preview" "multi" "Command Preview"
    menu_add_item "preview" "cmd_preview" "" "text" "" \
        "The command that will be executed (press ~ to copy to clipboard)"

    # Configure command preview - links checkboxes to command string
    menu_set_command_config "./run.sh" "cmd_preview" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 4: Actions
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Selected Stages" "action" "" \
        "Execute the selected pipeline stages" "r"

    # Run the menu loop
    while true; do
        if menu_run; then
            # User selected "run" - extract values and execute
            local update_words_val=$(menu_get_value "update_words")
            local extract_val=$(menu_get_value "extract")
            local parse_val=$(menu_get_value "parse")
            local validate_val=$(menu_get_value "validate")
            local catalog_val=$(menu_get_value "catalog_images")
            local html_val=$(menu_get_value "generate_html")
            local index_val=$(menu_get_value "generate_index")
            local threads_val=$(menu_get_value "threads")
            local force_val=$(menu_get_value "force")
            local dry_val=$(menu_get_value "dry_run")
            local verbose_val=$(menu_get_value "verbose")

            # Set global flags based on menu selection
            [[ "$update_words_val" == "1" ]] && UPDATE_WORDS=true || UPDATE_WORDS=false
            [[ "$extract_val" == "1" ]] && EXTRACT=true || EXTRACT=false
            [[ "$parse_val" == "1" ]] && PARSE=true || PARSE=false
            [[ "$validate_val" == "1" ]] && VALIDATE=true || VALIDATE=false
            [[ "$catalog_val" == "1" ]] && CATALOG_IMAGES=true || CATALOG_IMAGES=false
            [[ "$html_val" == "1" ]] && GENERATE_HTML=true || GENERATE_HTML=false
            [[ "$index_val" == "1" ]] && GENERATE_INDEX=true || GENERATE_INDEX=false

            # Config flags
            [[ -n "$threads_val" && "$threads_val" != "0" ]] && THREADS="$threads_val"
            [[ "$force_val" == "1" ]] && FORCE=true || FORCE=false
            [[ "$dry_val" == "1" ]] && DRY_RUN=true || DRY_RUN=false
            [[ "$verbose_val" == "1" ]] && VERBOSE=true || VERBOSE=false

            # Check if at least one stage is selected
            if ! $UPDATE_WORDS && ! $EXTRACT && ! $PARSE && ! $VALIDATE && \
               ! $CATALOG_IMAGES && ! $GENERATE_HTML && ! $GENERATE_INDEX; then
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
if $INTERACTIVE; then
    log_info "🎛️ Launching interactive mode with command preview..."
    interactive_mode_tui
    # After TUI, fall through to execute selected stages
fi

# Show what will be executed (in non-interactive or after TUI selection)
if $DRY_RUN || $VERBOSE; then
    echo "Pipeline stages to execute:"
    $UPDATE_WORDS && echo "  1. update-words"
    $EXTRACT && echo "  2. extract"
    $PARSE && echo "  3. parse"
    $VALIDATE && echo "  4. validate"
    $CATALOG_IMAGES && echo "  5. catalog-images"
    $GENERATE_HTML && echo "  6. generate-html"
    $GENERATE_INDEX && echo "  7. generate-index"
    echo ""
fi

# Execute stages in pipeline order (regardless of argument order)
$UPDATE_WORDS && run_update_words
$EXTRACT && run_extract
$PARSE && run_parse
$VALIDATE && run_validate
$CATALOG_IMAGES && run_catalog_images
$GENERATE_HTML && run_generate_html
$GENERATE_INDEX && run_generate_index

if ! $QUIET; then
    echo ""
    echo "✅ Pipeline completed successfully"
fi
# }}}
