#!/usr/bin/env bash
#
# phase-1-the-engine.sh -- the phase 1 demo: the engine, measured.
#
# For a general: phase 1 built a model that thinks -- weights in, tokens out,
# every piece of arithmetic and its conducting in the processor's own
# instructions, proven bit for bit against readable twins. A demo that
# described that would be less useful than one that prints the numbers the
# project's feasibility rests on, so this runs the three measuring tools:
#
#   what fits    -- how much memory thinking costs, per model, per board,
#                   and which strategy each board can afford
#   how fast     -- tokens per second natively, readable against assembly,
#                   and what that implies for models worth carrying
#   the boards   -- three emulated computers switched on, timed from power
#                   to the machine finding its own model and saying what
#                   room it has
#
# The last one boots three firmware roads and takes a minute or two.
#
# usage:
#   ./phase-1-the-engine.sh [--quick]    (--quick skips the boards)

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

# the RAM tiers, before anything writes into them
mkdir -p /tmp/every-software-image-able
mkdir -p /dev/shm/every-software-image-able
ln -sfn /tmp/every-software-image-able "${DIR}/tmp"
ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory

luajit "${DIR}/src/046-what-fits.lua" --dir "${DIR}"
luajit "${DIR}/src/051-measure-engine.lua" --dir "${DIR}"

if [ -z "${QUICK}" ]; then
  luajit "${DIR}/src/063-measure-boards.lua" --dir "${DIR}"
else
  printf '\n  (the boards were skipped; run without --quick to switch them on)\n\n'
fi
