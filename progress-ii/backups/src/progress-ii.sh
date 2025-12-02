#!/bin/bash

# Progress-II Main Game Script
# Terminal-based adventure game with AI-generated bash commands and git-based time manipulation
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"

# Game state variables
GAME_STATE="main_menu"
PLAYER_NAME=""
GAME_RUNNING=true

# {{{ clear_screen
clear_screen() {
    clear
    echo
}
# }}}

# {{{ display_header
display_header() {
    echo "============================================================================="
    echo "                              PROGRESS-II"
    echo "        Terminal Adventure Game with AI Commands & Time Manipulation"
    echo "============================================================================="
    echo
}
# }}}

# {{{ display_main_menu
display_main_menu() {
    clear_screen
    display_header
    
    echo "Main Menu:"
    echo "=========="
    echo
    echo "1) New Game     - Start a new adventure"
    echo "2) Load Game    - Continue existing adventure"
    echo "3) Settings     - Configure game options"
    echo "4) About        - Learn about Progress-II"
    echo "5) Quit         - Exit the game"
    echo
    echo -n "Please select an option (1-5): "
}
# }}}

# {{{ handle_main_menu_input
handle_main_menu_input() {
    local choice="$1"
    
    case "$choice" in
        1|"new"|"new game")
            GAME_STATE="new_game"
            ;;
        2|"load"|"load game")
            GAME_STATE="load_game"
            ;;
        3|"settings"|"config")
            GAME_STATE="settings"
            ;;
        4|"about"|"help")
            GAME_STATE="about"
            ;;
        5|"quit"|"exit"|"q")
            GAME_STATE="quit"
            ;;
        *)
            echo
            echo "Invalid option: '$choice'"
            echo "Please enter a number 1-5 or type the option name."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
    esac
}
# }}}

# {{{ display_new_game
display_new_game() {
    clear_screen
    display_header
    
    echo "New Game Setup:"
    echo "==============="
    echo
    echo "Welcome to Progress-II! This game features:"
    echo "- AI-generated bash commands for problem solving"
    echo "- Git-based time manipulation (save/rewind mechanics)"
    echo "- Character progression and companion management"
    echo "- Dynamic world with environmental variables"
    echo
    echo -n "Enter your character name (or 'back' to return): "
}
# }}}

# {{{ handle_new_game_input
handle_new_game_input() {
    local input="$1"
    
    if [ "$input" = "back" ] || [ "$input" = "menu" ]; then
        GAME_STATE="main_menu"
        return
    fi
    
    if [ -z "$input" ]; then
        echo
        echo "Character name cannot be empty."
        echo -n "Press Enter to try again..."
        read -r
        return
    fi
    
    PLAYER_NAME="$input"
    echo
    echo "Creating new game for '$PLAYER_NAME'..."
    
    # Initialize game state directory
    if initialize_state_directory "${DIR}/game-state"; then
        echo
        echo "Game world initialized successfully!"
        echo "Your adventure begins now..."
        echo
        echo -n "Press Enter to start your journey..."
        read -r
        GAME_STATE="game_world"
    else
        echo
        echo "Error: Failed to initialize game world."
        echo "Please check your permissions and try again."
        echo
        echo -n "Press Enter to return to menu..."
        read -r
        GAME_STATE="main_menu"
    fi
}
# }}}

# {{{ display_load_game
display_load_game() {
    clear_screen
    display_header
    
    echo "Load Game:"
    echo "=========="
    echo
    
    if [ ! -d "${DIR}/game-state" ]; then
        echo "No saved games found."
        echo "You'll need to start a new game first."
        echo
        echo -n "Press Enter to return to menu..."
        read -r
        GAME_STATE="main_menu"
        return
    fi
    
    echo "Checking for saved games..."
    get_state_directory_info "${DIR}/game-state"
    echo
    echo "Load game functionality will be implemented in Phase 1."
    echo "This will include git-based save state browsing and time travel."
    echo
    echo -n "Press Enter to return to menu..."
    read -r
    GAME_STATE="main_menu"
}
# }}}

# {{{ display_settings
display_settings() {
    clear_screen
    display_header
    
    echo "Settings:"
    echo "========="
    echo
    echo "Configuration options will include:"
    echo "- HDD storage path (required for SSD protection)"
    echo "- Logging mode (performance vs human-readable)"
    echo "- AI model selection (local vs cloud)"
    echo "- Game difficulty and mechanics"
    echo
    echo "Settings management will be implemented in Phase 1."
    echo
    echo -n "Press Enter to return to menu..."
    read -r
    GAME_STATE="main_menu"
}
# }}}

