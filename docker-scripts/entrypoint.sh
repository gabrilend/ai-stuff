#!/bin/bash
# Container Entrypoint Script
# Detects GPU, sets up environment, and drops into interactive shell
#
# This script runs on container start and configures the graphics environment
# based on what hardware is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# {{{ setup_environment
setup_environment() {
    # Source GPU detection environment variables
    eval "$("$SCRIPT_DIR/detect-gpu.sh" env)"

    # Export for child processes
    export GPU_VENDOR
    export GPU_DEVICE
    export VULKAN_AVAILABLE
    export OPENGL_AVAILABLE
}
# }}}

# {{{ print_welcome
print_welcome() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              ai-stuff Sandbox Environment                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  GPU:     $GPU_VENDOR (${GPU_DEVICE:0:40})"
    echo "║  Vulkan:  $VULKAN_AVAILABLE    OpenGL: $OPENGL_AVAILABLE"
    echo "║  Display: ${DISPLAY:-not set}"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Workspace: /workspace                                       ║"
    echo "║  Run 'detect-gpu.sh status' for detailed GPU info           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$GPU_VENDOR" = "software" ]; then
        echo "⚠  No hardware GPU detected - using software rendering"
        echo "   Graphics demos will be slow. Compute shaders may fail."
        echo ""
    fi

    if [ -z "$DISPLAY" ]; then
        echo "⚠  DISPLAY not set - graphical applications won't work"
        echo "   Use VNC mode or set DISPLAY for X11 forwarding"
        echo ""
    fi
}
# }}}

# {{{ main
main() {
    setup_environment
    print_welcome

    # Add scripts to PATH
    export PATH="$SCRIPT_DIR:$PATH"

    # If arguments provided, run them
    if [ $# -gt 0 ]; then
        exec "$@"
    else
        # Drop into interactive bash
        exec /bin/bash
    fi
}
# }}}

main "$@"
