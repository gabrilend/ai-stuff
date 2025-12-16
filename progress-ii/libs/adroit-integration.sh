#!/bin/bash
# {{{ Adroit Integration Library for Progress-II
# Provides bash functions to interact with adroit character system
# Designed for seamless integration in progress-ii adventure scripts

# Hard-coded DIR path as per CLAUDE.md requirements  
DIR="${1:-/home/ritz/programming/ai-stuff/progress-ii}"

# {{{ Configuration
ADROIT_PATH="$DIR/libs/adroit"
ADROIT_BINARY="$ADROIT_PATH/src/adroit"
INTEGRATION_BINARY="$DIR/build/integration"
CHARACTER_DATA_DIR="$DIR/game-state/characters"
TEMP_DIR="/tmp/progress-ii-adroit"

# Ensure directories exist
mkdir -p "$CHARACTER_DATA_DIR" "$TEMP_DIR"
# }}}

# {{{ Utility functions
log_adroit() {
    echo "🧙 [Adroit] $1" >&2
}

check_adroit_available() {
    if [[ ! -d "$ADROIT_PATH" ]]; then
        echo "❌ Adroit dependency not found. Run 'make deps' first." >&2
        return 1
    fi
    
    if [[ ! -f "$ADROIT_BINARY" ]]; then
        log_adroit "Building adroit..."
        (cd "$ADROIT_PATH/src" && make) || {
            echo "❌ Failed to build adroit" >&2
            return 1
        }
    fi
    
    return 0
}
# }}}

# {{{ Character Management
generate_character() {
    local character_name="${1:-$(whoami)_$(date +%s)}"
    local output_file="$CHARACTER_DATA_DIR/$character_name.json"
    
    log_adroit "Generating character: $character_name"
    
    if ! check_adroit_available; then
        return 1
    fi
    
    # Create temporary script to generate character and export JSON
    local temp_script="$TEMP_DIR/generate_char.sh"
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# Generate character using adroit and export to JSON
cd "$1" || exit 1

# Run adroit in headless mode (if available) or use integration binary
if [[ -f "./integration_test" ]]; then
    ./integration_test > /tmp/char_output.txt
elif [[ -f "../../build/integration" ]]; then
    ../../build/integration > /tmp/char_output.txt
else
    echo "No suitable character generator found" >&2
    exit 1
fi

# For now, create a placeholder JSON structure
# This will be enhanced when adroit JSON export is implemented
cat > "$2" << JSONEOF
{
    "name": "$3",
    "generated_at": "$(date -Iseconds)",
    "stats": {
        "str": $((RANDOM % 13 + 8)),
        "dex": $((RANDOM % 13 + 8)),
        "con": $((RANDOM % 13 + 8)),
        "int": $((RANDOM % 13 + 8)),
        "wis": $((RANDOM % 13 + 8)),
        "cha": $((RANDOM % 13 + 8))
    },
    "hp": {
        "current": $((RANDOM % 20 + 20)),
        "maximum": $((RANDOM % 20 + 20))
    },
    "equipment": [
        "leather armor",
        "short sword",
        "backpack",
        "rations"
    ],
    "adroit_integration": true
}
JSONEOF
EOF
    
    chmod +x "$temp_script"
    
    # Run character generation
    if "$temp_script" "$ADROIT_PATH/src" "$output_file" "$character_name"; then
        log_adroit "Character saved to: $output_file"
        echo "$output_file"
        return 0
    else
        echo "❌ Failed to generate character" >&2
        return 1
    fi
}

load_character() {
    local character_file="$1"
    
    if [[ ! -f "$character_file" ]]; then
        echo "❌ Character file not found: $character_file" >&2
        return 1
    fi
    
    # Validate JSON and extract basic info
    if command -v jq >/dev/null; then
        local name
        name=$(jq -r '.name // "Unknown"' "$character_file" 2>/dev/null)
        if [[ $? -eq 0 && "$name" != "null" ]]; then
            log_adroit "Loaded character: $name"
            echo "$character_file"
            return 0
        fi
    fi
    
    # Fallback: basic validation
    if grep -q '"name"' "$character_file" && grep -q '"stats"' "$character_file"; then
        log_adroit "Character loaded (basic validation)"
        echo "$character_file"
        return 0
    fi
    
    echo "❌ Invalid character file format" >&2
    return 1
}

