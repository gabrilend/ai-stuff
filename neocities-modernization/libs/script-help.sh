# script-help.sh: --help for every bash script, from the script's own header.
#
# Every script opens with a comment saying what it is and how to run it (a
# house rule), so that comment is its help. A script sources this file and
# calls script_help "$0" "$@" before it does anything else; given --help or -h
# it prints the header and exits. The reading is done by libs/script-help.lua,
# so Lua and bash scripts show their help the same way.
#
#   source "$(dirname "$(readlink -f "$0")")/../libs/script-help.sh"
#   script_help "$0" "$@"

# {{{ script_help
script_help() {
    local script="$1"
    shift
    local a
    for a in "$@"; do
        if [ "$a" = "--help" ] || [ "$a" = "-h" ]; then
            local here
            here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
            # the Lua arrives on standard input: "luajit -e CODE ARGS" would
            # read the first argument as a script to run
            luajit - "$here/script-help.lua" "$script" <<'LUA'
io.write(dofile(arg[1]).header(arg[2]), "\n")
LUA
            exit $?
        fi
    done
}
# }}}
