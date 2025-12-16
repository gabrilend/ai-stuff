#!/bin/bash

# Save/Load Operations Library for Progress-II
# Handles game state persistence with atomic operations and integrity checking
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"
source "${DIR}/libs/state-serialization.sh"
source "${DIR}/libs/terminal-interface.sh"

# Default save format and settings
DEFAULT_SAVE_FORMAT="human"
MAX_SAVE_SLOTS=10
SAVE_FILE_EXTENSION=".save"
METADATA_EXTENSION=".meta"

# {{{ generate_save_filename
generate_save_filename() {
    local save_name="$1"
    local slot_number="${2:-1}"
    local timestamp="${3:-$(date '+%Y%m%d_%H%M%S')}"
    
    if [ -n "$save_name" ] && [ "$save_name" != "auto" ]; then
        echo "${save_name}_slot${slot_number}_${timestamp}${SAVE_FILE_EXTENSION}"
    else
        echo "autosave_slot${slot_number}_${timestamp}${SAVE_FILE_EXTENSION}"
    fi
}
# }}}

# {{{ generate_save_metadata
generate_save_metadata() {
    local save_file="$1"
    local character_name="$2"
    local level="$3"
    local location="$4"
    local format="$5"
    
    cat << EOF
# Progress-II Save Game Metadata
# Generated: $(get_timestamp)

[SAVE_INFO]
save_file="$save_file"
created="$(get_timestamp)"
game_version="Phase1_v0.1"
format="$format"

[CHARACTER_SUMMARY]
name="$character_name"
level=$level
location="$location"

[FILE_INFO]
size=$(stat -c%s "$save_file" 2>/dev/null || echo "0")
checksum=$(sha256sum "$save_file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

[GAME_STATE]
total_playtime="0:00:00"
last_action="Game saved"
save_count=1
EOF
}
# }}}

# {{{ save_game_state
save_game_state() {
    local character_name="$1"
    local level="${2:-1}"
    local experience="${3:-0}"
    local location="${4:-Tutorial Clearing}"
    local save_name="${5:-auto}"
    local slot_number="${6:-1}"
    local format="${7:-$DEFAULT_SAVE_FORMAT}"
    local base_dir="${8:-$DIR/game-state}"
    
    # Validate inputs
    format=$(validate_format "$format") || return 1
    
    if [ "$slot_number" -lt 1 ] || [ "$slot_number" -gt "$MAX_SAVE_SLOTS" ]; then
        echo "Error: Save slot must be between 1 and $MAX_SAVE_SLOTS" >&2
        return 1
    fi
    
    # Ensure save directory exists
    local save_dir="$base_dir/saves/checkpoints"
    if [ ! -d "$save_dir" ]; then
        echo "Error: Save directory does not exist: $save_dir" >&2
        return 1
    fi
    
    # Generate filenames
    local save_filename
    save_filename=$(generate_save_filename "$save_name" "$slot_number")
    local save_path="$save_dir/$save_filename"
    local temp_save_path="${save_path}.tmp"
    local metadata_path="${save_path%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
    
    echo "Saving game state..."
    echo "Character: $character_name (Level $level)"
    echo "Location: $location"
    echo "Format: $format"
    echo "Slot: $slot_number"
    
    # Create temporary save file for atomic operation
    {
        echo "# Progress-II Game Save File"
        echo "# Generated: $(get_timestamp)"
        echo "# Format: $format"
        echo "# Slot: $slot_number"
        echo ""
        
        echo "[CHARACTER_DATA]"
        serialize_character_data "$character_name" "$level" "$experience" "$location" "$format"
        echo ""
        
        echo "[WORLD_STATE]" 
        # Use default world values for now - will be enhanced in later phases
        serialize_world_state 50 50 50 "$format"
        echo ""
        
        echo "[GAME_CONFIG]"
        serialize_game_config "$base_dir" "$format" "local" "$format"
        
    } > "$temp_save_path"
    
    # Validate the temporary save file
    if [ ! -f "$temp_save_path" ] || [ ! -s "$temp_save_path" ]; then
        echo "Error: Failed to create save file" >&2
        rm -f "$temp_save_path"
        return 1
    fi
    
    # Atomic move to final location
    if ! mv "$temp_save_path" "$save_path"; then
        echo "Error: Failed to finalize save file" >&2
        rm -f "$temp_save_path"
        return 1
    fi
    
    # Generate metadata file
    generate_save_metadata "$save_path" "$character_name" "$level" "$location" "$format" > "$metadata_path"
    
    # Verify save integrity
    if validate_save_file "$save_path"; then
        echo "Game saved successfully to: $save_filename"
        return 0
    else
        echo "Error: Save file validation failed" >&2
        rm -f "$save_path" "$metadata_path"
        return 1
    fi
}
# }}}

# {{{ load_game_state
load_game_state() {
    local save_file="$1"
    local base_dir="${2:-$DIR/game-state}"
    
    # Handle different input formats
    local save_path
    if [[ "$save_file" =~ ^[0-9]+$ ]]; then
        # Slot number provided - find most recent save in that slot
        save_path=$(find_latest_save_in_slot "$save_file" "$base_dir")
        if [ -z "$save_path" ]; then
            echo "Error: No save found in slot $save_file" >&2
            return 1
        fi
    elif [ -f "$save_file" ]; then
        # Full path provided
        save_path="$save_file"
    elif [ -f "$base_dir/saves/checkpoints/$save_file" ]; then
        # Filename provided
        save_path="$base_dir/saves/checkpoints/$save_file"
    else
        echo "Error: Save file not found: $save_file" >&2
        return 1
    fi
    
    echo "Loading game state from: $(basename "$save_path")"
    
    # Validate save file integrity
    if ! validate_save_file "$save_path"; then
        echo "Error: Save file is corrupted or invalid" >&2
        return 1
    fi
    
    # Extract and parse save data
    local character_data world_data config_data
    
    # Extract character data section (skip the [CHARACTER_DATA] header line)
    character_data=$(sed -n '/^\[CHARACTER_DATA\]/,/^\[WORLD_STATE\]/p' "$save_path" | sed '1d;$d')
    if [ -z "$character_data" ]; then
        echo "Error: No character data found in save file" >&2
        return 1
    fi
    
    # Extract world data section
    world_data=$(sed -n '/^\[WORLD_STATE\]/,/^\[GAME_CONFIG\]/p' "$save_path" | sed '1d;$d')
    
    # Extract config data section  
    config_data=$(sed -n '/^\[GAME_CONFIG\]/,/$/p' "$save_path" | tail -n +2)
    
    # Determine format from save file
    local format
    format=$(grep "^# Format:" "$save_path" | head -1 | cut -d' ' -f3)
    format=$(validate_format "$format") || format="human"
    
    # Parse character data
    local parsed_character
    parsed_character=$(deserialize_character_data "$character_data" "$format")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to parse character data" >&2
        return 1
    fi
    
    # Parse world data
    local parsed_world
    parsed_world=$(deserialize_world_state "$world_data" "$format")
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to parse world data, using defaults"
        parsed_world="WORLD_STRUGGLE=50\nWORLD_MAGIC=50\nWORLD_GROWTH=50\nWORLD_LOCATION=Tutorial Clearing"
    fi
    
    # Output parsed data for the caller to use
    echo "# Loaded Game State"
    echo "LOAD_SUCCESS=true"
    echo "SAVE_FILE=$save_path"
    echo "SAVE_FORMAT=$format"
    echo "$parsed_character"
    echo "$parsed_world"
    
    echo "Game loaded successfully!" >&2
    return 0
}
# }}}

# {{{ list_save_games
list_save_games() {
    local base_dir="${1:-$DIR/game-state}"
    local save_dir="$base_dir/saves/checkpoints"
    
    if [ ! -d "$save_dir" ]; then
        echo "No save directory found"
        return 1
    fi
    
    echo "Available Save Games:"
    echo "===================="
    
    local save_count=0
    local slot_summary=()
    
    # Initialize slot summary
    for i in $(seq 1 $MAX_SAVE_SLOTS); do
        slot_summary[$i]="Empty"
    done
    
    # Process save files
    for save_file in "$save_dir"/*${SAVE_FILE_EXTENSION}; do
        if [ ! -f "$save_file" ]; then
            continue
        fi
        
        ((save_count++))
        local filename
        filename=$(basename "$save_file")
        
        # Extract slot number
        local slot_num
        slot_num=$(echo "$filename" | sed -n 's/.*_slot\([0-9]\+\)_.*/\1/p')
        
        # Get metadata if available
        local metadata_file="${save_file%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
        local character_name level location save_time
        
        if [ -f "$metadata_file" ]; then
            character_name=$(grep '^name=' "$metadata_file" | cut -d'"' -f2)
            level=$(grep '^level=' "$metadata_file" | cut -d'=' -f2)
            location=$(grep '^location=' "$metadata_file" | cut -d'"' -f2)
            save_time=$(grep '^created=' "$metadata_file" | cut -d'"' -f2)
        else
            # Fallback to parsing save file directly
            character_name=$(grep '^name=' "$save_file" | head -1 | cut -d'"' -f2)
            level=$(grep '^level=' "$save_file" | head -1 | cut -d'=' -f2)
            location=$(grep '^location=' "$save_file" | head -1 | cut -d'"' -f2)
            save_time=$(stat -c %y "$save_file" | cut -d'.' -f1)
        fi
        
        # Update slot summary
        if [ -n "$slot_num" ] && [ "$slot_num" -ge 1 ] && [ "$slot_num" -le $MAX_SAVE_SLOTS ]; then
            slot_summary[$slot_num]="$character_name (Lv$level) - $location"
        fi
        
        echo "Slot $slot_num: $filename"
        echo "  Character: $character_name (Level $level)"
        echo "  Location: $location"
        echo "  Saved: $save_time"
        echo "  Size: $(stat -c%s "$save_file" 2>/dev/null | numfmt --to=iec || echo "Unknown")"
        echo
    done
    
    if [ $save_count -eq 0 ]; then
        echo "No save games found."
        echo "Start a new game to create your first save."
        return 0
    fi
    
    echo "Quick Slot Summary:"
    echo "=================="
    for i in $(seq 1 $MAX_SAVE_SLOTS); do
        printf "Slot %2d: %s\n" "$i" "${slot_summary[$i]}"
    done
    
    echo ""
    echo "Total saves: $save_count"
    return 0
}
# }}}

# {{{ delete_save_game
delete_save_game() {
    local save_identifier="$1"
    local base_dir="${2:-$DIR/game-state}"
    local confirm="${3:-true}"
    
    # Find the save file
    local save_path
    if [[ "$save_identifier" =~ ^[0-9]+$ ]]; then
        # Slot number provided
        save_path=$(find_latest_save_in_slot "$save_identifier" "$base_dir")
        if [ -z "$save_path" ]; then
            echo "Error: No save found in slot $save_identifier" >&2
            return 1
        fi
    elif [ -f "$save_identifier" ]; then
        save_path="$save_identifier"
    elif [ -f "$base_dir/saves/checkpoints/$save_identifier" ]; then
        save_path="$base_dir/saves/checkpoints/$save_identifier"
    else
        echo "Error: Save file not found: $save_identifier" >&2
        return 1
    fi
    
    local filename
    filename=$(basename "$save_path")
    local metadata_path="${save_path%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
    
    # Confirmation check
    if [ "$confirm" = "true" ]; then
        echo "Are you sure you want to delete save: $filename?"
        if ! confirm_action "Delete this save game"; then
            echo "Save deletion cancelled."
            return 0
        fi
    fi
    
    # Delete save file and metadata
    if rm -f "$save_path" "$metadata_path"; then
        echo "Save game deleted: $filename"
        return 0
    else
        echo "Error: Failed to delete save game" >&2
        return 1
    fi
}
# }}}

# {{{ validate_save_file
validate_save_file() {
    local save_file="$1"
    
    # Check if file exists and is readable
    if [ ! -f "$save_file" ] || [ ! -r "$save_file" ]; then
        return 1
    fi
    
    # Check if file has content
    if [ ! -s "$save_file" ]; then
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^\[CHARACTER_DATA\]" "$save_file"; then
        return 1
    fi
    
    # Verify checksum if metadata exists
    local metadata_file="${save_file%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
    if [ -f "$metadata_file" ]; then
        local stored_checksum expected_checksum
        stored_checksum=$(grep '^checksum=' "$metadata_file" | cut -d'=' -f2)
        expected_checksum=$(sha256sum "$save_file" | cut -d' ' -f1)
        
        if [ -n "$stored_checksum" ] && [ "$stored_checksum" != "unknown" ] && [ "$stored_checksum" != "$expected_checksum" ]; then
            echo "Warning: Save file checksum mismatch - file may be corrupted" >&2
            return 1
        fi
    fi
    
    return 0
}
# }}}

# {{{ find_latest_save_in_slot
find_latest_save_in_slot() {
    local slot_number="$1"
    local base_dir="${2:-$DIR/game-state}"
    local save_dir="$base_dir/saves/checkpoints"
    
    # Find all saves for the specified slot, sorted by modification time
    find "$save_dir" -name "*_slot${slot_number}_*${SAVE_FILE_EXTENSION}" -type f 2>/dev/null | \
        xargs ls -t 2>/dev/null | head -1
}
# }}}

# {{{ cleanup_old_saves
cleanup_old_saves() {
    local base_dir="${1:-$DIR/game-state}"
    local keep_per_slot="${2:-3}"
    local save_dir="$base_dir/saves/checkpoints"
    
    echo "Cleaning up old save files (keeping $keep_per_slot per slot)..."
    
    local cleaned_count=0
    
    for slot in $(seq 1 $MAX_SAVE_SLOTS); do
        # Get all saves for this slot, sorted by modification time (newest first)
        local save_files
        mapfile -t save_files < <(find "$save_dir" -name "*_slot${slot}_*${SAVE_FILE_EXTENSION}" -type f 2>/dev/null | xargs ls -t 2>/dev/null)
        
        # If we have more than the keep limit, delete the oldest ones
        if [ ${#save_files[@]} -gt $keep_per_slot ]; then
            for ((i=keep_per_slot; i<${#save_files[@]}; i++)); do
                local save_file="${save_files[$i]}"
                local metadata_file="${save_file%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
                
                if rm -f "$save_file" "$metadata_file"; then
                    echo "Deleted old save: $(basename "$save_file")"
                    ((cleaned_count++))
                fi
            done
        fi
    done
    
    if [ $cleaned_count -eq 0 ]; then
        echo "No old saves to clean up."
    else
        echo "Cleaned up $cleaned_count old save files."
    fi
    
    return 0
}
# }}}

# {{{ get_save_info
get_save_info() {
    local save_file="$1"
    
    if ! validate_save_file "$save_file"; then
        echo "Error: Invalid save file" >&2
        return 1
    fi
    
    local filename
    filename=$(basename "$save_file")
    local metadata_file="${save_file%${SAVE_FILE_EXTENSION}}${METADATA_EXTENSION}"
    
    echo "Save File Information:"
    echo "====================="
    echo "File: $filename"
    echo "Path: $save_file"
    echo "Size: $(stat -c%s "$save_file" | numfmt --to=iec)"
    echo "Modified: $(stat -c %y "$save_file" | cut -d'.' -f1)"
    
    if [ -f "$metadata_file" ]; then
        echo ""
        echo "Metadata:"
        echo "---------"
        grep -E '^(name|level|location|created|format)=' "$metadata_file" | sed 's/^/  /'
    fi
    
    # Show character info from save file
    echo ""
    echo "Character Data:"
    echo "--------------"
    local character_section
    character_section=$(sed -n '/^\[CHARACTER_DATA\]/,/^\[/p' "$save_file" | sed '$d' | tail -n +2)
    
    if echo "$character_section" | grep -q '^name='; then
        # Human format
        echo "$character_section" | grep -E '^(name|level|experience|location)=' | sed 's/^/  /'
    else
        # Binary format - decode and show
        echo "  Format: Binary (base64 encoded)"
        echo "  Data length: ${#character_section} characters"
    fi
    
    return 0
}
# }}}

# Export functions for use by other scripts
export -f generate_save_filename
export -f generate_save_metadata
export -f save_game_state
export -f load_game_state
export -f list_save_games
export -f delete_save_game
export -f validate_save_file
export -f find_latest_save_in_slot
export -f cleanup_old_saves
export -f get_save_info