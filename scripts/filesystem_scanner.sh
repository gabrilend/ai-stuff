#!/bin/bash
#
# filesystem_scanner.sh
#
# Walks a folder and writes one plain-text picture of everything inside it --
# every subfolder as an indented tree, every file with its size, every symlink
# with where it points -- followed by totals. The picture is meant to be handed
# to a language model as context ("here is what this machine holds"), so it is
# plain text with a fixed layout. It can also put itself in cron to redraw the
# picture weekly.
#
# Where things go, and why:
#   - The picture is written to the scripts folder's RAM artifact tier,
#     tmp/shared-memory/filesystem-scanner/, named after the scanned folder.
#     It is a regenerable artifact, so it lives in RAM; and it is never
#     written INTO the folder being scanned. An earlier version did, which
#     meant scanning / (its old default) tried to write /filesystem_hierarchy.txt
#     and every scan of a project left a file in that project.
#   - The folder scanned by default is the ai-stuff monorepo (DIR below),
#     not /. Scanning the whole machine is still possible; it just has to be
#     asked for by name.
#   - Cron is only ever touched by the explicit --install-cron and
#     --uninstall-cron commands, and the cron job logs into the same RAM tier
#     (the old /var/log path is not writable by a normal user, so every cron
#     run failed to log).
#
# Usage:
#   filesystem_scanner.sh [folder] [-o output-file]
#   filesystem_scanner.sh --install-cron [folder]
#   filesystem_scanner.sh --uninstall-cron
#   filesystem_scanner.sh --show-cron [folder]
#   filesystem_scanner.sh -h

# The folder scanned when none is named. Hard-coded per the house rule;
# override with the first argument.
DIR="/home/ritz/programming/ai-stuff"

# Where this script and its RAM tier live.
SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"
ARTIFACT_DIR="${SCRIPTS_DIR}/tmp/shared-memory/filesystem-scanner"

# Output file; set from the scanned folder's name once arguments are read,
# unless -o names one.
OUTPUT_FILE=""

# Cron job configuration - modify these human-readable values as needed
CRON_MINUTE=0              # 0-59: Minute of the hour
CRON_HOUR=2                # 0-23: Hour of the day (24-hour format)
CRON_DAY_OF_MONTH="*"      # 1-31 or "*": Day of month (* = every day)
CRON_MONTH="*"             # 1-12 or "*": Month (* = every month)
CRON_DAY_OF_WEEK=0         # 0-7 or "*": Day of week (0=Sunday, 7=Sunday, * = every day)
CRON_USER="$(whoami)"      # Current user
CRON_LOG_FILE="${ARTIFACT_DIR}/cron.log"
CRON_COMMENT="# Automated filesystem hierarchy scanner"

# Absolute path of this script, for the cron line.
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
# {{{ build_cron_schedule
build_cron_schedule() {
    CRON_SCHEDULE="$CRON_MINUTE $CRON_HOUR $CRON_DAY_OF_MONTH $CRON_MONTH $CRON_DAY_OF_WEEK"
}
# }}}

# {{{ get_human_readable_schedule
get_human_readable_schedule() {
    local readable=""
    
    # Handle day of week
    case "$CRON_DAY_OF_WEEK" in
        0|7) readable="Every Sunday" ;;
        1) readable="Every Monday" ;;
        2) readable="Every Tuesday" ;;
        3) readable="Every Wednesday" ;;
        4) readable="Every Thursday" ;;
        5) readable="Every Friday" ;;
        6) readable="Every Saturday" ;;
        *) readable="Every day" ;;
    esac
    
    # Handle time
    local hour_12=$(( CRON_HOUR == 0 ? 12 : ( CRON_HOUR > 12 ? CRON_HOUR - 12 : CRON_HOUR ) ))
    local ampm="AM"
    if [[ $CRON_HOUR -ge 12 ]]; then
        ampm="PM"
    fi
    local minute_str=$(printf "%02d" "$CRON_MINUTE")
    
    readable="$readable at $hour_12:$minute_str $ampm"
    
    # Handle monthly/daily specifics
    if [[ "$CRON_DAY_OF_MONTH" != "*" ]]; then
        readable="$readable on the ${CRON_DAY_OF_MONTH}$(ordinal_suffix "$CRON_DAY_OF_MONTH") of"
    fi
    
    if [[ "$CRON_MONTH" != "*" ]]; then
        case "$CRON_MONTH" in
            1) readable="$readable January" ;;
            2) readable="$readable February" ;;
            3) readable="$readable March" ;;
            4) readable="$readable April" ;;
            5) readable="$readable May" ;;
            6) readable="$readable June" ;;
            7) readable="$readable July" ;;
            8) readable="$readable August" ;;
            9) readable="$readable September" ;;
            10) readable="$readable October" ;;
            11) readable="$readable November" ;;
            12) readable="$readable December" ;;
        esac
    elif [[ "$CRON_DAY_OF_MONTH" != "*" ]]; then
        readable="$readable every month"
    fi
    
    echo "$readable"
}
# }}}

