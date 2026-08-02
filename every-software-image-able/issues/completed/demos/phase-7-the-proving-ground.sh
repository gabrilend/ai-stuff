#!/usr/bin/env bash
#
# phase-7-the-proving-ground.sh -- the phase 7 demo: the same machine,
# explored with the discipline held and with it broken, side by side.
#
# For a general: this phase built the place the rest is developed. The
# demonstration is the difference the discipline makes -- a machine that
# behaves is not accused, one that misbehaves is caught by name, and on a
# bench of parts that can really be destroyed, the well-behaved one survives
# and the reckless one does not.
#
# The trap matrix boots nine emulated machines and takes several minutes.
#
# usage:
#   ./phase-7-the-proving-ground.sh [--quick]   (--quick skips the boots)

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/every-software-image-able"
# }}}

QUICK=""
for word in "$@"; do
  case "$word" in
    --quick) QUICK="yes" ;;
    *)       DIR="$word" ;;
  esac
done

mkdir -p /tmp/every-software-image-able
mkdir -p /dev/shm/every-software-image-able
ln -sfn /tmp/every-software-image-able "${DIR}/tmp"
ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory

luajit "${DIR}/src/093-test-devices-that-die.lua" --dir "${DIR}"
luajit "${DIR}/src/096-test-watching-and-power.lua" --dir "${DIR}"

if [ -z "${QUICK}" ]; then
  luajit "${DIR}/src/022-test-traps.lua" --dir "${DIR}"
else
  printf '\n  (the trap matrix was skipped; run without --quick to boot them)\n\n'
fi
