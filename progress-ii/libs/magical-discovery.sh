#!/bin/bash

# Magical Discovery Storage System for Progress-II
# Stores the nature of magical discovery intuit through the land
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source state directory management
source "${DIR}/libs/state-directory.sh"

# Magic discovery constants
MAGIC_DISCOVERY_DIR="${DIR}/game-state/world/magical-discoveries"
ENVIRONMENTAL_VARS_FILE="${DIR}/game-state/world/variables/environmental-oscillations.txt"
DISCOVERY_INDEX_FILE="${DIR}/game-state/world/magical-discoveries/discovery-index.txt"

# {{{ initialize_magical_discovery_system
initialize_magical_discovery_system() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Initializing magical discovery storage system..."
    
    # Create magical discovery directories
    mkdir -p "${base_dir}/world/magical-discoveries/locations"
    mkdir -p "${base_dir}/world/magical-discoveries/essences" 
    mkdir -p "${base_dir}/world/magical-discoveries/resonances"
    mkdir -p "${base_dir}/world/magical-discoveries/manifestations"
    
    # Initialize environmental oscillation variables
    initialize_environmental_variables "${base_dir}"
    
    # Create discovery index if it doesn't exist
    if [[ ! -f "${base_dir}/world/magical-discoveries/discovery-index.txt" ]]; then
        echo "# Magical Discovery Index - Progress-II" > "${base_dir}/world/magical-discoveries/discovery-index.txt"
        echo "# Each line: timestamp|location|essence_type|resonance_strength|manifestation" >> "${base_dir}/world/magical-discoveries/discovery-index.txt"
        echo >> "${base_dir}/world/magical-discoveries/discovery-index.txt"
    fi
    
    echo "Magical discovery system initialized successfully"
    return 0
}
# }}}

# {{{ initialize_environmental_variables
initialize_environmental_variables() {
    local base_dir="${1:-${DIR}/game-state}"
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    
    if [[ ! -f "${env_file}" ]]; then
        echo "# Environmental Variable Oscillations - Progress-II" > "${env_file}"
        echo "# Variables oscillate like sine curves, affecting magical discovery" >> "${env_file}"
        echo >> "${env_file}"
        
        # Initialize oscillating variables with starting values (0.0 to 1.0 scale)
        echo "struggle_peace=0.5" >> "${env_file}"
        echo "magic_drain=0.6" >> "${env_file}"
        echo "growth_death=0.7" >> "${env_file}"
        echo "fire_ice=0.3" >> "${env_file}"
        echo "nature_astral=0.8" >> "${env_file}"
        echo "wind_stone=0.4" >> "${env_file}"
        echo "blood_temple=0.2" >> "${env_file}"
        echo "metal_wood=0.9" >> "${env_file}"
        echo "few_all=0.6" >> "${env_file}"
        echo "struggle_silence=0.1" >> "${env_file}"
        
        echo >> "${env_file}"
        echo "# Last updated: $(date)" >> "${env_file}"
    fi
}
# }}}

# {{{ record_magical_discovery
record_magical_discovery() {
    local location="${1}"
    local essence_type="${2}"
    local discovery_description="${3}"
    local base_dir="${4:-${DIR}/game-state}"
    
    if [[ -z "${location}" || -z "${essence_type}" || -z "${discovery_description}" ]]; then
        echo "Error: Missing required parameters for magical discovery recording"
        echo "Usage: record_magical_discovery <location> <essence_type> <description> [base_dir]"
        return 1
    fi
    
    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
    local discovery_id="${timestamp}_${location// /_}"
    
    # Calculate resonance strength based on current environmental variables
    local resonance=$(calculate_magical_resonance "${essence_type}" "${base_dir}")
    
    # Store discovery in location-based file
    local location_file="${base_dir}/world/magical-discoveries/locations/${location// /_}.txt"
    echo "=== Discovery: ${timestamp} ===" >> "${location_file}"
    echo "Essence Type: ${essence_type}" >> "${location_file}"
    echo "Resonance Strength: ${resonance}" >> "${location_file}"
    echo "Description: ${discovery_description}" >> "${location_file}"
    echo >> "${location_file}"
    
    # Store essence-based categorization
    local essence_file="${base_dir}/world/magical-discoveries/essences/${essence_type// /_}.txt"
    echo "${timestamp}|${location}|${resonance}|${discovery_description}" >> "${essence_file}"
    
    # Update discovery index
    local index_file="${base_dir}/world/magical-discoveries/discovery-index.txt"
    echo "${timestamp}|${location}|${essence_type}|${resonance}|${discovery_description}" >> "${index_file}"
    
    # Generate manifestation based on environmental state
    generate_magical_manifestation "${discovery_id}" "${location}" "${essence_type}" "${resonance}" "${base_dir}"
    
    echo "Magical discovery recorded: ${essence_type} at ${location} (resonance: ${resonance})"
    return 0
}
# }}}

