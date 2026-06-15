#!/bin/bash

# {{{ setup_dir_path
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

DIR=$(setup_dir_path "$1")

# Issue 8-059: ensure the tmpfs-backed tmp/ symlink exists before any
# write into it.
"${DIR}/scripts/ensure-tmp-symlink" "${DIR}"
OLLAMA_LOG="${DIR}/tmp/ollama-cuda.log"

echo "================================="
echo "🔧 CUDA-Enabled Ollama Startup"
echo "================================="
echo "Starting Ollama with CUDA support on port 10265..."
echo ""

# Set up environment for CUDA-compiled Ollama
OLLAMA_PROJECT_DIR="/mnt/mtwo/programs/ollama"
OLLAMA_BIN="${OLLAMA_PROJECT_DIR}/local/ollama/bin"

export PATH="${OLLAMA_PROJECT_DIR}/local/gcc13/bin:${OLLAMA_PROJECT_DIR}/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="${OLLAMA_PROJECT_DIR}/local/gcc13/lib64:${OLLAMA_PROJECT_DIR}/local/cuda/lib64:${OLLAMA_PROJECT_DIR}/local/ollama/lib:$LD_LIBRARY_PATH"
export CUDA_HOME="${OLLAMA_PROJECT_DIR}/local/cuda"

# Set Ollama to bind to port 10265 (router accessible)
export OLLAMA_HOST="192.168.0.115:10265"

echo "Environment configured:"
echo "• CUDA_HOME: $CUDA_HOME"
echo "• OLLAMA_HOST: $OLLAMA_HOST"
echo "• Binary path: ${OLLAMA_BIN}/ollama"
echo ""

# Check if Ollama is already running on port 10265
echo "Checking if Ollama is already running on port 10265..."
if curl -s --max-time 2 "http://${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
    echo "✓ Ollama is already running on ${OLLAMA_HOST}"
    exit 0
fi

echo "Starting Ollama service..."
echo "Command: OLLAMA_HOST=${OLLAMA_HOST} ${OLLAMA_BIN}/ollama serve"
echo ""

# Start Ollama service with CUDA support
OLLAMA_HOST="${OLLAMA_HOST}" "${OLLAMA_BIN}/ollama" serve > "${OLLAMA_LOG}" 2>&1 &
OLLAMA_PID=$!

echo "Ollama started with PID: $OLLAMA_PID"
echo "Waiting for service to initialize..."
sleep 5

# Verify the service started successfully
if curl -s --max-time 5 "http://${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
    echo "✅ Ollama CUDA service started successfully on ${OLLAMA_HOST}"
    echo "✅ Version: $(OLLAMA_HOST="${OLLAMA_HOST}" "${OLLAMA_BIN}/ollama" --version 2>&1 | grep -o 'client version is [0-9.]*' || echo 'CUDA-compiled version')"
    echo ""
    echo "🔧 Service management:"
    echo "• Logs: tail -f ${OLLAMA_LOG}"
    echo "• Stop: kill $OLLAMA_PID"
    echo "• Status: curl -s ${OLLAMA_HOST}/api/tags"
    echo ""
    echo "🚀 Ready for embedding operations!"
else
    echo "❌ Failed to start Ollama service"
    echo "Check logs: ${OLLAMA_LOG}"
    echo "Process status:"
    ps aux | grep ollama
    exit 1
fi