# {{{ ordinal_suffix
ordinal_suffix() {
    local num="$1"
    case "$num" in
        *1[0-9]|*[04-9]) echo "th" ;;
        *1) echo "st" ;;
        *2) echo "nd" ;;
        *3) echo "rd" ;;
    esac
}
# }}}

# {{{ print_usage
print_usage() {
    build_cron_schedule
    local human_schedule=$(get_human_readable_schedule)
    
    echo "Usage: $0 [folder] [-o output-file]   |   --install-cron [folder]   |   --uninstall-cron   |   --show-cron [folder]"
    echo "Scans filesystem hierarchy and creates text display for LLM processing"
    echo "Default folder: $DIR"
    echo "Output: $ARTIFACT_DIR/<folder-name>-hierarchy.txt (RAM; never inside the scanned folder)"
    echo ""
    echo "Cron job options:"
    echo "  --install-cron    Install cron job with schedule: $human_schedule"
    echo "  --uninstall-cron  Remove cron job for this script"
    echo "  --show-cron       Show current cron job configuration"
    echo ""
    echo "Current schedule configuration:"
    echo "  Minute: $CRON_MINUTE (0-59)"
    echo "  Hour: $CRON_HOUR (0-23, 24-hour format)"
    echo "  Day of Month: $CRON_DAY_OF_MONTH (1-31 or * for every day)"
    echo "  Month: $CRON_MONTH (1-12 or * for every month)"
    echo "  Day of Week: $CRON_DAY_OF_WEEK (0-7, 0=Sunday, * for every day)"
}
# }}}

# {{{ validate_directory
validate_directory() {
    if [[ ! -d "$DIR" ]]; then
        echo "Error: Directory '$DIR' does not exist or is not accessible"
        exit 1
    fi
    
    if [[ ! -r "$DIR" ]]; then
        echo "Error: Directory '$DIR' is not readable"
        exit 1
    fi
}
# }}}

# {{{ generate_tree_structure
generate_tree_structure() {
    local base_dir="$1"
    local output_file="$2"
    local max_depth="${3:-10}"
    
    echo "=== FILESYSTEM HIERARCHY SCAN ===" > "$output_file"
    echo "Scan Date: $(date)" >> "$output_file"
    echo "Base Directory: $base_dir" >> "$output_file"
    echo "Max Depth: $max_depth levels" >> "$output_file"
    echo "===============================" >> "$output_file"
    echo "" >> "$output_file"
    
    # Use find with controlled depth to prevent infinite recursion
    find "$base_dir" -maxdepth "$max_depth" -type d 2>/dev/null | \
    sort | \
    while IFS= read -r dir; do
        # Calculate depth level
        depth=$(echo "$dir" | tr -cd '/' | wc -c)
        relative_depth=$((depth - $(echo "$base_dir" | tr -cd '/' | wc -c)))
        
        # Create indentation
        indent=""
        for ((i=0; i<relative_depth; i++)); do
            indent+="  "
        done
        
        # Get directory name
        dirname=$(basename "$dir")
        if [[ "$dir" == "$base_dir" ]]; then
            dirname="[ROOT: $base_dir]"
        fi
        
        echo "${indent}├── $dirname/" >> "$output_file"
        
        # List files in current directory
        find "$dir" -maxdepth 1 -type f 2>/dev/null | sort | while IFS= read -r file; do
            filename=$(basename "$file")
            filesize=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
            echo "${indent}│   ├── $filename (${filesize} bytes)" >> "$output_file"
        done
        
        # List symlinks
        find "$dir" -maxdepth 1 -type l 2>/dev/null | sort | while IFS= read -r link; do
            linkname=$(basename "$link")
            target=$(readlink "$link" 2>/dev/null || echo "broken")
            echo "${indent}│   ├── $linkname -> $target [SYMLINK]" >> "$output_file"
        done
    done
}
# }}}

