#!/bin/bash
# ai-stuff sandbox runner
# Launches the containerized development environment with graphics support
# Automatically detects GPU vendor and configures appropriately
#
# Usage:
#   ./docker-run.sh           # Interactive mode, auto-detects everything
#   ./docker-run.sh x11       # Force X11 mode (Linux only)
#   ./docker-run.sh vnc       # Force VNC mode (access via browser)
#   ./docker-run.sh headless  # No GUI, compute only
#   ./docker-run.sh build     # Build/rebuild the container image
#   ./docker-run.sh gpu-info  # Show GPU detection info (without starting container)

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="ai-stuff-sandbox"

# {{{ show_help
show_help() {
    echo "ai-stuff Docker Sandbox"
    echo ""
    echo "Usage: $0 [mode]"
    echo ""
    echo "Modes:"
    echo "  x11       - X11 forwarding (Linux, lowest latency)"
    echo "  vnc       - VNC server (any OS, browser access at http://localhost:6080)"
    echo "  headless  - No GUI (compute-only tasks)"
    echo "  build     - Build/rebuild the container image"
    echo "  gpu-info  - Show detected GPU information"
    echo "  help      - Show this message"
    echo ""
    echo "If no mode specified, auto-detects: X11 on Linux with DISPLAY, VNC otherwise."
    echo ""
    echo "GPU Support:"
    echo "  NVIDIA - Requires nvidia-container-toolkit installed on host"
    echo "  AMD    - Works automatically via /dev/dri"
    echo "  Intel  - Works automatically via /dev/dri"
    echo "  None   - Falls back to software rendering (slow)"
}
# }}}

# {{{ build_image
build_image() {
    echo "Building $IMAGE_NAME..."
    docker build -t "$IMAGE_NAME" "$DIR"
}
# }}}

# {{{ detect_host_gpu
detect_host_gpu() {
    # Detect GPU on the host system to determine which Docker options to use

    # Check for NVIDIA
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        # Verify nvidia-container-toolkit is available
        if docker info 2>/dev/null | grep -q "nvidia"; then
            echo "nvidia"
            return 0
        else
            echo "nvidia-no-toolkit"
            return 0
        fi
    fi

    # Check for AMD via DRI
    if [ -d /dev/dri ]; then
        if lspci 2>/dev/null | grep -qi "AMD.*VGA\|AMD.*Display\|Radeon"; then
            echo "amd"
            return 0
        fi

        # Check for Intel
        if lspci 2>/dev/null | grep -qi "Intel.*VGA\|Intel.*Graphics"; then
            echo "intel"
            return 0
        fi

        # DRI exists but unknown GPU
        echo "dri-generic"
        return 0
    fi

    echo "none"
    return 1
}
# }}}

# {{{ get_gpu_docker_args
get_gpu_docker_args() {
    local gpu_type="$1"
    local args=""

    case "$gpu_type" in
        nvidia)
            # Full NVIDIA support with container toolkit
            args="--gpus all -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all"
            ;;
        nvidia-no-toolkit)
            # NVIDIA present but toolkit not installed
            echo "WARNING: NVIDIA GPU detected but nvidia-container-toolkit not found." >&2
            echo "         GPU will not be available in container." >&2
            echo "         Install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html" >&2
            args="-v /dev/dri:/dev/dri --group-add video --group-add render"
            ;;
        amd|intel|dri-generic)
            # AMD/Intel/generic - use DRI
            args="-v /dev/dri:/dev/dri --group-add video --group-add render"
            ;;
        none)
            # No GPU - software rendering
            echo "WARNING: No GPU detected. Using software rendering (slow)." >&2
            args="-e LIBGL_ALWAYS_SOFTWARE=1"
            ;;
    esac

    echo "$args"
}
# }}}

