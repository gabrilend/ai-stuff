#!/usr/bin/env bash
# build-task-pool.sh — Placeholder for the in-flight task-pool library.
#
# What it does in plain words: nothing yet. The threading work is
# being developed elsewhere in the repo; once libs/900-task-pool.{c,h}
# stabilises and the project decides to build it as a separate
# library (or bake it into the game build), the logic goes here.
#
# Until then this script is a no-op so that scripts/build.sh can call
# it unconditionally without conditionals — the existence of the call
# site documents the intent and the script body documents the gap.

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"

if [[ -f "${DIR}/libs/900-task-pool.c" || -f "${DIR}/libs/900-task-pool.h" ]]; then
	echo "build-task-pool: source detected at ${DIR}/libs/900-task-pool.* — build still TODO."
else
	echo "build-task-pool: no source yet, nothing to do."
fi

exit 0
