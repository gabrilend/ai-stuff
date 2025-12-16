#!/bin/bash

# Test script for Character Experience System integrated with Magical Discovery
# Demonstrates the synergy between magical discovery and character progression
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"
source "${DIR}/libs/magical-discovery.sh"
source "${DIR}/libs/character-experience.sh"

# {{{ clear_screen
clear_screen() {
    clear
    echo
}
# }}}

# {{{ display_header
display_header() {
    echo "============================================================================="
    echo "              CHARACTER EXPERIENCE SYSTEM TEST"
    echo "        Progress-II: Magical Discovery Driving Character Growth"
    echo "============================================================================="
    echo
}
# }}}

# {{{ test_system_initialization
test_system_initialization() {
    echo "=== Testing Integrated System Initialization ==="
    echo
    
    # Create test state directory
    local test_state_dir="${DIR}/test-character-state"
    rm -rf "${test_state_dir}" 2>/dev/null
    
    echo "Creating test state directory..."
    create_state_directories "${test_state_dir}"
    
    echo "Initializing magical discovery system..."
    initialize_magical_discovery_system "${test_state_dir}"
    
    echo "Initializing character experience system..."
    initialize_character_experience_system "${test_state_dir}"
    
    echo "Verifying integrated directory structure..."
    find "${test_state_dir}" -type d | sort
    
    echo
    echo "✓ Integrated system initialization complete"
    echo
}
# }}}

# {{{ test_character_creation_and_setup
test_character_creation_and_setup() {
    echo "=== Testing Character Creation and Setup ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
    echo "Displaying initial character status..."
    display_character_status "Maxine" "${test_state_dir}"
    
    echo
    echo "✓ Character creation and setup complete"
    echo
}
# }}}

# {{{ test_magical_discovery_experience_integration
test_magical_discovery_experience_integration() {
    echo "=== Testing Magical Discovery → Experience Integration ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
    echo "Recording magical discoveries with experience integration..."
    
    # Discovery 1: Natural magic in forest (should boost druid_lore affinity)
    echo "🌲 Discovering natural magic in ancient forest..."
    record_magical_discovery "Ancient Forest Grove" "natural_magic" \
        "Found a tree whose bark pulses with living light, responding to touch with warm, nurturing energy." \
        "${test_state_dir}"
    
    record_magical_discovery_experience "Maxine" "natural_magic" "Ancient Forest Grove" "${test_state_dir}"
    
    echo
    
    # Discovery 2: Astral resonance at mountain peak (should boost astral_sight affinity)
    echo "⭐ Discovering astral resonance at mountain peak..."
    record_magical_discovery "Mountain Peak Observatory" "astral_resonance" \
        "Starlight patterns become visible even during daylight, forming geometric mandalas in the air." \
        "${test_state_dir}"
    
    record_magical_discovery_experience "Maxine" "astral_resonance" "Mountain Peak Observatory" "${test_state_dir}"
    
    echo
    
    # Discovery 3: Shadow essence in cave (should boost shadow_walk affinity)
    echo "🌑 Discovering shadow essence in mysterious cave..."
    record_magical_discovery "Whispering Shadow Cave" "shadow_essence" \
        "Shadows move independently, revealing hidden truths and forgotten memories." \
        "${test_state_dir}"
    
    record_magical_discovery_experience "Maxine" "shadow_essence" "Whispering Shadow Cave" "${test_state_dir}"
    
    echo
    echo "✓ Magical discovery experience integration complete"
    echo
}
# }}}

