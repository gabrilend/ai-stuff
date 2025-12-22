#!/bin/bash

# Configurable base directory for projects (can be overridden by argument)
PROJECTS_BASE_DIR="/home/ritz/programming/ai-stuff"
DIR="$PROJECTS_BASE_DIR"

# Global verbosity level (default: 2 = standard)
export VERBOSITY=2

# Global output file path (empty = stdout only)
export OUTPUT_FILE=""

# Global variable for menu selection result
export MENU_RESULT=""

# Global associative array for storing per-project output file paths
# This gets dynamically populated from stored data in the script itself
declare -A PROJECT_OUTPUT_PATHS

# STORED_PROJECT_PATHS_START
# This section stores per-project output file paths and gets updated dynamically
# Format: PROJECT_NAME|OUTPUT_PATH
# Format: PROJECT_NAME|OUTPUT_PATH
# delta-version|/home/ritz/programming/ai-stuff/README.md
# progress-ii|/home/ritz/programming/ai-stuff/progress-ii-progress.md
# STORED_PROJECT_PATHS_END

# {{{ load_project_paths
load_project_paths() {
    local script_path="$0"
    local in_section=false
    
    while IFS= read -r line; do
        if [[ "$line" == "# STORED_PROJECT_PATHS_START" ]]; then
            in_section=true
            continue
        elif [[ "$line" == "# STORED_PROJECT_PATHS_END" ]]; then
            break
        elif [ "$in_section" = true ] && [[ "$line" =~ ^#[[:space:]]*(.+)\|(.+)$ ]]; then
            local project_name="${BASH_REMATCH[1]}"
            local output_path="${BASH_REMATCH[2]}"
            PROJECT_OUTPUT_PATHS["$project_name"]="$output_path"
        fi
    done < "$script_path"
}
# }}}

# {{{ save_project_paths
save_project_paths() {
    local script_path="$0"
    local temp_file=$(mktemp)
    local in_section=false
    
    # Copy everything except the stored paths section
    while IFS= read -r line; do
        if [[ "$line" == "# STORED_PROJECT_PATHS_START" ]]; then
            echo "$line"
            echo "# This section stores per-project output file paths and gets updated dynamically"
            echo "# Format: PROJECT_NAME|OUTPUT_PATH"
            
            # Write current project paths
            for project in "${!PROJECT_OUTPUT_PATHS[@]}"; do
                echo "# $project|${PROJECT_OUTPUT_PATHS[$project]}"
            done
            
            in_section=true
        elif [[ "$line" == "# STORED_PROJECT_PATHS_END" ]]; then
            echo "$line"
            in_section=false
        elif [ "$in_section" = false ]; then
            echo "$line"
        fi
    done < "$script_path" > "$temp_file"
    
    # Replace the original script with the updated version
    mv "$temp_file" "$script_path"
    chmod +x "$script_path"
}
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: $0 [options] [project_dir] [conversation_file|all]"
    echo ""
    echo "Export and browse Claude conversation transcripts with multiple output formats"
    echo ""
    echo "Arguments:"
    echo "  project_dir       Project directory (default: $DIR)"
    echo "  conversation_file Optional conversation file to print (supports partial matches)"
    echo "  all               Print all conversations in the project"
    echo ""
    echo "Verbosity Options:"
    echo "  -v0, --minimal    Minimal output - code and essential content only"
    echo "  -v1, --compact    Compact output - skip user sentiments, show responses"
    echo "  -v2, --standard   Standard output - include everything (default)"
    echo "  -v3, --verbose    Verbose output - include context files and expansions"
    echo "  -v4, --complete   Complete output - everything + LLM execution details + vimfolds"
    echo "  -v5, --raw        Raw output - include ALL intermediate LLM steps and tool results"
    echo ""
    echo "Interactive Mode:"
    echo "  $0                    # Interactive project browser with conversation export"
    echo "  $0 handheld-office    # Browse conversations for specific project"
    echo ""
    echo "Direct Export Mode:"
    echo "  $0 handheld-office c0567703"
    echo "  $0 --compact handheld-office all > backup.md"
    echo "  $0 -v1 /path/to/project conversation.md"
    echo ""
    echo "File Export Examples:"
    echo "  $0 -v3 handheld-office 3 > conversation.md    # Export selection 3 to file"
    echo "  $0 --complete handheld-office all > full-backup.md   # Export all conversations"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
}
# }}}

# {{{ parse_verbosity_args
parse_verbosity_args() {
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v0|--minimal)
                VERBOSITY=0
                shift
                ;;
            -v1|--compact)
                VERBOSITY=1
                shift
                ;;
            -v2|--standard)
                VERBOSITY=2
                shift
                ;;
            -v3|--verbose)
                VERBOSITY=3
                shift
                ;;
            -v4|--complete)
                VERBOSITY=4
                shift
                ;;
            -v5|--raw)
                VERBOSITY=5
                shift
                ;;
            -h|--help)
                show_usage >&2
                exit 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # Return remaining arguments
    printf '%s\n' "${args[@]}"
}
# }}}

