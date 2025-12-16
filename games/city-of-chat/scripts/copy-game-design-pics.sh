#!/bin/bash

# {{{ copy_game_design_pics
# Copy game design pictures and generate ML analysis notes
DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
SOURCE_DIR="/home/ritz/pictures/my-art/game-design"
DEST_DIR="${DIR}/pics"


# {{{ setup_analysis_tools
setup_analysis_tools() {
    # Ensure ML analysis tools are compiled and ready
    if [ ! -f "${DIR}/libs/image_info" ]; then
        echo "Compiling image metadata utility..."
        gcc -o "${DIR}/libs/image_info" "${DIR}/src/image_info.c"
        if [ $? -ne 0 ]; then
            echo "Warning: Could not compile image_info utility"
        fi
    fi
    
    # Ensure ML vision analysis script is executable
    chmod +x "${DIR}/scripts/ml_vision_analysis.sh"
    chmod +x "${DIR}/scripts/process_ml_analysis.lua"
}
# }}}

# {{{ copy_and_analyze
copy_and_analyze() {
    local source_dir="$1"
    local dest_dir="$2"
    
    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory $source_dir does not exist"
        exit 1
    fi
    
    # Create destination directory
    mkdir -p "$dest_dir"
    
    echo "Copying images from $source_dir to $dest_dir..."
    
    # Counter for progress
    local count=0
    local total=$(find "$source_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) | wc -l)
    
    # Copy images and generate analysis
    find "$source_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) | while read -r image_file; do
        count=$((count + 1))
        filename=$(basename "$image_file")
        name_without_ext="${filename%.*}"
        ext="${filename##*.}"
        
        dest_image="$dest_dir/$filename"
        notes_file="$dest_dir/${name_without_ext}-notes.txt"
        
        echo "[$count/$total] Processing: $filename"
        
        # Copy image
        cp "$image_file" "$dest_image"
        
        # Generate ML analysis notes if they don't exist
        if [ ! -f "$notes_file" ]; then
            echo "  Generating ML analysis..."
            
            # Create temporary file for analysis results
            local temp_analysis="/tmp/analysis_$(basename "$filename" .${ext}).txt"
            
            # Run ML vision analysis
            "${DIR}/scripts/ml_vision_analysis.sh" "$dest_image" "auto" > "$temp_analysis" 2>/dev/null
            
            if [ $? -eq 0 ] && [ -s "$temp_analysis" ]; then
                # Process analysis with Lua script to generate documentation
                lua "${DIR}/scripts/process_ml_analysis.lua" "$dest_image" "$temp_analysis" "$DIR" 2>/dev/null
                
                # Also create the basic notes file
                cp "$temp_analysis" "$notes_file"
                echo "" >> "$notes_file"
                echo "USER NOTES:" >> "$notes_file"
                echo "(Add your own observations and design ideas below)" >> "$notes_file"
                echo "" >> "$notes_file"
            else
                # Fallback to basic analysis using C utility
                echo "  Fallback to basic analysis..."
                echo "Image Analysis for Game Design Inspiration" > "$notes_file"
                echo "==================================================" >> "$notes_file"
                echo "Filename: $filename" >> "$notes_file"
                
                if [ -f "${DIR}/libs/image_info" ]; then
                    "${DIR}/libs/image_info" "$dest_image" >> "$notes_file" 2>/dev/null
                fi
                
                echo "" >> "$notes_file"
                echo "USER NOTES:" >> "$notes_file"
                echo "(Add your own observations and design ideas below)" >> "$notes_file"
                echo "" >> "$notes_file"
            fi
            
            # Clean up temporary file
            rm -f "$temp_analysis"
        else
            echo "  Notes file already exists, skipping analysis"
        fi
    done
    
    echo "Completed! Processed $total images."
    echo "Images copied to: $dest_dir"
    echo "Analysis notes generated for each image with -notes.txt suffix"
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    echo "=== Interactive Mode ==="
    echo "Game Design Picture Copy and Analysis Tool"
    echo ""
    
    echo "Select operation:"
    echo "1) Copy all images and generate analysis"
    echo "2) Copy images only (no analysis)"
    echo "3) Generate analysis for existing images"
    echo "4) Show current image count"
    echo ""
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            setup_analysis_tools
            copy_and_analyze "$SOURCE_DIR" "$DEST_DIR"
            ;;
        2)
            echo "Copying images without analysis..."
            mkdir -p "$DEST_DIR"
            cp "$SOURCE_DIR"/*.{png,jpg,jpeg,gif,bmp} "$DEST_DIR" 2>/dev/null || echo "No image files found or copy failed"
            ;;
        3)
            setup_analysis_tools
            echo "Generating ML analysis for existing images..."
            find "$DEST_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) | while read -r image_file; do
                filename=$(basename "$image_file")
                name_without_ext="${filename%.*}"
                notes_file="$DEST_DIR/${name_without_ext}-notes.txt"
                
                if [ ! -f "$notes_file" ]; then
                    echo "Analyzing: $filename"
                    temp_analysis="/tmp/analysis_$(basename "$filename").txt"
                    "${DIR}/scripts/ml_vision_analysis.sh" "$image_file" "auto" > "$temp_analysis" 2>/dev/null
                    
                    if [ $? -eq 0 ] && [ -s "$temp_analysis" ]; then
                        lua "${DIR}/scripts/process_ml_analysis.lua" "$image_file" "$temp_analysis" "$DIR" 2>/dev/null
                        cp "$temp_analysis" "$notes_file"
                    else
                        echo "Basic analysis fallback for: $filename"
                        echo "Image Analysis for $filename" > "$notes_file"
                        if [ -f "${DIR}/libs/image_info" ]; then
                            "${DIR}/libs/image_info" "$image_file" >> "$notes_file" 2>/dev/null
                        fi
                    fi
                    rm -f "$temp_analysis"
                fi
            done
            ;;
        4)
            source_count=$(find "$SOURCE_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
            dest_count=$(find "$DEST_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
            notes_count=$(find "$DEST_DIR" -name "*-notes.txt" 2>/dev/null | wc -l)
            docs_count=$(find "$DIR/docs/design-analysis" -name "*-analysis.md" 2>/dev/null | wc -l)
            issues_count=$(find "$DIR/issues/design-driven" -name "*" -type f 2>/dev/null | wc -l)
            
            echo "Source directory ($SOURCE_DIR): $source_count images"
            echo "Destination directory ($DEST_DIR): $dest_count images"
            echo "Analysis notes files: $notes_count"
            echo "Generated documentation files: $docs_count"
            echo "Generated issue files: $issues_count"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}
# }}}

# Main execution
main() {
    # Check for interactive flag
    if [ "$1" = "-I" ]; then
        shift
        DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
        SOURCE_DIR="/home/ritz/pictures/my-art/game-design"
        DEST_DIR="${DIR}/pics"
        interactive_mode
    else
        # Default behavior: copy and analyze
        setup_analysis_tools
        copy_and_analyze "$SOURCE_DIR" "$DEST_DIR"
    fi
}

main "$@"
# }}}