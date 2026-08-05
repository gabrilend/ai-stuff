#!/bin/bash
# =============================================================================
# carry-back.sh - move commits out of a sandbox and onto the disk
# =============================================================================
#
# WHAT THIS IS, IN PLAIN TERMS
#
# A sandbox built by init-project.sh lives in RAM, which means the machine
# losing power erases it. This script is the thing that stops that mattering.
# It watches a sandbox's branch, and the moment a commit appears there, copies
# that commit into the real repository on disk. Work becomes permanent at the
# instant it is committed, and the volatility of RAM stops being a risk and
# becomes merely a property.
#
# THE ONE DESIGN DECISION WORTH KNOWING
#
# The traffic runs one way: the real repository *pulls from* the sandbox. The
# sandbox is never given a route out.
#
# This is what preserves the isolation. Had the sandbox pushed instead, it
# would need a writable handle on the real repository, and that handle would be
# a hole straight through the wall the sandbox exists to provide - anything
# running inside could reach through it. By inverting the direction, everything
# that touches the real repository runs out here, on the safe side, and the
# thing being read has no idea it is being read.
#
# The same commits arrive either way. Only the direction of trust differs, and
# the direction of trust is the whole security argument.
#
# HOW A COMMIT LANDS
#
# Three steps, and the middle one is the interesting one.
#
#   1. Fetch the sandbox's branch into a staging ref. Not into the branch
#      itself: git flatly refuses to fetch into a branch that is checked out
#      somewhere, and the real repository always has its branch checked out.
#      A staging ref sidesteps that, and it is also the safety property that
#      matters most - once the fetch completes the commit is on disk, durable,
#      before anything has been decided about the working tree.
#
#   2. Fast-forward the real branch to the staging ref, but only if the real
#      working tree is clean. A dirty tree means somebody is mid-edit out here,
#      and moving the branch under them would be rude at best.
#
#   3. Report. Silence would be indistinguishable from a broken watcher.
#
# If step 2 is declined the commit is still saved from step 1. Nothing is ever
# lost by a dirty tree; the visible update simply waits.
#
# USAGE
#
#   carry-back.sh <project>            watch continuously (the usual mode)
#   carry-back.sh --once <project>     carry whatever is pending, then stop
#   carry-back.sh --status <project>   report without changing anything
#   carry-back.sh --interval <n> ...   seconds between checks, default 5
#   carry-back.sh --dir <path> ...     operate on a different monorepo
#   carry-back.sh --help
# =============================================================================

set -o errexit
set -o nounset
set -o pipefail

# --- Configuration -----------------------------------------------------------
# DIR is the monorepo root; every other path derives from it, so this script
# runs correctly from any working directory.
DIR="/mnt/mtwo/programming/ai-stuff"
SANDBOX_ROOT="/tmp/claude-sandbox"
POLL_INTERVAL=5

# --- Runtime state -----------------------------------------------------------
PROJECT_NAME=""
SANDBOX_PATH=""
SANDBOX_BRANCH=""
STAGING_REF=""
MODE="watch"

# {{{ print_usage()
print_usage() {
    cat <<'USAGE'
carry-back.sh - move commits out of a RAM sandbox and onto the disk

  carry-back.sh <project>
      Watch the project's sandbox and carry every commit to the real
      repository as it appears. Runs until interrupted.

  carry-back.sh --once <project>
      Carry anything currently pending, then exit. Useful before shutting
      the machine down, or from a script.

  carry-back.sh --status <project>
      Say what is pending and whether it could be carried right now.
      Changes nothing.

  carry-back.sh --interval <seconds> <project>
      How often to look. Default 5.

  carry-back.sh --dir <path> <project>
      Operate against a different monorepo root. For testing.

Commits are pulled by the real repository; the sandbox is never given a route
out. A commit reaches the disk as soon as it is made, even if the real working
tree is too dirty to update visibly.
USAGE
}
# }}}

# {{{ fail()
fail() {
    printf 'carry-back: %s\n' "$1" >&2
    exit 1
}
# }}}

# {{{ announce()
# Timestamped so a long-running watcher's output reads as a log rather than a
# puddle of identical lines.
announce() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}
# }}}

