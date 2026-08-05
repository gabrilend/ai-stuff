#!/bin/bash
# screen-record-stream launcher
# Starts the HTTP server for bidirectional screen sharing
#
# Usage:
#   ./run.sh                      # Start server on port 8080
#   ./run.sh --port=9000          # Custom port
#   ./run.sh --peer=192.168.1.50  # Connect to peer
#   ./run.sh --help               # Show help

DIR="${1:-/mnt/mtwo/programming/ai-stuff/screen-record-stream/}"

# Allow DIR override via --dir= argument
for arg in "$@"; do
    case $arg in
        --dir=*)
            DIR="${arg#*=}"
            ;;
    esac
done

# Ensure DIR ends with /
[[ "${DIR}" != */ ]] && DIR="${DIR}/"

# {{{ check_dependencies
check_dependencies() {
    local missing=0

    if ! command -v luajit &> /dev/null; then
        echo "ERROR: luajit not found"
        missing=1
    fi

    if ! command -v ffmpeg &> /dev/null; then
        echo "ERROR: ffmpeg not found"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo "Install missing dependencies:"
        echo "  sudo apt install luajit ffmpeg"
        exit 1
    fi
}
# }}}

# {{{ show_help
show_help() {
    cat << EOF
Screen Record Stream - Bidirectional screen sharing over HTTP

Usage: $0 [OPTIONS]

Options:
  --port=PORT       Server port (default: 8080)
  --peer=HOST       Peer's IP address to connect to
  --peer-port=PORT  Peer's port (default: 8080)
  --quality=N       JPEG quality 1-100 (default: 80)
  --fps=N           Target frames per second (default: 10)
  --display=DISP    X11 display (default: :0)
  --dir=PATH        Project directory
  --help            Show this help

Examples:
  $0                                    # Start server only
  $0 --peer=192.168.1.100               # Connect to peer
  $0 --port=9000 --fps=5                # Custom port + lower FPS

Once running, open http://localhost:8080/ in your browser.

Phase 1 Endpoints (single frame):
  /         - Index page
  /screen   - Current screenshot (JPEG)
  /bytes    - Hex dump of screenshot bytes
  /stats    - Transfer statistics
  /live     - Auto-refreshing live view (polling)

Phase 2 Endpoints (streaming):
  /live-stream   - Live stream viewer with SSE (recommended)
  /stream        - Raw SSE event stream
  /stream-stats  - Streaming and change detection statistics

EOF
}
# }}}

# Parse --help
for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            exit 0
            ;;
    esac
done

check_dependencies

echo "Starting screen-record-stream from ${DIR}"
echo ""

# Run the server
cd "${DIR}"
exec luajit "${DIR}src/006-main.lua" "$@"