# {{{ calculate_magical_resonance
calculate_magical_resonance() {
    local essence_type="${1}"
    local base_dir="${2:-${DIR}/game-state}"
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    
    if [[ ! -f "${env_file}" ]]; then
        echo "0.5"  # Default resonance
        return 0
    fi
    
    # Read current environmental values
    local magic_drain=$(grep "magic_drain=" "${env_file}" | cut -d'=' -f2)
    local nature_astral=$(grep "nature_astral=" "${env_file}" | cut -d'=' -f2)
    local growth_death=$(grep "growth_death=" "${env_file}" | cut -d'=' -f2)
    
    # Calculate resonance based on essence type and environmental state
    local resonance="0.5"  # Default
    
    case "${essence_type}" in
        "natural_magic"|"forest_essence"|"growth_energy")
            # Nature-based essences resonate with magic_drain and nature_astral
            resonance=$(echo "scale=2; (${magic_drain:-0.5} + ${nature_astral:-0.5} + ${growth_death:-0.5}) / 3" | bc)
            ;;
        "shadow_essence"|"drain_energy"|"void_touch")
            # Drain-based essences resonate inversely with magic but align with death
            resonance=$(echo "scale=2; ((1 - ${magic_drain:-0.5}) + (1 - ${growth_death:-0.5})) / 2" | bc)
            ;;
        "astral_resonance"|"star_essence"|"cosmic_flow")
            # Astral essences primarily resonate with nature_astral
            resonance=$(echo "scale=2; ${nature_astral:-0.5} * 1.2" | bc)
            ;;
        *)
            # Unknown essence types get average of all magical variables
            resonance=$(echo "scale=2; (${magic_drain:-0.5} + ${nature_astral:-0.5}) / 2" | bc)
            ;;
    esac
    
    # Ensure resonance stays within 0.0-1.0 bounds
    if (( $(echo "${resonance} > 1.0" | bc -l) )); then
        resonance="1.0"
    elif (( $(echo "${resonance} < 0.0" | bc -l) )); then
        resonance="0.0"
    fi
    
    echo "${resonance}"
}
# }}}

# {{{ generate_magical_manifestation
generate_magical_manifestation() {
    local discovery_id="${1}"
    local location="${2}"
    local essence_type="${3}"
    local resonance="${4}"
    local base_dir="${5:-${DIR}/game-state}"
    
    local manifestation_file="${base_dir}/world/magical-discoveries/manifestations/${discovery_id}.txt"
    
    echo "=== Magical Manifestation: ${discovery_id} ===" > "${manifestation_file}"
    echo "Location: ${location}" >> "${manifestation_file}"
    echo "Essence Type: ${essence_type}" >> "${manifestation_file}"
    echo "Resonance Strength: ${resonance}" >> "${manifestation_file}"
    echo >> "${manifestation_file}"
    
    # Generate manifestation description based on resonance strength
    if (( $(echo "${resonance} > 0.8" | bc -l) )); then
        echo "Manifestation: POWERFUL - The discovery pulses with incredible energy" >> "${manifestation_file}"
        echo "Effect: The very air shimmers with magical potential" >> "${manifestation_file}"
        echo "Influence: Attracts magical creatures and enhances nearby enchantments" >> "${manifestation_file}"
    elif (( $(echo "${resonance} > 0.6" | bc -l) )); then
        echo "Manifestation: STRONG - Clear magical emanations visible to trained eyes" >> "${manifestation_file}"
        echo "Effect: Gentle warmth radiates from the discovery site" >> "${manifestation_file}"
        echo "Influence: Enhances natural healing and magical intuition" >> "${manifestation_file}"
    elif (( $(echo "${resonance} > 0.4" | bc -l) )); then
        echo "Manifestation: MODERATE - Subtle but noticeable magical presence" >> "${manifestation_file}"
        echo "Effect: Occasional sparkles of light dance around the area" >> "${manifestation_file}"
        echo "Influence: Provides minor enhancement to magical sensitivity" >> "${manifestation_file}"
    elif (( $(echo "${resonance} > 0.2" | bc -l) )); then
        echo "Manifestation: WEAK - Faint magical echo, almost imperceptible" >> "${manifestation_file}"
        echo "Effect: A sense of otherworldly presence lingers" >> "${manifestation_file}"
        echo "Influence: Requires deep meditation to perceive effects" >> "${manifestation_file}"
    else
        echo "Manifestation: DORMANT - Magical potential exists but remains hidden" >> "${manifestation_file}"
        echo "Effect: No visible changes, but something waits beneath" >> "${manifestation_file}"
        echo "Influence: May awaken under different environmental conditions" >> "${manifestation_file}"
    fi
    
    echo >> "${manifestation_file}"
    echo "Recorded: $(date)" >> "${manifestation_file}"
}
# }}}