# {{{ parse_arguments()
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) print_usage; exit 0 ;;
            --once)    MODE="once"; shift ;;
            --status)  MODE="status"; shift ;;
            --interval)
                [ $# -ge 2 ] || fail "--interval needs a number of seconds"
                POLL_INTERVAL="$2"
                shift 2
                ;;
            --dir)
                [ $# -ge 2 ] || fail "--dir needs a path"
                DIR="$2"
                shift 2
                ;;
            -*) fail "unknown option: $1" ;;
            *)
                [ -z "${PROJECT_NAME}" ] || fail "more than one project named: ${PROJECT_NAME}, $1"
                PROJECT_NAME="$1"
                shift
                ;;
        esac
    done

    [ -n "${PROJECT_NAME}" ] || { print_usage; exit 1; }

    SANDBOX_PATH="${SANDBOX_ROOT}/${PROJECT_NAME}"
    [ -d "${SANDBOX_PATH}/.git" ] \
        || fail "no sandbox repository at ${SANDBOX_PATH}
       Build one with: init-project.sh --refresh ${PROJECT_NAME}"

    # The branch is read from the sandbox rather than assumed, so that a
    # sandbox created with --branch is followed correctly without having to
    # repeat the choice here and keep the two in step by hand.
    SANDBOX_BRANCH=$(git -C "${SANDBOX_PATH}" symbolic-ref --short HEAD)

    # Each project gets its own staging ref. They must not share one, or two
    # watchers running at once would overwrite each other's landing ground and
    # the loser's commit would appear to have been carried when it had not.
    STAGING_REF="refs/carried/${PROJECT_NAME}"
}
# }}}

# {{{ sandbox_head()
sandbox_head() {
    git -C "${SANDBOX_PATH}" rev-parse HEAD
}
# }}}

# {{{ pending_commits()
# What the sandbox has that the real repository does not. Empty means nothing
# to do; this is the question the watcher asks on every tick, so it stays
# cheap - two ref lookups and a revision walk, no working tree involved.
pending_commits() {
    # Where the real repository currently stands. The sandbox can be asked
    # about this commit directly, even though it was made out here and never
    # fetched in: the sandbox borrows the real object store, so every object
    # the real repository has is already visible from inside. That is what
    # makes a one-line revision walk sufficient to answer the question.
    local real_head
    real_head=$(git -C "${DIR}" rev-parse --verify --quiet "${SANDBOX_BRANCH}" \
        || git -C "${DIR}" rev-parse --verify --quiet master)

    git -C "${SANDBOX_PATH}" log --oneline "${real_head}..HEAD" 2>/dev/null
}
# }}}

# {{{ real_tree_is_clean()
# Whether the real repository can have its branch moved without disturbing
# anybody. Ignored files do not count - the monorepo is full of them by design,
# and treating build output as a reason to refuse would mean refusing always.
real_tree_is_clean() {
    [ -z "$(git -C "${DIR}" status --porcelain --untracked-files=no)" ]
}
# }}}

# {{{ clear_duplicate_blockers()
# Removes untracked files that would block the fast-forward, but only the ones
# that are byte-for-byte identical to what is arriving.
#
# The situation this exists for: a file is created on disk untracked - a
# project skeleton, a generated document - and the sandbox then commits the
# same path. Git refuses to fast-forward over an untracked file, because it
# cannot know whether that file is precious. Content answers the question it
# cannot ask. Identical bytes mean the file is a duplicate of what is arriving
# and deleting it loses nothing; different bytes mean two people wrote the same
# filename with different intent, which is a real conflict and stays untouched.
#
# Returns failure if any genuine conflict was found, having reported it.
clear_duplicate_blockers() {
    local -a conflicts=()
    local -a incoming=()
    mapfile -t incoming < <(git -C "${DIR}" diff --name-only HEAD "${STAGING_REF}")

    local path disk_hash incoming_hash
    for path in ${incoming[@]+"${incoming[@]}"}; do
        [ -f "${DIR}/${path}" ] || continue

        # A tracked file is git's problem, not ours; the merge handles it.
        if git -C "${DIR}" ls-files --error-unmatch "${path}" >/dev/null 2>&1; then
            continue
        fi

        disk_hash=$(git -C "${DIR}" hash-object "${DIR}/${path}")
        incoming_hash=$(git -C "${DIR}" rev-parse "${STAGING_REF}:${path}" 2>/dev/null || echo "")

        if [ "${disk_hash}" = "${incoming_hash}" ]; then
            rm -f "${DIR}/${path}"
        else
            conflicts+=("${path}")
        fi
    done

    if [ "${#conflicts[@]}" -gt 0 ]; then
        announce "untracked files on disk differ from the incoming versions:"
        for path in "${conflicts[@]}"; do
            announce "    ${path}"
        done
        announce "  the commits are safe at ${STAGING_REF}. Move or delete those"
        announce "  files, then run --once to finish carrying."
        return 1
    fi

    return 0
}
# }}}

