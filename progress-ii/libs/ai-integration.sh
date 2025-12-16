#!/bin/bash

# AI Integration Library for Progress-II
# Handles AI model integration, command generation, and safety validation
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# AI Configuration
AI_BACKEND="mock"  # Default to mock for Phase 1 - will support real AI in later phases
AI_MAX_RETRIES=3
AI_TIMEOUT=30
AI_SAFETY_MODE="strict"

# Command safety whitelist - only safe commands allowed in Phase 1
SAFE_COMMANDS=(
    "echo" "cat" "ls" "pwd" "whoami" "date" "head" "tail" "wc" "grep" "find"
    "sort" "uniq" "cut" "tr" "sed" "awk" "dirname" "basename" "realpath"
)

# {{{ initialize_ai_backend
initialize_ai_backend() {
    local backend="${1:-$AI_BACKEND}"
    
    echo "Initializing AI backend: $backend"
    
    case "$backend" in
        "mock")
            echo "Mock AI backend initialized (Phase 1 development mode)"
            AI_BACKEND="mock"
            return 0
            ;;
        "claude")
            echo "Claude AI backend would be initialized here"
            echo "This will be implemented in later phases"
            AI_BACKEND="claude"
            return 0
            ;;
        "openai")
            echo "OpenAI API backend would be initialized here" 
            echo "This will be implemented in later phases"
            AI_BACKEND="openai"
            return 0
            ;;
        *)
            echo "Error: Unknown AI backend: $backend" >&2
            return 1
            ;;
    esac
}
# }}}

# {{{ validate_ai_availability
validate_ai_availability() {
    local backend="${1:-$AI_BACKEND}"
    
    case "$backend" in
        "mock")
            echo "Mock AI backend is always available"
            return 0
            ;;
        "claude")
            echo "Would check Claude API availability here"
            return 1  # Not implemented yet
            ;;
        "openai")
            echo "Would check OpenAI API availability here"
            return 1  # Not implemented yet
            ;;
        *)
            echo "Error: Unknown backend for validation: $backend" >&2
            return 1
            ;;
    esac
}
# }}}

# {{{ create_context_prompt
create_context_prompt() {
    local problem_description="$1"
    local character_name="${2:-Player}"
    local location="${3:-Unknown Location}"
    local current_directory="${4:-$(pwd)}"
    
    cat << EOF
You are an AI assistant helping ${character_name} in the terminal-based adventure game Progress-II.

Current Context:
- Character: ${character_name}
- Location: ${location}
- Current Directory: ${current_directory}
- Problem: ${problem_description}

Generate a single, safe bash command that would help solve this problem.
The command should be educational, safe, and appropriate for a game context.

Only use these safe commands: ${SAFE_COMMANDS[*]}

Respond with ONLY the bash command, no explanation or markdown formatting.
EOF
}
# }}}

# {{{ generate_ai_response
generate_ai_response() {
    local prompt="$1"
    local backend="${2:-$AI_BACKEND}"
    
    case "$backend" in
        "mock")
            # Mock AI responses for Phase 1 development
            local problem
            problem=$(echo "$prompt" | grep "Problem:" | sed 's/.*Problem: //')
            
            case "$problem" in
                *"find files"*|*"search"*)
                    echo "find . -name '*.txt' -type f"
                    ;;
                *"list"*|*"show"*)
                    echo "ls -la"
                    ;;
                *"count"*|*"how many"*)
                    echo "ls | wc -l"
                    ;;
                *"size"*|*"disk"*)
                    echo "du -sh ."
                    ;;
                *"date"*|*"time"*)
                    echo "date '+%Y-%m-%d %H:%M:%S'"
                    ;;
                *"who"*|*"user"*)
                    echo "whoami"
                    ;;
                *"path"*|*"directory"*)
                    echo "pwd"
                    ;;
                *"sort"*|*"order"*)
                    echo "ls | sort"
                    ;;
                *"recent"*|*"latest"*)
                    echo "ls -lt | head -5"
                    ;;
                *)
                    echo "echo 'Try describing your problem more specifically'"
                    ;;
            esac
            ;;
        "claude"|"openai")
            echo "Real AI integration will be implemented in later phases"
            echo "For now, using mock responses"
            generate_ai_response "$prompt" "mock"
            ;;
        *)
            echo "echo 'Unknown AI backend'"
            ;;
    esac
}
# }}}

# {{{ validate_command_safety
validate_command_safety() {
    local command="$1"
    local safety_mode="${2:-$AI_SAFETY_MODE}"
    
    # Extract the base command (first word)
    local base_command
    base_command=$(echo "$command" | awk '{print $1}')
    
    # Check if command is in whitelist
    local is_safe=false
    for safe_cmd in "${SAFE_COMMANDS[@]}"; do
        if [ "$base_command" = "$safe_cmd" ]; then
            is_safe=true
            break
        fi
    done
    
    if [ "$is_safe" = "false" ]; then
        echo "UNSAFE: Command '$base_command' not in whitelist" >&2
        return 1
    fi
    
    # Check for dangerous patterns
    if echo "$command" | grep -E "(rm|del|format|mkfs|dd|>|>>|;|&&|\|\||\`|\\\$\\\()" >/dev/null; then
        echo "UNSAFE: Command contains dangerous patterns" >&2
        return 1
    fi
    
    # Check for directory traversal attempts
    if echo "$command" | grep -E "\.\./|\.\." >/dev/null; then
        echo "UNSAFE: Command contains directory traversal" >&2
        return 1
    fi
    
    echo "SAFE: Command passed safety validation"
    return 0
}
# }}}