# {{{ find_all_projects_recursive
find_all_projects_recursive() {
    local search_dir="$1"
    local base_dir="$2"
    local depth="${3:-0}"
    
    # Limit recursion depth to prevent infinite loops
    if [ "$depth" -gt 5 ]; then
        return
    fi
    
    for item in "$search_dir"/*/; do
        if [ ! -d "$item" ]; then
            continue
        fi
        
        local dirname=$(basename "$item")
        
        # Skip hidden directories, system directories, and library directories
        if [[ "$dirname" =~ ^\. ]] || [[ "$dirname" == "node_modules" ]] || [[ "$dirname" == ".git" ]]; then
            continue
        fi
        
        # Skip Wine directories and system directories
        if [[ "$dirname" == "dosdevices" ]] || [[ "$dirname" == "drive_c" ]] || [[ "$search_dir" == *"/dosdevices/"* ]]; then
            continue
        fi
        
        # Skip system library directories
        if [[ "$dirname" =~ ^lib ]] || [[ "$dirname" == "usr" ]] || [[ "$dirname" == "var" ]] || [[ "$dirname" == "etc" ]] || [[ "$dirname" == "bin" ]] || [[ "$dirname" == "sbin" ]]; then
            continue
        fi
        
        # Skip if we're inside a libs directory (these are usually external libraries)
        if [[ "$search_dir" == *"/libs"* ]] || [[ "$search_dir" == *"/lib"* ]] || [[ "$dirname" == "libs" ]] || [[ "$dirname" == "lib" ]]; then
            continue
        fi
        
        # Check if this directory is a project (has CLAUDE.md or common project structure)
        local is_project=false
        
        # Check for CLAUDE.md file or .claude directory
        if [ -f "$item/CLAUDE.md" ] || [ -f "$item/.claude/CLAUDE.md" ] || [ -d "$item/.claude" ]; then
            is_project=true
        fi
        
        # Check for common project structure (notes, docs, src)
        local structure_count=0
        for common_dir in "notes" "docs" "src" "scripts" "assets" "libs"; do
            if [ -d "$item/$common_dir" ]; then
                ((structure_count++))
            fi
        done
        
        # If it has 2 or more common project directories, consider it a project
        if [ $structure_count -ge 2 ]; then
            is_project=true
        fi
        
        # If it's a project, output it and don't recurse further into it
        if [ "$is_project" = true ]; then
            local relative_path=$(realpath --relative-to="$base_dir" "$item")
            echo "$relative_path"
        else
            # Not a project, recurse into it to find nested projects
            find_all_projects_recursive "$item" "$base_dir" $((depth + 1))
        fi
    done
}

# {{{ count_conversations
count_conversations() {
    local project_dir="$1"
    local count=0
    
    if [ -d "$project_dir/llm-transcripts" ]; then
        count=$(ls -1 "$project_dir/llm-transcripts/"*.md 2>/dev/null | wc -l)
    fi
    
    echo "$count"
}
# }}}

# {{{ display_file_with_box
display_file_with_box() {
    local file_path="$1"
    local title="$2"
    
    if [ ! -f "$file_path" ]; then
        echo "📄 **File:** $file_path (not found)"
        return
    fi
    
    local filename=$(basename "$file_path")
    local filesize=$(stat -c%s "$file_path" 2>/dev/null || echo "unknown")
    local line_count=$(wc -l < "$file_path" 2>/dev/null || echo "unknown")
    
    # Box-drawing characters
    local top_left="┌"
    local top_right="┐"
    local bottom_left="└"
    local bottom_right="┘"
    local horizontal="─"
    local vertical="│"
    
    # Create header
    local header="$title: $filename ($filesize bytes, $line_count lines)"
    local header_length=${#header}
    local box_width=$((header_length + 4))
    
    # Top border
    echo -n "$top_left"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "$top_right"
    
    # Header line
    echo "$vertical $header $vertical"
    
    # Separator line
    echo -n "├"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "┤"
    
    # File content with line numbers and borders
    local line_num=1
    while IFS= read -r line || [ -n "$line" ]; do
        printf "$vertical %3d │ %s" "$line_num" "$line"
        # Pad to box width
        local content_length=$((7 + ${#line}))
        if [ $content_length -lt $((box_width - 1)) ]; then
            printf "%*s" $((box_width - content_length - 1)) ""
        fi
        echo " $vertical"
        ((line_num++))
    done < "$file_path"
    
    # Bottom border
    echo -n "$bottom_left"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "$bottom_right"
}
# }}}

# {{{ show_edit_context
show_edit_context() {
    local file_path="$1"
    local old_string="$2"
    local new_string="$3"
    
    if [ ! -f "$file_path" ]; then
        echo "📝 **Edit Context:** $file_path (file not found)"
        return
    fi
    
    # Find the line containing the new string (since edit has already happened)
    local match_line=$(grep -n -F "$new_string" "$file_path" | head -1 | cut -d: -f1)
    
    if [ -z "$match_line" ]; then
        # Fallback: try to find partial match or just show general context
        echo "📝 **Edit Context:** Changes applied to $file_path"
        echo "   Changed: '$(echo "$old_string" | head -c 50)...' → '$(echo "$new_string" | head -c 50)...'"
        return
    fi
    
    local filename=$(basename "$file_path")
    local total_lines=$(wc -l < "$file_path")
    
    # Calculate context range (10 lines before and after, but respect file boundaries)
    local start_line=$((match_line - 10))
    local end_line=$((match_line + 10))
    
    [ $start_line -lt 1 ] && start_line=1
    [ $end_line -gt $total_lines ] && end_line=$total_lines
    
    # Box-drawing characters
    local top_left="┌"
    local top_right="┐"
    local bottom_left="└"
    local bottom_right="┘"
    local horizontal="─"
    local vertical="│"
    
    echo ""
    echo "📝 **Edit Context:** $filename (lines $start_line-$end_line, change at line $match_line)"
    
    # Create header
    local header="Edit Context: $filename (lines $start_line-$end_line)"
    local header_length=${#header}
    local box_width=$((header_length + 4))
    
    # Top border
    echo -n "$top_left"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "$top_right"
    
    # Header line
    echo "$vertical $header $vertical"
    
    # Separator line
    echo -n "├"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "┤"
    
    # Show context with line numbers
    local line_num=1
    sed -n "${start_line},${end_line}p" "$file_path" | while IFS= read -r line || [ -n "$line" ]; do
        local current_line=$((start_line + line_num - 1))
        
        # Highlight the changed line
        if [ $current_line -eq $match_line ]; then
            printf "$vertical %3d ▶ %s" "$current_line" "$line"
        else
            printf "$vertical %3d │ %s" "$current_line" "$line"
        fi
        
        # Pad to box width
        local content_length=$((8 + ${#line}))
        if [ $content_length -lt $((box_width - 1)) ]; then
            printf "%*s" $((box_width - content_length - 1)) ""
        fi
        echo " $vertical"
        ((line_num++))
    done
    
    # Bottom border
    echo -n "$bottom_left"
    printf "${horizontal}%.0s" $(seq 1 $((box_width - 2)))
    echo "$bottom_right"
}
# }}}

# {{{ arrow_key_menu
arrow_key_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local key
    
    # Hide cursor
    printf "\033[?25l"
    
    # Calculate padding needed based on total number of options
    local total_options=${#options[@]}
    local padding_width=${#total_options}
    
    # Function to draw menu
    draw_menu() {
        # Clear screen and move to top
        printf "\033[2J\033[H"
        
        echo "$title"
        echo "$(printf '=%.0s' {1..50})"
        echo ""
        
        for i in "${!options[@]}"; do
            local option_number=$(printf "%0${padding_width}d" $((i + 1)))
            if [ $i -eq $selected ]; then
                # Highlighted option
                printf "\033[7m  ▶ %s) %s  \033[0m\n" "$option_number" "${options[i]}"
            else
                printf "    %s) %s\n" "$option_number" "${options[i]}"
            fi
        done
        
        echo ""
        local max_index=$(printf "%0${padding_width}d" $total_options)
        echo "Navigation: ↑/↓ arrows or j/k, Enter to select, 01-$max_index for instant selection, 's' settings, 'q' quit"
    }
    
    # Initial draw
    draw_menu
    
    local input_buffer=""
    local input_timeout=0
    
    while true; do
        # Read single character
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A')  # Up arrow
                        ((selected > 0)) && ((selected--))
                        draw_menu
                        input_buffer=""
                        ;;
                    '[B')  # Down arrow
                        ((selected < ${#options[@]} - 1)) && ((selected++))
                        draw_menu
                        input_buffer=""
                        ;;
                esac
                ;;
            '')  # Enter key
                # If we have input buffer, try to use it as selection
                if [ -n "$input_buffer" ]; then
                    local num=$((input_buffer - 1))
                    if [ $num -ge 0 ] && [ $num -lt ${#options[@]} ]; then
                        selected=$num
                        printf "\033[?25h"
                        MENU_RESULT="$selected"
                        return 0
                    else
                        input_buffer=""
                        draw_menu
                    fi
                else
                    # Show cursor
                    printf "\033[?25h"
                    MENU_RESULT="$selected"
                    return 0
                fi
                ;;
            [0-9])  # Number keys - build up selection
                input_buffer="${input_buffer}${key}"
                
                # Check if we have enough digits for a complete number
                if [ ${#input_buffer} -eq $padding_width ]; then
                    local num=$((input_buffer - 1))
                    if [ $num -ge 0 ] && [ $num -lt ${#options[@]} ]; then
                        selected=$num
                        printf "\033[?25h"
                        MENU_RESULT="$selected"
                        return 0
                    else
                        input_buffer=""
                        draw_menu
                    fi
                fi
                ;;
            'j'|'J')  # Vim-style down
                ((selected < ${#options[@]} - 1)) && ((selected++))
                draw_menu
                input_buffer=""
                ;;
            'k'|'K')  # Vim-style up
                ((selected > 0)) && ((selected--))
                draw_menu
                input_buffer=""
                ;;
            'q'|'Q')  # Quit
                printf "\033[?25h"
                MENU_RESULT="quit"
                return 1
                ;;
            's'|'S')  # Settings
                printf "\033[?25h"
                MENU_RESULT="settings"
                return 2
                ;;
            *)
                # Any other key clears input buffer
                input_buffer=""
                ;;
        esac
    done
}
# }}}

# {{{ interactive_select_project
interactive_select_project() {
    local base_dir="$1"
    
    # Get all projects using recursive search
    local projects=()
    
    # Use a temporary file to avoid the hanging process substitution
    local temp_projects=$(mktemp)
    find_all_projects_recursive "$base_dir" "$base_dir" > "$temp_projects"
    
    while IFS= read -r project_path; do
        if [ -n "$project_path" ]; then
            projects+=("$project_path")
        fi
    done < "$temp_projects"
    
    rm -f "$temp_projects"
    
    if [ ${#projects[@]} -eq 0 ]; then
        echo "No projects found in $base_dir"
        exit 1
    fi
    
    # Build project options with conversation counts
    local project_options=()
    for project in "${projects[@]}"; do
        local project_path="$base_dir/$project"
        local conv_count=$(count_conversations "$project_path")
        local display_name="$project"
        
        # For nested projects, show the full path for clarity
        if [[ "$project" == */* ]]; then
            display_name="$project"
        fi
        
        if [ "$conv_count" -gt 0 ]; then
            project_options+=("$display_name ($conv_count conversations)")
        else
            project_options+=("$display_name (no conversations)")
        fi
    done
    
    # Show current settings
    echo ""
    echo "🔧 Current Settings:"
    echo "  Verbosity: $VERBOSITY"
    case $VERBOSITY in
        0) echo "    (Minimal output)" ;;
        1) echo "    (Compact output)" ;;
        2) echo "    (Standard output)" ;;
        3) echo "    (Verbose output)" ;;
        4) echo "    (Complete output)" ;;
        5) echo "    (Raw output)" ;;
    esac
    if [ -n "$OUTPUT_FILE" ]; then
        echo "  💾 Output: $OUTPUT_FILE"
    else
        echo "  🖥️ Output: Terminal only"
    fi
    
    # Use arrow key menu for project selection
    while true; do
        local title="🗂️ Claude Conversation Exporter
