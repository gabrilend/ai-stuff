#!/bin/bash
# Project Demo Selector Script
# Asks for a phase number and runs the relevant demo
# As specified in CLAUDE.md instructions

# Hard-coded DIR path as per CLAUDE.md requirements  
DIR="${1:-/home/ritz/programming/ai-stuff/adroit/src}"

cd "$DIR" || {
    echo "❌ Error: Cannot access project directory: $DIR"
    echo "Usage: $0 [project_directory]"
    exit 1
}

# {{{ banner
echo ""
echo "🎯 ═══════════════════════════════════════════════════════════════════ 🎯"
echo "                       ADROIT PROJECT DEMO SELECTOR"
echo "                     Choose a phase demonstration"
echo "🎯 ═══════════════════════════════════════════════════════════════════ 🎯"
echo ""
# }}}

# {{{ detect_completed_phases
COMPLETED_PHASES=()
PHASE_COUNT=0

# Check for completed phase directories
if [ -d "issues/completed/phase-1" ]; then
    COMPLETED_PHASES+=("1")
    ((PHASE_COUNT++))
fi

if [ -d "issues/completed/phase-2" ]; then
    COMPLETED_PHASES+=("2") 
    ((PHASE_COUNT++))
fi

echo "📊 Project Status:"
echo "  • Completed Phases: ${PHASE_COUNT}"
echo "  • Available Demos: ${COMPLETED_PHASES[*]}"
echo ""
# }}}

# {{{ display_phase_descriptions
echo "Available Phase Demonstrations:"
echo ""

if [[ " ${COMPLETED_PHASES[*]} " =~ " 1 " ]]; then
    echo "1️⃣  Phase 1: Complete Character Generation System"
    echo "    • Fixed compilation errors and memory management"
    echo "    • Complete stat generation with 5 methods"
    echo "    • Equipment generation and probability tables"
    echo "    • Professional Raylib graphical interface"
    echo "    • Comprehensive build system"
    echo ""
fi

if [[ " ${COMPLETED_PHASES[*]} " =~ " 2 " ]]; then
    echo "2️⃣  Phase 2: Modular Integration Architecture" 
    echo "    • Cross-language integration (C ↔ Bash ↔ Lua/LuaJIT)"
    echo "    • Progress-ii project integration via bash bridge"
    echo "    • High-performance LuaJIT scripting support"
    echo "    • Thread-safe module system architecture"
    echo "    • Template-driven ecosystem expansion"
    echo ""
fi

if [ ${PHASE_COUNT} -eq 0 ]; then
    echo "⚠️  No completed phase demonstrations found."
    echo "Run the project setup and complete Phase 1 first."
    exit 1
fi
# }}}

# {{{ interactive_phase_selection
while true; do
    echo "🔧 Demo Selection Options:"
    echo "  • Enter phase number (1-${PHASE_COUNT}) to run phase demo"
    echo "  • Enter 'a' for all phases in sequence"
    echo "  • Enter 'i' for interactive mode with additional options"
    echo "  • Enter 'q' to quit"
    echo ""
    
    read -p "Select phase to demonstrate (1-${PHASE_COUNT}/a/i/q): " selection
    
    case $selection in
        1)
            if [[ " ${COMPLETED_PHASES[*]} " =~ " 1 " ]]; then
                echo ""
                echo "🚀 Running Phase 1 demonstration..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                ./issues/completed/phase-1/run_demo.sh "$DIR"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            else
                echo "❌ Phase 1 demo not available"
            fi
            ;;
        2)
            if [[ " ${COMPLETED_PHASES[*]} " =~ " 2 " ]]; then
                echo ""
                echo "🚀 Running Phase 2 demonstration..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                ./issues/completed/phase-2/run_demo.sh "$DIR"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            else
                echo "❌ Phase 2 demo not available"
            fi
            ;;
        a|A)
            echo ""
            echo "🌟 Running all phase demonstrations in sequence..."
            echo ""
            
            for phase in "${COMPLETED_PHASES[@]}"; do
                echo "🚀 Starting Phase $phase demonstration..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                ./issues/completed/phase-$phase/run_demo.sh "$DIR"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                if [ "$phase" != "${COMPLETED_PHASES[-1]}" ]; then
                    echo "⏸️  Press Enter to continue to next phase demo..."
                    read
                fi
            done
            
            echo "🎉 All phase demonstrations completed!"
            ;;
        i|I)
            echo ""
            echo "🔧 Interactive Mode - Additional Options:"
            echo ""
            echo "1. Run main application (./adroit)"
            echo "2. Run Lua/LuaJIT integration test"
            echo "3. Run stat generation test" 
            echo "4. Show project structure"
            echo "5. Show integration documentation"
            echo "6. Return to main menu"
            echo ""
            read -p "Select interactive option (1-6): " interactive_choice
            
            case $interactive_choice in
                1)
                    echo "🎮 Launching main Adroit application..."
                    ./adroit
                    ;;
                2)
                    echo "🌙 Running Lua/LuaJIT integration test..."
                    make lua-test
                    ;;
                3)
                    echo "🎲 Running stat generation test..."
                    ./simple_stat_test 2>/dev/null || {
                        echo "Compiling stat test..."
                        gcc -Isrc -Ilibs simple_stat_test.c src/dice.c -o simple_stat_test -lm && ./simple_stat_test
                    }
                    ;;
                4)
                    echo "📁 Project structure:"
                    tree -L 3 . 2>/dev/null || find . -type d | head -30
                    ;;
                5)
                    echo "📚 Integration documentation:"
                    echo ""
                    ls -la docs/integration* docs/modular* docs/table-of-contents.md 2>/dev/null || echo "Check docs/ directory"
                    echo ""
                    echo "Key integration files:"
                    find libs/ -name "*.h" | sort 2>/dev/null
                    ;;
                6)
                    echo "Returning to main menu..."
                    ;;
                *)
                    echo "Invalid selection."
                    ;;
            esac
            ;;
        q|Q|quit|exit)
            echo ""
            echo "👋 Exiting demo selector. Thank you!"
            echo ""
            echo "🎯 Project Summary:"
            echo "  • ${PHASE_COUNT} phases completed"
            echo "  • Professional RPG character generator operational"
            echo "  • Modular integration framework ready for expansion"
            echo "  • LuaJIT high-performance scripting integration"
            echo "  • Ready for ai-stuff ecosystem development"
            echo ""
            echo "🚀 Run './demo_selector.sh' anytime to access these demonstrations"
            echo ""
            exit 0
            ;;
        *)
            echo "❌ Invalid selection. Please enter a number 1-${PHASE_COUNT}, 'a', 'i', or 'q'."
            echo ""
            ;;
    esac
    
    # Ask if user wants to continue after running a demo
    if [[ "$selection" =~ ^[1-9]$ ]]; then
        echo ""
        echo "🔄 Would you like to run another demonstration? (y/n)"
        read -p "> " continue_choice
        if [[ "$continue_choice" =~ ^[nN] ]]; then
            echo ""
            echo "👋 Demo session complete. Project ready for development!"
            exit 0
        fi
        echo ""
    fi
done
# }}}

# Interactive mode support as per CLAUDE.md
if [ "$1" = "-I" ]; then
    # Interactive mode is the default behavior of this script
    # All functionality is already interactive
    echo "ℹ️  This script runs in interactive mode by default"
fi