#!/bin/bash
# publishable.sh - which projects may be pushed, read from the external
# projects configuration.
#
# In plain terms: projects in the main ai-stuff folder are published with the
# monorepo. Projects found under the extra roots listed in
# config/external-projects.conf stay on this machine unless the [publishable]
# section names them. A project nobody listed is never pushed: forgetting to
# list one keeps it private, never the other way round (issue 039).
#
# Source this file; it defines functions only. The configuration file is
# ${DELTA_CONFIG_DIR:-<delta-version>/config}/external-projects.conf, the same
# one list-projects.sh reads.
#
#   publishable_config_file       -- the configuration file's path
#   publishable_setting S K D     -- key K in section [S], or D when absent
#   publishable_roots             -- "name<US>path" per configured extra root,
#                                    US being the unit separator 0x1f
#   publishable_is_on VALUE       -- true for on, yes, true or 1
#   project_publishable PATH      -- prints main, yes or no for a project path
#   project_publishable_key PATH  -- prints "root-name/project" for an extra
#                                    root's project, or nothing

PUBLISHABLE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -- {{{ publishable_config_file
function publishable_config_file() {
    local config_dir="${DELTA_CONFIG_DIR:-$(dirname "$(dirname "$PUBLISHABLE_LIB_DIR")")/config}"
    echo "$config_dir/external-projects.conf"
}
# }}}

# -- {{{ publishable_trim
function publishable_trim() {
    local text="$1"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    printf '%s' "$text"
}
# }}}

# -- {{{ publishable_section_lines
function publishable_section_lines() {
    # Prints "key<US>value" for every key=value line in section [$1]. The
    # unit separator (0x1f), unlike a tab, keeps an empty field when read.
    local wanted="$1" config_file line in_section=false key value
    config_file="$(publishable_config_file)"
    [[ -f "$config_file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
            [[ "${BASH_REMATCH[1]}" == "$wanted" ]] && in_section=true || in_section=false
            continue
        fi
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="$(publishable_trim "${BASH_REMATCH[1]}")"
            value="$(publishable_trim "${BASH_REMATCH[2]}")"
            printf $'%s\x1f%s\n' "$key" "$value"
        fi
    done < "$config_file"
}
# }}}

# -- {{{ publishable_setting
function publishable_setting() {
    local section="$1" key="$2" default="${3:-}" found_key found_value
    while IFS=$'\x1f' read -r found_key found_value; do
        if [[ "$found_key" == "$key" ]]; then
            printf '%s\n' "$found_value"
            return 0
        fi
    done < <(publishable_section_lines "$section")
    printf '%s\n' "$default"
}
# }}}

# -- {{{ publishable_is_on
function publishable_is_on() {
    case "${1,,}" in
        on|yes|true|1) return 0 ;;
        *) return 1 ;;
    esac
}
# }}}

# -- {{{ publishable_roots
function publishable_roots() {
    # Configured extra roots that exist, as "name<US>absolute path". A root
    # given as a relative path is skipped with a warning: it would resolve
    # differently from every working directory.
    local name path
    while IFS=$'\x1f' read -r name path; do
        [[ -z "$path" ]] && continue
        if [[ "$path" != /* ]]; then
            echo "Warning: extra root '$name' ($path) is not an absolute path; skipped" >&2
            continue
        fi
        [[ -d "$path" ]] || continue
        printf $'%s\x1f%s\n' "$name" "${path%/}"
    done < <(publishable_section_lines "external_directories")
}
# }}}

# -- {{{ project_publishable_key
function project_publishable_key() {
    local project="${1%/}" name path
    while IFS=$'\x1f' read -r name path; do
        if [[ "$(dirname "$project")" == "$path" ]]; then
            printf '%s/%s\n' "$name" "$(basename "$project")"
            return 0
        fi
    done < <(publishable_roots)
}
# }}}

# -- {{{ project_publishable
function project_publishable() {
    # main: inside the main root, published with the monorepo.
    # yes:  under an extra root and listed as publishable.
    # no:   under an extra root and not listed, or listed as anything but on.
    local project="${1%/}" key
    key="$(project_publishable_key "$project")"
    if [[ -z "$key" ]]; then
        echo "main"
    elif publishable_is_on "$(publishable_setting "publishable" "$key" "no")"; then
        echo "yes"
    else
        echo "no"
    fi
}
# }}}
