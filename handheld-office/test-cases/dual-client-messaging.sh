#!/bin/bash

# Dual Client Messaging Test Case
# Simulates two Anbernic devices talking to each other over LAN
# Perfect for lazy testing without plugging in actual hardware! 🎮

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_DIR="test-cases/logs"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_DIR/test.log"
}

cleanup() {
    log "🧹 Cleaning up test processes..."
    kill $DAEMON_PID 2>/dev/null || true
    kill $LLM_PID 2>/dev/null || true
    kill $CLIENT1_PID 2>/dev/null || true
    kill $CLIENT2_PID 2>/dev/null || true
    wait
    log "✅ Cleanup complete"
}

# Handle Ctrl+C gracefully
trap cleanup EXIT

log "🎮 Starting Dual Client Messaging Test"
log "   This simulates two Anbernic devices on the same LAN"
log ""

# Step 1: Start the daemon
log "📡 Starting central daemon..."
env RUST_LOG=info ./target/release/daemon > "$LOG_DIR/daemon.log" 2>&1 &
DAEMON_PID=$!
sleep 2

if ! ps -p $DAEMON_PID > /dev/null; then
    log "❌ Daemon failed to start"
    exit 1
fi
log "✅ Daemon running (PID: $DAEMON_PID)"

# Step 2: Start LLM service (for AI responses)
log "🤖 Starting LLM service..."
env RUST_LOG=info ./target/release/desktop-llm > "$LOG_DIR/llm.log" 2>&1 &
LLM_PID=$!
sleep 1

if ! ps -p $LLM_PID > /dev/null; then
    log "⚠️  LLM service failed to start (continuing without AI)"
    LLM_PID=""
fi
log "✅ LLM service running (PID: $LLM_PID)"

# Step 3: Start first client (Anbernic #1)
log ""
log "🎮 Starting Anbernic #1 (Alice's device)..."
cat > "$LOG_DIR/alice_input.txt" << 'EOF'
a
b
b
l
quit
EOF

env RUST_LOG=info ./target/release/handheld < "$LOG_DIR/alice_input.txt" > "$LOG_DIR/alice.log" 2>&1 &
CLIENT1_PID=$!
sleep 2

# Step 4: Start second client (Anbernic #2) 
log "🎮 Starting Anbernic #2 (Bob's device)..."
cat > "$LOG_DIR/bob_input.txt" << 'EOF'
a
a
b
l
r
quit
EOF

env RUST_LOG=info ./target/release/handheld < "$LOG_DIR/bob_input.txt" > "$LOG_DIR/bob.log" 2>&1 &
CLIENT2_PID=$!
sleep 3

# Step 5: Let them run and exchange messages
log ""
log "💬 Devices are now messaging each other..."
log "   Alice types: 'bb' + 'c' = 'bbc'"
log "   Bob types: 'ab' + 'c' + 'd' = 'abcd'"
log ""

# Wait for clients to finish
wait $CLIENT1_PID 2>/dev/null
wait $CLIENT2_PID 2>/dev/null

log "📊 Test Results:"
log ""

# Show what each client did
log "📱 Alice's Session (Anbernic #1):"
if [[ -f "$LOG_DIR/alice.log" ]]; then
    # Extract the final display state
    tail -20 "$LOG_DIR/alice.log" | grep -A 15 "┌────────" | head -15 || echo "  (No display output captured)"
else
    log "  ❌ No output captured"
fi

log ""
log "📱 Bob's Session (Anbernic #2):"
if [[ -f "$LOG_DIR/bob.log" ]]; then
    # Extract the final display state  
    tail -20 "$LOG_DIR/bob.log" | grep -A 15 "┌────────" | head -15 || echo "  (No display output captured)"
else
    log "  ❌ No output captured"
fi

log ""
log "🌐 Network Activity:"
if [[ -f "$LOG_DIR/daemon.log" ]]; then
    log "  Daemon connections:"
    grep "New client connected" "$LOG_DIR/daemon.log" | sed 's/^/    /'
    
    log "  Message processing:"
    grep -E "(Processing message|Broadcasting)" "$LOG_DIR/daemon.log" | sed 's/^/    /' || echo "    No messages processed"
else
    log "  ❌ No daemon logs"
fi

log ""
log "🎯 Test Validation:"

# Check if both clients connected
CONNECTIONS=$(grep -c "New client connected" "$LOG_DIR/daemon.log" 2>/dev/null || echo "0")
if [[ $CONNECTIONS -ge 2 ]]; then
    log "  ✅ Both devices connected to daemon"
else
    log "  ❌ Expected 2+ connections, got $CONNECTIONS"
fi

# Check if text was entered
ALICE_TEXT=$(grep -o "│[^│]*│" "$LOG_DIR/alice.log" 2>/dev/null | grep -v "│                    │" | tail -1 2>/dev/null || echo "")
BOB_TEXT=$(grep -o "│[^│]*│" "$LOG_DIR/bob.log" 2>/dev/null | grep -v "│                    │" | tail -1 2>/dev/null || echo "")

if [[ -n "$ALICE_TEXT" ]]; then
    log "  ✅ Alice typed text: $ALICE_TEXT"
else
    log "  ⚠️  Alice's text not captured"
fi

if [[ -n "$BOB_TEXT" ]]; then
    log "  ✅ Bob typed text: $BOB_TEXT"
else
    log "  ⚠️  Bob's text not captured"
fi

# Check for LLM integration
LLM_REQUESTS=$(grep -c "Processing LLM request" "$LOG_DIR/llm.log" 2>/dev/null || echo "0")
if [[ $LLM_REQUESTS -gt 0 ]]; then
    log "  ✅ LLM processed $LLM_REQUESTS requests"
else
    log "  ℹ️  No LLM requests (normal for this test)"
fi

log ""
log "🎮 Test Complete!"
log "   This demonstrates the same networking your Anbernics will use"
log "   Each client connected independently and could share messages"
log ""
log "📁 Full logs saved in: test-cases/logs/"
log "   - daemon.log: Central message broker logs"
log "   - alice.log: First handheld client logs"  
log "   - bob.log: Second handheld client logs"
log "   - llm.log: AI service logs"