# {{{ display_about
display_about() {
    clear_screen
    display_header
    
    echo "About Progress-II:"
    echo "=================="
    echo
    echo "Progress-II is an innovative terminal-based adventure game featuring:"
    echo
    echo "🤖 AI-Generated Commands:"
    echo "   The game's AI generates bash one-liners to solve problems,"
    echo "   making complex terminal operations accessible and magical."
    echo
    echo "⏰ Git-Based Time Travel:"
    echo "   Every game action is versioned with git, allowing you to"
    echo "   'rewind time' and explore different decision paths."
    echo
    echo "📁 Filesystem Integration:"
    echo "   Your game world exists as files and directories on disk,"
    echo "   making the virtual and real worlds seamlessly connected."
    echo
    echo "🎭 Character & Companions:"
    echo "   Play as Maxine and her valorous companions, gaining"
    echo "   experience and abilities through your adventures."
    echo
    echo "🌍 Dynamic World:"
    echo "   Environmental variables create an ever-changing world"
    echo "   that responds to your actions and choices."
    echo
    echo "Development: Phase 1 - Foundation and Core Infrastructure"
    echo
    echo -n "Press Enter to return to menu..."
    read -r
    GAME_STATE="main_menu"
}
# }}}

# {{{ display_game_world
display_game_world() {
    clear_screen
    display_header
    
    echo "Welcome to the World of Progress-II"
    echo "===================================="
    echo
    echo "Player: $PLAYER_NAME"
    echo "Location: Tutorial Clearing"
    echo "Status: Beginning Adventure"
    echo
    echo "You find yourself in a peaceful clearing surrounded by ancient trees."
    echo "A gentle breeze carries whispers of adventures yet to come."
    echo
    echo "Available Actions:"
    echo "=================="
    echo "1) Explore surroundings"
    echo "2) Check character status"
    echo "3) Practice with AI commands"
    echo "4) Save progress"
    echo "5) Return to main menu"
    echo
    echo -n "What would you like to do? (1-5): "
}
# }}}

# {{{ handle_game_world_input
handle_game_world_input() {
    local choice="$1"
    
    case "$choice" in
        1|"explore")
            echo
            echo "You begin to explore the clearing..."
            echo "This feature will be expanded in Phase 2 with full world systems."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        2|"status"|"character")
            echo
            echo "Character Status:"
            echo "================"
            echo "Name: $PLAYER_NAME"
            echo "Level: 1 (Novice Adventurer)"
            echo "Experience: 0/5"
            echo "Companions: None yet"
            echo
            echo "Character progression will be implemented in Phase 1."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        3|"ai"|"commands")
            echo
            echo "AI Command Practice:"
            echo "==================="
            echo "The AI command system will generate bash one-liners"
            echo "to help solve problems and automate tasks."
            echo
            echo "Example: 'Find all text files larger than 1MB'"
            echo "AI Response: find . -name '*.txt' -size +1M"
            echo
            echo "AI integration will be implemented in Phase 1."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        4|"save")
            echo
            echo "Saving game state..."
            echo "Git-based save system will create a commit with your progress."
            echo "Save/load functionality will be implemented in Phase 1."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        5|"menu"|"back")
            GAME_STATE="main_menu"
            ;;
        *)
            echo
            echo "Invalid option: '$choice'"
            echo "Please enter a number 1-5 or type the action name."
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
    esac
}
# }}}

# {{{ handle_quit
handle_quit() {
    clear_screen
    display_header
    
    echo "Thank you for playing Progress-II!"
    echo "=================================="
    echo
    echo "Your adventure awaits your return."
    echo "Progress-II is currently in Phase 1 development."
    echo
    echo "Future phases will bring:"
    echo "- Complete AI command integration"
    echo "- Full git-based time manipulation"
    echo "- Rich world exploration and quests"
    echo "- Advanced character progression"
    echo "- Community features and sharing"
    echo
    echo "Visit the project repository for updates and development progress."
    echo
    
    GAME_RUNNING=false
}
# }}}

# {{{ main_game_loop
main_game_loop() {
    while [ "$GAME_RUNNING" = true ]; do
        case "$GAME_STATE" in
            "main_menu")
                display_main_menu
                read -r user_input
                handle_main_menu_input "$user_input"
                ;;
            "new_game")
                display_new_game
                read -r user_input
                handle_new_game_input "$user_input"
                ;;
            "load_game")
                display_load_game
                ;;
            "settings")
                display_settings
                ;;
            "about")
                display_about
                ;;
            "game_world")
                display_game_world
                read -r user_input
                handle_game_world_input "$user_input"
                ;;
            "quit")
                handle_quit
                ;;
            *)
                echo "Error: Unknown game state: $GAME_STATE"
                GAME_STATE="main_menu"
                ;;
        esac
    done
}
# }}}

# {{{ main
main() {
    # Check if we're being sourced or executed
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        # Script is being executed directly
        echo "Starting Progress-II..."
        main_game_loop
    else
        # Script is being sourced - just load functions
        echo "Progress-II functions loaded."
    fi
}
# }}}

# Run main function
main "$@"