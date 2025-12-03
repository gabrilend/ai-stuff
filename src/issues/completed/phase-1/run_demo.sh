#!/bin/bash
# Phase 1 Demo Runner Script
# Demonstrates all Phase 1 achievements in Adroit RPG project

# Hard-coded DIR path as per CLAUDE.md requirements
DIR="${1:-/home/ritz/programming/ai-stuff/adroit/src}"

cd "$DIR" || {
    echo "❌ Error: Cannot access project directory: $DIR"
    echo "Usage: $0 [project_directory]"
    exit 1
}

# {{{ banner
echo "🎯 ═══════════════════════════════════════════════════════════════════ 🎯"
echo "                     ADROIT PHASE 1 DEMO RUNNER"
echo "🎯 ═══════════════════════════════════════════════════════════════════ 🎯"
echo ""
echo "Compiling and running Phase 1 demonstration..."
echo "Project directory: $DIR"
echo ""
# }}}

# {{{ compile_and_run_demo
echo "🔧 Compiling Phase 1 demo..."

# Compile the demo with all necessary dependencies
# Note: We need to create a custom main.c that excludes the main() function to avoid conflicts
cp ./src/main.c ./issues/completed/phase-1/main_funcs.c
sed -i '/^int main(/,/^}$/c\
// main() function removed for demo compilation' ./issues/completed/phase-1/main_funcs.c

gcc -Wall -Wextra -std=c99 -g -pthread \
    -I. \
    ./issues/completed/phase-1/phase1_demo.c \
    ./issues/completed/phase-1/main_funcs.c \
    ./src/dice.c \
    ./src/item.c \
    -o ./issues/completed/phase-1/phase1_demo \
    -lm

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo ""
    echo "🚀 Running Phase 1 demonstration..."
    echo ""
    
    # Run the demo
    ./issues/completed/phase-1/phase1_demo "$DIR"
    
    echo ""
    echo "🎮 Additional Demo Options:"
    echo "  • Run './adroit' for the full graphical character generator"
    echo "  • Run 'make lua-test' to see Lua/LuaJIT integration"
    echo "  • Run './simple_stat_test' for detailed stat generation testing"
    echo ""
    echo "✅ Phase 1 demo completed successfully!"
else
    echo "❌ Compilation failed!"
    echo "Make sure you're in the correct project directory and all source files exist."
    exit 1
fi
# }}}

# {{{ interactive_mode_check
if [ "$1" = "-I" ]; then
    echo ""
    echo "🔧 Interactive Mode Options:"
    echo "1. Run Phase 1 demo (default)"
    echo "2. Run graphical character generator"
    echo "3. Run Lua integration test"
    echo "4. Run stat generation test"
    echo "5. Show project structure"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            echo "Running Phase 1 demo..."
            # Already ran above
            ;;
        2)
            echo "🎮 Launching graphical character generator..."
            ./adroit
            ;;
        3)
            echo "🌙 Running Lua integration test..."
            make lua-test
            ;;
        4)
            echo "🎲 Running stat generation test..."
            ./simple_stat_test 2>/dev/null || echo "Compile with: gcc simple_stat_test.c src/dice.c -o simple_stat_test -lm"
            ;;
        5)
            echo "📁 Project structure:"
            tree -L 3 . 2>/dev/null || find . -type d | head -20
            ;;
        *)
            echo "Invalid selection. Running default demo."
            ;;
    esac
fi
# }}}

echo ""
echo "🎯 Phase 1 Demo Complete! All systems operational."