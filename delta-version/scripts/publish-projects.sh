#!/bin/bash
# publish-projects.sh - shows which projects outside the main ai-stuff folder
# would be pushed, and pushes them only when the configuration says so.
#
# In plain terms: config/external-projects.conf lists extra folders that hold
# projects (issue 024). Each project found there stays on this machine unless
# the [publishable] section names it. For every project this prints whether
# it may be published, which remote and branch it tracks, how many commits
# are waiting, and the exact command that would push them. Nothing is pushed
# until [publishing] push is turned on, and even then only listed projects
# are pushed. Projects in the main folder are not handled here: they are
# published with the monorepo itself. (Issue 039: listed roots instead of a
# whole-disk search, opt-in pushing, no symlinks.)
#
# Usage:
#   publish-projects.sh                  preview every extra root's projects
#   publish-projects.sh --dir DIR        the monorepo whose delta-version/config
#                                        is read (default below)
#   publish-projects.sh --config-dir D   read D/external-projects.conf instead
#   publish-projects.sh --help
#
# The commit counts read the local remote-tracking branches; nothing is
# fetched, so a count is as fresh as the project's last fetch.
#
# Exit status: 0 when every push asked for succeeded (or none was asked
# for), 1 when a push failed, 2 on a usage error.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -- {{{ show_help
function show_help() {
    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)
                [[ -n "${2:-}" ]] || { echo "--dir needs a folder" >&2; exit 2; }
                DIR="$2"
                export DELTA_CONFIG_DIR="${DELTA_CONFIG_DIR:-$DIR/delta-version/config}"
                shift 2 ;;
            --config-dir)
                [[ -n "${2:-}" ]] || { echo "--config-dir needs a folder" >&2; exit 2; }
                export DELTA_CONFIG_DIR="$2"; shift 2 ;;
            --help|-h)
                show_help; exit 0 ;;
            *)
                echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
        esac
    done
}
# }}}

# -- {{{ project_push_plan
function project_push_plan() {
    # Prints "state|remote|branch|upstream branch|commits" for one project,
    # separated by the ASCII unit separator (0x1f) rather than tabs: read
    # would merge a run of tabs and shift the empty fields. state is one of: no-git, not-own-repository,
    # detached, no-upstream, up-to-date, ahead.
    local project="$1" top branch upstream remote merge ahead
    if ! git -C "$project" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        printf $'no-git\x1f\x1f\x1f\x1f0\n'; return
    fi
    top="$(cd "$(git -C "$project" rev-parse --show-toplevel)" && pwd -P)"
    if [[ "$top" != "$(cd "$project" && pwd -P)" ]]; then
        # Pushing here would push the enclosing repository, not this project.
        printf $'not-own-repository\x1f\x1f\x1f\x1f0\n'; return
    fi
    branch="$(git -C "$project" symbolic-ref --quiet --short HEAD 2>/dev/null)"
    if [[ -z "$branch" ]]; then
        printf $'detached\x1f\x1f\x1f\x1f0\n'; return
    fi
    remote="$(git -C "$project" config "branch.$branch.remote" 2>/dev/null)"
    merge="$(git -C "$project" config "branch.$branch.merge" 2>/dev/null)"
    upstream="$(git -C "$project" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
    if [[ -z "$remote" || -z "$merge" || -z "$upstream" ]]; then
        printf $'no-upstream\x1f\x1f%s\x1f\x1f0\n' "$branch"; return
    fi
    ahead="$(git -C "$project" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if [[ "$ahead" -eq 0 ]]; then
        printf $'up-to-date\x1f%s\x1f%s\x1f%s\x1f0\n' "$remote" "$branch" "${merge#refs/heads/}"
    else
        printf $'ahead\x1f%s\x1f%s\x1f%s\x1f%s\n' "$remote" "$branch" "${merge#refs/heads/}" "$ahead"
    fi
}
# }}}

# -- {{{ push_command
function push_command() {
    # The one command that pushes a project's branch to its upstream.
    local project="$1" remote="$2" branch="$3" target="$4"
    printf 'git -C %q push %q %q\n' "$project" "$remote" "$branch:$target"
}
# }}}

# -- {{{ report_project
function report_project() {
    # One project's lines. Returns 1 when a push was made and failed.
    local key="$1" project="$2" pushing="$3"
    local publishable state remote branch target ahead command
    publishable="$(project_publishable "$project")"
    IFS=$'\x1f' read -r state remote branch target ahead < <(project_push_plan "$project")

    echo "  $key  ($project)"
    if [[ "$publishable" != "yes" ]]; then
        echo "    kept local: not listed as publishable"
        if [[ "$state" == "ahead" ]]; then
            echo "    note: $ahead commit(s) for $remote/$target are never pushed from here"
        fi
        return 0
    fi
    case "$state" in
        no-git)             echo "    publishable, but not a git repository: nothing to push" ;;
        not-own-repository) echo "    publishable, but it lives inside another repository: pushing would push that one, so it is skipped" ;;
        detached)           echo "    publishable, but not on a branch: nothing to push" ;;
        no-upstream)        echo "    publishable, but branch $branch tracks no remote: nothing to push" ;;
        up-to-date)         echo "    publishable; $branch matches $remote/$target as of the last fetch" ;;
        ahead)
            command="$(push_command "$project" "$remote" "$branch" "$target")"
            if [[ "$pushing" == true ]]; then
                echo "    pushing $ahead commit(s): $command"
                if git -C "$project" push --quiet "$remote" "$branch:$target"; then
                    echo "    pushed"
                else
                    echo "    push FAILED"
                    return 1
                fi
            else
                echo "    would push $ahead commit(s):"
                echo "      $command"
            fi
            ;;
    esac
    return 0
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    # shellcheck source=libs/publishable.sh
    source "$SCRIPT_DIR/libs/publishable.sh"
    # shellcheck source=list-projects.sh
    source "$SCRIPT_DIR/list-projects.sh"

    local pushing=false failed=0 roots=0 projects=0 name root project
    publishable_is_on "$(publishable_setting "publishing" "push" "off")" && pushing=true

    echo "Projects outside the main folder ($(publishable_config_file)):"
    if [[ "$pushing" == true ]]; then
        echo "  [publishing] push is on: listed projects with waiting commits are pushed."
    else
        echo "  Preview only. Set push = on under [publishing] to push the listed projects."
    fi
    echo ""

    while IFS=$'\x1f' read -r name root; do
        roots=$((roots + 1))
        while IFS= read -r project; do
            [[ -z "$project" ]] && continue
            projects=$((projects + 1))
            report_project "$name/$(basename "$project")" "$project" "$pushing" || failed=1
        done < <(DIR="$root" get_project_list_for_integration "abs-paths" "$root")
    done < <(publishable_roots)

    if [[ "$roots" -eq 0 ]]; then
        echo "  No extra roots are configured, or none of them exists."
    elif [[ "$projects" -eq 0 ]]; then
        echo "  The extra roots hold no projects."
    fi
    return "$failed"
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