📁 Select a project to export conversations:"
        
        # Call arrow_key_menu directly and use global variable for result
        arrow_key_menu "$title" "${project_options[@]}"
        local exit_code=$?
        
        case "$exit_code" in
            0)  # Project selected
                if [[ "$MENU_RESULT" =~ ^[0-9]+$ ]]; then
                    local selected_project="${projects[$MENU_RESULT]}"
                    local selected_path="$base_dir/$selected_project"
                    local conv_count=$(count_conversations "$selected_path")
                    
                    echo ""
                    echo "✅ Selected project: $selected_project"
                    
                    # Debug: check if project name is empty
                    if [ -z "$selected_project" ]; then
                        echo "DEBUG: Empty project name detected! MENU_RESULT=$MENU_RESULT" >&2
                        echo "DEBUG: projects array: ${projects[*]}" >&2
                        continue
                    fi
                    
                    if [ "$conv_count" -gt 0 ]; then
                        interactive_select_conversation "$selected_path"
                        return 0
                    else
                        echo "⚠️  This project has no conversation files yet."
                        echo "💡 Generating conversation transcripts..."
                        
                        # Create llm-transcripts directory if it doesn't exist
                        mkdir -p "$selected_path/llm-transcripts"
                        
                        # Try to run backup script to generate conversations
                        local backup_generated=false
                        if [ -f "$selected_path/scripts/backup-conversations" ]; then
                            echo "🔄 Running project backup script..."
                            (cd "$selected_path" && source scripts/backup-conversations && backup-conversations "$selected_path" 2>/dev/null) && backup_generated=true
                        elif [ -f "$selected_path/backup-conversations.sh" ]; then
                            echo "🔄 Running project backup script..."
                            (cd "$selected_path" && ./backup-conversations.sh 2>/dev/null) && backup_generated=true
                        elif [ -f "$PROJECTS_BASE_DIR/scripts/backup-conversations" ]; then
                            echo "🔄 Using global backup script..."
                            (source "$PROJECTS_BASE_DIR/scripts/backup-conversations" && backup-conversations "$selected_path" 2>/dev/null) && backup_generated=true
                        fi
                        
                        # Check if conversations were generated
                        local new_conv_count=$(count_conversations "$selected_path")
                        if [ "$new_conv_count" -gt 0 ]; then
                            echo "✅ Generated $new_conv_count conversation files"
                            interactive_select_conversation "$selected_path"
                            return 0
                        else
                            echo "❌ No conversation files could be generated for this project."
                            echo "💡 This project may not have any Claude conversations yet."
                            echo "📁 Conversation files should be stored in $selected_path/llm-transcripts/"
                            echo ""
                            echo "Press Enter to return to project selection..."
                            read -r
                            continue
                        fi
                    fi
                fi
                ;;
            1)  # Quit
                if [ "$MENU_RESULT" = "quit" ]; then
                    echo "Goodbye!"
                    exit 0
                fi
                ;;
            2)  # Settings
                if [ "$MENU_RESULT" = "settings" ]; then
                    interactive_settings_menu ""
                    continue
                fi
                ;;
        esac
    done
}
# }}}

# {{{ find_conversations
find_conversations() {
    local search_dir="$1"
    
    echo "Available conversations in $search_dir:"
    echo "========================================"
    
    if [ -d "$search_dir/llm-transcripts" ]; then
        ls -la "$search_dir/llm-transcripts/"*.md 2>/dev/null | while read -r line; do
            filename=$(basename "$(echo "$line" | awk '{print $NF}')")
            filesize=$(echo "$line" | awk '{print $5}')
            echo "  $filename ($filesize bytes)"
        done
    else
        echo "  No llm-transcripts directory found"
    fi
    
    echo ""
}
# }}}