# {{{ generate_summary_stats
generate_summary_stats() {
    local base_dir="$1"
    local output_file="$2"
    
    echo "" >> "$output_file"
    echo "=== FILESYSTEM STATISTICS ===" >> "$output_file"
    
    # Count directories
    dir_count=$(find "$base_dir" -type d 2>/dev/null | wc -l)
    echo "Total Directories: $dir_count" >> "$output_file"
    
    # Count files
    file_count=$(find "$base_dir" -type f 2>/dev/null | wc -l)
    echo "Total Files: $file_count" >> "$output_file"
    
    # Count symlinks
    link_count=$(find "$base_dir" -type l 2>/dev/null | wc -l)
    echo "Total Symlinks: $link_count" >> "$output_file"
    
    # Calculate total size
    total_size=$(find "$base_dir" -type f -exec stat -c%s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
    echo "Total Size: ${total_size:-0} bytes" >> "$output_file"
    
    echo "============================" >> "$output_file"
}
# }}}

# {{{ create_llm_ready_format
create_llm_ready_format() {
    local output_file="$1"
    
    echo "" >> "$output_file"
    echo "=== LLM PROCESSING NOTES ===" >> "$output_file"
    echo "This filesystem hierarchy scan is optimized for LLM ingestion." >> "$output_file"
    echo "Structure follows standard tree format with consistent indentation." >> "$output_file"
    echo "File sizes included for context and analysis." >> "$output_file"
    echo "Symlinks clearly marked to prevent confusion." >> "$output_file"
    echo "Scan completed at: $(date)" >> "$output_file"
    echo "===========================" >> "$output_file"
}
# }}}

# {{{ install_cronjob
install_cronjob() {
    local temp_cron_file="/tmp/temp_crontab_$$"
    
    # Build the cron schedule from human-readable variables
    build_cron_schedule
    local human_schedule=$(get_human_readable_schedule)
    
    echo "Installing cron job for filesystem scanner..."
    echo "Schedule: $human_schedule"
    echo "Cron format: $CRON_SCHEDULE"
    echo "Script: $SCRIPT_PATH"
    echo "Log file: $CRON_LOG_FILE"
    
    # Get current crontab (ignore errors if no crontab exists)
    crontab -l 2>/dev/null > "$temp_cron_file" || touch "$temp_cron_file"
    
    # Check if our cron job already exists
    if grep -q "$SCRIPT_PATH" "$temp_cron_file"; then
        echo "Warning: Cron job for this script already exists. Removing old entry..."
        grep -v "$SCRIPT_PATH" "$temp_cron_file" > "${temp_cron_file}.new"
        mv "${temp_cron_file}.new" "$temp_cron_file"
    fi
    
    # Add our cron job entry
    echo "$CRON_COMMENT" >> "$temp_cron_file"
    echo "$CRON_SCHEDULE $SCRIPT_PATH \"$DIR\" >> $CRON_LOG_FILE 2>&1" >> "$temp_cron_file"
    
    # Install the new crontab
    if crontab "$temp_cron_file"; then
        echo "Cron job installed successfully!"
        echo "The scanner will run with schedule: $CRON_SCHEDULE"
        echo "Logs will be written to: $CRON_LOG_FILE"
    else
        echo "Error: Failed to install cron job"
        rm -f "$temp_cron_file"
        exit 1
    fi
    
    # Clean up
    rm -f "$temp_cron_file"
}
# }}}

# {{{ uninstall_cronjob
uninstall_cronjob() {
    local temp_cron_file="/tmp/temp_crontab_$$"
    
    echo "Uninstalling cron job for filesystem scanner..."
    
    # Get current crontab
    if ! crontab -l 2>/dev/null > "$temp_cron_file"; then
        echo "No crontab found for user $CRON_USER"
        return 0
    fi
    
    # Check if our cron job exists
    if ! grep -q "$SCRIPT_PATH" "$temp_cron_file"; then
        echo "No cron job found for this script"
        rm -f "$temp_cron_file"
        return 0
    fi
    
    # Remove our cron job and its comment
    grep -v "$SCRIPT_PATH" "$temp_cron_file" | grep -v "$CRON_COMMENT" > "${temp_cron_file}.new"
    
    # Install the updated crontab
    if crontab "${temp_cron_file}.new"; then
        echo "Cron job uninstalled successfully!"
    else
        echo "Error: Failed to uninstall cron job"
        rm -f "$temp_cron_file" "${temp_cron_file}.new"
        exit 1
    fi
    
    # Clean up
    rm -f "$temp_cron_file" "${temp_cron_file}.new"
}
# }}}

# {{{ show_cronjob_config
show_cronjob_config() {
    build_cron_schedule
    local human_schedule=$(get_human_readable_schedule)
    
    echo "=== CRON JOB CONFIGURATION ==="
    echo "Human Schedule: $human_schedule"
    echo "Cron Format: $CRON_SCHEDULE"
    echo "User: $CRON_USER"
    echo "Script: $SCRIPT_PATH"
    echo "Target directory: $DIR"
    echo "Log file: $CRON_LOG_FILE"
    echo "Comment: $CRON_COMMENT"
    echo ""
    echo "Individual time components:"
    echo "  Minute: $CRON_MINUTE"
    echo "  Hour: $CRON_HOUR"
    echo "  Day of Month: $CRON_DAY_OF_MONTH"
    echo "  Month: $CRON_MONTH"
    echo "  Day of Week: $CRON_DAY_OF_WEEK"
    echo "=============================="
    
    echo ""
    echo "Current cron jobs for user $CRON_USER:"
    if crontab -l 2>/dev/null | grep -E "(filesystem_scanner|$SCRIPT_PATH)"; then
        echo "Found filesystem scanner cron job(s) above."
    else
        echo "No filesystem scanner cron jobs found."
    fi
}
# }}}

# {{{ main_execution
main_execution() {
    echo "Starting filesystem scan..."
    echo "Target directory: $DIR"
    
    # Validate directory access
    validate_directory
    
    # Set reasonable depth limit to prevent overwhelming output
    MAX_DEPTH=8
    
    # Generate the tree structure
    echo "Generating filesystem hierarchy..."
    generate_tree_structure "$DIR" "$OUTPUT_FILE" "$MAX_DEPTH"
    
    # Add summary statistics
    echo "Calculating filesystem statistics..."
    generate_summary_stats "$DIR" "$OUTPUT_FILE"
    
    # Add LLM processing notes
    create_llm_ready_format "$OUTPUT_FILE"
    
    echo "Filesystem scan complete!"
    echo "Output saved to: $OUTPUT_FILE"
    echo "File size: $(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown") bytes"
}
# }}}