# {{{ query_discoveries_by_location
query_discoveries_by_location() {
    local location="${1}"
    local base_dir="${2:-${DIR}/game-state}"
    
    if [[ -z "${location}" ]]; then
        echo "Error: Location parameter required"
        return 1
    fi
    
    local location_file="${base_dir}/world/magical-discoveries/locations/${location// /_}.txt"
    
    if [[ -f "${location_file}" ]]; then
        echo "=== Magical Discoveries at ${location} ==="
        cat "${location_file}"
    else
        echo "No magical discoveries recorded at ${location}"
    fi
}
# }}}

# {{{ query_discoveries_by_essence
query_discoveries_by_essence() {
    local essence_type="${1}"
    local base_dir="${2:-${DIR}/game-state}"
    
    if [[ -z "${essence_type}" ]]; then
        echo "Error: Essence type parameter required"
        return 1
    fi
    
    local essence_file="${base_dir}/world/magical-discoveries/essences/${essence_type// /_}.txt"
    
    if [[ -f "${essence_file}" ]]; then
        echo "=== ${essence_type} Discoveries ==="
        echo "Timestamp|Location|Resonance|Description"
        echo "----------------------------------------"
        cat "${essence_file}"
    else
        echo "No discoveries recorded for essence type: ${essence_type}"
    fi
}
# }}}

# {{{ update_environmental_variables
update_environmental_variables() {
    local base_dir="${1:-${DIR}/game-state}"
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    
    if [[ ! -f "${env_file}" ]]; then
        echo "Error: Environmental variables file not found"
        return 1
    fi
    
    echo "Updating environmental oscillations..."
    
    # Create temporary file for updates
    local temp_file=$(mktemp)
    
    # Read current values and apply oscillation changes
    while IFS='=' read -r var_name var_value; do
        if [[ "${var_name}" =~ ^[a-z_]+$ ]]; then
            # Generate small random oscillation (-0.1 to +0.1)
            local oscillation=$(echo "scale=3; (${RANDOM} % 200 - 100) / 1000" | bc)
            local new_value=$(echo "scale=3; ${var_value} + ${oscillation}" | bc)
            
            # Keep values within 0.0-1.0 bounds
            if (( $(echo "${new_value} > 1.0" | bc -l) )); then
                new_value="1.0"
            elif (( $(echo "${new_value} < 0.0" | bc -l) )); then
                new_value="0.0"
            fi
            
            echo "${var_name}=${new_value}" >> "${temp_file}"
        else
            echo "${var_name}=${var_value}" >> "${temp_file}"
        fi
    done < <(grep "=" "${env_file}")
    
    # Replace old file with updated values
    mv "${temp_file}" "${env_file}"
    echo >> "${env_file}"
    echo "# Last updated: $(date)" >> "${env_file}"
    
    echo "Environmental variables updated"
}
# }}}

# {{{ display_current_magical_state
display_current_magical_state() {
    local base_dir="${1:-${DIR}/game-state}"
    local env_file="${base_dir}/world/variables/environmental-oscillations.txt"
    
    echo "=== Current Magical State of the Land ==="
    echo
    
    if [[ -f "${env_file}" ]]; then
        echo "Environmental Oscillations:"
        echo "--------------------------"
        
        while IFS='=' read -r var_name var_value; do
            if [[ "${var_name}" =~ ^[a-z_]+$ ]]; then
                # Convert to percentage and create visual bar
                local percentage=$(echo "scale=0; ${var_value} * 100" | bc)
                local bar_length=$((percentage / 5))  # Scale to 20-char bar
                local bar=$(printf "%*s" "${bar_length}" | tr ' ' '█')
                local empty=$(printf "%*s" $((20 - bar_length)) | tr ' ' '░')
                
                printf "%-15s [%s%s] %3d%%\n" "${var_name}" "${bar}" "${empty}" "${percentage}"
            fi
        done < <(grep "=" "${env_file}")
        
        echo
        echo "Recent Discoveries:"
        echo "------------------"
        local index_file="${base_dir}/world/magical-discoveries/discovery-index.txt"
        if [[ -f "${index_file}" ]]; then
            tail -n 5 "${index_file}" | grep -v "^#" | while IFS='|' read -r timestamp location essence resonance description; do
                if [[ -n "${timestamp}" ]]; then
                    echo "• ${timestamp}: ${essence} at ${location} (${resonance})"
                fi
            done
        else
            echo "No discoveries recorded yet"
        fi
    else
        echo "Environmental variables not initialized"
    fi
}
# }}}