list_characters() {
    log_adroit "Available characters:"
    
    if [[ ! -d "$CHARACTER_DATA_DIR" ]]; then
        echo "No characters found"
        return 0
    fi
    
    local count=0
    for char_file in "$CHARACTER_DATA_DIR"/*.json; do
        if [[ -f "$char_file" ]]; then
            local basename
            basename=$(basename "$char_file" .json)
            
            if command -v jq >/dev/null; then
                local name level
                name=$(jq -r '.name // "Unknown"' "$char_file" 2>/dev/null)
                level=$(jq -r '.level // 1' "$char_file" 2>/dev/null)
                echo "  $((++count)). $name (Level $level) [$basename]"
            else
                echo "  $((++count)). $basename"
            fi
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "  No characters found. Use generate_character() to create one."
    fi
}
# }}}

# {{{ Character Information Extraction
get_character_stat() {
    local character_file="$1"
    local stat_name="$2"
    
    if [[ ! -f "$character_file" ]]; then
        echo "0"
        return 1
    fi
    
    if command -v jq >/dev/null; then
        jq -r ".stats.$stat_name // 10" "$character_file" 2>/dev/null
    else
        # Fallback: grep and sed extraction
        grep "\"$stat_name\"" "$character_file" | sed 's/.*: *\([0-9]*\).*/\1/' | head -1
    fi
}

get_character_name() {
    local character_file="$1"
    
    if [[ ! -f "$character_file" ]]; then
        echo "Unknown"
        return 1
    fi
    
    if command -v jq >/dev/null; then
        jq -r '.name // "Unknown"' "$character_file" 2>/dev/null
    else
        grep '"name"' "$character_file" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1
    fi
}

get_character_hp() {
    local character_file="$1"
    local hp_type="${2:-current}"  # current or maximum
    
    if [[ ! -f "$character_file" ]]; then
        echo "0"
        return 1
    fi
    
    if command -v jq >/dev/null; then
        jq -r ".hp.$hp_type // 20" "$character_file" 2>/dev/null
    else
        grep "\"$hp_type\"" "$character_file" | sed 's/.*: *\([0-9]*\).*/\1/' | head -1
    fi
}

calculate_stat_modifier() {
    local stat_value="$1"
    local modifier=$(((stat_value - 10) / 2))
    
    if [[ $modifier -gt 0 ]]; then
        echo "+$modifier"
    else
        echo "$modifier"
    fi
}
# }}}

# {{{ Adventure Integration
check_stat_roll() {
    local character_file="$1"
    local stat_name="$2"
    local difficulty="${3:-15}"  # Default DC 15
    
    local stat_value
    stat_value=$(get_character_stat "$character_file" "$stat_name")
    
    local modifier
    modifier=$(calculate_stat_modifier "$stat_value")
    
    local roll=$((RANDOM % 20 + 1))
    local total=$((roll + modifier))
    
    log_adroit "Rolling $stat_name check: $roll$modifier = $total vs DC $difficulty"
    
    if [[ $total -ge $difficulty ]]; then
        echo "SUCCESS: $total >= $difficulty"
        return 0
    else
        echo "FAILURE: $total < $difficulty"  
        return 1
    fi
}

modify_character_hp() {
    local character_file="$1"
    local hp_change="$2"  # Positive for healing, negative for damage
    
    if [[ ! -f "$character_file" ]]; then
        echo "❌ Character file not found" >&2
        return 1
    fi
    
    local current_hp max_hp new_hp
    current_hp=$(get_character_hp "$character_file" "current")
    max_hp=$(get_character_hp "$character_file" "maximum")
    new_hp=$((current_hp + hp_change))
    
    # Clamp to valid range
    if [[ $new_hp -gt $max_hp ]]; then
        new_hp=$max_hp
    elif [[ $new_hp -lt 0 ]]; then
        new_hp=0
    fi
    
    # Update the file
    if command -v jq >/dev/null; then
        local temp_file="$TEMP_DIR/char_update.json"
        jq ".hp.current = $new_hp" "$character_file" > "$temp_file" && mv "$temp_file" "$character_file"
    else
        # Fallback: sed replacement
        sed -i "s/\"current\": *[0-9]*/\"current\": $new_hp/" "$character_file"
    fi
    
    if [[ $hp_change -gt 0 ]]; then
        log_adroit "Healed for $hp_change HP (now $new_hp/$max_hp)"
    else
        log_adroit "Took ${hp_change#-} damage (now $new_hp/$max_hp)"
    fi
    
    # Check for character death
    if [[ $new_hp -le 0 ]]; then
        log_adroit "⚠️ Character unconscious or dying!"
        return 2
    fi
    
    return 0
}

