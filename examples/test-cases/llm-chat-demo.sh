#!/bin/bash

# LLM Chat Demo Test Case
# Shows AI-powered conversation between handheld devices
# Tests the full vision: type on gameboy, get AI responses!

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_DIR="examples/test-cases/logs"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_DIR/llm-test.log"
}

cleanup() {
    log "🧹 Stopping all services..."
    kill $DAEMON_PID 2>/dev/null || true
    kill $LLM_PID 2>/dev/null || true
    kill $CLIENT_PID 2>/dev/null || true
    wait
}

trap cleanup EXIT

log "🤖 LLM Chat Demo - AI-Powered Handheld Messaging"
log "   This tests the full AI pipeline: Anbernic → Daemon → LLM → Response"
log ""

# Step 1: Start daemon
log "📡 Starting daemon..."
env RUST_LOG=info ./files/target/release/daemon > "$LOG_DIR/daemon-llm.log" 2>&1 &
DAEMON_PID=$!
sleep 2

# Step 2: Start LLM service 
log "🤖 Starting LLM service (with fallback AI)..."
env RUST_LOG=info ./files/target/release/desktop-llm > "$LOG_DIR/llm-service.log" 2>&1 &
LLM_PID=$!
sleep 2

# Step 3: Create an interactive LLM test
log "🎮 Starting handheld with LLM requests..."

# Create a script that simulates typing "llm:hello" 
cat > "$LOG_DIR/llm_commands.txt" << 'EOF'
llm:hello world
llm:what is 2+2?
llm:tell me a joke
quit
EOF

log "   Sending AI requests:"
log "     → llm:hello world"
log "     → llm:what is 2+2?"  
log "     → llm:tell me a joke"
log ""

# Run the client with LLM commands
./files/target/release/handheld < "$LOG_DIR/llm_commands.txt" > "$LOG_DIR/llm-client.log" 2>&1

log "📊 LLM Test Results:"
log ""

# Show daemon activity
if [[ -f "$LOG_DIR/daemon-llm.log" ]]; then
    CONNECTIONS=$(grep -c "New client connected" "$LOG_DIR/daemon-llm.log" 2>/dev/null || echo "0")
    log "🌐 Network: $CONNECTIONS clients connected"
    
    # Show message forwarding
    grep -E "(Processing message|LlmRequest)" "$LOG_DIR/daemon-llm.log" | sed 's/^/    /' || true
fi

log ""

# Show LLM service activity
if [[ -f "$LOG_DIR/llm-service.log" ]]; then
    LLM_REQUESTS=$(grep -c "Processing LLM request" "$LOG_DIR/llm-service.log" 2>/dev/null || echo "0")
    log "🤖 AI Processing: $LLM_REQUESTS requests handled"
    
    # Show what the LLM processed
    log "   AI Responses:"
    grep -A 2 "Processing LLM request" "$LOG_DIR/llm-service.log" | grep -E "(request|Echo response)" | sed 's/^/    /' || echo "    (No detailed logs)"
fi

log ""

# Show client display
if [[ -f "$LOG_DIR/llm-client.log" ]]; then
    log "📱 Handheld Display:"
    # Extract the final screen state
    tail -30 "$LOG_DIR/llm-client.log" | grep -A 15 "┌────────" | head -15 | sed 's/^/    /' || echo "    (No display captured)"
fi

log ""
log "🎯 Validation:"

# Check the full pipeline
if [[ $CONNECTIONS -gt 0 ]]; then
    log "  ✅ Handheld connected to daemon"
else
    log "  ❌ No connections detected"
fi

if [[ $LLM_REQUESTS -gt 0 ]]; then
    log "  ✅ LLM service processed requests ($LLM_REQUESTS)"
else
    log "  ⚠️  No LLM requests processed (check logs)"
fi

# Check for LLM responses in daemon
RESPONSES=$(grep -c "LlmResponse" "$LOG_DIR/daemon-llm.log" 2>/dev/null || echo "0")
if [[ $RESPONSES -gt 0 ]]; then
    log "  ✅ AI responses sent back ($RESPONSES)"
else
    log "  ⚠️  No AI responses detected"
fi

log ""
log "🚀 Next Steps:"
log "   - Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh"
log "   - Run: ollama pull llama2"
log "   - Then your Anbernic will get real AI responses!"
log ""
log "📁 Detailed logs in: examples/test-cases/logs/"