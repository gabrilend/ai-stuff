#!/bin/bash
# install-ticket-hook.sh - put the ticket preview hook into a repository's
# post-commit hook, or take it out again (issue 022).
#
# Nothing installs this for you: run it yourself when you want the hook.
# The hook it installs is a two-line file that calls ticket-hook.sh, which
# previews distributing any ticket template a commit changed and writes
# only if config/ticket-hooks.conf says "write = on" (off as shipped).
#
# An existing post-commit hook that this script did not install is never
# replaced; the script says how to call the ticket hook from it instead.
#
# Usage: install-ticket-hook.sh [--repo PATH] [--uninstall] [--status]
#   --repo       the repository (default /mnt/mtwo/programming/ai-stuff)
#   --uninstall  remove the hook, only if this script installed it
#   --status     say whether it is installed, and change nothing
#
# Exit status: 0 done (or already so), 1 refused (someone else's hook is
# there), 2 usage error or not a git repository.

# {{{ DIR Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/ticket-hook.sh"
MARK="# installed by delta-version/scripts/install-ticket-hook.sh"
ACTION=install
# }}}

# -- {{{ say
function say() { echo "install-ticket-hook: $*"; }
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) DIR="$2"; shift 2 ;;
            --uninstall) ACTION=uninstall; shift ;;
            --status) ACTION=status; shift ;;
            -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) say "unknown argument $1 (see --help)"; exit 2 ;;
        esac
    done
}
# }}}

# -- {{{ hook_path
function hook_path() {
    # Where git looks for this repository's post-commit hook (honours
    # core.hooksPath).
    local hooks
    hooks="$(git -C "$DIR" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" || return 1
    [ -n "$hooks" ] || return 1
    echo "$hooks/post-commit"
}
# }}}

# -- {{{ ours
function ours() {
    [ -f "$1" ] && grep -qxF -- "$MARK" "$1"
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    local hook
    hook="$(hook_path)" || { say "$DIR is not a git repository"; exit 2; }

    case "$ACTION" in
        status)
            if ours "$hook"; then say "installed at $hook"
            elif [ -e "$hook" ]; then say "not installed; $hook is another hook"
            else say "not installed"; fi
            exit 0 ;;
        uninstall)
            if ours "$hook"; then
                rm -f "$hook" && say "removed $hook"
                exit 0
            elif [ -e "$hook" ]; then
                say "$hook was not installed by this script; left alone"
                exit 1
            fi
            say "not installed; nothing to remove"
            exit 0 ;;
    esac

    if ours "$hook"; then
        say "already installed at $hook"
        exit 0
    fi
    if [ -e "$hook" ]; then
        say "$hook already exists and is not the ticket hook; left alone."
        say "To use both, add this line to it:"
        echo "    $(printf '%q' "$HOOK_SCRIPT") || true"
        exit 1
    fi
    mkdir -p "$(dirname "$hook")"
    {
        echo "#!/bin/bash"
        echo "$MARK"
        echo "# Previews filing any ticket template this commit changed; see"
        echo "# delta-version/config/ticket-hooks.conf. Never stops a commit."
        echo "$(printf '%q' "$HOOK_SCRIPT") || true"
    } > "$hook"
    chmod +x "$hook"
    say "installed at $hook (preview only while write = off in ticket-hooks.conf)"
}
# }}}

main "$@"
