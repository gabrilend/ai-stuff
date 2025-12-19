#!/bin/bash

# {{{ setup_dir_path
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

# Parse command line arguments
DIR=""
INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -I)
            INTERACTIVE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# Set up directory
DIR=$(setup_dir_path "$DIR")

# Ensure we're in the right directory
cd "$DIR" || {
    echo "Error: Could not access directory $DIR" >&2
    exit 1
}

# Update input files using words sync script
echo "📁 Updating input files..."
"$DIR/scripts/update-words" || {
    echo "Warning: Failed to update input files, continuing anyway..." >&2
}

# Run content extraction from archives (modernized scripts)
echo "🔄 Extracting content from backup archives..."
"$DIR/scripts/update" "$DIR" || {
    echo "Error: Content extraction failed" >&2
    exit 1
}

# Run main HTML generation pipeline
echo "🌐 Generating HTML from extracted content..."
if [ "$INTERACTIVE" = true ]; then
    lua src/main.lua "$DIR" -I
else
    lua src/main.lua "$DIR"
fi

# Generate numeric similarity index (build product, always overwrites)
echo "🔢 Generating numeric similarity index..."
lua "$DIR/scripts/generate-numeric-index" "$DIR" > /dev/null || {
    echo "Error: Numeric index generation failed" >&2
    exit 1
}