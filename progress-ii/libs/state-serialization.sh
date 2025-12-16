#!/bin/bash

# State Serialization Library for Progress-II
# Handles dual-format serialization: human-readable and binary formats
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/terminal-interface.sh"

# Default serialization format
DEFAULT_FORMAT="human"

# {{{ get_timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}
# }}}

# {{{ validate_format
validate_format() {
    local format="$1"
    
    case "$format" in
        "human"|"readable"|"json")
            echo "human"
            return 0
            ;;
        "binary"|"bin"|"compressed")
            echo "binary"
            return 0
            ;;
        *)
            echo "Error: Invalid format '$format'. Use 'human' or 'binary'." >&2
            return 1
            ;;
    esac
}
# }}}

# {{{ serialize_character_data
serialize_character_data() {
    local character_name="$1"
    local level="${2:-1}"
    local experience="${3:-0}"
    local location="${4:-Tutorial Clearing}"
    local format="${5:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            cat << EOF
# Character Data - Progress-II Game Save
# Generated: $(get_timestamp)
# Format: Human-Readable

[CHARACTER]
name="$character_name"
level=$level
experience=$experience
location="$location"
created="$(get_timestamp)"

[STATS]
wit=0
strength=0
druid=0
social=0
luck=100

[INVENTORY]
items=()
gold=0

[COMPANIONS]
count=0
list=()
EOF
            ;;
        "binary")
            # Create binary representation using base64 encoding of structured data
            {
                echo "PROG2_CHAR_V1"
                echo "$character_name"
                echo "$level"
                echo "$experience"
                echo "$location"
                echo "$(get_timestamp)"
                echo "0:0:0:0:100"  # stats
                echo "0:"           # inventory
                echo "0:"           # companions
            } | base64 -w 0
            ;;
    esac
}
# }}}

# {{{ deserialize_character_data
deserialize_character_data() {
    local input_data="$1"
    local format="${2:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            # Parse human-readable format
            local name level experience location
            
            name=$(echo "$input_data" | grep '^name=' | cut -d'"' -f2)
            level=$(echo "$input_data" | grep '^level=' | cut -d'=' -f2)
            experience=$(echo "$input_data" | grep '^experience=' | cut -d'=' -f2)
            location=$(echo "$input_data" | grep '^location=' | cut -d'"' -f2)
            
            echo "CHARACTER_NAME=$name"
            echo "CHARACTER_LEVEL=$level"
            echo "CHARACTER_EXPERIENCE=$experience"
            echo "CHARACTER_LOCATION=$location"
            ;;
        "binary")
            # Decode binary format
            local decoded_data
            decoded_data=$(echo "$input_data" | base64 -d)
            
            local name level experience location timestamp stats inventory companions
            {
                read -r header
                read -r name
                read -r level
                read -r experience
                read -r location
                read -r timestamp
                read -r stats
                read -r inventory
                read -r companions
            } <<< "$decoded_data"
            
            if [ "$header" != "PROG2_CHAR_V1" ]; then
                echo "Error: Invalid binary character data format" >&2
                return 1
            fi
            
            echo "CHARACTER_NAME=$name"
            echo "CHARACTER_LEVEL=$level"
            echo "CHARACTER_EXPERIENCE=$experience"
            echo "CHARACTER_LOCATION=$location"
            ;;
    esac
}
# }}}

# {{{ serialize_world_state
serialize_world_state() {
    local struggle="${1:-50}"
    local magic="${2:-50}"
    local growth="${3:-50}"
    local format="${4:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            cat << EOF
# World State - Progress-II Game Save
# Generated: $(get_timestamp)
# Format: Human-Readable

[ENVIRONMENTAL_VARIABLES]
struggle_peace=$struggle
magic_drain=$magic
growth_death=$growth
fire_ice=50
nature_astral=50
wind_stone=50
blood_temple=50
metal_wood=50
few_all=50
struggle_silence=50

[LOCATIONS]
current="Tutorial Clearing"
discovered=("Tutorial Clearing")
available=("Forest Path" "Ancient Grove" "Mystic Lake")

[WORLD_EVENTS]
active_quests=()
completed_quests=()
available_events=()
EOF
            ;;
        "binary")
            # Create binary representation
            {
                echo "PROG2_WORLD_V1"
                echo "$struggle:$magic:$growth:50:50:50:50:50:50:50"
                echo "Tutorial Clearing"
                echo "1:Tutorial Clearing"
                echo "3:Forest Path:Ancient Grove:Mystic Lake"
                echo "0:0:0"  # events
            } | base64 -w 0
            ;;
    esac
}
# }}}

