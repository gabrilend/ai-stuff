#!/bin/bash

# Galactic Battlegrounds Runner Script
# This script runs Star Wars: Galactic Battlegrounds through Wine

# Default directory - can be overridden by command line argument
DIR="/home/ritz/programming/ai-stuff/games/galactic-battlegrounds"
GAME_DIR="/home/ritz/dile/games/gog-games/galactic-battlegrounds"

# Allow directory override via command line argument
if [ $# -gt 0 ]; then
    DIR="$1"
fi

# {{{ setup_environment
setup_environment() {
    # Set up Wine environment
    export WINEPREFIX="$DIR/wineprefix"
    export WINEDEBUG=-all
    
    # Create wine prefix if it doesn't exist
    if [ ! -d "$WINEPREFIX" ]; then
        echo "Creating Wine prefix at $WINEPREFIX..."
        winecfg
    fi
}
# }}}

# {{{ install_game
install_game() {
    echo "Installing Galactic Battlegrounds..."
    
    # Check if installer exists
    if [ ! -f "$GAME_DIR/setup_sw_galactic_battlegrounds_saga_2.0.0.4.exe" ]; then
        echo "Error: Game installer not found at $GAME_DIR"
        echo "Please ensure the installer is present and try again."
        exit 1
    fi
    
    # Run the installer
    cd "$GAME_DIR"
    wine setup_sw_galactic_battlegrounds_saga_2.0.0.4.exe
}
# }}}

# {{{ run_game
run_game() {
    echo "Starting Galactic Battlegrounds..."
    
    # Try common installation paths
    POSSIBLE_PATHS=(
        "$WINEPREFIX/drive_c/Program Files (x86)/LucasArts/Star Wars Galactic Battlegrounds"
        "$WINEPREFIX/drive_c/Program Files/LucasArts/Star Wars Galactic Battlegrounds"
        "$WINEPREFIX/drive_c/GOG Games/Star Wars - Galactic Battlegrounds Saga"
        "$WINEPREFIX/drive_c/Program Files (x86)/GOG.com/Star Wars - Galactic Battlegrounds Saga"
    )
    
    GAME_FOUND=false
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            echo "Found game at: $path"
            cd "$path"
            
            # Look for the executable
            if [ -f "Battlegrounds.exe" ]; then
                wine Battlegrounds.exe
                GAME_FOUND=true
                break
            elif [ -f "SWGB.exe" ]; then
                wine SWGB.exe
                GAME_FOUND=true
                break
            fi
        fi
    done
    
    if [ "$GAME_FOUND" = false ]; then
        echo "Game executable not found. Please install the game first using:"
        echo "$0 --install"
    fi
}
# }}}

# {{{ show_help
show_help() {
    echo "Galactic Battlegrounds Runner"
    echo "Usage: $0 [directory] [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --install, -i   Install the game"
    echo "  --run, -r       Run the game (default)"
    echo "  --config, -c    Open Wine configuration"
    echo ""
    echo "Directory argument:"
    echo "  [directory]     Override the default working directory"
    echo "                  Default: $DIR"
}
# }}}

# {{{ open_winecfg
open_winecfg() {
    echo "Opening Wine configuration..."
    winecfg
}
# }}}

# Main execution
setup_environment

# Parse command line arguments
case "${!#}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --install|-i)
        install_game
        exit 0
        ;;
    --config|-c)
        open_winecfg
        exit 0
        ;;
    --run|-r|*)
        run_game
        exit 0
        ;;
esac