#!/bin/bash
# test-embeddings.sh — Smoke-test the project's embedding server.
#
# Issue 025 replaced Ollama with two llama-server instances; this script
# only exercises the embedding one. It hits two endpoints in sequence:
#   GET  /v1/models      — liveness; confirms the server is up at all
#   POST /v1/embeddings  — round-trip; confirms the model is loaded and
#                          producing well-shaped output
#
# A failure at either step exits non-zero. The exit code is meaningful so
# CI / wrappers can chain on it.

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/words-pdf}"

# {{{ constants
# Defaults match scripts/start-llamacpp-server.sh. Override either via
# env var to test a different instance (e.g. one on localhost during dev).
ENDPOINT="${INFERENCE_EMBEDDING_HOST:-192.168.1.100:20165}"
URL_BASE="http://${ENDPOINT}"
MODEL_NAME="${EMBEDDING_MODEL:-nomic-embed-text:v1.5}"

# nomic-embed-text v1.5 is a 137M-parameter model with a 768-dimensional
# output vector. Any other dimension here means the wrong model was loaded
# (or that we picked up the wrong server entirely).
EXPECTED_DIM=768

TMP_OUT="${DIR}/tmp/test-embedding-response.json"
# }}}

mkdir -p "${DIR}/tmp"

echo "Testing embedding server at ${URL_BASE}..."
echo "============================================="

# {{{ liveness check via /v1/models
echo -n "Checking server liveness (GET /v1/models)... "
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
    "${URL_BASE}/v1/models" || echo "000")
if [ "${HTTP_CODE}" = "200" ]; then
    echo "✓ server responds (HTTP 200)"
else
    echo "✗ no response (HTTP ${HTTP_CODE})"
    echo "Start the server with: ./scripts/start-llamacpp-server.sh"
    exit 1
fi
# }}}

# {{{ embedding round-trip
echo -n "Testing embedding generation (POST /v1/embeddings)... "
curl -s --max-time 30 \
    -X POST "${URL_BASE}/v1/embeddings" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL_NAME}\", \"input\": \"clustering: test embedding\"}" \
    > "${TMP_OUT}"

# A well-formed response has the OpenAI shape:
#   {"object":"list","data":[{"object":"embedding","embedding":[...],"index":0}],"model":"..."}
if ! grep -q '"embedding"' "${TMP_OUT}"; then
    echo "✗ no embedding field in response"
    echo "Raw response:"
    cat "${TMP_OUT}"
    rm -f "${TMP_OUT}"
    exit 1
fi

# data[0].embedding is the float array we care about
ACTUAL_DIM=$(jq '.data[0].embedding | length' "${TMP_OUT}" 2>/dev/null || echo "0")
if [ "${ACTUAL_DIM}" != "${EXPECTED_DIM}" ]; then
    echo "✗ wrong dimension: got ${ACTUAL_DIM}, expected ${EXPECTED_DIM}"
    echo "   (suggests the wrong model is loaded on the embedding port)"
    rm -f "${TMP_OUT}"
    exit 1
fi
echo "✓ ${ACTUAL_DIM}-dimensional embedding returned"
# }}}

rm -f "${TMP_OUT}"

echo ""
echo "✓ Embedding server is ready."
echo ""
echo "Next: run the PDF generator —"
echo "  ${DIR}/run"
