#!/bin/bash

# Character Experience System for Progress-II
# Integrates with magical discovery system for enhanced progression
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"
source "${DIR}/libs/magical-discovery.sh"

# Character experience constants
CHARACTER_DIR="${DIR}/game-state/characters"
EXPERIENCE_LOG="${DIR}/game-state/logs/experience-events.log"
STAT_DEFINITIONS="${DIR}/game-state/characters/stat-definitions.txt"

# {{{ initialize_character_experience_system
initialize_character_experience_system() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Initializing character experience system..."
    
    # Ensure character directories exist
    mkdir -p "${base_dir}/characters/maxine"
    mkdir -p "${base_dir}/characters/companions"
    mkdir -p "${base_dir}/logs"
    
    # Initialize stat definitions if they don't exist
    initialize_stat_definitions "${base_dir}"
    
    # Initialize Maxine's character file if it doesn't exist
    initialize_maxine_character "${base_dir}"
    
    # Create experience event log
    if [[ ! -f "${base_dir}/logs/experience-events.log" ]]; then
        echo "# Experience Events Log - Progress-II" > "${base_dir}/logs/experience-events.log"
        echo "# Format: timestamp|character|event_type|experience_gained|source|details" >> "${base_dir}/logs/experience-events.log"
        echo >> "${base_dir}/logs/experience-events.log"
    fi
    
    echo "Character experience system initialized successfully"
    return 0
}
# }}}

# {{{ initialize_stat_definitions
initialize_stat_definitions() {
    local base_dir="${1:-${DIR}/game-state}"
    local stat_file="${base_dir}/characters/stat-definitions.txt"
    
    if [[ ! -f "${stat_file}" ]]; then
        echo "# Character Stat Definitions - Progress-II" > "${stat_file}"
        echo "# Each stat has magical essence affinities and affects gameplay" >> "${stat_file}"
        echo >> "${stat_file}"
        
        # Core stats with magical essence affinities
        echo "# Primary Stats (Problem-solving approaches)" >> "${stat_file}"
        echo "wit=0|natural_magic,astral_resonance|Creative problem solving, clever solutions" >> "${stat_file}"
        echo "strength=0|earth_pulse,flame_spirit|Physical solutions, brute force approaches" >> "${stat_file}"
        echo "intuition=0|astral_resonance,shadow_essence|Reading situations, sensing truth" >> "${stat_file}"
        echo "resilience=0|earth_pulse,water_essence|Surviving hardship, maintaining hope" >> "${stat_file}"
        echo >> "${stat_file}"
        
        echo "# Magical Stats (Environmental interaction)" >> "${stat_file}"
        echo "druid_lore=0|natural_magic,forest_essence|Understanding nature, forest navigation" >> "${stat_file}"
        echo "astral_sight=0|astral_resonance,star_essence|Seeing beyond physical, cosmic awareness" >> "${stat_file}"
        echo "shadow_walk=0|shadow_essence,void_touch|Moving unseen, understanding darkness" >> "${stat_file}"
        echo "elemental_bond=0|flame_spirit,water_essence|Connection to elemental forces" >> "${stat_file}"
        echo >> "${stat_file}"
        
        echo "# Social Stats (Interaction and influence)" >> "${stat_file}"
        echo "charm=0|natural_magic,flame_spirit|Marketplace bartering, social influence" >> "${stat_file}"
        echo "empathy=0|water_essence,natural_magic|Understanding others, emotional connection" >> "${stat_file}"
        echo "leadership=0|flame_spirit,astral_resonance|Guiding companions, inspiring others" >> "${stat_file}"
        echo >> "${stat_file}"
        
        echo "# Survival Stats (Practical skills)" >> "${stat_file}"
        echo "survival=0|earth_pulse,natural_magic|Outdoor skills, resource gathering" >> "${stat_file}"
        echo "crafting=0|earth_pulse,flame_spirit|Making tools, creating useful items" >> "${stat_file}"
        echo "luck=0|astral_resonance,cosmic_flow|Favorable outcomes, avoiding disaster" >> "${stat_file}"
        
        echo >> "${stat_file}"
        echo "# Format: stat_name=value|essence_affinity1,essence_affinity2|description" >> "${stat_file}"
        echo "# Essence affinities determine experience bonuses when allocating points" >> "${stat_file}"
    fi
}
# }}}

