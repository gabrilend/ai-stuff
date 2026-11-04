#!/usr/bin/env bash
# project-dir.sh: every shell program's project folder, read from --dir PATH.
#
# WHAT IT DOES (for a CEO): the shell twin of libs/project-dir.lua. A script
# sources this and hands it its command line; it finds --dir PATH (the one
# way every program now names its project folder, Issue 10-076), keeps the
# script's own flags for the script's own parser, and stops the script on
# any word that is neither a flag nor a flag's value, naming the word -- a
# stray word is usually a flag that lost its dashes.
#
# Use:
#   source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
#   project_dir_read "/default/project" "--jobs --match" "$@"
#   set -- "${PROJECT_ARGS[@]}"     # the script's own flags, in order
#   # $DIR is the project folder
#
# Sourced, not run: its exit stops the script that sourced it, which is the
# point. It sets two globals:
#   DIR           string -- the project folder, without a trailing "/"
#   PROJECT_ARGS  array  -- every other word, in order, --dir and its value removed

# {{{ project_dir_read
# $1    the project folder when --dir is not given (string)
# $2    this script's flags that take a value in the next word, separated by
#       spaces ("--jobs --match"); "" when it has none. A "--flag=value" word
#       needs no entry: it is one word.
# $3... the script's command line
project_dir_read() {
    local default_dir="$1"
    local value_flags=" $2 "
    shift 2
    local program
    program="$(basename "$0")"
    DIR="$default_dir"
    PROJECT_ARGS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --dir)
                # no folder after --dir, or another flag where it belongs:
                # both would otherwise make a nonsense project folder
                if [ $# -lt 2 ] || [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    echo "${program}: --dir needs a folder after it (--dir PATH)" >&2
                    exit 1
                fi
                DIR="$2"
                shift 2
                ;;
            --dir=*)
                DIR="${1#*=}"
                if [ -z "$DIR" ]; then
                    echo "${program}: --dir= needs a folder after the '='" >&2
                    exit 1
                fi
                shift
                ;;
            -*)
                # a flag of the script's own, kept with its value when it is
                # one that takes the next word
                PROJECT_ARGS+=("$1")
                if [[ "$value_flags" == *" $1 "* ]] && [ $# -ge 2 ]; then
                    PROJECT_ARGS+=("$2")
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                # a word with no flag in front of it: the mistake this exists to catch
                echo "${program}: unexpected word on the command line: $1" >&2
                echo "  every value follows its flag, and the project folder is --dir PATH" >&2
                exit 1
                ;;
        esac
    done
    # one trailing "/" or more is dropped, so "$DIR/x" never doubles it
    while [ "${#DIR}" -gt 1 ] && [ "${DIR%/}" != "$DIR" ]; do
        DIR="${DIR%/}"
    done
}
# }}}