# {{{ run_x11
run_x11() {
    echo "Starting in X11 mode..."

    local gpu_type
    gpu_type=$(detect_host_gpu)
    echo "Detected GPU: $gpu_type"

    local gpu_args
    gpu_args=$(get_gpu_docker_args "$gpu_type")

    # Allow local X connections
    xhost +local:docker 2>/dev/null || {
        echo "WARNING: Could not run xhost. X11 forwarding may fail." >&2
        echo "         Try: xhost +local:docker" >&2
    }

    # shellcheck disable=SC2086
    docker run -it --rm \
        --name ai-stuff-sandbox \
        $gpu_args \
        -e DISPLAY="$DISPLAY" \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        --network host \
        "$IMAGE_NAME"
}
# }}}

# {{{ run_vnc
run_vnc() {
    echo "Starting in VNC mode..."
    echo ""
    echo "After startup, access via:"
    echo "  - VNC client: localhost:5901 (password: sandbox)"
    echo "  - Browser:    http://localhost:6080/vnc.html"
    echo ""

    local gpu_type
    gpu_type=$(detect_host_gpu)
    echo "Detected GPU: $gpu_type"

    local gpu_args
    gpu_args=$(get_gpu_docker_args "$gpu_type")

    # shellcheck disable=SC2086
    docker run -it --rm \
        --name ai-stuff-sandbox \
        $gpu_args \
        -p 5901:5901 \
        -p 6080:6080 \
        "$IMAGE_NAME" \
        /home/sandbox/start-vnc.sh
}
# }}}

# {{{ run_headless
run_headless() {
    echo "Starting in headless mode (no GUI)..."

    local gpu_type
    gpu_type=$(detect_host_gpu)
    echo "Detected GPU: $gpu_type"

    local gpu_args
    gpu_args=$(get_gpu_docker_args "$gpu_type")

    # For headless, we only need compute capabilities
    if [ "$gpu_type" = "nvidia" ]; then
        gpu_args="--gpus all -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=compute,utility"
    fi

    # shellcheck disable=SC2086
    docker run -it --rm \
        --name ai-stuff-sandbox \
        $gpu_args \
        "$IMAGE_NAME"
}
# }}}

# {{{ show_gpu_info
show_gpu_info() {
    echo "Host GPU Detection"
    echo "=================="
    echo ""

    local gpu_type
    gpu_type=$(detect_host_gpu)

    echo "Detected type: $gpu_type"
    echo ""

    case "$gpu_type" in
        nvidia)
            echo "NVIDIA GPU with container toolkit ready."
            nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null || echo "(nvidia-smi details unavailable)"
            ;;
        nvidia-no-toolkit)
            echo "NVIDIA GPU detected but nvidia-container-toolkit is NOT installed."
            echo ""
            echo "To enable NVIDIA GPU in containers, install the toolkit:"
            echo "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
            echo ""
            echo "After installation, restart Docker and try again."
            ;;
        amd)
            echo "AMD GPU detected. Will use /dev/dri."
            if command -v lspci &> /dev/null; then
                lspci | grep -i "vga\|display" | grep -i "amd\|radeon" || true
            fi
            ;;
        intel)
            echo "Intel GPU detected. Will use /dev/dri."
            if command -v lspci &> /dev/null; then
                lspci | grep -i "vga\|display" | grep -i "intel" || true
            fi
            ;;
        dri-generic)
            echo "DRI devices found but GPU vendor unknown."
            echo "Will attempt to use /dev/dri."
            ;;
        none)
            echo "No GPU detected."
            echo "Container will use software rendering (llvmpipe)."
            echo "This is slow but functional for testing."
            ;;
    esac

    echo ""
    echo "Docker GPU args that would be used:"
    echo "  $(get_gpu_docker_args "$gpu_type")"
}
# }}}

# {{{ auto_detect_mode
auto_detect_mode() {
    # Check if we're on Linux with X11 available
    if [ -n "$DISPLAY" ] && [ -e /tmp/.X11-unix ]; then
        echo "x11"
    else
        echo "vnc"
    fi
}
# }}}

# {{{ main
main() {
    local mode="${1:-$(auto_detect_mode)}"

    case "$mode" in
        build)
            build_image
            ;;
        x11)
            run_x11
            ;;
        vnc)
            run_vnc
            ;;
        headless)
            run_headless
            ;;
        gpu-info|gpu)
            show_gpu_info
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown mode: $mode"
            show_help
            exit 1
            ;;
    esac
}
# }}}

main "$@"
