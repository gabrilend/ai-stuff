#!/usr/bin/env bash
#
# phase-5-the-image.sh -- the phase 5 demo: one recipe, three boards.
#
# For a general: phase 5 built the thing that turns a description of a seed
# and a description of a computer into bytes you can put on a card. The claim
# is that supporting a new machine is a new file and no code, so the demo is
# the same recipe built for every board the project describes -- and the
# identities of the results, which differ because the boards differ and
# repeat exactly when nothing does.
#
# usage:
#   ./phase-5-the-image.sh

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

luajit "${DIR}/src/098-show-the-images.lua" --dir "${DIR}"
luajit "${DIR}/src/090-test-the-image.lua" --dir "${DIR}"