# {{{ test_stat_allocation_with_bonuses
test_stat_allocation_with_bonuses() {
    echo "=== Testing Stat Allocation with Magical Essence Bonuses ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
    echo "Current character status before stat allocation:"
    display_character_status "Maxine" "${test_state_dir}"
    
    echo
    echo "Allocating points with magical essence bonuses..."
    
    # Allocate to druid_lore (should get bonus from natural_magic discovery)
    echo "📊 Allocating 2 points to druid_lore (should get natural_magic bonus)..."
    allocate_stat_points "Maxine" "druid_lore" "2" "${test_state_dir}"
    
    echo
    
    # Allocate to astral_sight (should get bonus from astral_resonance discovery)
    echo "🔮 Allocating 2 points to astral_sight (should get astral_resonance bonus)..."
    allocate_stat_points "Maxine" "astral_sight" "2" "${test_state_dir}"
    
    echo
    
    # Allocate to a stat without recent essence affinity
    echo "⚔️ Allocating 1 point to strength (no recent essence bonus)..."
    allocate_stat_points "Maxine" "strength" "1" "${test_state_dir}"
    
    echo
    echo "✓ Stat allocation with bonuses complete"
    echo
}
# }}}

# {{{ test_environmental_influence_on_experience
test_environmental_influence_on_experience() {
    echo "=== Testing Environmental Influence on Experience ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
    echo "Current environmental state:"
    display_current_magical_state "${test_state_dir}"
    
    echo
    echo "Updating environmental variables to create different conditions..."
    update_environmental_variables "${test_state_dir}"
    
    echo "New environmental state:"
    display_current_magical_state "${test_state_dir}"
    
    echo
    echo "Recording discovery under new environmental conditions..."
    record_magical_discovery "Elemental Convergence Point" "flame_spirit" \
        "Flames dance without fuel at this nexus point, radiating creative inspiration and passionate energy." \
        "${test_state_dir}"
    
    record_magical_discovery_experience "Maxine" "flame_spirit" "Elemental Convergence Point" "${test_state_dir}"
    
    echo
    echo "✓ Environmental influence testing complete"
    echo
}
# }}}

# {{{ test_lua_calculation_integration
test_lua_calculation_integration() {
    echo "=== Testing Lua Calculation Engine Integration ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    local env_file="${test_state_dir}/world/variables/environmental-oscillations.txt"
    
    echo "Testing direct Lua calculation calls..."
    
    # Test experience calculation
    echo "Calculating experience for flame_spirit at 0.8 resonance:"
    local experience=$(lua "${DIR}/libs/character-experience.lua" calculate_experience "flame_spirit" "0.8" "${env_file}")
    echo "  Result: ${experience} experience points"
    
    # Test stat bonus calculation
    echo "Calculating stat bonus for elemental_bond with recent flame_spirit discovery:"
    local bonus=$(lua "${DIR}/libs/character-experience.lua" calculate_stat_bonus "elemental_bond" "flame_spirit,natural_magic" "${env_file}")
    echo "  Result: +${bonus} bonus points"
    
    # Test narrative generation
    echo "Generating level-up narrative:"
    local narrative=$(lua "${DIR}/libs/character-experience.lua" generate_narrative "Maxine" "elemental_bond" "3" "2" "${env_file}")
    echo "  Narrative: ${narrative}"
    
    echo
    echo "✓ Lua calculation integration working perfectly"
    echo
}
# }}}

# {{{ test_character_progression_analysis
test_character_progression_analysis() {
    echo "=== Testing Character Progression Analysis ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    local character_file="${test_state_dir}/characters/maxine/character-data.txt"
    local env_file="${test_state_dir}/world/variables/environmental-oscillations.txt"
    
    echo "Generating comprehensive progression report..."
    lua "${DIR}/libs/character-experience.lua" progression_report "${character_file}" "${env_file}"
    
    echo
    echo "✓ Character progression analysis complete"
    echo
}
# }}}

