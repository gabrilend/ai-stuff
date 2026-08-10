#!/usr/bin/env bash
#
# patches.sh — the switchboard for every customization this project makes to
# Xonotic.
#
# The situation this exists to handle: we want to change a piece of software we
# do not own and do not wish to take over. Copying it and editing the copy means
# every future release from its authors arrives as a merge conflict. Editing it
# in place means our changes are silently destroyed the next time we fetch.
#
# So we do neither. The copy under source/ is treated as a disposable build
# artifact, thrown away and re-fetched whenever convenient. What we keep is a
# collection of small scripts, each of which knows how to stamp one change into
# a fresh copy and how to peel that same change back off. Every build stamps
# them on, builds, and peels them off again, so the copy always returns to
# exactly what its authors shipped.
#
# The practical payoff: our changes are individually named and individually
# reversible, a new release from upstream costs a re-fetch instead of a
# negotiation, and any change that upstream has since adopted on their own is
# reported to us as redundant rather than quietly rotting.
#
# This file is sourced, not run. It finds the patch scripts, declares which of
# them each build variant wants, and defines the drivers that walk those lists.

# {{{ paths
# Hard-coded default so any script can source this from any working directory.
# Override by exporting DIR before sourcing.
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/xonotic-turning-radius}"

# The two upstream trees. They are separate projects with separate histories:
# the engine is the C program that draws the world and reads the keyboard; the
# data tree holds the game's own code, written in QuakeC, plus its config files.
SRC_ENGINE="${DIR}/source/darkplaces"
SRC_DATA="${DIR}/source/xonotic-data.pk3dir"

# Every tree the reset and audit drivers walk. Adding a third upstream means
# adding it here and nowhere else.
SRC_TREES=("${SRC_ENGINE}" "${SRC_DATA}")

PATCHES_DIR="${DIR}/patches"
# }}}

# {{{ auto-registration
# Sourcing a patch file defines its three functions, which IS its registration.
# There is deliberately no manifest listing which files exist: a manifest is a
# second place to update, and a second place to update is a place to forget.
for _patch_file in "${PATCHES_DIR}"/P[0-9][0-9][0-9]-*.sh; do
    [[ -f "${_patch_file}" ]] && source "${_patch_file}"
done
for _patch_file in "${PATCHES_DIR}"/I[0-9][0-9][0-9]-*.sh; do
    [[ -f "${_patch_file}" ]] && source "${_patch_file}"
done
unset _patch_file
# }}}

# {{{ profile selection
# The one genuinely declarative input in the system: which changes each build
# variant wants. Kept as data so it can be read and diffed, rather than as a
# sequence of calls buried in a driver.
#
#   layout-only  the keyboard layout and nothing else. Runs on a stock,
#                unmodified Xonotic install. This is the variant that proves
#                the layout is worth having before any code is written.
#   standard     the layout plus the menu switch that applies it.
#   full         everything, including the turning mechanics.
declare -A PREBUILD_PATCHES=(
    ["layout-only"]="P001"
    ["standard"]="P001"
    ["full"]="P001"
)

declare -A INSTALL_PATCHES=(
    ["layout-only"]=""
    ["standard"]=""
    ["full"]=""
)

# Read from a file rather than passed as a flag, so that forgetting the flag is
# not a way to silently build the wrong thing.
PROFILE="${PROFILE:-$([[ -f "${DIR}/.profile" ]] && cat "${DIR}/.profile" || echo "layout-only")}"
# }}}

# {{{ reset_source_trees()
# Drives every upstream tree back to the commit it was fetched at.
#
# Wired as an unconditional pre-flight at every entry point, never as "only if
# something looks wrong". Running it always is the whole point: it makes a clean
# starting tree a guarantee instead of a hope, and it is the only thing that
# recovers from a build killed by a signal that took the cleanup handler with it.
#
# It goes to a commit, so unlike the unapply driver it cannot invent changes
# that were never ours.
reset_source_trees() {
    local tree
    for tree in "${SRC_TREES[@]}"; do
        if [[ ! -d "${tree}/.git" ]]; then
            echo "ERROR: ${tree} is not a checkout. Run scripts/redownload-source." >&2
            return 1
        fi
        git -C "${tree}" reset --hard HEAD --quiet
        # Untracked files are ours by definition: upstream cannot have left any
        # in a freshly-reset tree. Patches that CREATE files (rather than edit
        # them) leave exactly this kind of residue if their inverse failed.
        git -C "${tree}" clean -fdq
    done
}
# }}}