# {{{ deserialize_world_state
deserialize_world_state() {
    local input_data="$1"
    local format="${2:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            local struggle magic growth current_location
            
            struggle=$(echo "$input_data" | grep '^struggle_peace=' | cut -d'=' -f2)
            magic=$(echo "$input_data" | grep '^magic_drain=' | cut -d'=' -f2)
            growth=$(echo "$input_data" | grep '^growth_death=' | cut -d'=' -f2)
            current_location=$(echo "$input_data" | grep '^current=' | cut -d'"' -f2)
            
            echo "WORLD_STRUGGLE=$struggle"
            echo "WORLD_MAGIC=$magic"
            echo "WORLD_GROWTH=$growth"
            echo "WORLD_LOCATION=$current_location"
            ;;
        "binary")
            local decoded_data
            decoded_data=$(echo "$input_data" | base64 -d)
            
            local header env_vars current_location discovered available events
            {
                read -r header
                read -r env_vars
                read -r current_location
                read -r discovered
                read -r available
                read -r events
            } <<< "$decoded_data"
            
            if [ "$header" != "PROG2_WORLD_V1" ]; then
                echo "Error: Invalid binary world data format" >&2
                return 1
            fi
            
            local struggle magic growth
            IFS=':' read -r struggle magic growth _ _ _ _ _ _ _ <<< "$env_vars"
            
            echo "WORLD_STRUGGLE=$struggle"
            echo "WORLD_MAGIC=$magic"
            echo "WORLD_GROWTH=$growth"
            echo "WORLD_LOCATION=$current_location"
            ;;
    esac
}
# }}}

# {{{ serialize_game_config
serialize_game_config() {
    local hdd_path="${1:-$DIR/game-state}"
    local logging_mode="${2:-human}"
    local ai_model="${3:-local}"
    local format="${4:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            cat << EOF
# Game Configuration - Progress-II
# Generated: $(get_timestamp)
# Format: Human-Readable

[STORAGE]
hdd_path="$hdd_path"
logging_mode="$logging_mode"
auto_save=true
backup_count=5

[AI_SETTINGS]
model_type="$ai_model"
api_timeout=30
command_safety="sandbox"
max_retries=3

[GAME_SETTINGS]
difficulty="normal"
tutorial_completed=false
sound_enabled=true
animations_enabled=true
EOF
            ;;
        "binary")
            {
                echo "PROG2_CONFIG_V1"
                echo "$hdd_path"
                echo "$logging_mode"
                echo "true:5"  # auto_save:backup_count
                echo "$ai_model:30:sandbox:3"  # ai settings
                echo "normal:false:true:true"  # game settings
            } | base64 -w 0
            ;;
    esac
}
# }}}

# {{{ deserialize_game_config
deserialize_game_config() {
    local input_data="$1"
    local format="${2:-$DEFAULT_FORMAT}"
    
    format=$(validate_format "$format") || return 1
    
    case "$format" in
        "human")
            local hdd_path logging_mode ai_model difficulty
            
            hdd_path=$(echo "$input_data" | grep '^hdd_path=' | cut -d'"' -f2)
            logging_mode=$(echo "$input_data" | grep '^logging_mode=' | cut -d'"' -f2)
            ai_model=$(echo "$input_data" | grep '^model_type=' | cut -d'"' -f2)
            difficulty=$(echo "$input_data" | grep '^difficulty=' | cut -d'"' -f2)
            
            echo "CONFIG_HDD_PATH=$hdd_path"
            echo "CONFIG_LOGGING_MODE=$logging_mode"
            echo "CONFIG_AI_MODEL=$ai_model"
            echo "CONFIG_DIFFICULTY=$difficulty"
            ;;
        "binary")
            local decoded_data
            decoded_data=$(echo "$input_data" | base64 -d)
            
            local header hdd_path logging_mode auto_backup ai_settings game_settings
            {
                read -r header
                read -r hdd_path
                read -r logging_mode
                read -r auto_backup
                read -r ai_settings
                read -r game_settings
            } <<< "$decoded_data"
            
            if [ "$header" != "PROG2_CONFIG_V1" ]; then
                echo "Error: Invalid binary config data format" >&2
                return 1
            fi
            
            local ai_model difficulty
            IFS=':' read -r ai_model _ _ _ <<< "$ai_settings"
            IFS=':' read -r difficulty _ _ _ <<< "$game_settings"
            
            echo "CONFIG_HDD_PATH=$hdd_path"
            echo "CONFIG_LOGGING_MODE=$logging_mode"
            echo "CONFIG_AI_MODEL=$ai_model"
            echo "CONFIG_DIFFICULTY=$difficulty"
            ;;
    esac
}
# }}}