# {{{ interactive_settings_menu
interactive_settings_menu() {
    local project_name="$1"
    while true; do
        echo ""
        echo "🔧 Claude Conversation Settings"
        echo "=============================="
        echo ""
        echo "Current Settings:"
        echo "  Verbosity Level: $VERBOSITY"
        case $VERBOSITY in
            0) echo "    (v0 - Minimal: code and essential content only)" ;;
            1) echo "    (v1 - Compact: skip user sentiments, show responses)" ;;
            2) echo "    (v2 - Standard: include everything - default)" ;;
            3) echo "    (v3 - Verbose: include context files and expansions)" ;;
            4) echo "    (v4 - Complete: everything + LLM execution details + vimfolds)" ;;
            5) echo "    (v5 - Raw: include ALL intermediate LLM steps and tool results)" ;;
        esac
        echo "  Output File: ${OUTPUT_FILE:-"[Display to terminal only]"}"
        echo ""
        echo "Options:"
        echo "  1) Change verbosity level"
        echo "  2) Set output file path"
        echo "  3) Clear output file (display to terminal)"
        echo "  4) Show current configuration"
        echo "  5) Reset to defaults"
        echo "  b) Back to main menu"
        echo ""
        echo -n "Enter choice (1-5, b): "
        read -r choice
        
        case "$choice" in
            1)
                echo ""
                echo "Select Verbosity Level:"
                echo "======================"
                echo "  0) Minimal - Code and essential content only"
                echo "  1) Compact - Skip user sentiments, show responses"
                echo "  2) Standard - Include everything (default)"
                echo "  3) Verbose - Include context files and expansions"
                echo "  4) Complete - Everything + LLM execution details + vimfolds"
                echo "  5) Raw - Include ALL intermediate LLM steps and tool results"
                echo ""
                echo -n "Enter verbosity level (0-5): "
                read -r new_verbosity
                
                if [[ "$new_verbosity" =~ ^[0-5]$ ]]; then
                    VERBOSITY=$new_verbosity
                    echo ""
                    echo "✅ Verbosity level set to $VERBOSITY"
                else
                    echo ""
                    echo "❌ Invalid verbosity level. Please enter 0-5."
                fi
                ;;
            2)
                echo ""
                echo "📁 Set Output File Path:"
                echo "======================="
                echo "Enter the FULL, ABSOLUTE path where you want to save the output."
                echo "Example: /home/username/Documents/claude-conversations.txt"
                echo "Note: File will be created if it doesn't exist, or appended if it does."
                echo ""
                
                # Get stored path for this project
                local stored_path=""
                if [ -n "$project_name" ] && [ -n "${PROJECT_OUTPUT_PATHS[$project_name]}" ]; then
                    stored_path="${PROJECT_OUTPUT_PATHS[$project_name]}"
                    echo "Previous path for this project: $stored_path"
                    echo "(Press Enter to use previous path, or type new path)"
                fi
                
                if [ -n "$stored_path" ]; then
                    echo -n "Enter absolute file path [$stored_path]: "
                    read -r new_output_file
                    # If user just pressed enter, use stored path
                    if [ -z "$new_output_file" ]; then
                        new_output_file="$stored_path"
                    fi
                else
                    echo -n "Enter absolute file path: "
                    read -r new_output_file
                fi
                
                if [ -z "$new_output_file" ]; then
                    echo ""
                    echo "❌ No path entered. Output file not changed."
                    continue
                fi
                
                # Check if it's an absolute path
                if [[ "$new_output_file" != /* ]]; then
                    echo ""
                    echo "❌ Path must be absolute (start with /). Please try again."
                    continue
                fi
                
                # Check if the directory exists
                local output_dir=$(dirname "$new_output_file")
                if [ ! -d "$output_dir" ]; then
                    echo ""
                    echo -n "Directory '$output_dir' doesn't exist. Create it? (y/n): "
                    read -r create_dir
                    if [[ "$create_dir" == "y" ]] || [[ "$create_dir" == "Y" ]]; then
                        if mkdir -p "$output_dir" 2>/dev/null; then
                            echo "✅ Directory created successfully."
                        else
                            echo "❌ Failed to create directory. Check permissions."
                            continue
                        fi
                    else
                        echo "❌ Output file not set."
                        continue
                    fi
                fi
                
                # Test if we can write to the file
                if touch "$new_output_file" 2>/dev/null; then
                    OUTPUT_FILE="$new_output_file"
                    echo ""
                    echo "✅ Output file set to: $OUTPUT_FILE"
                    
                    # Save this path for the current project
                    if [ -n "$project_name" ]; then
                        PROJECT_OUTPUT_PATHS["$project_name"]="$new_output_file"
                        save_project_paths
                        echo "💾 Path saved for project '$project_name'"
                    fi
                else
                    echo ""
                    echo "❌ Cannot write to '$new_output_file'. Check permissions."
                fi
                ;;
            3)
                OUTPUT_FILE=""
                echo ""
                echo "✅ Output file cleared. Will display to terminal only."
                ;;
            4)
                echo ""
                echo "📋 Current Configuration:"
                echo "========================"
                echo "Verbosity Level: $VERBOSITY"
                echo "Output File: ${OUTPUT_FILE:-"[Display to terminal only]"}"
                echo "Project Directory: $DIR"
                echo "Script Location: $0"
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            5)
                VERBOSITY=2
                OUTPUT_FILE=""
                echo ""
                echo "✅ Settings reset to defaults (verbosity=2, no output file)"
                ;;
            b|B)
                return
                ;;
            '')
                echo "Please enter a choice."
                ;;
            *)
                echo "Invalid choice. Please enter 1-5 or 'b'."
                ;;
        esac
    done
}
# }}}

# {{{ output_content
output_content() {
    local content="$1"
    
    if [ -n "$OUTPUT_FILE" ]; then
        # Output to both terminal and file
        echo "$content" | tee -a "$OUTPUT_FILE"
    else
        # Output to terminal only
        echo "$content"
    fi
}
# }}}

# {{{ interactive_select_conversation
interactive_select_conversation() {
    local project_dir="$1"
    local transcript_dir="$project_dir/llm-transcripts"
    
    if [ ! -d "$transcript_dir" ]; then
        echo "No llm-transcripts directory found in $project_dir"
        echo "Creating directory and attempting to backup conversations..."
        mkdir -p "$transcript_dir"
        
        # Try to run backup script if it exists
        if [ -f "$project_dir/scripts/backup-conversations" ]; then
            echo "Running backup script from scripts/..."
            (cd "$project_dir" && source scripts/backup-conversations && backup-conversations "$project_dir" 2>/dev/null) || true
        elif [ -f "$project_dir/backup-conversations.sh" ]; then
            echo "Running backup script from project root..."
            (cd "$project_dir" && ./backup-conversations.sh 2>/dev/null) || true
        elif [ -f "/home/ritz/programming/ai-stuff/scripts/backup-conversations" ]; then
            echo "Using global backup script from /home/ritz/programming/ai-stuff/scripts/..."
            (source "/home/ritz/programming/ai-stuff/scripts/backup-conversations" && backup-conversations "$project_dir" 2>/dev/null) || true
        fi
        
        # Check if we now have conversations
        if [ ! -n "$(ls -A "$transcript_dir/"*.md 2>/dev/null)" ]; then
            echo "No conversations found after backup attempt."
            echo "This project may not have any Claude conversations yet."
            exit 1
        fi
        echo "Backup completed! Found conversations:"
    fi
    
    # Build array of conversation files
    local conversations=()
    local count=0
    
    for file in "$transcript_dir"/*.md; do
        if [ -f "$file" ]; then
            conversations[count]="$file"
            ((count++))
        fi
    done
    
    if [ ${#conversations[@]} -eq 0 ]; then
        echo "No conversations found in $transcript_dir"
        exit 1
    fi
    
    # Display conversation selection menu
    while true; do
        echo ""
        echo "📋 Claude Conversation Exporter"
        echo "=============================="
        echo ""
        echo "Current Settings: Verbosity=$VERBOSITY"
        case $VERBOSITY in
            0) echo "  (Minimal output)" ;;
            1) echo "  (Compact output)" ;;
            2) echo "  (Standard output)" ;;
            3) echo "  (Verbose output)" ;;
            4) echo "  (Complete output)" ;;
            5) echo "  (Raw output)" ;;
        esac
        if [ -n "$OUTPUT_FILE" ]; then
            echo "  💾 Saving to: $OUTPUT_FILE"
        else
            echo "  🖥️ Display to terminal only"
        fi
        echo ""
        echo "Available Conversations:"
        echo "----------------------"
        for i in "${!conversations[@]}"; do
            local filename=$(basename "${conversations[i]}")
            local filesize=$(stat -c%s "${conversations[i]}" 2>/dev/null || echo "unknown")
            local num=$((i + 1))
            echo "  $num) $filename ($filesize bytes)"
        done
        echo ""
        echo "Actions:"
        echo "  a) Print ALL conversations"
        echo "  s) Settings (change verbosity, view config)"
        echo "  q) Quit"
        echo ""
        echo -n "Enter selection (1-${#conversations[@]}, a, s, q): "
        read -r selection
        
        case "$selection" in
            s|S)
                interactive_settings_menu "$(basename "$project_dir")"
                continue
                ;;
            q|Q)
                echo "Goodbye!"
                exit 0
                ;;
            a|A)
                echo ""
                if [ -n "$OUTPUT_FILE" ]; then
                    echo "🔄 Saving all conversations to: $OUTPUT_FILE"
                    echo "📅 Generated on: $(date)" >> "$OUTPUT_FILE"
                    echo "===========================================" >> "$OUTPUT_FILE"
                    print_all_conversations "$project_dir" >> "$OUTPUT_FILE"
                    echo "✅ All conversations saved to: $OUTPUT_FILE"
                else
                    print_all_conversations "$project_dir"
                fi
                echo ""
                echo "========================================================"
                echo -n "Press Enter to continue, 's' for settings, or 'q' to quit: "
                read -r continue_choice
                if [[ "$continue_choice" == "q" ]] || [[ "$continue_choice" == "Q" ]]; then
                    echo "Goodbye!"
                    exit 0
                elif [[ "$continue_choice" == "s" ]] || [[ "$continue_choice" == "S" ]]; then
                    interactive_settings_menu "$(basename "$project_dir")"
                    continue
                else
                    # Default behavior: exit after successful print/export
                    echo "Goodbye!"
                    exit 0
                fi
                ;;
            ''|*[!0-9]*)
                echo "Invalid input. Please enter a number between 1 and ${#conversations[@]}, 'a' for all, 's' for settings, or 'q' to quit."
                continue
                ;;
            *)
                if [ "$selection" -ge 1 ] && [ "$selection" -le "${#conversations[@]}" ]; then
                    local selected_file="${conversations[$((selection - 1))]}"
                    local filename=$(basename "$selected_file")
                    echo ""
                    echo "Printing conversation: $filename"
                    echo "========================================================"
                    echo ""
                    
                    if [ -n "$OUTPUT_FILE" ]; then
                        echo "🔄 Saving conversation to: $OUTPUT_FILE"
                        echo "📅 Generated on: $(date)" >> "$OUTPUT_FILE"
                        echo "===========================================" >> "$OUTPUT_FILE"
                        echo "Conversation: $filename" >> "$OUTPUT_FILE"
                        echo "===========================================" >> "$OUTPUT_FILE"
                        print_conversation "$project_dir" "$filename" >> "$OUTPUT_FILE"
                        echo "✅ Conversation saved to: $OUTPUT_FILE"
                    else
                        print_conversation "$project_dir" "$filename"
                    fi
                    
                    echo ""
                    echo "========================================================"
                    echo -n "Press Enter to continue, 's' for settings, or 'q' to quit: "
                    read -r continue_choice
                    if [[ "$continue_choice" == "q" ]] || [[ "$continue_choice" == "Q" ]]; then
                        echo "Goodbye!"
                        exit 0
                    elif [[ "$continue_choice" == "s" ]] || [[ "$continue_choice" == "S" ]]; then
                        interactive_settings_menu "$(basename "$project_dir")"
                        continue
                    else
                        # Default behavior: exit after successful print/export
                        echo "Goodbye!"
                        exit 0
                    fi
                else
                    echo "Invalid selection. Please enter a number between 1 and ${#conversations[@]}."
                    continue
                fi
                ;;
        esac
    done
}
# }}}

# {{{ print_project_context_files
print_project_context_files() {
    local project_dir="$1"
    local -n displayed_files_ref=$2
    
    echo "## 📋 Project Context Files"
    echo ""
    
    # Print global CLAUDE.md
    if [ -f "/mnt/mtwo/.claude/CLAUDE.md" ]; then
        echo "### 🌍 Global CLAUDE.md"
        echo ""
        echo "\`\`\`markdown"
        cat "/mnt/mtwo/.claude/CLAUDE.md"
        echo ""
        echo "\`\`\`"
        echo ""
        displayed_files_ref["/mnt/mtwo/.claude/CLAUDE.md"]=1
    fi
    
    # Print local CLAUDE.md files
    for claude_file in "$project_dir/CLAUDE.md" "$project_dir/.claude/CLAUDE.md" "$project_dir/issues/CLAUDE.md"; do
        if [ -f "$claude_file" ]; then
            local relative_path=$(realpath --relative-to="$project_dir" "$claude_file" 2>/dev/null || echo "$claude_file")
            echo "### 📄 Local CLAUDE.md: $relative_path"
            echo ""
            echo "\`\`\`markdown"
            cat "$claude_file"
            echo ""
            echo "\`\`\`"
            echo ""
            displayed_files_ref["$claude_file"]=1
        fi
    done
    
    # Print vision files
    for vision_file in "$project_dir/notes/vision" "$project_dir/vision" "$project_dir/notes/vision.md" "$project_dir/vision.md"; do
        if [ -f "$vision_file" ]; then
            local relative_path=$(realpath --relative-to="$project_dir" "$vision_file" 2>/dev/null || echo "$vision_file")
            echo "### 🔮 Vision: $relative_path"
            echo ""
            echo "\`\`\`"
            cat "$vision_file"
            echo ""
            echo "\`\`\`"
            echo ""
            displayed_files_ref["$vision_file"]=1
        fi
    done
    
    echo "=================================================================================="
    echo ""
}
# }}}

# {{{ should_include_line
should_include_line() {
    local line="$1"
    local in_user_section="$2"
    local in_assistant_section="$3"
    
    case $VERBOSITY in
        0) # Minimal: Only code blocks and file content
            if [[ $line =~ ^\`\`\` ]] || \
               [[ $line =~ ^[[:space:]]*\`[^\`]+\`[[:space:]]*$ ]] || \
               [[ $line =~ \*\*📄[[:space:]]+Full[[:space:]]+content ]] || \
               [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Cc]reated ]] || \
               [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Ww]rote ]] || \
               [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Gg]enerated ]]; then
                return 0
            fi
            return 1
            ;;
        1) # Compact: Skip user sentiments, show assistant responses
            if [ "$in_user_section" = true ]; then
                # In user sections, only show technical requests, skip sentiments
                if [[ $line =~ ^###[[:space:]]+User[[:space:]]+Request ]] || \
                   [[ $line =~ ^-{10,} ]] || \
                   [[ $line =~ [Cc]an[[:space:]]+you ]] || \
                   [[ $line =~ [Pp]lease ]] || \
                   [[ $line =~ [Hh]elp ]] || \
                   [[ $line =~ [Ii]mplement ]] || \
                   [[ $line =~ [Cc]reate ]] || \
                   [[ $line =~ [Aa]dd ]] || \
                   [[ $line =~ [Uu]pdate ]] || \
                   [[ $line =~ [Ff]ix ]]; then
                    return 0
                fi
                # Skip emotional expressions and casual conversation
                if [[ $line =~ [Gg]reat|[Ee]xcellent|[Aa]wesome|[Tt]hanks|[Tt]hank[[:space:]]+you ]] || \
                   [[ $line =~ ^[[:space:]]*$ ]] || \
                   [[ $line =~ ^[[:space:]]*[.!?]+[[:space:]]*$ ]]; then
                    return 1
                fi
                return 0
            fi
            return 0
            ;;
        2) # Standard: Include everything (default)
            return 0
            ;;
        3) # Verbose: Include everything
            return 0
            ;;
        4) # Complete: Include everything + enhanced execution details
            return 0
            ;;
        5) # Raw: Include everything including intermediate steps
            return 0
            ;;
    esac
    return 0
}
# }}}

# {{{ process_conversation_with_file_expansion
process_conversation_with_file_expansion() {
    local conversation_file="$1"
    local project_dir="$2"
    local -n displayed_files_ref=$3
    local -n referenced_files_ref=$4
    
    # Read the file content into a variable to avoid subshell issues
    local content=$(tail -n +4 "$conversation_file")
    local in_user_section=false
    local in_assistant_section=false
    
    while IFS= read -r line; do
        # Track conversation sections for verbosity filtering
        if [[ $line =~ ^###[[:space:]]+User[[:space:]]+Request ]]; then
            in_user_section=true
            in_assistant_section=false
        elif [[ $line =~ ^###[[:space:]]+Assistant[[:space:]]+Response ]]; then
            in_user_section=false
            in_assistant_section=true
        elif [[ $line =~ ^-{10,} ]]; then
            in_user_section=false
            in_assistant_section=false
        fi
        
        # Apply verbosity filtering
        if ! should_include_line "$line" "$in_user_section" "$in_assistant_section"; then
            continue
        fi
        
        # Enhanced file detection patterns for v4 - includes LLM execution details
        local file_detected=false
        local file_path=""
        
        # Check for file creation patterns and expand them
        if [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Cc]reated[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
           [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Ww]rote[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
           [[ $line =~ ^[[:space:]]*([0-9]+)→.*[Gg]enerated[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]]; then
            
            file_path="${BASH_REMATCH[2]}"
            file_detected=true
            
        # Enhanced patterns for v4 - detect file reads, edits, and tool operations
        elif [ $VERBOSITY -eq 4 ]; then
            # Detect Read tool operations
            if [[ $line =~ [Rr]ead[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
               [[ $line =~ [Rr]eading[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
               [[ $line =~ file_path.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]]; then
                file_path="${BASH_REMATCH[1]}"
                file_detected=true
                
            # Detect Edit tool operations
            elif [[ $line =~ [Ee]dit[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
                 [[ $line =~ [Ee]diting[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
                 [[ $line =~ [Uu]pdated[[:space:]]+.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]]; then
                file_path="${BASH_REMATCH[1]}"
                file_detected=true
                
            # Detect Bash command references to files
            elif [[ $line =~ [Bb]ash.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]] || \
                 [[ $line =~ [Cc]ommand.*[\`\"\']*([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\']* ]]; then
                file_path="${BASH_REMATCH[1]}"
                file_detected=true
                
            # Detect file path references in general
            elif [[ $line =~ [\`\"\']([^[:space:]]+\.[a-zA-Z]{1,4})[\`\"\'] ]]; then
                file_path="${BASH_REMATCH[1]}"
                file_detected=true
            fi
        fi
        
        if [ "$file_detected" = true ] && [ -n "$file_path" ]; then
            # Try to find the file in various locations
            local full_path=""
            for potential_path in "$project_dir/$file_path" "$file_path" "$project_dir/$(basename "$file_path")"; do
                if [ -f "$potential_path" ]; then
                    full_path="$potential_path"
                    break
                fi
            done
            
            if [ -n "$full_path" ]; then
                echo "$line"
                
                # Show file content based on verbosity level
                if [ $VERBOSITY -ge 1 ] && [ -z "${displayed_files_ref[$full_path]}" ]; then
                    echo ""
                    echo "**📄 Full content of $file_path:**"
                    echo ""
                    echo "\`\`\`$(get_file_language "$file_path")"
                    cat "$full_path"
                    echo ""
                    echo "\`\`\`"
                    echo ""
                    displayed_files_ref["$full_path"]=1
                else
                    # Always mark for vimfold inclusion at v4 for comprehensive context
                    if [ $VERBOSITY -eq 4 ]; then
                        referenced_files_ref["$full_path"]=1
                    elif [ $VERBOSITY -ge 3 ]; then
                        referenced_files_ref["$full_path"]=1
                    fi
                fi
            else
                echo "$line"
            fi
            
        # Check for file reference patterns like "lines 1-10" and remove "missing" indicators
        elif [[ $line =~ \([0-9]+[[:space:]]+lines[[:space:]]+missing\) ]]; then
            # Remove the "missing lines" indicator
            echo "${line/\([0-9]*[[:space:]]*lines[[:space:]]*missing\)/}"
            
        else
            # Enhanced execution detail annotation for v4
            if [ $VERBOSITY -eq 4 ]; then
                # Annotate tool calls and LLM operations
                if [[ $line =~ \<function_calls\> ]] || \
                   [[ $line =~ \<invoke[[:space:]]+name= ]] || \
                   [[ $line =~ \</function_calls\> ]]; then
                    echo "🔧 **LLM Tool Call:** $line"
                    
                elif [[ $line =~ [Bb]ash[[:space:]]+command: ]] || \
                     [[ $line =~ [Rr]unning[[:space:]]+command: ]] || \
                     [[ $line =~ [Ee]xecuting: ]]; then
                    echo "⚡ **Command Execution:** $line"
                    
                elif [[ $line =~ [Rr]ead[[:space:]]+tool ]] || \
                     [[ $line =~ [Ee]dit[[:space:]]+tool ]] || \
                     [[ $line =~ [Ww]rite[[:space:]]+tool ]] || \
                     [[ $line =~ [Gg]rep[[:space:]]+tool ]]; then
                    echo "🛠️ **Tool Operation:** $line"
                    
                elif [[ $line =~ [Cc]hecking[[:space:]] ]] || \
                     [[ $line =~ [Vv]erifying[[:space:]] ]] || \
                     [[ $line =~ [Tt]esting[[:space:]] ]]; then
                    echo "🔍 **Verification Step:** $line"
                    
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        fi
    done <<< "$content"
}
# }}}

# {{{ print_referenced_files_in_folds
print_referenced_files_in_folds() {
    local project_dir="$1"
    local -n referenced_files_ref=$2
    local -n displayed_files_ref=$3
    
    if [ ${#referenced_files_ref[@]} -gt 0 ]; then
        echo ""
        if [ $VERBOSITY -eq 4 ]; then
            echo "## 📁 Referenced Files & Execution Context (Vimfolds)"
            echo ""
            echo "*Complete execution context - all referenced files with LLM operation details:*"
        else
            echo "## 📁 Referenced Files (Collapsed)"
            echo ""
            echo "*The following files were referenced multiple times in conversations and are available in collapsed sections:*"
        fi
        echo ""
        
        for file_path in "${!referenced_files_ref[@]}"; do
            if [ -f "$file_path" ]; then
                local relative_path=$(realpath --relative-to="$project_dir" "$file_path" 2>/dev/null || basename "$file_path")
                local filesize=$(stat -c%s "$file_path" 2>/dev/null || echo "unknown")
                local file_lines=$(wc -l < "$file_path" 2>/dev/null || echo "unknown")
                local file_modified=$(stat -c%y "$file_path" 2>/dev/null || echo "unknown")
                
                if [ $VERBOSITY -eq 4 ]; then
                    echo "<!-- {{{ $relative_path - Complete Context -->"
                    echo "### 📄 $relative_path"
                    echo ""
                    echo "**File Metadata:**"
                    echo "- Size: $filesize bytes"
                    echo "- Lines: $file_lines"
                    echo "- Modified: $file_modified"
                    echo "- Language: $(get_file_language "$file_path")"
                    echo ""
                    echo "**File Content:**"
                    echo ""
                    echo "\`\`\`$(get_file_language "$file_path")"
                    cat "$file_path"
                    echo ""
                    echo "\`\`\`"
                    echo "<!-- }}} -->"
                else
                    echo "<!-- {{{ $relative_path ($filesize bytes) -->"
                    echo "### 📄 $relative_path"
                    echo ""
                    echo "\`\`\`$(get_file_language "$file_path")"
                    cat "$file_path"
                    echo ""
                    echo "\`\`\`"
                    echo "<!-- }}} -->"
                fi
                echo ""
            fi
        done
    fi
}
# }}}

# {{{ process_raw_conversation
process_raw_conversation() {
    local project_dir="$1"
    local -n displayed_files_ref=$2
    local -n referenced_files_ref=$3
    
    # Find the corresponding Claude project directory by searching all projects
    local claude_project_dir=""
    local claude_base_dir="$HOME/.claude/projects"
    
    # Try to find any project directory that contains JSONL files
    for claude_project in "$claude_base_dir"/*; do
        if [ -d "$claude_project" ] && [ -n "$(ls "$claude_project"/*.jsonl 2>/dev/null)" ]; then
            claude_project_dir="$claude_project"
            break
        fi
    done
    
    if [ -z "$claude_project_dir" ]; then
        echo "Could not find any Claude project directory with conversation data in: $claude_base_dir"
        return 1
    fi
    
    echo "## 🔍 Raw Claude Conversation Data"
    echo ""
    echo "**Source:** $claude_project_dir"
    echo "**Note:** This shows ALL intermediate steps, tool calls, and LLM reasoning"
    echo ""
    echo "=================================================================================="
    echo ""
    
    local conversation_count=0
    
    # Process each JSONL file directly
    for jsonl_file in "$claude_project_dir"/*.jsonl; do
        if [ -f "$jsonl_file" ]; then
            conversation_count=$((conversation_count + 1))
            local conversation_id=$(basename "$jsonl_file" .jsonl)
            
            echo "### 📡 Raw Conversation $conversation_count: $conversation_id"
            echo ""
            echo "**JSONL File:** $jsonl_file"
            echo ""
            
            # Process raw JSONL data with pure bash
            local message_count=0
            local -A displayed_files
            
            while IFS= read -r line || [ -n "$line" ]; do
                [ -z "$line" ] && continue
                ((message_count++))
                
                # Extract basic fields using jq
                local msg_type=$(echo "$line" | jq -r '.type // "unknown"')
                local timestamp=$(echo "$line" | jq -r '.timestamp // .created_at // "unknown"')
                
                # Skip tool result messages entirely - they don't add value
                if [ "$msg_type" = "tool_result" ]; then
                    # Don't increment message count or display anything for tool results
                    ((message_count--))
                    continue
                fi
                
                # Skip user messages that contain tool-related content (likely misclassified tool results)
                if [ "$msg_type" = "user" ]; then
                    local user_content=$(echo "$line" | jq -r '.message.content // ""')
                    if [[ "$user_content" =~ "Tool completed" ]] || \
                       [[ "$user_content" =~ "Tool Result" ]] || \
                       [[ "$user_content" =~ "⚙️" ]] || \
                       [[ "$user_content" =~ "🔧 \*\*Tool" ]]; then
                        # This is likely a tool result misclassified as user message, skip it
                        ((message_count--))
                        continue
                    fi
                fi
                
                echo "#### 📨 Message $message_count"
                echo "**Type:** $msg_type | **Time:** $timestamp"
                
                # Check if this is a message with content
                if echo "$line" | jq -e '.message.content' >/dev/null 2>&1; then
                    echo "**Content:**"
                    
                    # Check if content is a string (user message) or array (assistant message)
                    local content_type=$(echo "$line" | jq -r '.message.content | type')
                    
                    if [ "$content_type" = "string" ]; then
                        # User message - content is a simple string
                        local user_content=$(echo "$line" | jq -r '.message.content // ""')
                        if [ -n "$user_content" ] && [ "$user_content" != "null" ]; then
                            echo "$user_content"
                        fi
                    elif [ "$content_type" = "array" ]; then
                        # Assistant message - content is an array
                        echo "$line" | jq -c '.message.content[]?' | while read -r content_item; do
                            local item_type=$(echo "$content_item" | jq -r '.type // "text"')
                            
                            case "$item_type" in
                                "text")
                                    local text_content=$(echo "$content_item" | jq -r '.text // ""')
                                    if [ -n "$text_content" ] && [ "$text_content" != "null" ]; then
                                        echo "$text_content"
                                    fi
                                    ;;
                                "tool_use")
                                    local tool_name=$(echo "$content_item" | jq -r '.name // "unknown"')
                                    local tool_input=$(echo "$content_item" | jq -r '.input // {}')
                                    
                                    case "$tool_name" in
                                        "Read")
                                            local file_path=$(echo "$tool_input" | jq -r '.file_path // ""')
                                            echo "🔧 **Read:** $file_path"
                                            ;;
                                        "Write")
                                            local file_path=$(echo "$tool_input" | jq -r '.file_path // ""')
                                            echo "🔧 **Write:** $file_path"
                                            # Auto-display the written file content with box-drawing if it exists and hasn't been displayed
                                            if [ -f "$file_path" ] && [ -z "${displayed_files[$file_path]}" ]; then
                                                echo ""
                                                display_file_with_box "$file_path" "Written File"
                                                displayed_files["$file_path"]=1
                                            fi
                                            ;;
                                        "Edit")
                                            local file_path=$(echo "$tool_input" | jq -r '.file_path // ""')
                                            local old_str=$(echo "$tool_input" | jq -r '.old_string // ""')
                                            local new_str=$(echo "$tool_input" | jq -r '.new_string // ""')
                                            echo "🔧 **Edit:** $file_path"
                                            # Show edit context with surrounding lines
                                            show_edit_context "$file_path" "$old_str" "$new_str"
                                            ;;
                                        "TodoWrite")
                                            echo "🔧 **TodoWrite:**"
                                            echo "$tool_input" | jq -r '.todos[]? | 
                                                if .status == "completed" then "   ✅ " + .content
                                                elif .status == "in_progress" then "   🟡 " + .content  
                                                else "   ⭕ " + .content
                                                end'
                                            ;;
                                        "Bash")
                                            local command=$(echo "$tool_input" | jq -r '.command // ""')
                                            echo "🔧 **Bash:** \`$command\`"
                                            ;;
                                        *)
                                            echo "🔧 **$tool_name:** $tool_input"
                                            ;;
                                    esac
                                    ;;
                                "tool_result")
                                    # Skip tool results - they don't add value to the conversation flow
                                    ;;
                                *)
                                    echo "❓ **Unknown content type:** $item_type"
                                    ;;
                            esac
                        done
                    fi
                fi
                
                echo ""
                echo "---"
                echo ""
                
            done < "$jsonl_file"
            
            echo "📊 **Total Messages Processed:** $message_count"
            
            echo ""
            echo "=================================================================================="
            echo ""
        fi
    done
    
    echo "🔍 **Raw Data Processing Complete** - $conversation_count conversation files analyzed"
    echo ""
}
# }}}

# {{{ print_all_conversations
print_all_conversations() {
    local project_dir="$1"
    local transcript_dir="$project_dir/llm-transcripts"
    
    if [ ! -d "$transcript_dir" ]; then
        echo "No llm-transcripts directory found in $project_dir"
        echo "Creating directory and attempting to backup conversations..."
        mkdir -p "$transcript_dir"
        
        # Try to run backup script if it exists
        if [ -f "$project_dir/scripts/backup-conversations" ]; then
            echo "Running backup script from scripts/..."
            (cd "$project_dir" && source scripts/backup-conversations && backup-conversations "$project_dir" 2>/dev/null) || true
        elif [ -f "$project_dir/backup-conversations.sh" ]; then
            echo "Running backup script from project root..."
            (cd "$project_dir" && ./backup-conversations.sh 2>/dev/null) || true
        elif [ -f "/home/ritz/programming/ai-stuff/scripts/backup-conversations" ]; then
            echo "Using global backup script from /home/ritz/programming/ai-stuff/scripts/..."
            (source "/home/ritz/programming/ai-stuff/scripts/backup-conversations" && backup-conversations "$project_dir" 2>/dev/null) || true
        fi
        
        # Check if we now have conversations
        if [ ! -n "$(ls -A "$transcript_dir/"*.md 2>/dev/null)" ]; then
            echo "No conversations found after backup attempt."
            echo "This project may not have any Claude conversations yet."
            exit 1
        fi
        echo "Backup completed!"
        echo ""
    fi
    
    # Initialize file tracking
    declare -A displayed_files
    declare -A referenced_files
    
    # Generate header
    local project_name=$(basename "$project_dir")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local total_files=$(ls -1 "$transcript_dir"/*.md 2>/dev/null | wc -l)
    
    echo "# 🎒 Claude Conversation Backup - Full Context Pack"
    echo ""
    echo "**Project:** $project_name  "
    echo "**Generated:** $timestamp  "
    echo "**Total Conversations:** $total_files  "
    echo "**Ready for Distribution:** As the traveller pleases ✨"
    echo ""
    echo "=================================================================================="
    echo ""
    
    # Print CLAUDE.md files and vision files based on verbosity
    if [ $VERBOSITY -ge 3 ]; then
        print_project_context_files "$project_dir" displayed_files
    fi
    
    # Handle raw processing for v5
    if [ $VERBOSITY -eq 5 ]; then
        process_raw_conversation "$project_dir" displayed_files referenced_files
        local count="raw"
    else
        # Print all conversations with separators and file reference expansion
        local count=0
        for file in "$transcript_dir"/*.md; do
            if [ -f "$file" ]; then
                ((count++))
                local filename=$(basename "$file")
                local filesize=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
                
                echo "## 📜 Conversation $count: $filename"
                echo ""
                echo "*File size: $filesize bytes*"
                echo ""
                echo "---"
                echo ""
                
                # Process conversation content with file reference expansion
                process_conversation_with_file_expansion "$file" "$project_dir" displayed_files referenced_files
                
                echo ""
                echo "=================================================================================="
                echo ""
            fi
        done
    fi
    
    # Print referenced files in vimfolds for complete verbosity
    if [ $VERBOSITY -ge 4 ]; then
        print_referenced_files_in_folds "$project_dir" referenced_files displayed_files
    fi
    
    echo "🎒 **End of Context Pack** - $count conversations included"
    echo ""
    echo "*\"The traveller carries wisdom in many forms, ready to share when the path calls for it.\"*"
}
# }}}

# {{{ print_conversation
print_conversation() {
    local project_dir="$1"
    local conversation_pattern="$2"
    local transcript_dir="$project_dir/llm-transcripts"
    
    if [ ! -d "$transcript_dir" ]; then
        echo "No llm-transcripts directory found in $project_dir"
        echo "Creating directory and attempting to backup conversations..."
        mkdir -p "$transcript_dir"
        
        # Try to run backup script if it exists
        if [ -f "$project_dir/scripts/backup-conversations" ]; then
            echo "Running backup script from scripts/..."
            (cd "$project_dir" && source scripts/backup-conversations && backup-conversations "$project_dir" 2>/dev/null) || true
        elif [ -f "$project_dir/backup-conversations.sh" ]; then
            echo "Running backup script from project root..."
            (cd "$project_dir" && ./backup-conversations.sh 2>/dev/null) || true
        elif [ -f "/home/ritz/programming/ai-stuff/scripts/backup-conversations" ]; then
            echo "Using global backup script from /home/ritz/programming/ai-stuff/scripts/..."
            (source "/home/ritz/programming/ai-stuff/scripts/backup-conversations" && backup-conversations "$project_dir" 2>/dev/null) || true
        fi
        
        # Check if we now have conversations
        if [ ! -n "$(ls -A "$transcript_dir/"*.md 2>/dev/null)" ]; then
            echo "No conversations found after backup attempt."
            echo "This project may not have any Claude conversations yet."
            exit 1
        fi
        echo "Backup completed!"
        echo ""
    fi
    
    # Find matching conversation file
    local conversation_file=""
    for file in "$transcript_dir"/*.md; do
        if [[ "$(basename "$file")" == *"$conversation_pattern"* ]]; then
            conversation_file="$file"
            break
        fi
    done
    
    if [ -z "$conversation_file" ] || [ ! -f "$conversation_file" ]; then
        echo "Error: Could not find conversation matching '$conversation_pattern'"
        echo ""
        find_conversations "$project_dir"
        exit 1
    fi
    
    echo "Printing conversation: $(basename "$conversation_file")"
    echo "========================================================"
    echo ""
    
    # Handle raw processing for v5 single conversations
    if [ $VERBOSITY -eq 5 ]; then
        declare -A displayed_files
        declare -A referenced_files
        
        # Print context files first
        print_project_context_files "$project_dir" displayed_files
        
        # Process raw conversation data for specific conversation
        local conversation_id=$(basename "$conversation_file" _summary.md)
        
        # Find the JSONL file by searching claude project directories
        local jsonl_file=""
        local claude_base_dir="$HOME/.claude/projects"
        
        # Try different possible project directory patterns
        for claude_project in "$claude_base_dir"/*; do
            if [ -d "$claude_project" ]; then
                local test_file="$claude_project/$conversation_id.jsonl"
                if [ -f "$test_file" ]; then
                    jsonl_file="$test_file"
                    break
                fi
            fi
        done
        
        if [ -f "$jsonl_file" ]; then
            echo "## 🔍 Raw Single Conversation: $conversation_id"
            echo ""
            echo "**JSONL Source:** $jsonl_file"
            echo "**Note:** Complete intermediate steps and tool results included"
            echo ""
            
            # Use the same Python processing as in process_raw_conversation but for single file
            python3 -c "
import json
import sys
from datetime import datetime

def format_timestamp(ts):
    if isinstance(ts, str):
        try:
            return datetime.fromisoformat(ts.replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
        except:
            return ts
    elif isinstance(ts, (int, float)):
        try:
            return datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
        except:
            return str(ts)
    return str(ts)

def process_content(content):
    if isinstance(content, str):
        return content
    elif isinstance(content, list):
        result = []
        for item in content:
            if isinstance(item, dict):
                if item.get('type') == 'text':
                    text_content = item.get('text', '')
                    if text_content.strip():  # Only add non-empty text
                        result.append(text_content)
                elif item.get('type') == 'tool_use':
                    tool_name = item.get('name', 'unknown')
                    tool_id = item.get('id', 'N/A')
                    result.append(f\"🔧 **{tool_name}:** {tool_id}\")
                    if 'input' in item and item['input']:
                        # Format tool input more readably
                        input_data = item['input']
                        if isinstance(input_data, dict):
                            for key, value in input_data.items():
                                if isinstance(value, str) and len(value) > 100:
                                    # Truncate very long strings
                                    result.append(f\"   **{key}:** {value[:100]}...\")
                                else:
                                    result.append(f\"   **{key}:** {value}\")
                        else:
                            result.append(f\"   **Input:** {input_data}\")
                elif item.get('type') == 'tool_result':
                    # Include tool results but format them better
                    tool_id = item.get('tool_use_id', 'N/A')
                    result.append(f\"⚙️ **Tool completed** (id: {tool_id})\")
                    tool_content = item.get('content', '')
                    if tool_content and tool_content.strip():
                        # Limit tool result content length
                        if len(tool_content) > 200:
                            result.append(f\"   {tool_content[:200]}...\")
                        else:
                            result.append(f\"   {tool_content}\")
                else:
                    result.append(f\"❓ **Unknown Content Type:** {item.get('type', 'undefined')}\")
            else:
                result.append(str(item))
        return '\n'.join(result)
    return str(content)

message_count = 0
with open('$jsonl_file', 'r') as f:
    for line_num, line in enumerate(f, 1):
        try:
            data = json.loads(line.strip())
            message_count += 1
            
            msg_type = data.get('type', 'unknown')
            timestamp = data.get('timestamp', data.get('created_at', 'unknown'))
            
            print(f'#### 📨 Message {message_count}')
            print(f'**Type:** {msg_type} | **Time:** {format_timestamp(timestamp)}')
            
            if 'message' in data:
                message = data['message']
                if isinstance(message, dict):
                    if 'content' in message:
                        print(f'**Content:**')
                        content_output = process_content(message['content'])
                        if content_output.strip():  # Only print non-empty content
                            print(content_output)
                        else:
                            print('(empty content)')
                else:
                    print('**Message:** ' + str(message))
            else:
                print('**Content:** (no message data)')
            
            print()
            print('---')
            print()
            
        except json.JSONDecodeError as e:
            print(f'❌ **JSON Error on line {line_num}:** {e}')
            print()
        except Exception as e:
            print(f'❌ **Processing Error on line {line_num}:** {e}')
            print()

print(f'📊 **Total Messages:** {message_count}')
" 2>/dev/null
        else
            echo "❌ **Raw JSONL file not found:** $jsonl_file"
            echo ""
            echo "Falling back to processed summary:"
            cat "$conversation_file"
        fi
        
    # Include context files for single conversations at v3+  
    elif [ $VERBOSITY -ge 3 ]; then
        declare -A displayed_files
        declare -A referenced_files
        print_project_context_files "$project_dir" displayed_files
        
        # Process the conversation with file expansion
        echo "## 📜 Conversation Content"
        echo ""
        process_conversation_with_file_expansion "$conversation_file" "$project_dir" displayed_files referenced_files
        
        # Print referenced files in vimfolds for complete verbosity
        if [ $VERBOSITY -ge 4 ]; then
            print_referenced_files_in_folds "$project_dir" referenced_files displayed_files
        fi
    else
        # Print the conversation with simple formatting
        cat "$conversation_file"
    fi
}
# }}}

# {{{ main
main() {
    # Load stored project output paths
    load_project_paths
    
    # Check for help flag first
    for arg in "$@"; do
        if [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
            show_usage
            exit 0
        fi
    done
    
    # Parse verbosity arguments directly in main to preserve VERBOSITY changes
    local remaining_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v0|--minimal)
                VERBOSITY=0
                shift
                ;;
            -v1|--compact)
                VERBOSITY=1
                shift
                ;;
            -v2|--standard)
                VERBOSITY=2
                shift
                ;;
            -v3|--verbose)
                VERBOSITY=3
                shift
                ;;
            -v4|--complete)
                VERBOSITY=4
                shift
                ;;
            -v5|--raw)
                VERBOSITY=5
                shift
                ;;
            -h|--help)
                show_usage >&2
                exit 0
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done
    
    # If no arguments remain, show help and start interactive mode
    if [ ${#remaining_args[@]} -eq 0 ]; then
        echo "🚀 Welcome to Claude Conversation Exporter!"
        echo ""
        show_usage
        echo ""
        echo "========================================================"
        echo "🎯 Starting Interactive Mode..."
        echo ""
        
        # Use the configured base directory for project selection
        local base_dir="$PROJECTS_BASE_DIR"
        interactive_select_project "$base_dir"
        if [ $? -eq 0 ]; then
            # The interactive_select_project function will call interactive_select_conversation directly
            true
        fi
        exit 0
    fi
    
    # Check if project is specified as argument
    if [[ -n "${remaining_args[0]}" ]]; then
        # Override DIR if first argument is a directory path
        if [[ "${remaining_args[0]}" =~ ^/ ]] && [[ -d "${remaining_args[0]}" ]]; then
            DIR="${remaining_args[0]}"
            remaining_args=("${remaining_args[@]:1}")
        elif [[ -d "$DIR/${remaining_args[0]}" ]]; then
            # Handle relative paths like "handheld-office"
            DIR="$DIR/${remaining_args[0]}"
            remaining_args=("${remaining_args[@]:1}")
        fi
        
        # If no conversation specified after project, start interactive conversation selection
        if [ ${#remaining_args[@]} -eq 0 ]; then
            interactive_select_conversation "$DIR"
            exit 0
        fi
    else
        # This case should not be reached since we handle no arguments above
        echo "Error: Unexpected argument parsing state"
        exit 1
    fi
    
    # Handle "all" command
    if [[ "${remaining_args[0]}" == "all" ]]; then
        print_all_conversations "$DIR"
        exit 0
    fi
    
    conversation_pattern="${remaining_args[0]}"
    print_conversation "$DIR" "$conversation_pattern"
}
# }}}

# Run main function with all arguments
main "$@"
