#!/usr/bin/env bash
#
# phase-3-what-it-is-told.sh -- the phase 3 demo: the text payload.
#
# For a general: phase 3 wrote what the machine wakes up holding. This shows
# the numbers that matter about it -- how much is carried, how little is held
# at boot, what fetching costs -- and then shows the machine asking what it
# is carrying and reaching for something it was not given.
#
# The interesting number here is the ratio. A machine that woke up holding
# everything it carries would have no room left to think.
#
# usage:
#   ./phase-3-what-it-is-told.sh

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/every-software-image-able"
# }}}

for word in "$@"; do
  case "$word" in
    --*) ;;
    *)   DIR="$word" ;;
  esac
done

mkdir -p /tmp/every-software-image-able
mkdir -p /dev/shm/every-software-image-able
ln -sfn /tmp/every-software-image-able "${DIR}/tmp"
ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory

luajit "${DIR}/src/097-show-the-payload.lua" --dir "${DIR}"
luajit "${DIR}/src/085-test-the-payload.lua" --dir "${DIR}"
