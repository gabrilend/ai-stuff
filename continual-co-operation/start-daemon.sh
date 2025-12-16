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
    if ! curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
        error "Ollama is not running. Please:"
        echo "  1. Install: curl -fsSL https://ollama.ai/install.sh | sh"
        echo "  2. Start: ollama serve"
        echo "  3. Pull a model: ollama pull llama2"
        return 1
    fi
    
    success "Dependencies check passed!"
    return 0
}
# }}}

# {{{ interactive_setup
interactive_setup() {
    if [[ "$1" == "-I" ]]; then
        log "🎛️  Interactive Daemon Setup"
        echo ""
        echo "Daemon operation modes:"
        echo "1. Quick start (10 minutes, gentle heartbeat)"
        echo "2. Standard operation (1 hour, normal heartbeat)"
        echo "3. Extended contemplation (4 hours, slow heartbeat)"
        echo "4. Custom configuration"
        echo "5. Background daemon (detached process)"
        echo ""
        read -p "Select mode (1-5): " choice
        
        case $choice in
            1) 
                log "Starting quick 10-minute session..."
                lua "$DIR/src/run-daemon.lua" "$DIR" quick
                return $?
                ;;
            2) 
                log "Starting standard 1-hour session..."
                lua "$DIR/src/run-daemon.lua" "$DIR" standard
                return $?
                ;;
            3)
                log "Starting extended 4-hour session..."
                lua "$DIR/src/run-daemon.lua" "$DIR" extended
                return $?
                ;;
            4)
                log "Starting custom configuration..."
                lua "$DIR/src/run-daemon.lua" "$DIR" custom
                return $?
                ;;
            5)
                log "Starting background daemon..."
                nohup lua "$DIR/src/run-daemon.lua" "$DIR" background > "$DIR/outputs/daemon-background.log" 2>&1 &
                echo $! > "$DIR/daemon.pid"
                success "Daemon started in background (PID: $(cat $DIR/daemon.pid))"
                echo "Monitor with: tail -f $DIR/outputs/daemon-background.log"
                echo "Stop with: kill \$(cat $DIR/daemon.pid)"
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

# {{{ daemon_status
daemon_status() {
    if [[ -f "$DIR/daemon.pid" ]]; then
        local pid=$(cat "$DIR/daemon.pid")
        if kill -0 "$pid" 2>/dev/null; then
            success "Daemon is running (PID: $pid)"
            if [[ -f "$DIR/outputs/daemon-background.log" ]]; then
                echo "Recent activity:"
                tail -5 "$DIR/outputs/daemon-background.log"
            fi
        else
            warn "Daemon PID file exists but process is not running"
            rm -f "$DIR/daemon.pid"
        fi
    else
        log "No daemon currently running"
    fi
}
# }}}

# {{{ stop_daemon
stop_daemon() {
    if [[ -f "$DIR/daemon.pid" ]]; then
        local pid=$(cat "$DIR/daemon.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping daemon (PID: $pid)..."
            kill "$pid"
            rm -f "$DIR/daemon.pid"
            success "Daemon stopped"
        else
            warn "Daemon PID file exists but process is not running"
            rm -f "$DIR/daemon.pid"
        fi
    else
        log "No daemon PID file found"
    fi
}
# }}}

# {{{ main
main() {
    case "${1:-run}" in
        "status")
            daemon_status
            ;;
        "stop")
            stop_daemon
            ;;
        "run"|"-I")
            log "🤖 Starting Continual Co-operation Daemon"
            echo ""
            
            if ! check_dependencies; then
                exit 1
            fi
            
            if ! interactive_setup "$@"; then
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [run|status|stop|-I]"
            echo "  run    - Start daemon in foreground"
            echo "  -I     - Interactive setup mode"
            echo "  status - Check daemon status"
            echo "  stop   - Stop background daemon"
            exit 1
            ;;
    esac
}
# }}}

main "$@"