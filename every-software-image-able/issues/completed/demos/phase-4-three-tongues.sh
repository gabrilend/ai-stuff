#!/usr/bin/env bash
#
# phase-4-three-tongues.sh -- the phase 4 demo: three engines, one answer.
#
# For a general: this project has no compiler. The arithmetic that runs a
# model was written three times by hand, once for each family of processor
# people actually own. The claim phase 4 makes is not that all three work --
# it is that all three produce THE SAME NUMBERS, to the last bit.
#
# So the demo shows the counts, and then earns them: it boots a real emulated
# machine of each kind and makes them agree in front of you. A summary that
# printed numbers somebody typed would prove nothing, and the summary here is
# derived from the modules themselves for exactly that reason -- the count of
# routines in it was written by hand as eleven and was twelve by the time it
# first ran.
#
# It takes a few minutes, nearly all of it firmware getting to the payload.
#
# usage:
#   ./phase-4-three-tongues.sh [--quick]   (--quick skips the boots)

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/every-software-image-able"
# }}}

QUICK=""
for word in "$@"; do
  case "$word" in
    --quick) QUICK="yes" ;;
    --*)     ;;
    *)       DIR="$word" ;;
  esac
done

mkdir -p /tmp/every-software-image-able
mkdir -p /dev/shm/every-software-image-able
ln -sfn /tmp/every-software-image-able "${DIR}/tmp"
ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory

# the shape of the claim, and every number in it derived rather than typed
luajit "${DIR}/src/130-show-the-tongues.lua" --dir "${DIR}"

if [ -n "${QUICK}" ]; then
  printf '  (the machines were skipped; run without --quick to switch them on.\n'
  printf '   Without them the numbers above are a story rather than a claim.)\n\n'
  exit 0
fi

# and then the machines themselves. Each of these builds a payload, wraps it
# in the envelope its own firmware will open, boots that machine, and reads
# back what it said on a wire.
printf '\n  now the machines. Each one boots and is asked.\n\n'

luajit "${DIR}/src/125-test-quantised-kernels.lua" --dir "${DIR}"
luajit "${DIR}/src/110-test-forward-aarch64.lua"   --dir "${DIR}"
luajit "${DIR}/src/116-test-forward-riscv64.lua"   --dir "${DIR}"
luajit "${DIR}/src/127-test-tokenizer-elsewhere.lua" --dir "${DIR}"
luajit "${DIR}/src/129-test-say-elsewhere.lua"     --dir "${DIR}"
