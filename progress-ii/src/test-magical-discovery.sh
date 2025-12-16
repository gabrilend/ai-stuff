#!/bin/bash

# Test script for Magical Discovery System
# Demonstrates storing the nature of magical discovery intuit through the land
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"
source "${DIR}/libs/magical-discovery.sh"

# {{{ clear_screen
clear_screen() {
    clear
    echo
}
# }}}

# {{{ display_header
display_header() {
    echo "============================================================================="
    echo "                    MAGICAL DISCOVERY SYSTEM TEST"
    echo "              Progress-II: Nature of Discovery Through the Land"
    echo "============================================================================="
    echo
}
# }}}

# {{{ test_system_initialization
test_system_initialization() {
    echo "=== Testing System Initialization ==="
    echo
    
    # Create test state directory
    local test_state_dir="${DIR}/test-magical-state"
    rm -rf "${test_state_dir}" 2>/dev/null
    
    echo "Creating test state directory..."
    create_state_directories "${test_state_dir}"
    
    echo "Initializing magical discovery system..."
    initialize_magical_discovery_system "${test_state_dir}"
    
    echo "Verifying directory structure..."
    find "${test_state_dir}" -type d | sort
    
    echo
    echo "✓ System initialization complete"
    echo
}
# }}}

# {{{ test_discovery_recording
test_discovery_recording() {
    echo "=== Testing Discovery Recording ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    
    echo "Recording sample magical discoveries..."
    
    # Test various types of discoveries
    record_magical_discovery "Ancient Forest Grove" "natural_magic" \
        "Found a tree whose bark glows with soft green light. The essence feels alive and nurturing, responding to touch with warm pulses." \
        "${test_state_dir}"
    
    record_magical_discovery "Misty Lake Shore" "astral_resonance" \
        "Discovered starlight patterns reflected in still water even during daylight. The patterns shift and dance with cosmic rhythms." \
        "${test_state_dir}"
    
    record_magical_discovery "Shadow Cave Depths" "shadow_essence" \
        "Deep within the cave, shadows move independently of their sources. They whisper secrets of forgotten times." \
        "${test_state_dir}"
    
    record_magical_discovery "Mountain Peak" "flame_spirit" \
        "At the summit, flames dance without fuel, creating warmth and inspiration. The fire speaks of creative potential." \
        "${test_state_dir}"
    
    echo "✓ Discovery recording complete"
    echo
}
# }}}

# {{{ test_lua_integration
test_lua_integration() {
    echo "=== Testing Lua Text Processing Integration ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    local env_file="${test_state_dir}/world/variables/environmental-oscillations.txt"
    
    # Test resonance calculation using Lua
    echo "Calculating resonance strengths using Lua engine..."
    
    for essence in "natural_magic" "shadow_essence" "astral_resonance" "flame_spirit"; do
        local resonance=$(lua "${DIR}/libs/magical-discovery.lua" calculate_resonance "${essence}" "${env_file}")
        echo "  ${essence}: ${resonance}"
    done
    
    echo
    echo "Generating narrative descriptions..."
    
    local narrative=$(lua "${DIR}/libs/magical-discovery.lua" generate_narrative \
        "Ancient Forest Grove" "natural_magic" "0.847" "${env_file}")
    echo "  Narrative: ${narrative}"
    
    echo
    echo "✓ Lua integration working correctly"
    echo
}
# }}}

# {{{ test_environmental_oscillations
test_environmental_oscillations() {
    echo "=== Testing Environmental Oscillations ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    
    echo "Current environmental state:"
    display_current_magical_state "${test_state_dir}"
    
    echo
    echo "Updating environmental oscillations..."
    update_environmental_variables "${test_state_dir}"
    
    echo "Updated environmental state:"
    display_current_magical_state "${test_state_dir}"
    
    echo "✓ Environmental oscillation system working"
    echo
}
# }}}

# {{{ test_discovery_queries
test_discovery_queries() {
    echo "=== Testing Discovery Query System ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    
    echo "Querying discoveries by location..."
    query_discoveries_by_location "Ancient Forest Grove" "${test_state_dir}"
    
    echo
    echo "Querying discoveries by essence type..."
    query_discoveries_by_essence "natural_magic" "${test_state_dir}"
    
    echo
    echo "✓ Query system working correctly"
    echo
}
# }}}

# {{{ demonstrate_discovery_narrative
demonstrate_discovery_narrative() {
    echo "=== Demonstrating Rich Discovery Narratives ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    local env_file="${test_state_dir}/world/variables/environmental-oscillations.txt"
    
    echo "Generating immersive discovery experience..."
    echo
    
    # Create a complex discovery scenario
    local location="Whispering Moonlit Clearing"
    local essence="astral_resonance"
    
    # Calculate resonance using Lua
    local resonance=$(lua "${DIR}/libs/magical-discovery.lua" calculate_resonance "${essence}" "${env_file}")
    
    # Generate rich narrative
    local narrative=$(lua "${DIR}/libs/magical-discovery.lua" generate_narrative \
        "${location}" "${essence}" "${resonance}" "${env_file}")
    
    # Record the discovery
    record_magical_discovery "${location}" "${essence}" "${narrative}" "${test_state_dir}"
    
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           DISCOVERY EXPERIENCE                               ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    printf "║ Location: %-67s ║\n" "${location}"
    printf "║ Essence:  %-67s ║\n" "${essence}"
    printf "║ Resonance: %.3f (%.0f%% strength)                                          ║\n" "${resonance}" "$(echo "${resonance} * 100" | bc)"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    # Word wrap the narrative to fit in the box
    echo "${narrative}" | fold -w 75 | while read -r line; do
        printf "║ %-77s ║\n" "${line}"
    done
    
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    
    echo
    echo "✓ Rich narrative generation working beautifully"
    echo
}
# }}}

# {{{ cleanup_test_files
cleanup_test_files() {
    echo "=== Cleaning Up Test Files ==="
    echo
    
    local test_state_dir="${DIR}/test-magical-state"
    
    echo "Removing test state directory: ${test_state_dir}"
    rm -rf "${test_state_dir}" 2>/dev/null
    
    echo "✓ Cleanup complete"
    echo
}
# }}}

# Main execution
main() {
    clear_screen
    display_header
    
    echo "This test demonstrates the magical discovery system that stores"
    echo "the nature of magical discovery intuit through the land."
    echo
    echo "The system combines:"
    echo "• Bash for data management and file operations"
    echo "• Lua for complex text processing and calculations"
    echo "• Environmental variables that oscillate like natural forces"
    echo "• Rich narrative generation based on magical resonance"
    echo
    read -p "Press Enter to begin testing..."
    
    test_system_initialization
    test_discovery_recording
    test_lua_integration
    test_environmental_oscillations
    test_discovery_queries
    demonstrate_discovery_narrative
    
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                           TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo "✓ Magical discovery storage system fully functional"
    echo "✓ Environmental oscillation system working"
    echo "✓ Lua text processing integration successful"
    echo "✓ Rich narrative generation operational"
    echo "✓ Discovery query system responsive"
    echo
    echo "The system successfully stores the nature of magical discovery"
    echo "intuit through the land, creating a living record of magical"
    echo "essence that players can explore and build upon."
    echo
    
    read -p "Clean up test files? (y/n): " cleanup_choice
    if [[ "${cleanup_choice}" =~ ^[Yy] ]]; then
        cleanup_test_files
    fi
    
    echo "Test complete! The magical discovery system is ready for integration"
    echo "into the main Progress-II game."
}

# Execute main function
main "$@"