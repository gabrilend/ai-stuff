#!/bin/bash

# State Directory Management Library for Progress-II
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# {{{ create_state_directories
create_state_directories() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Creating state directory structure at: ${base_dir}"
    
    # Create all required directories
    mkdir -p "${base_dir}/characters/maxine"
    mkdir -p "${base_dir}/characters/companions"
    mkdir -p "${base_dir}/world/locations"
    mkdir -p "${base_dir}/world/items"
    mkdir -p "${base_dir}/world/variables"
    mkdir -p "${base_dir}/logs/serialized"
    mkdir -p "${base_dir}/logs/human-readable"
    mkdir -p "${base_dir}/saves/checkpoints"
    mkdir -p "${base_dir}/backup"
    
    echo "State directory structure created successfully"
    return 0
}
# }}}

# {{{ validate_directory_structure
validate_directory_structure() {
    local base_dir="${1:-${DIR}/game-state}"
    local errors=0
    
    echo "Validating state directory structure at: ${base_dir}"
    
    local required_dirs=(
        "${base_dir}"
        "${base_dir}/characters"
        "${base_dir}/characters/maxine"
        "${base_dir}/characters/companions"
        "${base_dir}/world"
        "${base_dir}/world/locations"
        "${base_dir}/world/items"
        "${base_dir}/world/variables"
        "${base_dir}/logs"
        "${base_dir}/logs/serialized"
        "${base_dir}/logs/human-readable"
        "${base_dir}/saves"
        "${base_dir}/saves/checkpoints"
        "${base_dir}/backup"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${dir}" ]; then
            echo "Error: Missing required directory: ${dir}"
            ((errors++))
        elif [ ! -r "${dir}" ] || [ ! -w "${dir}" ]; then
            echo "Error: Directory not readable/writable: ${dir}"
            ((errors++))
        fi
    done
    
    if [ ${errors} -eq 0 ]; then
        echo "Directory structure validation passed"
        return 0
    else
        echo "Directory structure validation failed with ${errors} errors"
        return 1
    fi
}
# }}}

# {{{ repair_directory_structure
repair_directory_structure() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Attempting to repair state directory structure..."
    
    if validate_directory_structure "${base_dir}" >/dev/null 2>&1; then
        echo "Directory structure is already valid, no repair needed"
        return 0
    fi
    
    if create_state_directories "${base_dir}"; then
        echo "Directory structure repaired successfully"
        return 0
    else
        echo "Error: Failed to repair directory structure"
        return 1
    fi
}
# }}}

# {{{ set_directory_permissions
set_directory_permissions() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Setting directory permissions for: ${base_dir}"
    
    chmod 750 "${base_dir}" || {
        echo "Error: Failed to set permissions on base directory"
        return 1
    }
    
    find "${base_dir}" -type d -exec chmod 750 {} \; || {
        echo "Error: Failed to set permissions on subdirectories"
        return 1
    }
    
    find "${base_dir}" -type f -exec chmod 640 {} \; 2>/dev/null || {
        echo "Warning: Some file permissions could not be set"
    }
    
    echo "Directory permissions set successfully"
    return 0
}
# }}}

# {{{ get_state_directory_info
get_state_directory_info() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "State Directory Information:"
    echo "=========================="
    echo "Base Directory: ${base_dir}"
    
    if [ ! -d "${base_dir}" ]; then
        echo "Status: Directory does not exist"
        return 1
    fi
    
    echo "Status: Directory exists"
    echo "Size: $(du -sh "${base_dir}" 2>/dev/null | cut -f1)"
    echo "Permissions: $(stat -c "%a" "${base_dir}" 2>/dev/null)"
    echo ""
    echo "Subdirectory Status:"
    
    local subdirs=(
        "characters/maxine"
        "characters/companions"  
        "world/locations"
        "world/items"
        "world/variables"
        "logs/serialized"
        "logs/human-readable"
        "saves/checkpoints"
        "backup"
    )
    
    for subdir in "${subdirs[@]}"; do
        local full_path="${base_dir}/${subdir}"
        if [ -d "${full_path}" ]; then
            local file_count=$(find "${full_path}" -type f 2>/dev/null | wc -l)
            echo "  [OK] ${subdir} - ${file_count} files"
        else
            echo "  [MISSING] ${subdir}"
        fi
    done
    
    return 0
}
# }}}

# {{{ initialize_state_directory
initialize_state_directory() {
    local base_dir="${1:-${DIR}/game-state}"
    
    echo "Initializing state directory system..."
    
    if ! create_state_directories "${base_dir}"; then
        echo "Error: Failed to create state directories"
        return 1
    fi
    
    if ! set_directory_permissions "${base_dir}"; then
        echo "Error: Failed to set directory permissions"
        return 1
    fi
    
    if ! validate_directory_structure "${base_dir}"; then
        echo "Error: Directory structure validation failed"
        return 1
    fi
    
    echo "State directory system initialized successfully"
    get_state_directory_info "${base_dir}"
    return 0
}
# }}}

# Export functions
export -f create_state_directories
export -f validate_directory_structure
export -f repair_directory_structure
export -f set_directory_permissions
export -f get_state_directory_info
export -f initialize_state_directory