display_character_summary() {
    local character_file="$1"
    
    if [[ ! -f "$character_file" ]]; then
        echo "❌ Character file not found" >&2
        return 1
    fi
    
    local name str dex con int wis cha current_hp max_hp
    name=$(get_character_name "$character_file")
    str=$(get_character_stat "$character_file" "str")
    dex=$(get_character_stat "$character_file" "dex") 
    con=$(get_character_stat "$character_file" "con")
    int=$(get_character_stat "$character_file" "int")
    wis=$(get_character_stat "$character_file" "wis")
    cha=$(get_character_stat "$character_file" "cha")
    current_hp=$(get_character_hp "$character_file" "current")
    max_hp=$(get_character_hp "$character_file" "maximum")
    
    echo "🧙 ═══════════════════════════════════════════════════════════════════"
    echo "                         $name"
    echo "🧙 ═══════════════════════════════════════════════════════════════════"
    echo "HP: $current_hp/$max_hp"
    echo ""
    echo "STR: $str ($(calculate_stat_modifier "$str"))    DEX: $dex ($(calculate_stat_modifier "$dex"))    CON: $con ($(calculate_stat_modifier "$con"))"
    echo "INT: $int ($(calculate_stat_modifier "$int"))    WIS: $wis ($(calculate_stat_modifier "$wis"))    CHA: $cha ($(calculate_stat_modifier "$cha"))"
    echo "🧙 ═══════════════════════════════════════════════════════════════════"
}
# }}}

# {{{ Integration Demo
demo_adroit_integration() {
    log_adroit "Starting integration demonstration..."
    
    # Generate a test character
    local char_file
    char_file=$(generate_character "demo_adventurer")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to generate demo character" >&2
        return 1
    fi
    
    # Display character info
    display_character_summary "$char_file"
    
    # Simulate some adventure events
    echo ""
    log_adroit "Simulating adventure events..."
    
    echo "🗡️ Attempting to bash down a door..."
    if check_stat_roll "$char_file" "str" 15; then
        echo "   You smash through the door with ease!"
    else
        echo "   The door holds firm. You'll need another approach."
        modify_character_hp "$char_file" -2
        echo "   You hurt your shoulder trying. (-2 HP)"
    fi
    
    echo ""
    echo "🕵️ Searching for hidden treasure..."
    if check_stat_roll "$char_file" "wis" 12; then
        echo "   You notice a loose stone in the wall!"
        echo "   Behind it, you find a healing potion!"
        modify_character_hp "$char_file" 5
        echo "   You drink it immediately. (+5 HP)"
    else
        echo "   Nothing catches your eye here."
    fi
    
    echo ""
    display_character_summary "$char_file"
    
    log_adroit "Demo complete! Character saved at: $char_file"
}
# }}}

# Interactive mode support as per CLAUDE.md
if [[ "$1" = "-I" ]]; then
    echo "🧙 Interactive Adroit Integration"
    echo ""
    echo "Available functions:"
    echo "1. Generate new character"
    echo "2. List existing characters"
    echo "3. Load character"
    echo "4. Display character summary"
    echo "5. Run integration demo"
    echo "6. Exit"
    echo ""
    
    while true; do
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                read -p "Character name (or press Enter for auto): " char_name
                generate_character "$char_name"
                ;;
            2)
                list_characters
                ;;
            3)
                read -p "Character filename: " char_file
                load_character "$CHARACTER_DATA_DIR/$char_file"
                ;;
            4)
                read -p "Character filename: " char_file
                display_character_summary "$CHARACTER_DATA_DIR/$char_file"
                ;;
            5)
                demo_adroit_integration
                ;;
            6)
                echo "👋 Exiting adroit integration"
                exit 0
                ;;
            *)
                echo "Invalid selection. Please choose 1-6."
                ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read
        echo ""
    done
fi

# Export functions for use in other scripts
export -f generate_character load_character list_characters
export -f get_character_stat get_character_name get_character_hp calculate_stat_modifier
export -f check_stat_roll modify_character_hp display_character_summary
export -f demo_adroit_integration
# }}}