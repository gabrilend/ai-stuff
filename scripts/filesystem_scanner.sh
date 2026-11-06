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
#   filesystem_scanner.sh --install-cron [folder] [--day DAY] [--at H:MM]
#   filesystem_scanner.sh --uninstall-cron
#   filesystem_scanner.sh --show-cron [folder] [--day DAY] [--at H:MM]
#   filesystem_scanner.sh -I [folder]     (menu: pick a folder, scan it, set
#                                          up or remove the cron job)
#   filesystem_scanner.sh -h
#
# DAY is a weekday (sun, mon, ... sat, or 0-7) or "daily". Every folder the
# script scans is remembered in the RAM tier (recent-folders.txt), and the
# menu offers the most recent ones.

# The folder scanned when none is named. Hard-coded per the house rule;
# override with the first argument.
DIR="/home/ritz/programming/ai-stuff"
DEFAULT_DIR="$DIR"
FOLDER_GIVEN=""

# Where the scripts folder and its RAM tier live. SCRIPTS_DIR may be set in
# the environment, as for backup-conversations (the tests point it at a
# scratch folder).
SCRIPTS_DIR="${SCRIPTS_DIR:-/home/ritz/programming/ai-stuff/scripts}"
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

# The crontab command. Only the test suite sets FILESYSTEM_SCANNER_CRONTAB, to
# a stand-in that keeps the "crontab" in a scratch file, so no test can touch
# the real one.
CRONTAB="${FILESYSTEM_SCANNER_CRONTAB:-crontab}"

# How many recently scanned folders are remembered for the menu.
RECENT_LIMIT=8
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
    
    echo "Usage: $0 [folder] [-o output-file]   |   --install-cron [folder] [--day DAY] [--at H:MM]   |   --uninstall-cron   |   --show-cron [folder]   |   -I [folder]"
    echo "Scans filesystem hierarchy and creates text display for LLM processing"
    echo "Default folder: $DIR"
    echo "Output: $ARTIFACT_DIR/<folder-name>-hierarchy.txt (RAM; never inside the scanned folder)"
    echo ""
    echo "Cron job options:"
    echo "  --install-cron    Install cron job with schedule: $human_schedule"
    echo "  --uninstall-cron  Remove cron job for this script"
    echo "  --show-cron       Show current cron job configuration"
    echo "  --day DAY         With --install-cron or --show-cron: sun..sat, 0-7, or daily"
    echo "  --at H:MM         With --install-cron or --show-cron: the time, 24-hour clock"
    echo ""
    echo "  -I, --interactive Menu: pick a folder, scan it, install or remove the cron job"
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
    "$CRONTAB" -l 2>/dev/null > "$temp_cron_file" || touch "$temp_cron_file"
    
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
    if "$CRONTAB" "$temp_cron_file"; then
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
    if ! "$CRONTAB" -l 2>/dev/null > "$temp_cron_file"; then
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
    if "$CRONTAB" "${temp_cron_file}.new"; then
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
    if "$CRONTAB" -l 2>/dev/null | grep -E "(filesystem_scanner|$SCRIPT_PATH)"; then
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
    
    remember_folder "$DIR"

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
    prepare_tiers || exit 1
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="$(output_path_for "$DIR")"
    fi
}
# }}}

# {{{ prepare_tiers
# Builds the RAM tier behind tmp/ if a reboot erased it, and the scanner's
# folder in it. Returns 1 (having said why) if that cannot be done.
prepare_tiers() {
    # shellcheck source=libs/ensure-ram-tiers
    source "${SCRIPTS_DIR}/libs/ensure-ram-tiers" || return 1
    ensure_ram_tiers "$SCRIPTS_DIR" || return 1
    mkdir -p "$ARTIFACT_DIR"
}
# }}}

# {{{ output_path_for
# Where the picture of a folder goes when -o does not say: its full path with
# the slashes turned into dashes, in the RAM tier.
output_path_for() {
    local name
    name="$(realpath "$1" | sed 's|^/||; s|/|-|g')"
    [[ -z "$name" ]] && name="root"
    echo "${ARTIFACT_DIR}/${name}-hierarchy.txt"
}
# }}}

# {{{ remember_folder
# Puts a scanned folder at the top of recent-folders.txt, dropping its older
# entry, and keeps RECENT_LIMIT of them. RAM like the pictures themselves: a
# reboot forgets them, which costs only a typed path.
remember_folder() {
    local folder file
    folder="$(realpath "$1" 2>/dev/null)" || return 0
    file="${ARTIFACT_DIR}/recent-folders.txt"
    {
        printf '%s\n' "$folder"
        [[ -f "$file" ]] && grep -v -x -F -- "$folder" "$file"
    } | head -n "$RECENT_LIMIT" > "${file}.new" && mv -f "${file}.new" "$file"
}
# }}}

# {{{ recent_folders
# The remembered folders that still exist, most recent first.
recent_folders() {
    local file="${ARTIFACT_DIR}/recent-folders.txt" folder
    [[ -f "$file" ]] || return 0
    while IFS= read -r folder; do
        [[ -d "$folder" ]] && echo "$folder"
    done < "$file"
}
# }}}