# {{{ convert_format
convert_format() {
    local input_data="$1"
    local from_format="$2"
    local to_format="$3"
    local data_type="$4"  # character, world, config
    
    from_format=$(validate_format "$from_format") || return 1
    to_format=$(validate_format "$to_format") || return 1
    
    if [ "$from_format" = "$to_format" ]; then
        echo "$input_data"
        return 0
    fi
    
    # Deserialize from source format and re-serialize to target format
    local parsed_data
    case "$data_type" in
        "character")
            parsed_data=$(deserialize_character_data "$input_data" "$from_format") || return 1
            
            # Extract values for re-serialization
            local name level experience location
            name=$(echo "$parsed_data" | grep "^CHARACTER_NAME=" | cut -d'=' -f2)
            level=$(echo "$parsed_data" | grep "^CHARACTER_LEVEL=" | cut -d'=' -f2)
            experience=$(echo "$parsed_data" | grep "^CHARACTER_EXPERIENCE=" | cut -d'=' -f2)
            location=$(echo "$parsed_data" | grep "^CHARACTER_LOCATION=" | cut -d'=' -f2)
            
            serialize_character_data "$name" "$level" "$experience" "$location" "$to_format"
            ;;
        "world")
            parsed_data=$(deserialize_world_state "$input_data" "$from_format") || return 1
            
            local struggle magic growth
            struggle=$(echo "$parsed_data" | grep "^WORLD_STRUGGLE=" | cut -d'=' -f2)
            magic=$(echo "$parsed_data" | grep "^WORLD_MAGIC=" | cut -d'=' -f2)
            growth=$(echo "$parsed_data" | grep "^WORLD_GROWTH=" | cut -d'=' -f2)
            
            serialize_world_state "$struggle" "$magic" "$growth" "$to_format"
            ;;
        "config")
            parsed_data=$(deserialize_game_config "$input_data" "$from_format") || return 1
            
            local hdd_path logging_mode ai_model
            hdd_path=$(echo "$parsed_data" | grep "^CONFIG_HDD_PATH=" | cut -d'=' -f2)
            logging_mode=$(echo "$parsed_data" | grep "^CONFIG_LOGGING_MODE=" | cut -d'=' -f2)
            ai_model=$(echo "$parsed_data" | grep "^CONFIG_AI_MODEL=" | cut -d'=' -f2)
            
            serialize_game_config "$hdd_path" "$logging_mode" "$ai_model" "$to_format"
            ;;
        *)
            echo "Error: Unknown data type '$data_type'" >&2
            return 1
            ;;
    esac
}
# }}}

# {{{ validate_serialized_data
validate_serialized_data() {
    local data="$1"
    local format="$2"
    local data_type="$3"
    
    format=$(validate_format "$format") || return 1
    
    # Check for empty data
    if [ -z "$data" ]; then
        return 1
    fi
    
    # Attempt to deserialize and check for errors
    local result
    case "$data_type" in
        "character")
            result=$(deserialize_character_data "$data" "$format" 2>/dev/null)
            [ $? -eq 0 ] && echo "$result" | grep -q "CHARACTER_NAME=.*[^[:space:]]" && echo "$result" | grep -q "CHARACTER_LEVEL=[0-9]"
            ;;
        "world")
            result=$(deserialize_world_state "$data" "$format" 2>/dev/null)
            [ $? -eq 0 ] && echo "$result" | grep -q "WORLD_STRUGGLE=[0-9]" && echo "$result" | grep -q "WORLD_MAGIC=[0-9]"
            ;;
        "config")
            result=$(deserialize_game_config "$data" "$format" 2>/dev/null)
            [ $? -eq 0 ] && echo "$result" | grep -q "CONFIG_HDD_PATH=.*[^[:space:]]" && echo "$result" | grep -q "CONFIG_LOGGING_MODE=.*[^[:space:]]"
            ;;
        *)
            echo "Error: Unknown data type '$data_type'" >&2
            return 1
            ;;
    esac
    
    return $?
}
# }}}

# {{{ get_serialization_info
get_serialization_info() {
    local data="$1"
    local format="$2"
    
    format=$(validate_format "$format") || return 1
    
    local size compression_ratio
    size=${#data}
    
    case "$format" in
        "human")
            echo "Format: Human-readable"
            echo "Size: $size characters"
            echo "Compressed: No"
            echo "LLM Compatible: Yes"
            echo "Git Diff Friendly: Yes"
            ;;
        "binary")
            local original_size compressed_size
            # Estimate original size (rough calculation)
            original_size=$((size * 4 / 3))  # base64 overhead
            
            echo "Format: Binary (base64 encoded)"
            echo "Size: $size characters"
            echo "Estimated Original: $original_size bytes"
            echo "Compressed: Yes"
            echo "LLM Compatible: No"
            echo "Git Diff Friendly: No"
            ;;
    esac
}
# }}}

# Export functions for use by other scripts
export -f get_timestamp
export -f validate_format
export -f serialize_character_data
export -f deserialize_character_data
export -f serialize_world_state
export -f deserialize_world_state
export -f serialize_game_config
export -f deserialize_game_config
export -f convert_format
export -f validate_serialized_data
export -f get_serialization_info