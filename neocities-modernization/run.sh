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
  -I, --interactive   Launch TUI for interactive selection

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
  ./run.sh -I                        # Interactive TUI mode
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

# {{{ Main execution

# Handle interactive mode
if $INTERACTIVE; then
    log_info "🎛️ Launching interactive mode..."
    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR -I $ASSETS_ARG"
        exit 0
    fi
    luajit src/main.lua "$DIR" -I $ASSETS_ARG
    exit $?
fi

# Show what will be executed
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