# {{{ initialize_maxine_character
initialize_maxine_character() {
    local base_dir="${1:-${DIR}/game-state}"
    local maxine_file="${base_dir}/characters/maxine/character-data.txt"
    
    if [[ ! -f "${maxine_file}" ]]; then
        echo "# Maxine Character Data - Progress-II" > "${maxine_file}"
        echo "# Hero character with valorous companions" >> "${maxine_file}"
        echo >> "${maxine_file}"
        
        echo "name=Maxine" >> "${maxine_file}"
        echo "level=1" >> "${maxine_file}"
        echo "total_experience=0" >> "${maxine_file}"
        echo "available_points=0" >> "${maxine_file}"
        echo "points_until_unlock=5" >> "${maxine_file}"
        echo >> "${maxine_file}"
        
        echo "# Base stats (start at 1 for playability)" >> "${maxine_file}"
        echo "wit=1" >> "${maxine_file}"
        echo "strength=1" >> "${maxine_file}"
        echo "intuition=1" >> "${maxine_file}"
        echo "resilience=1" >> "${maxine_file}"
        echo "druid_lore=0" >> "${maxine_file}"
        echo "astral_sight=0" >> "${maxine_file}"
        echo "shadow_walk=0" >> "${maxine_file}"
        echo "elemental_bond=0" >> "${maxine_file}"
        echo "charm=1" >> "${maxine_file}"
        echo "empathy=1" >> "${maxine_file}"
        echo "leadership=0" >> "${maxine_file}"
        echo "survival=1" >> "${maxine_file}"
        echo "crafting=0" >> "${maxine_file}"
        echo "luck=1" >> "${maxine_file}"
        echo >> "${maxine_file}"
        
        echo "# Recent magical discoveries (for experience bonuses)" >> "${maxine_file}"
        echo "recent_essence_discoveries=" >> "${maxine_file}"
        echo "last_discovery_timestamp=" >> "${maxine_file}"
        echo >> "${maxine_file}"
        
        echo "# Character creation timestamp" >> "${maxine_file}"
        echo "created=$(date)" >> "${maxine_file}"
        echo "last_updated=$(date)" >> "${maxine_file}"
    fi
}
# }}}

# {{{ gain_experience
gain_experience() {
    local character_name="${1}"
    local experience_amount="${2}"
    local source="${3:-unknown}"
    local details="${4:-no details}"
    local base_dir="${5:-${DIR}/game-state}"
    
    if [[ -z "${character_name}" || -z "${experience_amount}" ]]; then
        echo "Error: Missing required parameters for experience gain"
        echo "Usage: gain_experience <character_name> <amount> [source] [details] [base_dir]"
        return 1
    fi
    
    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    
    if [[ ! -f "${character_file}" ]]; then
        echo "Error: Character file not found: ${character_file}"
        return 1
    fi
    
    # Get current experience and points
    local current_experience=$(grep "^total_experience=" "${character_file}" | cut -d'=' -f2)
    local current_points=$(grep "^available_points=" "${character_file}" | cut -d'=' -f2)
    local points_until_unlock=$(grep "^points_until_unlock=" "${character_file}" | cut -d'=' -f2)
    
    # Calculate new experience
    local new_experience=$((current_experience + experience_amount))
    
    # Calculate point pool unlocking (every 5 experience points)
    local points_gained=0
    local new_points_until_unlock=$((points_until_unlock - experience_amount))
    
    while (( new_points_until_unlock <= 0 )); do
        points_gained=$((points_gained + 1))
        new_points_until_unlock=$((new_points_until_unlock + 5))
    done
    
    local new_available_points=$((current_points + points_gained))
    
    # Apply magical discovery bonus if applicable
    local bonus_experience=$(calculate_magical_experience_bonus "${character_name}" "${source}" "${base_dir}")
    if (( bonus_experience > 0 )); then
        new_experience=$((new_experience + bonus_experience))
        details="${details} (magical bonus: +${bonus_experience})"
    fi
    
    # Update character file
    update_character_stat "${character_name}" "total_experience" "${new_experience}" "${base_dir}"
    update_character_stat "${character_name}" "available_points" "${new_available_points}" "${base_dir}"
    update_character_stat "${character_name}" "points_until_unlock" "${new_points_until_unlock}" "${base_dir}"
    update_character_stat "${character_name}" "last_updated" "$(date)" "${base_dir}"
    
    # Log experience event
    local log_file="${base_dir}/logs/experience-events.log"
    echo "${timestamp}|${character_name}|experience_gain|${experience_amount}|${source}|${details}" >> "${log_file}"
    
    # Distribute experience to companions (1 XP per 5 player XP)
    if [[ "${character_name,,}" == "maxine" ]]; then
        distribute_companion_experience "${experience_amount}" "${source}" "${details}" "${base_dir}"
    fi
    
    # Display experience gain message
    echo "✨ ${character_name} gained ${experience_amount} experience from ${source}"
    if (( bonus_experience > 0 )); then
        echo "   🌟 Magical resonance bonus: +${bonus_experience} experience"
    fi
    if (( points_gained > 0 )); then
        echo "   🎯 Unlocked ${points_gained} stat point(s)! Total available: ${new_available_points}"
    fi
    
    return 0
}
# }}}

