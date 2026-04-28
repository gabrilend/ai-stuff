#!/usr/bin/env bash
# build.sh — Build everything the 3d-rts game needs, then build the game.
#
# What it does in plain words: ensures every vendored library is at
# the version listed in libs/sources, builds those libraries if they
# are out of date, then builds the game binary. Any extra arguments
# are forwarded to `make` so a caller can do e.g.
# `bash build.sh "" clean` (the empty first arg means "default DIR").
#
# Each step is its own script so the orchestration here stays a
# linear list of steps — easy to read, easy to add to.

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"
shift || true

# Empty first arg means "use default DIR" — lets callers forward
# extra make arguments without having to repeat the directory.
if [[ -z "${DIR}" ]]; then
	DIR="/mnt/mtwo/programming/ai-stuff/games/3d-rts"
fi

DEPS_DIR="${DIR}/scripts/deps"

# Step 1: vendored raylib.
bash "${DEPS_DIR}/fetch-raylib.sh"   "${DIR}"
bash "${DEPS_DIR}/build-raylib.sh"   "${DIR}"

# Step 2: in-tree task-pool (placeholder until threading work lands).
bash "${DEPS_DIR}/build-task-pool.sh" "${DIR}"

# Step 3: the game itself.
make -C "${DIR}" "$@"
