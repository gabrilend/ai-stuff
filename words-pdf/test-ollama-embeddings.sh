#!/bin/bash

# Test script for Ollama embeddings system
# Checks if Ollama is running and EmbeddingGemma is available

DIR="/mnt/mtwo/programming/ai-stuff/words-pdf"

echo "Testing Ollama Embeddings System..."
echo "===================================="

# Auto-detect Ollama endpoint
OLLAMA_ENDPOINT=""
for endpoint in "http://localhost:11434" "http://127.0.0.1:11434" "http://192.168.0.115:11434"; do
    if curl -s --max-time 2 "$endpoint/api/tags" > /dev/null 2>&1; then
        OLLAMA_ENDPOINT="$endpoint"
        break
    fi
done

# Check if Ollama is running
echo -n "Checking if Ollama is running... "
if [ -n "$OLLAMA_ENDPOINT" ]; then
    echo "✓ Ollama is running at $OLLAMA_ENDPOINT"
else
    echo "✗ Ollama is not running or not accessible"
    echo "Please start Ollama with: ollama serve"
    exit 1
fi

# Check if EmbeddingGemma is available
echo -n "Checking if EmbeddingGemma:latest is available... "
OLLAMA_HOST_VAR="${OLLAMA_ENDPOINT#http://}"
if OLLAMA_HOST="$OLLAMA_HOST_VAR" ollama list | grep -q "EmbeddingGemma:latest"; then
    echo "✓ EmbeddingGemma:latest is available"
else
    echo "✗ EmbeddingGemma:latest not found"
    echo "Please install with: ollama pull EmbeddingGemma:latest"
    exit 1
fi

# Test a simple embedding
echo -n "Testing embedding generation... "
curl -s -X POST "$OLLAMA_ENDPOINT/api/embeddings" \
     -H "Content-Type: application/json" \
     -d '{"model": "EmbeddingGemma:latest", "prompt": "test embedding"}' \
     > /tmp/embedding_test.json

if grep -q '"embedding"' /tmp/embedding_test.json; then
    echo "✓ Embedding generation works"
    EMBEDDING_SIZE=$(jq '.embedding | length' /tmp/embedding_test.json 2>/dev/null)
    if [ "$EMBEDDING_SIZE" != "null" ] && [ "$EMBEDDING_SIZE" -gt 0 ]; then
        echo "  Embedding size: $EMBEDDING_SIZE dimensions"
    fi
else
    echo "✗ Embedding generation failed"
    echo "Error response:"
    cat /tmp/embedding_test.json
    exit 1
fi

echo ""
echo "✓ All checks passed! The Ollama embedding system is ready."
echo ""
echo "You can now run the updated PDF generation system:"
echo "  lua5.2 $DIR/compile-pdf-ai.lua $DIR $DIR/input/compiled.txt"

# Cleanup
rm -f /tmp/embedding_test.json