#!/usr/bin/env bash
#
# phase-2-the-hands.sh -- the phase 2 demo: a machine that can act.
#
# For a general: phase 1 made a machine that thinks. Phase 2 gave it hands --
# a way to ask for something and be answered, a voice, memory it can reach,
# storage it can keep things on, hardware it can explore without destroying,
# and the one hand everything else is downstream of: running code it just
# wrote.
#
# The demo is the machine narrating its own startup on a screen with no
# driver underneath it, and then being asked for something it has to write
# and run in order to answer. That is what the phase notes asked for, and it
# is shown rather than described:
#
#   the boundary   -- asking for something and being answered, every refusal
#                     a sentence, and a live exchange on the real engine
#   the voice      -- a sentence drawn into real firmware's framebuffer,
#                     checked against the font pixel by pixel
#   the reach      -- memory, storage and hardware, with the refusals that
#                     keep a machine from ending itself
#   what it writes -- a program assembled, placed, and run on this processor,
#                     and a runaway caught by the watch in its own loop
#
# The framebuffer half boots a real machine and takes a minute.
#
# usage:
#   ./phase-2-the-hands.sh [--quick]    (--quick skips the boot)

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

luajit "${DIR}/src/065-test-the-hands.lua" --dir "${DIR}"
luajit "${DIR}/src/075-test-run-what-it-wrote.lua" --dir "${DIR}"
luajit "${DIR}/src/078-test-keep-and-touch.lua" --dir "${DIR}"

if [ -z "${QUICK}" ]; then
  luajit "${DIR}/src/070-test-say.lua" --dir "${DIR}"
else
  printf '\n  (the drawing on a real board was skipped; run without --quick)\n\n'
fi
