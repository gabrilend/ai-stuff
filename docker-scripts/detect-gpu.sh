#!/bin/bash
# GPU Detection Script
# Identifies available GPU hardware and capabilities inside the container
# Outputs environment variables for use by other scripts
#
# Supports: NVIDIA, AMD, Intel, or software fallback (llvmpipe)

# {{{ detect_nvidia
detect_nvidia() {
    # Check for NVIDIA GPU via multiple methods
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            echo "nvidia"
            return 0
        fi
    fi

    # Check for NVIDIA device files
    if [ -e /dev/nvidia0 ]; then
        echo "nvidia"
        return 0
    fi

    return 1
}
# }}}

# {{{ detect_amd
detect_amd() {
    # Check for AMD GPU via DRI devices
    if [ -d /dev/dri ]; then
        # Look for AMD-specific identifiers in Vulkan
        if vulkaninfo 2>/dev/null | grep -qi "AMD\|RADV\|radeon"; then
            echo "amd"
            return 0
        fi

        # Check lspci output if available in /sys
        if [ -d /sys/bus/pci/devices ]; then
            for dev in /sys/bus/pci/devices/*/vendor; do
                # AMD vendor ID is 0x1002
                if [ -f "$dev" ] && grep -q "0x1002" "$dev" 2>/dev/null; then
                    echo "amd"
                    return 0
                fi
            done
        fi
    fi

    return 1
}
# }}}

# {{{ detect_intel
detect_intel() {
    # Check for Intel GPU via DRI devices
    if [ -d /dev/dri ]; then
        # Look for Intel-specific identifiers in Vulkan
        if vulkaninfo 2>/dev/null | grep -qi "Intel"; then
            echo "intel"
            return 0
        fi

        # Check for Intel device in /sys
        if [ -d /sys/bus/pci/devices ]; then
            for dev in /sys/bus/pci/devices/*/vendor; do
                # Intel vendor ID is 0x8086
                if [ -f "$dev" ] && grep -q "0x8086" "$dev" 2>/dev/null; then
                    # Verify it's a GPU class device (0x03)
                    class_file="$(dirname "$dev")/class"
                    if [ -f "$class_file" ] && grep -q "^0x03" "$class_file" 2>/dev/null; then
                        echo "intel"
                        return 0
                    fi
                fi
            done
        fi
    fi

    return 1
}
# }}}

# {{{ detect_any_gpu
detect_any_gpu() {
    # Try each vendor in order of typical performance
    local gpu

    gpu=$(detect_nvidia) && { echo "$gpu"; return 0; }
    gpu=$(detect_amd) && { echo "$gpu"; return 0; }
    gpu=$(detect_intel) && { echo "$gpu"; return 0; }

    # No hardware GPU found
    echo "software"
    return 1
}
# }}}

# {{{ get_gpu_info
get_gpu_info() {
    local gpu_type="$1"

    case "$gpu_type" in
        nvidia)
            if command -v nvidia-smi &> /dev/null; then
                nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "NVIDIA GPU (details unavailable)"
            else
                echo "NVIDIA GPU"
            fi
            ;;
        amd)
            vulkaninfo 2>/dev/null | grep -i "deviceName" | grep -i "AMD\|RADV" | head -1 | sed 's/.*= //' || echo "AMD GPU"
            ;;
        intel)
            vulkaninfo 2>/dev/null | grep -i "deviceName" | grep -i "Intel" | head -1 | sed 's/.*= //' || echo "Intel GPU"
            ;;
        software)
            echo "Software renderer (llvmpipe/lavapipe)"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}
# }}}

# {{{ check_vulkan_support
check_vulkan_support() {
    if command -v vulkaninfo &> /dev/null; then
        if vulkaninfo --summary &> /dev/null; then
            echo "yes"
            return 0
        fi
    fi
    echo "no"
    return 1
}
# }}}

# {{{ check_opengl_support
check_opengl_support() {
    if command -v glxinfo &> /dev/null; then
        if glxinfo 2>/dev/null | grep -q "OpenGL"; then
            echo "yes"
            return 0
        fi
    fi
    echo "no"
    return 1
}
# }}}

# {{{ print_status
print_status() {
    local gpu_type
    gpu_type=$(detect_any_gpu)

    echo "========================================"
    echo "         GPU Detection Results         "
    echo "========================================"
    echo ""
    echo "GPU Vendor:    $gpu_type"
    echo "GPU Device:    $(get_gpu_info "$gpu_type")"
    echo "Vulkan:        $(check_vulkan_support)"
    echo "OpenGL:        $(check_opengl_support)"
    echo ""

    if [ "$gpu_type" = "software" ]; then
        echo "WARNING: No hardware GPU detected."
        echo "Graphics will use software rendering (slow)."
        echo "Compute shaders may not be available."
        echo ""
        echo "To enable GPU access, ensure:"
        echo "  - /dev/dri is mounted (-v /dev/dri:/dev/dri)"
        echo "  - For NVIDIA: nvidia-container-toolkit is installed"
        echo "  - For AMD/Intel: user is in 'video' and 'render' groups"
    fi

    echo "========================================"
}
# }}}

# {{{ export_env
export_env() {
    local gpu_type
    gpu_type=$(detect_any_gpu)

    echo "export GPU_VENDOR=\"$gpu_type\""
    echo "export GPU_DEVICE=\"$(get_gpu_info "$gpu_type")\""
    echo "export VULKAN_AVAILABLE=\"$(check_vulkan_support)\""
    echo "export OPENGL_AVAILABLE=\"$(check_opengl_support)\""

    # Set software rendering fallback if no GPU
    if [ "$gpu_type" = "software" ]; then
        echo "export LIBGL_ALWAYS_SOFTWARE=1"
        echo "export GALLIUM_DRIVER=llvmpipe"
    fi
}
# }}}

# {{{ main
main() {
    case "${1:-status}" in
        status)
            print_status
            ;;
        env)
            export_env
            ;;
        type)
            detect_any_gpu
            ;;
        *)
            echo "Usage: $0 [status|env|type]"
            echo "  status - Print detailed GPU information"
            echo "  env    - Output environment variables for eval"
            echo "  type   - Output just the GPU type (nvidia/amd/intel/software)"
            exit 1
            ;;
    esac
}
# }}}

main "$@"