# {{{ calculate_magical_experience_bonus
calculate_magical_experience_bonus() {
    local character_name="${1}"
    local source="${2}"
    local base_dir="${3:-${DIR}/game-state}"
    
    # Check if source is a magical discovery
    if [[ "${source}" != "magical_discovery" ]]; then
        echo "0"
        return 0
    fi
    
    # Get environmental variables for bonus calculation
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    if [[ ! -f "${env_file}" ]]; then
        echo "0"
        return 0
    fi
    
    # Calculate bonus based on current magical state
    local magic_drain=$(grep "magic_drain=" "${env_file}" | cut -d'=' -f2)
    local nature_astral=$(grep "nature_astral=" "${env_file}" | cut -d'=' -f2)
    
    # Use Lua for complex bonus calculation
    local bonus=$(lua -e "
        local magic_level = ${magic_drain:-0.5}
        local astral_level = ${nature_astral:-0.5}
        local base_bonus = (magic_level + astral_level) / 2
        local scaled_bonus = math.floor(base_bonus * 5)
        print(scaled_bonus)
    ")
    
    echo "${bonus:-0}"
}
# }}}

# {{{ distribute_companion_experience
distribute_companion_experience() {
    local player_experience="${1}"
    local source="${2}"
    local details="${3}"
    local base_dir="${4:-${DIR}/game-state}"
    
    # Calculate companion experience (1 XP per 5 player XP)
    local companion_experience=$((player_experience / 5))
    
    if (( companion_experience > 0 )); then
        # Find all companion files
        local companions_dir="${base_dir}/characters/companions"
        if [[ -d "${companions_dir}" ]]; then
            for companion_file in "${companions_dir}"/*.txt; do
                if [[ -f "${companion_file}" ]]; then
                    local companion_name=$(basename "${companion_file}" .txt)
                    gain_experience "${companion_name}" "${companion_experience}" "shared_${source}" "${details}" "${base_dir}"
                fi
            done
        fi
    fi
}
# }}}

# {{{ allocate_stat_points
allocate_stat_points() {
    local character_name="${1}"
    local stat_name="${2}"
    local points_to_allocate="${3}"
    local base_dir="${4:-${DIR}/game-state}"
    
    if [[ -z "${character_name}" || -z "${stat_name}" || -z "${points_to_allocate}" ]]; then
        echo "Error: Missing required parameters for stat allocation"
        echo "Usage: allocate_stat_points <character_name> <stat_name> <points> [base_dir]"
        return 1
    fi
    
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    if [[ ! -f "${character_file}" ]]; then
        echo "Error: Character file not found: ${character_file}"
        return 1
    fi
    
    # Get current available points
    local available_points=$(grep "^available_points=" "${character_file}" | cut -d'=' -f2)
    
    if (( points_to_allocate > available_points )); then
        echo "Error: Not enough available points. Have: ${available_points}, Need: ${points_to_allocate}"
        return 1
    fi
    
    # Get current stat value
    local current_stat=$(grep "^${stat_name}=" "${character_file}" | cut -d'=' -f2)
    if [[ -z "${current_stat}" ]]; then
        echo "Error: Stat '${stat_name}' not found for character ${character_name}"
        return 1
    fi
    
    # Calculate magical essence bonus
    local essence_bonus=$(calculate_stat_essence_bonus "${character_name}" "${stat_name}" "${base_dir}")
    local total_points_gained=$((points_to_allocate + essence_bonus))
    
    # Update stat value
    local new_stat_value=$((current_stat + total_points_gained))
    update_character_stat "${character_name}" "${stat_name}" "${new_stat_value}" "${base_dir}"
    
    # Deduct available points
    local new_available_points=$((available_points - points_to_allocate))
    update_character_stat "${character_name}" "available_points" "${new_available_points}" "${base_dir}"
    update_character_stat "${character_name}" "last_updated" "$(date)" "${base_dir}"
    
    # Log stat allocation
    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
    local log_file="${base_dir}/logs/experience-events.log"
    echo "${timestamp}|${character_name}|stat_allocation|${points_to_allocate}|${stat_name}|allocated ${total_points_gained} points (${essence_bonus} essence bonus)" >> "${log_file}"
    
    # Display allocation message
    echo "📊 ${character_name}: ${stat_name} increased by ${total_points_gained} (${points_to_allocate} spent"
    if (( essence_bonus > 0 )); then
        echo "   + ${essence_bonus} magical essence bonus)"
    else
        echo ")"
    fi
    echo "   New ${stat_name}: ${new_stat_value}, Remaining points: ${new_available_points}"
    
    return 0
}
# }}}

# {{{ calculate_stat_essence_bonus
calculate_stat_essence_bonus() {
    local character_name="${1}"
    local stat_name="${2}"
    local base_dir="${3:-${DIR}/game-state}"
    
    # Get stat essence affinities
    local stat_file="${base_dir}/characters/stat-definitions.txt"
    local affinities=$(grep "^${stat_name}=" "${stat_file}" | cut -d'|' -f2)
    
    if [[ -z "${affinities}" ]]; then
        echo "0"
        return 0
    fi
    
    # Get character's recent discoveries
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    local recent_discoveries=$(grep "^recent_essence_discoveries=" "${character_file}" | cut -d'=' -f2)
    
    if [[ -z "${recent_discoveries}" ]]; then
        echo "0"
        return 0
    fi
    
    # Check for matching affinities using Lua
    local bonus=$(lua -e "
        local affinities = '${affinities}'
        local discoveries = '${recent_discoveries}'
        local bonus = 0
        
        for affinity in affinities:gmatch('[^,]+') do
            if discoveries:find(affinity) then
                bonus = bonus + 1
            end
        end
        
        print(bonus)
    ")
    
    echo "${bonus:-0}"
}
# }}}

# {{{ update_character_stat
update_character_stat() {
    local character_name="${1}"
    local stat_name="${2}"
    local new_value="${3}"
    local base_dir="${4:-${DIR}/game-state}"
    
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    
    if [[ ! -f "${character_file}" ]]; then
        echo "Error: Character file not found: ${character_file}"
        return 1
    fi
    
    # Create temporary file for update
    local temp_file=$(mktemp)
    
    # Update the stat or add it if it doesn't exist
    local stat_found=false
    while IFS= read -r line; do
        if [[ "${line}" =~ ^${stat_name}= ]]; then
            echo "${stat_name}=${new_value}" >> "${temp_file}"
            stat_found=true
        else
            echo "${line}" >> "${temp_file}"
        fi
    done < "${character_file}"
    
    # If stat wasn't found, add it
    if [[ "${stat_found}" == "false" ]]; then
        echo "${stat_name}=${new_value}" >> "${temp_file}"
    fi
    
    # Replace original file
    mv "${temp_file}" "${character_file}"
    return 0
}
# }}}

# {{{ record_magical_discovery_experience
record_magical_discovery_experience() {
    local character_name="${1}"
    local essence_type="${2}"
    local discovery_location="${3}"
    local base_dir="${4:-${DIR}/game-state}"
    
    # Calculate experience based on discovery resonance
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    local resonance=$(lua "${DIR}/libs/magical-discovery.lua" calculate_resonance "${essence_type}" "${env_file}")
    
    # Convert resonance to experience (1-10 XP based on resonance strength)
    local experience=$(lua -e "print(math.floor(${resonance} * 10) + 1)")
    
    # Add discovery to character's recent discoveries
    update_recent_discoveries "${character_name}" "${essence_type}" "${base_dir}"
    
    # Grant experience
    gain_experience "${character_name}" "${experience}" "magical_discovery" \
        "discovered ${essence_type} at ${discovery_location} (resonance: ${resonance})" "${base_dir}"
    
    echo "🔮 Magical discovery recorded! ${character_name} gains ${experience} experience from ${essence_type}"
}
# }}}

# {{{ update_recent_discoveries
update_recent_discoveries() {
    local character_name="${1}"
    local essence_type="${2}"
    local base_dir="${3:-${DIR}/game-state}"
    
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    local current_discoveries=$(grep "^recent_essence_discoveries=" "${character_file}" | cut -d'=' -f2)
    
    # Add new essence to recent discoveries (limit to last 5)
    local new_discoveries="${essence_type}"
    if [[ -n "${current_discoveries}" ]]; then
        new_discoveries="${current_discoveries},${essence_type}"
    fi
    
    # Keep only last 5 discoveries
    new_discoveries=$(echo "${new_discoveries}" | tr ',' '\n' | tail -5 | tr '\n' ',' | sed 's/,$//')
    
    # Update character file
    update_character_stat "${character_name}" "recent_essence_discoveries" "${new_discoveries}" "${base_dir}"
    update_character_stat "${character_name}" "last_discovery_timestamp" "$(date)" "${base_dir}"
}
# }}}

# {{{ display_character_status
display_character_status() {
    local character_name="${1}"
    local base_dir="${2:-${DIR}/game-state}"
    
    local character_file="${base_dir}/characters/${character_name,,}/character-data.txt"
    if [[ ! -f "${character_file}" ]]; then
        echo "Error: Character file not found: ${character_file}"
        return 1
    fi
    
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    printf "║                        %s CHARACTER STATUS                           ║\n" "${character_name^^}"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    # Basic info
    local level=$(grep "^level=" "${character_file}" | cut -d'=' -f2)
    local experience=$(grep "^total_experience=" "${character_file}" | cut -d'=' -f2)
    local available_points=$(grep "^available_points=" "${character_file}" | cut -d'=' -f2)
    local points_until_unlock=$(grep "^points_until_unlock=" "${character_file}" | cut -d'=' -f2)
    
    printf "║ Level: %-10s Experience: %-10s Available Points: %-10s ║\n" "${level}" "${experience}" "${available_points}"
    printf "║ Points until next unlock: %-10s                                    ║\n" "${points_until_unlock}"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    # Stats display
    echo "║                                    STATS                                      ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    # Get stat definitions for descriptions
    local stat_file="${base_dir}/characters/stat-definitions.txt"
    
    # Primary stats
    echo "║ PRIMARY STATS                                                                 ║"
    display_stat_row "wit" "${character_file}" "${stat_file}"
    display_stat_row "strength" "${character_file}" "${stat_file}"
    display_stat_row "intuition" "${character_file}" "${stat_file}"
    display_stat_row "resilience" "${character_file}" "${stat_file}"
    
    echo "║                                                                               ║"
    echo "║ MAGICAL STATS                                                                 ║"
    display_stat_row "druid_lore" "${character_file}" "${stat_file}"
    display_stat_row "astral_sight" "${character_file}" "${stat_file}"
    display_stat_row "shadow_walk" "${character_file}" "${stat_file}"
    display_stat_row "elemental_bond" "${character_file}" "${stat_file}"
    
    echo "║                                                                               ║"
    echo "║ SOCIAL STATS                                                                  ║"
    display_stat_row "charm" "${character_file}" "${stat_file}"
    display_stat_row "empathy" "${character_file}" "${stat_file}"
    display_stat_row "leadership" "${character_file}" "${stat_file}"
    
    echo "║                                                                               ║"
    echo "║ SURVIVAL STATS                                                                ║"
    display_stat_row "survival" "${character_file}" "${stat_file}"
    display_stat_row "crafting" "${character_file}" "${stat_file}"
    display_stat_row "luck" "${character_file}" "${stat_file}"
    
    # Recent discoveries
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    echo "║ RECENT MAGICAL DISCOVERIES                                                    ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    local recent_discoveries=$(grep "^recent_essence_discoveries=" "${character_file}" | cut -d'=' -f2)
    if [[ -n "${recent_discoveries}" ]]; then
        echo "${recent_discoveries}" | tr ',' '\n' | while read -r essence; do
            if [[ -n "${essence}" ]]; then
                printf "║ • %-75s ║\n" "${essence}"
            fi
        done
    else
        printf "║ %-77s ║\n" "No recent magical discoveries"
    fi
    
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
}
# }}}

# {{{ display_stat_row
display_stat_row() {
    local stat_name="${1}"
    local character_file="${2}"
    local stat_file="${3}"
    
    local stat_value=$(grep "^${stat_name}=" "${character_file}" | cut -d'=' -f2)
    local stat_description=$(grep "^${stat_name}=" "${stat_file}" | cut -d'|' -f3)
    
    if [[ -n "${stat_value}" ]]; then
        printf "║ %-15s: %2s  %-58s ║\n" "${stat_name}" "${stat_value}" "${stat_description:0:58}"
    fi
}
# }}}