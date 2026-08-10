#!/usr/bin/env bash
# patches.sh — every change we make to somebody else's emulator, and how to undo it.
#
# Upstream's code is an ingredient, not ours. It gets downloaded fresh, our changes
# are stamped onto it just long enough to compile, and then they come back off. So a
# change lives here as a matched pair of shell functions — one that makes the edit,
# one that is its exact inverse — instead of as a fork nobody can ever merge again.
#
# Adding a change means dropping a file named P001-some-name.sh into this directory
# that defines patch_P001_some_name and unpatch_P001_some_name. It is picked up by
# being here; there is no separate list to keep in sync and nothing to register.
#
# Every function below assumes the caller has already set SRC to the source tree.

PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcing a patch file is what registers it. The -f test matters because when no
# patch files exist yet the glob stays literal, and a literal pattern is not a file.
for patch_file in "${PATCHES_DIR}"/P[0-9][0-9][0-9]-*.sh; do
    if [[ -f "${patch_file}" ]]; then
        source "${patch_file}"
    fi
done

# {{{ reset_source_tree()
# Drives the tree to upstream's commit rather than trusting that it is already
# there. The hard reset undoes edits to files upstream ships; the clean removes
# files a patch created, which a reset would leave behind as untracked debris.
# Both are safe because we compile out-of-tree — nothing of ours lives in source/.
reset_source_tree() {
    git -C "${SRC}" reset --hard HEAD --quiet
    git -C "${SRC}" clean -qfd
    git -C "${SRC}" submodule foreach --quiet 'git reset --hard HEAD --quiet'
}
# }}}

# {{{ apply_patches()
# Applies in ascending ID order, so a later patch can rely on an earlier one having
# already landed. Nothing to apply is not an error — early in this project it is the
# expected state — but it is said out loud, because a silent no-op here would look
# exactly like a successful patched build while producing a stock emulator.
apply_patches() {
    local fn count=0
    for fn in $(declare -F | sed -n 's/^declare -f \(patch_P[0-9][0-9][0-9]_.*\)$/\1/p' | sort); do
        "${fn}"
        echo "patches: applied ${fn#patch_}"
        count=$((count + 1))
    done
    if [[ ${count} -eq 0 ]]; then
        echo "patches: NOTICE — no patches in ${PATCHES_DIR}, so this build is stock mGBA."
    fi
}
# }}}

# {{{ unapply_patches()
# Reverse order, for the mirror of the reason apply goes forwards: a patch that was
# layered on top of another has to come off before the one underneath it does.
unapply_patches() {
    local fn
    for fn in $(declare -F | sed -n 's/^declare -f \(unpatch_P[0-9][0-9][0-9]_.*\)$/\1/p' | sort -r); do
        "${fn}"
        echo "patches: reverted ${fn#unpatch_}"
    done
}
# }}}