# {{{ set_schedule_day
# Sets CRON_DAY_OF_WEEK from a weekday name, a number 0-7, or "daily".
# Returns 1 for anything else.
set_schedule_day() {
    case "${1,,}" in
        daily|every|"*") CRON_DAY_OF_WEEK="*" ;;
        sun|sunday) CRON_DAY_OF_WEEK=0 ;;
        mon|monday) CRON_DAY_OF_WEEK=1 ;;
        tue|tuesday) CRON_DAY_OF_WEEK=2 ;;
        wed|wednesday) CRON_DAY_OF_WEEK=3 ;;
        thu|thursday) CRON_DAY_OF_WEEK=4 ;;
        fri|friday) CRON_DAY_OF_WEEK=5 ;;
        sat|saturday) CRON_DAY_OF_WEEK=6 ;;
        [0-7]) CRON_DAY_OF_WEEK="$1" ;;
        *) return 1 ;;
    esac
}
# }}}

# {{{ set_schedule_time
# Sets CRON_HOUR and CRON_MINUTE from hour and minute, after checking them
# (0-23 and 0-59). Returns 1, changing nothing, if either is out of range.
set_schedule_time() {
    local hour="$1" minute="$2"
    [[ "$hour" =~ ^[0-9]{1,2}$ && "$minute" =~ ^[0-9]{1,2}$ ]] || return 1
    (( 10#$hour <= 23 && 10#$minute <= 59 )) || return 1
    CRON_HOUR=$((10#$hour))
    CRON_MINUTE=$((10#$minute))
}
# }}}

# {{{ installed_cron_lines
# This script's lines in the crontab, if any.
installed_cron_lines() {
    "$CRONTAB" -l 2>/dev/null | grep -F -- "$SCRIPT_PATH"
}
# }}}

# {{{ fit_to_screen
# Cuts a note to the terminal's width (less the box's borders), so a long
# path doesn't spill over the menu's frame. Long notes keep their start.
fit_to_screen() {
    local text="$1" cols
    cols="$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    local max=$(( cols - 4 ))
    if (( ${#text} > max )); then
        text="${text:0:max-3}..."
    fi
    echo "$text"
}
# }}}

# {{{ interactive_mode
# The menu (issue 014, phase 1). A "Do" list picks what Go does: scan now,
# install the cron job, remove it, or preview the schedule. Below it, the
# folder (the recent ones, or "Another folder..." to type a path), and the
# cron day and time. The panel at the bottom shows the cron job as installed
# and the last picture of the folder under the cursor. After each step the
# menu opens again, with a note of what happened in its subtitle; q leaves.
interactive_mode() {
    local libs_dir
    libs_dir="$(dirname "$SCRIPT_PATH")/libs"
    # shellcheck source=libs/lua-menu.sh
    source "$libs_dir/lua-menu.sh" || return 1
    prepare_tiers || return 1

    local given_output="$OUTPUT_FILE" chosen note="" status line i item choice
    local folder hour minute day human
    local -a folders=()
    local -A seen=()
    chosen="$(realpath "$DIR" 2>/dev/null || echo "$DIR")"
    local day_names=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

    while true; do
        build_cron_schedule
        human="$(get_human_readable_schedule)"

        # the folders to offer: the chosen one, the recent ones, and the
        # default folder when none was named on the command line
        folders=()
        seen=()
        while IFS= read -r folder; do
            [[ -n "$folder" && -z "${seen[$folder]+x}" ]] || continue
            seen[$folder]=1
            folders+=("$folder")
        done < <(echo "$chosen"; recent_folders
                 [[ -z "$FOLDER_GIVEN" && -d "$DEFAULT_DIR" ]] && realpath "$DEFAULT_DIR")
        (( ${#folders[@]} > RECENT_LIMIT + 1 )) && folders=("${folders[@]:0:RECENT_LIMIT+1}")

        menu_init
        menu_set_title "Filesystem Scanner" "$(fit_to_screen "${note:-Cron schedule: $human}")"
        menu_add_section "todo" "single" "Do"
        menu_add_item "todo" "do_scan" "Scan now" "checkbox" "1" "Write a picture of the chosen folder into the RAM tier"
        menu_add_item "todo" "do_install" "Install cron job" "checkbox" "0" "Scan the chosen folder on the schedule below (replaces this script's old job)"
        menu_add_item "todo" "do_remove" "Remove cron job" "checkbox" "0" "Take this script's job out of the crontab"
        menu_add_item "todo" "do_preview" "Preview schedule" "checkbox" "0" "Show the day and time chosen below in the title; changes nothing"

        menu_add_section "folder" "single" "Folder"
        for i in "${!folders[@]}"; do
            menu_add_item "folder" "folder_$i" "${folders[$i]}" "checkbox" \
                "$([[ "${folders[$i]}" == "$chosen" ]] && echo 1 || echo 0)" "${folders[$i]}"
            if [[ -z "$given_output" && -f "$(output_path_for "${folders[$i]}")" ]]; then
                menu_set_item_filepath "folder_$i" "$(output_path_for "${folders[$i]}")"
            fi
        done
        menu_add_item "folder" "folder_other" "Another folder..." "checkbox" "0" "Asks for a path once the menu closes"
        menu_set_section_max_visible "folder" 5

        menu_add_section "day" "single" "Cron day"
        menu_add_item "day" "day_any" "Every day" "checkbox" \
            "$([[ "$CRON_DAY_OF_WEEK" == "*" ]] && echo 1 || echo 0)" "Run every day"
        for i in 0 1 2 3 4 5 6; do
            menu_add_item "day" "day_$i" "${day_names[$i]}" "checkbox" \
                "$([[ "$CRON_DAY_OF_WEEK" == "$i" || ( "$i" == 0 && "$CRON_DAY_OF_WEEK" == 7 ) ]] && echo 1 || echo 0)" \
                "Run every ${day_names[$i]}"
        done
        menu_set_section_max_visible "day" 4

        menu_add_section "time" "multi" "Cron time (24-hour clock)"
        menu_add_item "time" "hour" "Hour" "flag" "${CRON_HOUR}:2" "0-23"
        menu_add_item "time" "minute" "Minute" "flag" "${CRON_MINUTE}:2" "0-59"

        menu_add_section "go" "multi" "Actions"
        menu_add_item "go" "go" "Go" "action" "" "Do what is chosen above"

        status="$(installed_cron_lines)"
        menu_add_content_source "text" "Cron job" "${status:-No cron job installed for this script.}"
        menu_add_content_source "item_file" "" ""

        menu_run || return 0
        note=""

        # what was chosen: the do item, the folder, the day, the time
        choice=""
        for item in do_scan do_install do_remove do_preview; do
            [[ "${MENU_VALUES[$item]:-0}" == "1" ]] && { choice="$item"; break; }
        done
        if [[ "${MENU_VALUES[folder_other]:-0}" == "1" ]]; then
            read -r -e -p "Folder to scan: " folder
            folder="${folder/#\~/$HOME}"
            if [[ -d "$folder" && -r "$folder" ]]; then
                chosen="$(realpath "$folder")"
            else
                note="Not a readable folder: $folder"
                continue
            fi
        else
            for i in "${!folders[@]}"; do
                [[ "${MENU_VALUES[folder_$i]:-0}" == "1" ]] && chosen="${folders[$i]}"
            done
        fi
        [[ "${MENU_VALUES[day_any]:-0}" == "1" ]] && CRON_DAY_OF_WEEK="*"
        for i in 0 1 2 3 4 5 6; do
            [[ "${MENU_VALUES[day_$i]:-0}" == "1" ]] && CRON_DAY_OF_WEEK="$i"
        done
        hour="${MENU_VALUES[hour]:-$CRON_HOUR}"
        minute="${MENU_VALUES[minute]:-$CRON_MINUTE}"
        if ! set_schedule_time "$hour" "$minute"; then
            note="Not done: the hour must be 0-23 and the minute 0-59 (got $hour:$minute)"
            continue
        fi
        build_cron_schedule
        human="$(get_human_readable_schedule)"

        case "$choice" in
            do_scan)
                if [[ ! -d "$chosen" || ! -r "$chosen" ]]; then
                    note="Not a readable folder: $chosen"
                    continue
                fi
                DIR="$chosen"
                OUTPUT_FILE="${given_output:-$(output_path_for "$chosen")}"
                if ( main_execution ) > /dev/null 2>&1; then
                    note="Scanned $chosen into $(basename "$OUTPUT_FILE")"
                else
                    note="The scan of $chosen failed"
                fi
                ;;
            do_install)
                DIR="$chosen"
                if ( install_cronjob ) > /dev/null 2>&1; then
                    note="Cron job installed: $human, scanning $chosen"
                else
                    note="The cron job could not be installed"
                fi
                ;;
            do_remove)
                if [[ -z "$(installed_cron_lines)" ]]; then
                    note="There was no cron job to remove"
                elif ( uninstall_cronjob ) > /dev/null 2>&1; then
                    note="Cron job removed"
                else
                    note="The cron job could not be removed"
                fi
                ;;
            do_preview)
                note="Schedule: $human (cron: $CRON_SCHEDULE)"
                ;;
        esac
    done
}
# }}}

# {{{ read_folder_and_output
# Reads "[folder] [-o file]" from what follows a command.
read_folder_and_output() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
            --day)
                if ! set_schedule_day "${2:-}"; then
                    echo "--day takes sun..sat, 0-7 or daily, not '${2:-}'" >&2; exit 1
                fi
                shift 2 ;;
            --at)
                if [[ ! "${2:-}" =~ ^([0-9]{1,2}):([0-9]{2})$ ]] \
                    || ! set_schedule_time "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; then
                    echo "--at takes a 24-hour time like 2:00 or 23:30, not '${2:-}'" >&2; exit 1
                fi
                shift 2 ;;
            -*) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
            *) DIR="$1"; FOLDER_GIVEN=1; shift ;;
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
    -I|--interactive)
        shift
        read_folder_and_output "$@"
        interactive_mode
        exit $?
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
