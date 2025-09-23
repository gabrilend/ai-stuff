#!/bin/bash

# Simple runner script for handheld office system
# No JSON dependencies, just pure bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_FILE="files/build/simple_run.log"
mkdir -p files/build

kay
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

start_daemon() {
    log "Starting daemon on port 8080..."
    ./files/target/release/daemon &
    DAEMON_PID=$!
    echo "$DAEMON_PID" > files/build/daemon.pid
    log "Daemon started with PID $DAEMON_PID"
    sleep 2  # Give daemon time to start
}

start_llm_service() {
    log "Starting LLM service..."
    ./files/target/release/desktop-llm &
    LLM_PID=$!
    echo "$LLM_PID" > files/build/llm.pid
    log "LLM service started with PID $LLM_PID"
}

start_handheld() {
    log "Starting handheld client..."
    ./files/target/release/handheld
}

stop_all() {
    log "Stopping all services..."
    
    if [[ -f files/build/daemon.pid ]]; then
        DAEMON_PID=$(cat files/build/daemon.pid)
        kill $DAEMON_PID 2>/dev/null || true
        rm -f files/build/daemon.pid
        log "Daemon stopped"
    fi
    
    if [[ -f files/build/llm.pid ]]; then
        LLM_PID=$(cat files/build/llm.pid)
        kill $LLM_PID 2>/dev/null || true
        rm -f files/build/llm.pid
        log "LLM service stopped"
    fi
    
    # Clean up any remaining processes
    pkill -f "target/release/daemon" 2>/dev/null || true
    pkill -f "target/release/desktop-llm" 2>/dev/null || true
    pkill -f "target/release/handheld" 2>/dev/null || true
}

status() {
    log "=== Handheld Office System Status ==="
    
    if [[ -f files/build/daemon.pid ]]; then
        DAEMON_PID=$(cat files/build/daemon.pid)
        if ps -p $DAEMON_PID > /dev/null 2>&1; then
            log "Daemon: RUNNING (PID $DAEMON_PID)"
        else
            log "Daemon: STOPPED (stale PID file)"
            rm -f files/build/daemon.pid
        fi
    else
        log "Daemon: STOPPED"
    fi
    
    if [[ -f files/build/llm.pid ]]; then
        LLM_PID=$(cat files/build/llm.pid)
        if ps -p $LLM_PID > /dev/null 2>&1; then
            log "LLM Service: RUNNING (PID $LLM_PID)"
        else
            log "LLM Service: STOPPED (stale PID file)"
            rm -f files/build/llm.pid
        fi
    else
        log "LLM Service: STOPPED"
    fi
    
    log "Network test:"
    if netstat -tln 2>/dev/null | grep -q ":8080"; then
        log "Port 8080: LISTENING"
    else
        log "Port 8080: NOT LISTENING"
    fi
}

# Handle Ctrl+C gracefully
trap stop_all EXIT

case "${1:-help}" in
    "daemon")
        start_daemon
        wait
        ;;
    "llm")
        start_llm_service
        wait
        ;;
    "handheld")
        start_handheld
        ;;
    "run")
        log "=== Starting Full Handheld Office System ==="
        start_daemon
        start_llm_service
        start_handheld
        ;;
    "stop")
        stop_all
        ;;
    "status")
        status
        ;;
    *)
        echo "Handheld Office Simple Runner"
        echo "Usage: $0 {daemon|llm|handheld|run|stop|status}"
        echo ""
        echo "  daemon    - Start daemon only"
        echo "  llm       - Start LLM service only"  
        echo "  handheld  - Start handheld client only"
        echo "  run       - Start full system (daemon + llm + handheld)"
        echo "  stop      - Stop all services"
        echo "  status    - Show system status"
        ;;
esac