# {{{ prepare_output
# Settles the output path and makes sure the RAM tier behind it exists (it is
# erased by every reboot). Stops, rather than writing somewhere else, if the
# tier cannot be built.
prepare_output() {
    # shellcheck source=libs/ensure-ram-tiers
    source "${SCRIPTS_DIR}/libs/ensure-ram-tiers"
    ensure_ram_tiers "$SCRIPTS_DIR" || exit 1
    mkdir -p "$ARTIFACT_DIR"
    if [[ -z "$OUTPUT_FILE" ]]; then
        local name
        name="$(realpath "$DIR" | sed 's|^/||; s|/|-|g')"
        [[ -z "$name" ]] && name="root"
        OUTPUT_FILE="${ARTIFACT_DIR}/${name}-hierarchy.txt"
    fi
}
# }}}

# {{{ read_folder_and_output
# Reads "[folder] [-o file]" from what follows a command.
read_folder_and_output() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
            -*) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
            *) DIR="$1"; shift ;;
        esac
    done
}
# }}}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        print_usage
        exit 0
        ;;
    --install-cron)
        shift
        read_folder_and_output "$@"
        validate_directory
        prepare_output
        install_cronjob
        exit 0
        ;;
    --uninstall-cron)
        uninstall_cronjob
        exit 0
        ;;
    --show-cron)
        shift
        read_folder_and_output "$@"
        show_cronjob_config
        exit 0
        ;;
    *)
        read_folder_and_output "$@"
        prepare_output
        main_execution
        ;;
esac
