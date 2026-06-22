#!/bin/bash
# build-deps.sh — Run each per-dependency builder (build-<dep>.sh) in turn.
#
# This is a thin orchestrator. Each dependency has its own build-<dep>.sh
# alongside this file; we invoke them in order, forwarding DIR to each.
# Per-builder flags (e.g. build-cuda.sh's --from-ollama) are NOT exposed
# here — invoke the individual script directly when you need those.
#
# Env vars are inherited normally, so the common knobs still work through
# this script:
#   FORCE=1        — build-cuda.sh re-installs from scratch
#   CUDA=0         — build-llamacpp.sh builds CPU-only
#   BUILD_JOBS=N   — build-llamacpp.sh parallel-job limit
#
# To add a new dependency: drop scripts/build-<name>.sh next to this file
# and append its filename to the BUILDERS array below.

set -euo pipefail

# Hard-coded project root; overrideable by the first positional arg.
# Per project convention, all paths in the script are relative to ${DIR}.
DIR="${1:-/home/ritz/programming/ai-stuff/words-pdf}"

# Resolve this script's own directory so we can find sibling build-<dep>.sh
# scripts regardless of where the caller invoked us from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# {{{ usage()
usage() {
    cat <<'EOF'
build-deps.sh — Run each build-<dep>.sh in turn.

USAGE:
  ./scripts/build-deps.sh [DIR]

ARGUMENTS:
  DIR                Path to the project root. Forwarded to each builder.
                     Defaults to /home/ritz/programming/ai-stuff/words-pdf.

ENVIRONMENT (forwarded to the relevant builder):
  FORCE=1            build-cuda.sh: wipe libs/cuda/ before installing.
  CUDA=0             build-llamacpp.sh: build CPU-only.
  BUILD_JOBS=N       build-llamacpp.sh: cap parallel jobs (default 8).

BUILDERS (run in this order):
  build-cuda.sh      Install/refresh CUDA toolkit into libs/cuda/.
  build-llamacpp.sh  Clone/update/compile llama.cpp into libs/llama.cpp/.

For builder-specific flags (e.g. build-cuda.sh --from-ollama), run the
individual script directly.
EOF
}
# }}}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Order matters: llama.cpp's build needs CUDA in place first (when CUDA=1).
BUILDERS=(
    "build-cuda.sh"
    "build-llamacpp.sh"
)

# {{{ run_builder()
# Prints a banner and runs one builder, forwarding DIR. The set -e at the
# top of the orchestrator means a non-zero exit from any builder aborts
# the whole run, so we don't need explicit failure handling here.
run_builder() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    if [ ! -x "${script_path}" ]; then
        echo "❌ Builder ${script_name} not found or not executable at ${script_path}" >&2
        exit 1
    fi
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "▶  ${script_name}"
    echo "════════════════════════════════════════════════════════════════"
    "${script_path}" "${DIR}"
}
# }}}

# {{{ main()
for builder in "${BUILDERS[@]}"; do
    run_builder "${builder}"
done

echo ""
echo "✅ All builders completed."
# }}}
