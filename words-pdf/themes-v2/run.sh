#!/bin/bash
# themes-v2/run.sh — Issue 029 driver. Chains the four pipeline
# scripts in order:
#
#   1. load-poem-embeddings.lua → tmp/poem-embeddings.bin
#                                 tmp/poem-texts.lua
#   2. hdbscan.lua              → tmp/clusters.lua
#                                 tmp/cluster-centroids.bin
#   3. tfidf.lua                → tmp/cluster-tfidf.lua
#   4. name-clusters.lua        → themes/derived-taxonomy.lua
#
# Each step's output is on disk, so --start-at lets you resume from a
# specific step after tuning (e.g. rerun naming after editing the prompt
# without re-clustering). --clean wipes intermediate files first.
#
# Requires:
#   * scripts/start-llamacpp-server.sh --background already running
#     (step 1 may embed missing poems; step 4 needs the chat endpoint
#     and the embedding endpoint for name candidates).

set -euo pipefail

# {{{ DIR + arg parsing
DIR="/home/ritz/programming/ai-stuff/words-pdf"
START_AT=1
CLEAN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-at)
            START_AT="$2"
            shift 2
            ;;
        --start-at=*)
            START_AT="${1#*=}"
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--start-at N] [--clean] [DIR]
  --start-at N   Resume from pipeline step N (1..4). Default 1.
  --clean        Delete intermediate files before starting.
  DIR            Project root (default: ${DIR}).
EOF
            exit 0
            ;;
        --*)
            echo "Unknown flag: $1" >&2
            exit 2
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done
# }}}

# {{{ clean if requested
if [[ "${CLEAN}" -eq 1 ]]; then
    echo "🧹 Cleaning intermediate files"
    rm -f "${DIR}/tmp/poem-embeddings.bin" \
          "${DIR}/tmp/poem-texts.lua" \
          "${DIR}/tmp/clusters.lua" \
          "${DIR}/tmp/cluster-centroids.bin" \
          "${DIR}/tmp/cluster-tfidf.lua"
fi
# }}}

# {{{ preflight
# The intermediate files live in tmp/, which is a tmpfs symlink. ./run
# normally creates the symlink for us, but this script may be invoked
# in isolation, so be defensive.
"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null

# name-clusters.lua loads themes/generators.lua to read generator
# metadata (style_descriptions + parameter axes). That module requires
# hpdf (for its draw functions, even though we only read metadata here),
# which in turn needs libhpdf.so on LD_LIBRARY_PATH. ./run sets this
# already; we re-export it here so themes-v2/run.sh works standalone too.
export LD_LIBRARY_PATH="${DIR}/libs/cuda/lib64:${DIR}/libs/libharu-RELEASE_2_3_0/build/src${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Each step bails out fast if its server endpoint is unreachable, so we
# don't pre-probe here — let the lua scripts' error messages name the
# specific issue (embedding server vs chat server vs cache miss).
# }}}

# {{{ step 1 — load poem embeddings
if [[ "${START_AT}" -le 1 ]]; then
    echo ""
    echo "=========================================="
    echo " Step 1/4: load-poem-embeddings.lua"
    echo "=========================================="
    luajit "${DIR}/themes-v2/load-poem-embeddings.lua" "${DIR}"
fi
# }}}

# {{{ step 2 — HDBSCAN
if [[ "${START_AT}" -le 2 ]]; then
    echo ""
    echo "=========================================="
    echo " Step 2/4: hdbscan.lua"
    echo "=========================================="
    luajit "${DIR}/themes-v2/hdbscan.lua" "${DIR}"
fi
# }}}

# {{{ step 3 — TF-IDF
if [[ "${START_AT}" -le 3 ]]; then
    echo ""
    echo "=========================================="
    echo " Step 3/4: tfidf.lua"
    echo "=========================================="
    luajit "${DIR}/themes-v2/tfidf.lua" "${DIR}"
fi
# }}}

# {{{ step 4 — name clusters
if [[ "${START_AT}" -le 4 ]]; then
    echo ""
    echo "=========================================="
    echo " Step 4/4: name-clusters.lua"
    echo "=========================================="
    luajit "${DIR}/themes-v2/name-clusters.lua" "${DIR}"
fi
# }}}

echo ""
echo "🎉 themes-v2 pipeline complete."
echo "   Output: ${DIR}/themes/derived-taxonomy.lua"