# {{{ carry()
# One carry cycle. Returns success if anything was moved.
#
# The two steps are deliberately separable: the fetch is unconditional and
# always safe, while the fast-forward is conditional and cosmetic. Work becomes
# durable in step one. Step two only decides whether you can see it yet.
carry() {
    local pending
    pending=$(pending_commits)

    if [ -z "${pending}" ]; then
        return 1
    fi

    local count
    count=$(printf '%s\n' "${pending}" | wc -l)
    announce "${count} commit(s) pending in the sandbox"

    # Step one: get it onto the disk. Nothing about the working tree can
    # prevent this, which is the point - durability must not depend on the
    # state somebody else left their editor in.
    git -C "${DIR}" fetch --quiet "${SANDBOX_PATH}" \
        "+${SANDBOX_BRANCH}:${STAGING_REF}"
    announce "saved to disk at ${STAGING_REF} - safe from reboot now"

    # Step two: make it visible, if that can be done without stepping on
    # anyone. A refusal here is not a failure; the work is already safe.
    if ! real_tree_is_clean; then
        announce "real working tree has uncommitted edits - not moving ${SANDBOX_BRANCH}."
        announce "  the commits are on disk and will appear once it is clean;"
        announce "  finish or stash out here, then run --once to catch up."
        return 0
    fi

    local current_branch
    current_branch=$(git -C "${DIR}" symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "${current_branch}" != "${SANDBOX_BRANCH}" ]; then
        announce "real repository is on '${current_branch}', sandbox is on '${SANDBOX_BRANCH}'."
        announce "  the commits are on disk; check out ${SANDBOX_BRANCH} and run --once."
        return 0
    fi

    # Untracked duplicates on disk would otherwise stop the fast-forward for a
    # reason that has nothing to do with the history being wrong.
    if ! clear_duplicate_blockers; then
        return 0
    fi

    # --ff-only rather than a merge. If these have diverged, something happened
    # that a script should not paper over - somebody committed on both sides,
    # or history was rewritten - and quietly creating a merge commit would hide
    # a situation a person needs to look at.
    local merge_output
    if merge_output=$(git -C "${DIR}" merge --ff-only "${STAGING_REF}" 2>&1); then
        announce "carried into ${SANDBOX_BRANCH}; the project directory now shows it"
    else
        announce "cannot fast-forward ${SANDBOX_BRANCH}:"
        printf '%s\n' "${merge_output}" | sed 's/^/             /'
        announce "  the commits are on disk at ${STAGING_REF} and are not lost."
    fi

    return 0
}
# }}}

# {{{ report_status()
report_status() {
    local pending
    pending=$(pending_commits)

    printf '  project   %s\n' "${PROJECT_NAME}"
    printf '  sandbox   %s\n' "${SANDBOX_PATH}"
    printf '  branch    %s\n' "${SANDBOX_BRANCH}"

    if [ -z "${pending}" ]; then
        printf '  pending   nothing - the disk has everything the sandbox has\n'
    else
        printf '  pending   %s commit(s):\n' "$(printf '%s\n' "${pending}" | wc -l)"
        printf '%s\n' "${pending}" | sed 's/^/              /'
    fi

    if real_tree_is_clean; then
        printf '  real tree clean - a carry would land visibly\n'
    else
        printf '  real tree has uncommitted edits - a carry would save to disk\n'
        printf '            but wait before moving the branch\n'
    fi
}
# }}}

# {{{ watch_forever()
# Polls rather than using inotify. The check is two ref reads and a revision
# walk - cheap enough that five-second polling costs nothing measurable, and
# polling has the advantage of recovering by itself if the sandbox is destroyed
# and rebuilt underneath us, which watches on a vanished directory do not.
watch_forever() {
    announce "watching ${PROJECT_NAME} (${SANDBOX_BRANCH}), checking every ${POLL_INTERVAL}s"
    announce "commits made in the sandbox will reach the disk within ${POLL_INTERVAL}s"

    local last_seen=""
    local current
    while true; do
        if [ ! -d "${SANDBOX_PATH}/.git" ]; then
            # The sandbox went away - rebooted, or refreshed out from under us.
            # Waiting is right: init-project.sh rebuilds it, and a watcher that
            # exited would have to be remembered and restarted by a human.
            announce "sandbox is gone; waiting for it to come back"
            last_seen=""
            sleep "${POLL_INTERVAL}"
            continue
        fi

        current=$(sandbox_head 2>/dev/null || echo "")
        if [ -n "${current}" ] && [ "${current}" != "${last_seen}" ]; then
            carry || true
            last_seen="${current}"
        fi

        sleep "${POLL_INTERVAL}"
    done
}
# }}}

# {{{ main()
main() {
    parse_arguments "$@"

    [ -d "${DIR}/.git" ] || fail "not a git repository: ${DIR}"

    case "${MODE}" in
        status) report_status ;;
        once)   carry || announce "nothing pending" ;;
        watch)  watch_forever ;;
    esac
}
# }}}

main "$@"
