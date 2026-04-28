#!/usr/bin/env bash
# build.sh — Build the 3d-rts game.
#
# What it does, in plain words: compiles the source code into a
# runnable game binary. It can be run from any directory. By default
# it builds the project at the hard-coded path below; passing a
# different path as the first argument builds *that* project instead
# (the mono-repo's standard "DIR override" convention). Any further
# arguments are forwarded to `make` (e.g. `bash build.sh "" run` to
# build and launch using the default DIR).

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"
shift || true

# If the first argument was empty, treat as "use default DIR". This
# pattern lets a caller forward extra make arguments without having
# to repeat the directory.
if [[ -z "${DIR}" ]]; then
	DIR="/mnt/mtwo/programming/ai-stuff/games/3d-rts"
fi

make -C "${DIR}" "$@"
