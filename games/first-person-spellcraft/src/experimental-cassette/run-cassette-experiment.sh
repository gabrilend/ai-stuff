#!/usr/bin/env bash
#
# run-cassette-experiment.sh
#
# WHAT (for a general): runs the experimental "cassette" branch (issue 905) end to
# end — it reads the project's startup note, proves in software that a slice of
# game bytes can be turned into audio tones and read back unchanged, and leaves a
# listenable .wav "cassette" plus a report in the project's RAM scratch area. It
# builds no hardware and gates no release; it is preserved whimsy that is honest
# about what it can and cannot yet do.
#
# HOW it stays portable: a hard-coded ${DIR} at the top, overridable by the first
# argument, with every path taken relative to ${DIR} — so it runs from anywhere.

set -euo pipefail

# {{{ resolve DIR (hard-coded, overridable by argument 1)
DIR="/mnt/mtwo/programming/ai-stuff/games/first-person-spellcraft"
if [ "${1:-}" != "" ]; then
   DIR="$1"
fi
# }}}

RUNNER="${DIR}/src/experimental-cassette/004-cassette-roundtrip-and-demo.lua"
INPUT_STARTUP="${DIR}/input/startup"

# {{{ ensure the RAM-backed scratch area exists (tmp -> /tmp, shared-memory -> /dev/shm)
# The project convention: ${DIR}/tmp is the exec tier, ${DIR}/tmp/shared-memory is
# the RAM artifact tier. Create both targets and the symlink before writing to them,
# rather than crashing when a directory is missing.
TMP_EXEC="/tmp/first-person-spellcraft"
SHM_DIR="/dev/shm/first-person-spellcraft"
mkdir -p "${TMP_EXEC}"
mkdir -p "${SHM_DIR}"
ln -sfn "${SHM_DIR}" "${DIR}/tmp/shared-memory"
ART_DIR="${DIR}/tmp/shared-memory"
# }}}

# {{{ first act: read input/
# The project rule is that a program's first act is to read input/. We honour it
# even here: show the startup note that a real run would parse for its config.
echo "== reading input/startup (the first act) =="
if [ -f "${INPUT_STARTUP}" ]; then
   cat "${INPUT_STARTUP}"
else
   echo "input/startup missing at ${INPUT_STARTUP} — refusing to guess a config." >&2
   exit 1
fi
echo
# }}}

# {{{ run the prover + demo, capture output without a pipe, log to RAM
# Assign the output to a variable and hand it where it needs to go, rather than
# piping through tee — so it is clear what is written where.
echo "== proving bytes -> tones -> bytes (software only) =="
LOG_PATH="${ART_DIR}/cassette-experiment.log"
set +e
RUN_OUTPUT="$(luajit "${RUNNER}" "${ART_DIR}")"
RUN_STATUS=$?
set -e
printf '%s\n' "${RUN_OUTPUT}" > "${LOG_PATH}"
printf '%s\n' "${RUN_OUTPUT}"
echo
echo "log written to: ${LOG_PATH}"
# }}}

# {{{ last act: a farewell (the authored output/goodbye seed is left untouched)
# The canonical output/goodbye seed is authored poetry; a research prototype has no
# business overwriting it, so this branch says its goodbye to stdout and leaves the
# seed for the real game's run loop to own.
echo
if [ "${RUN_STATUS}" -eq 0 ]; then
   echo "goodbye — the tape round-tripped. the wand's tiny voice survives the tones."
else
   echo "goodbye — the round-trip FAILED (see the log above); nothing was faked." >&2
fi
exit "${RUN_STATUS}"
# }}}
