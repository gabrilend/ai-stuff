#!/usr/bin/env bash
#
# run-bci-experiment.sh
#
# WHAT (for a general): runs the experimental brain-interface branch (issue 207, a
# Phase-2 STRETCH goal that is DOCUMENTED, NOT SCHEDULED — nothing depends on it).
# It reads the project's startup note, then proves in software, against a scripted
# "attention" trace, that the dream's pipe holds together: attention drifting "up
# and to the left" becomes an aim direction, which becomes the cable tensions that
# would move a ceiling-hung headset "at just the right tension." No EEG and no
# servos are involved; this is the software rehearsal before any hardware exists.
#
# HOW it stays portable: a hard-coded ${DIR} at the top, overridable by argument 1,
# with every path taken relative to ${DIR}.

set -euo pipefail

# {{{ resolve DIR (hard-coded, overridable by argument 1)
DIR="/mnt/mtwo/programming/ai-stuff/games/first-person-spellcraft"
if [ "${1:-}" != "" ]; then
   DIR="$1"
fi
# }}}

RUNNER="${DIR}/src/experimental-bci/009-bci-scripted-trace-demo.lua"
INPUT_STARTUP="${DIR}/input/startup"

# {{{ ensure the RAM-backed scratch area exists (tmp -> /tmp, shared-memory -> /dev/shm)
TMP_EXEC="/tmp/first-person-spellcraft"
SHM_DIR="/dev/shm/first-person-spellcraft"
mkdir -p "${TMP_EXEC}"
mkdir -p "${SHM_DIR}"
ln -sfn "${SHM_DIR}" "${DIR}/tmp/shared-memory"
ART_DIR="${DIR}/tmp/shared-memory"
# }}}

# {{{ first act: read input/
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
echo "== proving attention -> aim -> ceiling tension (software only) =="
LOG_PATH="${ART_DIR}/bci-experiment.log"
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
echo
if [ "${RUN_STATUS}" -eq 0 ]; then
   echo "goodbye — the daydream held: attention became tension, and no head was harmed."
else
   echo "goodbye — the attention pipe FAILED (see the log above); nothing was faked." >&2
fi
exit "${RUN_STATUS}"
# }}}