# {{{ tree_fingerprint()
# A cheap description of everything modified across all trees, used to tell
# whether an individual patch actually changed anything. Comparing this before
# and after a call is what lets the unapply driver report facts instead of
# assumptions.
tree_fingerprint() {
    local tree
    for tree in "${SRC_TREES[@]}"; do
        [[ -d "${tree}/.git" ]] && git -C "${tree}" status --porcelain
    done
}
# }}}

# {{{ patch_function_for()
# Finds the function implementing one patch, by convention rather than by
# lookup table. The naming convention IS the registry, so a patch cannot be
# defined but unregistered.
#
#   $1  the prefix: patch, unpatch, or patch_needs_applying
#   $2  the identifier, e.g. P001
patch_function_for() {
    local prefix="$1" id="$2"
    declare -F | sed 's/^declare -f //' | grep -m1 "^${prefix}_${id}"
}
# }}}

# {{{ apply_patches_prebuild()
# Stamps every change the active profile wants into the source trees.
apply_patches_prebuild() {
    local id fn applied=0
    for id in ${PREBUILD_PATCHES[${PROFILE}]:-}; do
        fn="$(patch_function_for "patch" "${id}")"
        if [[ -z "${fn}" ]]; then
            # A profile naming a patch that does not exist is a typo, and a typo
            # that silently applies fewer changes than intended is the worst
            # possible outcome. Refuse rather than continue.
            echo "ERROR: profile '${PROFILE}' lists ${id}, which no patch file defines." >&2
            return 1
        fi
        "${fn}"
        echo "  [${id}] applied"
        applied=$((applied + 1))
    done
    echo "${applied} patch(es) applied for profile '${PROFILE}'."
}
# }}}

# {{{ unapply_patches_prebuild()
# Peels every change back off, in reverse order, so that patches which happen to
# touch the same region unwind in the opposite order they were laid down.
#
# Reporting is computed, not narrated: each inverse is bracketed by a snapshot
# of what version control considers modified, and a patch is only reported as
# reverted if that snapshot actually changed. "Nothing reverted" therefore means
# something, rather than being a guess.
unapply_patches_prebuild() {
    local id fn before after reverted=0 noop=0
    local ids=(${PREBUILD_PATCHES[${PROFILE}]:-})
    local i
    for (( i=${#ids[@]}-1 ; i>=0 ; i-- )); do
        id="${ids[i]}"
        fn="$(patch_function_for "unpatch" "${id}")"
        [[ -z "${fn}" ]] && continue
        before="$(tree_fingerprint)"
        "${fn}"
        after="$(tree_fingerprint)"
        if [[ "${before}" != "${after}" ]]; then
            echo "  [${id}] reverted"
            reverted=$((reverted + 1))
        else
            noop=$((noop + 1))
        fi
    done
    echo "${reverted} reverted, ${noop} already clean."
}
# }}}

# {{{ patches_need_applying()
# Asks every patch's own probe whether it is currently absent. Used by the
# build to skip work that is already done, and by the dry run to report what
# would happen without doing it.
patches_need_applying() {
    local id fn
    for id in ${PREBUILD_PATCHES[${PROFILE}]:-}; do
        fn="$(patch_function_for "patch_needs_applying" "${id}")"
        [[ -z "${fn}" ]] && continue
        if "${fn}"; then
            return 0
        fi
    done
    return 1
}
# }}}

# {{{ list_all_patch_ids()
# Every patch that exists on disk, regardless of which profile selects it. The
# registry generator and the auditor want all of them; the drivers want only
# the active selection.
list_all_patch_ids() {
    local f base
    for f in "${PATCHES_DIR}"/[PI][0-9][0-9][0-9]-*.sh; do
        [[ -f "${f}" ]] || continue
        base="$(basename "${f}")"
        echo "${base%%-*}"
    done
}
# }}}
