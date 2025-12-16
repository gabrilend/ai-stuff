#!/bin/bash

# {{{ setup
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
# }}}

# {{{ check_dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check Lua
    if ! command -v lua >/dev/null 2>&1; then
        error "Lua is not installed. Please install Lua 5.1 or later."
        return 1
    fi
    
    # Check Ollama
    if ! command -v ollama >/dev/null 2>&1; then
        warn "Ollama not found. Trying to detect running instance..."
        if ! curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
            error "Ollama is not running. Please:"
            echo "  1. Install: curl -fsSL https://ollama.ai/install.sh | sh"
            echo "  2. Start: ollama serve"
            echo "  3. Pull a model: ollama pull llama2"
            return 1
        fi
    fi
    
    success "Dependencies check passed!"
    return 0
}
# }}}

# {{{ interactive_setup
interactive_setup() {
    if [[ "$1" == "-I" ]]; then
        log "🎛️  Interactive Setup Mode"
        echo ""
        echo "Available options:"
        echo "1. Start basic chat"
        echo "2. Test rolling memory with sample conversation"
        echo "3. Show memory statistics from previous sessions"
        echo "4. Reset all memory and start fresh"
        echo ""
        read -p "Select option (1-4): " choice
        
        case $choice in
            1) return 0 ;;
            2) 
                log "Starting memory test..."
                lua "$DIR/src/test-memory.lua" "$DIR"
                return $?
                ;;
            3)
                log "Showing memory statistics..."
                if [[ -f "$DIR/memory-state.json" ]]; then
                    echo "Memory file found:"
                    cat "$DIR/memory-state.json" | head -20
                else
                    warn "No memory file found"
                fi
                return 1
                ;;
            4)
                read -p "Are you sure you want to reset all memory? (y/N): " confirm
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    rm -f "$DIR/memory-state.json"
                    rm -rf "$DIR/outputs"
                    success "Memory reset complete"
                fi
                return 0
                ;;
            *)
                error "Invalid option"
                return 1
                ;;
        esac
    fi
    return 0
}
# }}}

# {{{ main
main() {
    log "🤖 Starting Continual Co-operation Rolling Memory System"
    echo ""
    
    if ! check_dependencies; then
        exit 1
    fi
    
    if ! interactive_setup "$@"; then
        exit 1
    fi
    
    log "Launching chat interface..."
    lua "$DIR/src/chat.lua" "$DIR"
}
# }}}

main "$@"