# {{{ execute_safe_command
execute_safe_command() {
    local command="$1"
    local timeout="${2:-$AI_TIMEOUT}"
    local working_dir="${3:-$(pwd)}"
    
    echo "Validating command safety: $command"
    
    if ! validate_command_safety "$command"; then
        echo "❌ Command failed safety validation" >&2
        return 1
    fi
    
    echo "✅ Command is safe, executing..."
    echo "Command: $command"
    echo "Working Directory: $working_dir"
    echo "Timeout: ${timeout}s"
    echo "----------------------------------------"
    
    # Change to working directory and execute with timeout
    (
        cd "$working_dir" || exit 1
        timeout "$timeout" bash -c "$command"
    )
    
    local exit_code=$?
    echo "----------------------------------------"
    echo "Command completed with exit code: $exit_code"
    
    return $exit_code
}
# }}}

# {{{ generate_bash_command
generate_bash_command() {
    local problem_description="$1"
    local character_name="${2:-Player}"
    local location="${3:-Tutorial Clearing}"
    local working_dir="${4:-$(pwd)}"
    
    echo "🤖 AI Command Generation"
    echo "======================="
    echo "Problem: $problem_description"
    echo "Context: $character_name at $location"
    echo "Directory: $working_dir"
    echo
    
    # Create context prompt for AI
    local prompt
    prompt=$(create_context_prompt "$problem_description" "$character_name" "$location" "$working_dir")
    
    # Generate AI response
    echo "Consulting AI for bash command suggestion..."
    local suggested_command
    suggested_command=$(generate_ai_response "$prompt")
    
    if [ -z "$suggested_command" ]; then
        echo "❌ AI failed to generate command" >&2
        return 1
    fi
    
    echo "💡 AI Suggestion: $suggested_command"
    echo
    
    # Offer execution or explanation
    echo "Options:"
    echo "1) Execute the command"
    echo "2) Explain the command"
    echo "3) Modify the command"
    echo "4) Cancel"
    echo
    echo -n "Choose option (1-4): "
    read -r choice
    
    case "$choice" in
        1)
            echo
            echo "Executing AI-generated command..."
            execute_safe_command "$suggested_command" "$AI_TIMEOUT" "$working_dir"
            ;;
        2)
            echo
            echo "Command Explanation:"
            echo "==================="
            explain_command "$suggested_command"
            ;;
        3)
            echo -n "Enter modified command: "
            read -r modified_command
            if [ -n "$modified_command" ]; then
                execute_safe_command "$modified_command" "$AI_TIMEOUT" "$working_dir"
            fi
            ;;
        *)
            echo "Command generation cancelled"
            ;;
    esac
}
# }}}

# {{{ explain_command
explain_command() {
    local command="$1"
    local base_command
    base_command=$(echo "$command" | awk '{print $1}')
    
    echo "Command: $command"
    echo
    
    case "$base_command" in
        "find")
            echo "The 'find' command searches for files and directories."
            echo "It can search by name, type, size, modification time, and more."
            ;;
        "ls")
            echo "The 'ls' command lists directory contents."
            echo "Common options: -l (long format), -a (show hidden), -t (sort by time)"
            ;;
        "grep")
            echo "The 'grep' command searches for text patterns in files."
            echo "It's very powerful for finding specific content."
            ;;
        "echo")
            echo "The 'echo' command displays text output."
            echo "It's useful for showing messages or variable values."
            ;;
        "wc")
            echo "The 'wc' command counts words, lines, or characters."
            echo "Options: -l (lines), -w (words), -c (characters)"
            ;;
        *)
            echo "This is a safe command that performs: $(man "$base_command" 2>/dev/null | head -1 || echo "a system operation")"
            ;;
    esac
    
    echo
    echo "This command is safe and approved for game use."
}
# }}}

# {{{ get_ai_status
get_ai_status() {
    echo "AI Integration Status:"
    echo "====================="
    echo "Backend: $AI_BACKEND"
    echo "Safety Mode: $AI_SAFETY_MODE"
    echo "Max Retries: $AI_MAX_RETRIES"
    echo "Timeout: ${AI_TIMEOUT}s"
    echo
    echo "Safe Commands Available: ${#SAFE_COMMANDS[@]}"
    echo "Safe Commands: ${SAFE_COMMANDS[*]}"
    echo
    
    if validate_ai_availability; then
        echo "AI Status: ✅ Available"
    else
        echo "AI Status: ❌ Unavailable"
    fi
}
# }}}

# Export functions for use by other scripts
export -f initialize_ai_backend
export -f validate_ai_availability
export -f create_context_prompt
export -f generate_ai_response
export -f validate_command_safety
export -f execute_safe_command
export -f generate_bash_command
export -f explain_command
export -f get_ai_status