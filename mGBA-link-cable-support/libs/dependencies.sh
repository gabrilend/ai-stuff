#!/usr/bin/env bash
# dependencies.sh — the libraries mGBA needs that this machine does not already have.
#
# The emulator links against a handful of outside libraries: compression, image
# decoding, audio and video. A distribution normally supplies these, but relying on
# that makes the build a question about which machine you happen to be standing at.
# So this directory carries its own: anything missing is downloaded as source next to
# the emulator's own source, compiled, and installed into a private prefix that only
# this project ever looks in. Nothing is installed system-wide and nothing needs root.
#
# A library already present on the machine is left alone. That is what keeps the
# first build from taking an hour — on a well-stocked machine most of this does
# nothing at all, and the probe that decides is a question asked of pkg-config rather
# than an assumption written down here.
#
# Adding a library means dropping a file D001-name.sh into this directory defining:
#
#   dep_D001_name_present   succeeds when the library is already usable
#   dep_D001_name_fetch     downloads or updates its source into libs/source/
#   dep_D001_name_build     compiles it into libs/prefix/
#
# It is picked up by being here. Ordering is by ID, so a library that another one
# links against gets a lower number and is therefore built first.
#
# Callers set LIBS to this directory before sourcing.

LIBS_SOURCE="${LIBS}/source"   # dependency source trees, downloaded by update
LIBS_PREFIX="${LIBS}/prefix"   # dependency build output, produced by install

# Everything downstream — the probes here, and cmake when it goes looking for these
# libraries later — finds our private copies through these two variables. Setting
# them here rather than in each script means there is one answer to "where do our
# libraries live", and the probe cannot disagree with the compiler about it.
export PKG_CONFIG_PATH="${LIBS_PREFIX}/lib/pkgconfig:${LIBS_PREFIX}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="${LIBS_PREFIX}:${CMAKE_PREFIX_PATH:-}"

for dep_file in "${LIBS}"/D[0-9][0-9][0-9]-*.sh; do
    if [[ -f "${dep_file}" ]]; then
        source "${dep_file}"
    fi
done

# {{{ dependency_ids()
# The declared fetch functions are the register of what exists; a library is part of
# the build because its file is in this directory, not because a list somewhere says so.
dependency_ids() {
    declare -F | sed -n 's/^declare -f dep_\(D[0-9][0-9][0-9]\)_.*_fetch$/\1/p' | sort
}
# }}}

# {{{ dependency_function()
# Finds the one function for an ID and a role, so callers never have to spell out a
# library's full name — the ID is enough to reach all three of its functions.
dependency_function() {
    declare -F | sed -n "s/^declare -f \(dep_$1_.*_$2\)$/\1/p" | head -1
}
# }}}

# {{{ dependency_name()
dependency_name() {
    local fn
    fn="$(dependency_function "$1" fetch)"
    fn="${fn#dep_$1_}"
    echo "${fn%_fetch}"
}
# }}}

# {{{ fetch_dependencies()
# Runs during update, alongside the emulator's own download, so that everything the
# build will need is on disk before the build starts. A library the machine already
# supplies is not downloaded at all — there would be nothing to do with it later.
fetch_dependencies() {
    local id name count=0
    mkdir -p "${LIBS_SOURCE}"
    for id in $(dependency_ids); do
        name="$(dependency_name "${id}")"
        if "$(dependency_function "${id}" present)"; then
            echo "libs: ${name} already on this machine — not downloading"
            continue
        fi
        echo "libs: fetching ${name}"
        "$(dependency_function "${id}" fetch)"
        count=$((count + 1))
    done
    echo "libs: ${count} dependency source tree(s) downloaded or updated"
}
# }}}

# {{{ build_dependencies()
# Runs during install, before the emulator is configured, because cmake decides which
# features to compile in by looking for these libraries — arriving late is the same as
# not arriving at all. The probe is re-asked here rather than remembered from update:
# a library installed by the package manager in between should be used, not rebuilt.
build_dependencies() {
    local id name count=0
    mkdir -p "${LIBS_PREFIX}"
    for id in $(dependency_ids); do
        name="$(dependency_name "${id}")"
        if "$(dependency_function "${id}" present)"; then
            echo "libs: ${name} already usable — not building"
            continue
        fi
        if [[ ! -d "${LIBS_SOURCE}/${name}" ]]; then
            echo "libs: ${name} is missing and its source was never downloaded. Run ./update first." >&2
            return 1
        fi
        echo "libs: building ${name}"
        "$(dependency_function "${id}" build)"
        # Asking again closes the gap between "the build command exited zero" and "the
        # library is actually usable" — a compile can succeed and still install its
        # description file somewhere the compiler will never look.
        if ! "$(dependency_function "${id}" present)"; then
            echo "libs: ${name} built but is still not usable; check ${LIBS_PREFIX}." >&2
            return 1
        fi
        count=$((count + 1))
    done
    echo "libs: ${count} dependency/dependencies built into ${LIBS_PREFIX}"
}
# }}}
