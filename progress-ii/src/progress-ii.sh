#!/bin/bash

# Progress-II Main Game Script
# Terminal-based adventure game with AI-generated bash commands and git-based time manipulation
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"
source "${DIR}/libs/git-integration.sh"
source "${DIR}/libs/save-load-operations.sh"
source "${DIR}/libs/ai-integration.sh"
source "${DIR}/libs/character-experience.sh"

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
        echo "Initializing character progression system..."
        if initialize_character_experience_system "${DIR}/game-state"; then
            # Set player name in Maxine's character data
            update_character_stat "maxine" "name" "$PLAYER_NAME" "${DIR}/game-state"
            
            echo
            echo "🎉 Game world and character system initialized successfully!"
            echo "Welcome, $PLAYER_NAME! Your adventure begins now..."
            echo
            
            # Give initial experience for starting the game
            gain_experience "maxine" "3" "game_start" "beginning the adventure" "${DIR}/game-state"
            
            echo
            echo -n "Press Enter to start your journey..."
            read -r
            GAME_STATE="game_world"
        else
            echo
            echo "Error: Failed to initialize character system."
            echo "Please check your permissions and try again."
            echo
            echo -n "Press Enter to return to menu..."
            read -r
            GAME_STATE="main_menu"
        fi
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
    
    # List available save games
    if list_save_games "${DIR}/game-state"; then
        echo
        echo "🕒 Time Travel Options (Git Rollback):"
        echo "====================================="
        
        # Show git rollback points if repository exists
        if [ -d "${DIR}/game-state/.git" ]; then
            list_rollback_points "${DIR}/game-state" 10
        else
            echo "Git repository not initialized yet."
        fi
        
        echo
        echo "Options:"
        echo "1) Load from save slot"
        echo "2) Browse git history (time travel)"
        echo "3) Return to menu"
        echo
        echo -n "Choose option (1-3): "
        read -r load_choice
        
        case "$load_choice" in
            1)
                echo -n "Enter save slot number (1-10): "
                read -r slot_num
                if load_game_state "$slot_num" "${DIR}/game-state"; then
                    echo "Game loaded successfully!"
                    GAME_STATE="game_world"
                else
                    echo "Failed to load game."
                fi
                ;;
            2)
                echo "Time travel functionality ready!"
                echo "You can rollback to any previous commit."
                echo "This feature will be enhanced in future phases."
                ;;
            *)
                echo "Returning to menu..."
                ;;
        esac
    else
        echo "No save games found yet."
        echo "Start a new game and save to create your first save point."
    fi
    
    echo
    echo -n "Press Enter to continue..."
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
            display_character_status "maxine" "${DIR}/game-state"
            
            # Character progression options
            echo
            echo "Character Options:"
            echo "=================="
            echo "1) Allocate stat points (if available)"
            echo "2) View detailed experience log"  
            echo "3) Practice skills to gain experience"
            echo "4) Return to game"
            echo
            echo -n "Choose option (1-4): "
            read -r char_choice
            
            case "$char_choice" in
                1)
                    # Handle stat allocation
                    local available_points
                    available_points=$(grep "^available_points=" "${DIR}/game-state/characters/maxine/character-data.txt" | cut -d'=' -f2)
                    
                    if [ "$available_points" -gt 0 ]; then
                        echo
                        echo "Available stat points: $available_points"
                        echo "Choose a stat to improve:"
                        echo "1) Wit  2) Strength  3) Intuition  4) Resilience"
                        echo "5) Charm  6) Empathy  7) Survival  8) Luck"
                        echo -n "Enter stat number: "
                        read -r stat_choice
                        
                        local stat_name
                        case "$stat_choice" in
                            1) stat_name="wit" ;;
                            2) stat_name="strength" ;;
                            3) stat_name="intuition" ;;
                            4) stat_name="resilience" ;;
                            5) stat_name="charm" ;;
                            6) stat_name="empathy" ;;
                            7) stat_name="survival" ;;
                            8) stat_name="luck" ;;
                            *) echo "Invalid choice"; stat_name="" ;;
                        esac
                        
                        if [ -n "$stat_name" ]; then
                            echo -n "How many points to allocate? (1-$available_points): "
                            read -r points_to_add
                            
                            if [ "$points_to_add" -le "$available_points" ] && [ "$points_to_add" -gt 0 ]; then
                                allocate_stat_points "maxine" "$stat_name" "$points_to_add" "${DIR}/game-state"
                            else
                                echo "Invalid number of points."
                            fi
                        fi
                    else
                        echo
                        echo "No stat points available. Gain more experience to unlock points!"
                    fi
                    ;;
                2)
                    echo
                    echo "Experience Log:"
                    echo "=============="
                    tail -10 "${DIR}/game-state/logs/experience-events.log" 2>/dev/null || echo "No experience log yet."
                    ;;
                3)
                    echo
                    echo "Practicing skills..."
                    gain_experience "maxine" "2" "skill_practice" "practicing in the tutorial clearing" "${DIR}/game-state"
                    ;;
                *)
                    echo "Returning to game..."
                    ;;
            esac
            
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        3|"ai"|"commands")
            echo
            echo "🤖 AI Command Assistant"
            echo "======================"
            
            # Initialize AI backend
            initialize_ai_backend "mock"
            
            echo "The AI will help you generate bash commands for various tasks."
            echo "This is perfect for learning terminal operations!"
            echo
            echo "What would you like to do?"
            echo "1) Ask AI to solve a specific problem"
            echo "2) Get AI status and capabilities"
            echo "3) Try example problems"
            echo "4) Return to game"
            echo
            echo -n "Choose option (1-4): "
            read -r ai_choice
            
            case "$ai_choice" in
                1)
                    echo
                    echo "Describe your problem (e.g., 'find all large files', 'count files in directory'):"
                    echo -n "> "
                    read -r problem_description
                    if [ -n "$problem_description" ]; then
                        generate_bash_command "$problem_description" "$PLAYER_NAME" "Tutorial Clearing" "${DIR}/game-state"
                    fi
                    ;;
                2)
                    echo
                    get_ai_status
                    ;;
                3)
                    echo
                    echo "Try these example problems:"
                    echo "- 'find files modified today'"
                    echo "- 'count total files in current directory'"
                    echo "- 'show the largest files'"
                    echo "- 'list files by modification time'"
                    echo
                    echo -n "Pick one or describe your own: "
                    read -r example_problem
                    if [ -n "$example_problem" ]; then
                        generate_bash_command "$example_problem" "$PLAYER_NAME" "Tutorial Clearing" "${DIR}/game-state"
                    fi
                    ;;
                *)
                    echo "Returning to game..."
                    ;;
            esac
            
            echo
            echo -n "Press Enter to continue..."
            read -r
            ;;
        4|"save")
            echo
            echo "Saving game state..."
            
            # Initialize git repository if needed
            if [ ! -d "${DIR}/game-state/.git" ]; then
                echo "Initializing git repository for save system..."
                initialize_git_repository "${DIR}/game-state"
            fi
            
            # Save using the save-load system
            if save_game_state "$PLAYER_NAME" "1" "0" "Tutorial Clearing" "manual" "1" "human" "${DIR}/game-state"; then
                echo "Creating git commit for time travel functionality..."
                create_save_commit "Manual save by player" "$PLAYER_NAME" "1" "Tutorial Clearing" "${DIR}/game-state"
                echo
                echo "✅ Game saved successfully!"
                echo "Your progress has been committed to git for time travel mechanics."
            else
                echo "❌ Failed to save game state."
            fi
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