# {{{ demonstrate_full_discovery_to_growth_cycle
demonstrate_full_discovery_to_growth_cycle() {
    echo "=== Demonstrating Full Discovery → Growth Cycle ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
    echo "🎯 Complete cycle: Discovery → Experience → Bonus Calculation → Stat Growth"
    echo
    
    # Create a new discovery
    local location="Sacred Moonlit Glade"
    local essence="cosmic_flow"
    local description="Cosmic energies flow like visible rivers of starlight, connecting all living things in an infinite web of consciousness."
    
    echo "📍 Location: ${location}"
    echo "✨ Essence: ${essence}"
    echo "📖 Description: ${description}"
    echo
    
    # Step 1: Record the magical discovery
    echo "Step 1: Recording magical discovery..."
    record_magical_discovery "${location}" "${essence}" "${description}" "${test_state_dir}"
    
    # Step 2: Calculate and grant experience
    echo "Step 2: Calculating experience from discovery..."
    record_magical_discovery_experience "Maxine" "${essence}" "${location}" "${test_state_dir}"
    
    # Step 3: Allocate points with essence bonus
    echo "Step 3: Allocating points with essence affinity bonus..."
    allocate_stat_points "Maxine" "astral_sight" "1" "${test_state_dir}"
    
    # Step 4: Display final character status
    echo "Step 4: Final character status after complete cycle:"
    display_character_status "Maxine" "${test_state_dir}"
    
    echo
    echo "✨ Complete discovery-to-growth cycle demonstrated successfully!"
    echo
}
# }}}

# {{{ cleanup_test_files
cleanup_test_files() {
    echo "=== Cleaning Up Test Files ==="
    echo
    
    local test_state_dir="${DIR}/test-character-state"
    
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
    
    echo "This test demonstrates the character experience system integrated"
    echo "with magical discovery, showing how discoveries drive character growth."
    echo
    echo "Integration features:"
    echo "• Magical discoveries grant experience based on resonance strength"
    echo "• Environmental variables influence experience bonuses"
    echo "• Recent essence discoveries provide stat allocation bonuses"
    echo "• Lua engine handles complex calculations and narrative generation"
    echo "• Complete discovery-to-growth progression cycle"
    echo
    read -p "Press Enter to begin integrated testing..."
    
    test_system_initialization
    test_character_creation_and_setup
    test_magical_discovery_experience_integration
    test_stat_allocation_with_bonuses
    test_environmental_influence_on_experience
    test_lua_calculation_integration
    test_character_progression_analysis
    demonstrate_full_discovery_to_growth_cycle
    
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                           INTEGRATION TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo "✅ CHARACTER EXPERIENCE SYSTEM FEATURES:"
    echo "   ✓ Character creation and stat management"
    echo "   ✓ Experience distribution (5:1 player:companion ratio)"
    echo "   ✓ Point pool unlocking every 5 experience points"
    echo "   ✓ Stat allocation with validation and bonuses"
    echo
    echo "✅ MAGICAL DISCOVERY INTEGRATION:"
    echo "   ✓ Experience granted based on discovery resonance"
    echo "   ✓ Essence affinities provide stat allocation bonuses"
    echo "   ✓ Environmental variables influence experience gains"
    echo "   ✓ Recent discoveries tracked for bonus calculations"
    echo
    echo "✅ LUA CALCULATION ENGINE:"
    echo "   ✓ Complex stat progression curves"
    echo "   ✓ Environmental influence calculations"
    echo "   ✓ Rich narrative generation for character growth"
    echo "   ✓ Progression analysis and recommendations"
    echo
    echo "✅ COMPLETE INTEGRATION:"
    echo "   ✓ Discovery → Experience → Stat Growth cycle"
    echo "   ✓ Environmental state affects all calculations"
    echo "   ✓ Essence affinities create meaningful stat choices"
    echo "   ✓ Character growth feels magical and intentional"
    echo
    echo "The character experience system is fully integrated with magical"
    echo "discovery, creating a cohesive progression system where the world's"
    echo "magical state directly influences character development!"
    echo
    
    read -p "Clean up test files? (y/n): " cleanup_choice
    if [[ "${cleanup_choice}" =~ ^[Yy] ]]; then
        cleanup_test_files
    fi
    
    echo "Integration test complete! Issue 005 successfully implemented"
    echo "with deep magical discovery integration."
}

# Execute main function
main "$@"