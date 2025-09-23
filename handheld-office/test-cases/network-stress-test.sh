#!/bin/bash

# Network Stress Test
# Simulates multiple Anbernic devices all talking at once
# Tests the daemon's ability to handle concurrent connections

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_DIR="test-cases/logs"
mkdir -p "$LOG_DIR"

NUM_CLIENTS=5
CLIENT_PIDS=()

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_DIR/stress-test.log"
}

cleanup() {
    log "🧹 Cleaning up $NUM_CLIENTS clients and services..."
    kill $DAEMON_PID 2>/dev/null || true
    
    for pid in "${CLIENT_PIDS[@]}"; do
        kill $pid 2>/dev/null || true
    done
    
    wait
    log "✅ All processes stopped"
}

trap cleanup EXIT

log "🚀 Network Stress Test - Multiple Anbernic Simulation"
log "   Testing $NUM_CLIENTS concurrent handheld devices"
log "   Each device will type different messages simultaneously"
log ""

# Start daemon with increased logging
log "📡 Starting high-capacity daemon..."
env RUST_LOG=debug ./target/release/daemon > "$LOG_DIR/stress-daemon.log" 2>&1 &
DAEMON_PID=$!
sleep 2

if ! ps -p $DAEMON_PID > /dev/null; then
    log "❌ Daemon failed to start"
    exit 1
fi

log "✅ Daemon ready for connections"
log ""

# Create unique input for each client
for i in $(seq 1 $NUM_CLIENTS); do
    cat > "$LOG_DIR/client${i}_input.txt" << EOF
a
b
$(printf 'l%.0s' $(seq 1 $i))
quit
EOF
done

# Start all clients simultaneously
log "🎮 Launching $NUM_CLIENTS handheld devices..."
for i in $(seq 1 $NUM_CLIENTS); do
    log "   Starting Anbernic #$i..."
    
    env RUST_LOG=info DEVICE_ID="anbernic_$i" ./target/release/handheld \
        < "$LOG_DIR/client${i}_input.txt" \
        > "$LOG_DIR/stress-client${i}.log" 2>&1 &
    
    CLIENT_PIDS+=($!)
    
    # Stagger starts slightly to avoid overwhelming
    sleep 0.5
done

log "⏳ All devices connecting... (waiting 5 seconds)"
sleep 5

log "📊 Stress Test Results:"
log ""

# Check daemon capacity
CONNECTIONS=$(grep -c "New client connected" "$LOG_DIR/stress-daemon.log" 2>/dev/null || echo "0")
ERRORS=$(grep -c "ERROR" "$LOG_DIR/stress-daemon.log" 2>/dev/null || echo "0")

log "🌐 Network Performance:"
log "   ✅ Connections handled: $CONNECTIONS/$NUM_CLIENTS"
log "   ⚠️  Network errors: $ERRORS"

if [[ $CONNECTIONS -eq $NUM_CLIENTS ]]; then
    log "   🎯 Perfect! All devices connected successfully"
elif [[ $CONNECTIONS -gt 0 ]]; then
    log "   ⚠️  Partial success: some devices connected"
else
    log "   ❌ Connection failure: no devices connected"
fi

log ""
log "📱 Individual Device Status:"

for i in $(seq 1 $NUM_CLIENTS); do
    if [[ -f "$LOG_DIR/stress-client${i}.log" ]]; then
        # Check if client successfully typed text
        TEXT_OUTPUT=$(grep -o "│[^│]*│" "$LOG_DIR/stress-client${i}.log" 2>/dev/null | grep -v "│                    │" | tail -1 || echo "")
        
        if [[ -n "$TEXT_OUTPUT" ]]; then
            log "   Device #$i: ✅ Typed successfully $TEXT_OUTPUT"
        else
            log "   Device #$i: ⚠️  No text captured"
        fi
    else
        log "   Device #$i: ❌ No logs generated"
    fi
done

log ""
log "🔍 Message Flow Analysis:"

# Analyze message processing
MESSAGES_SENT=$(grep -c "Processing message" "$LOG_DIR/stress-daemon.log" 2>/dev/null || echo "0")
BROADCASTS=$(grep -c "broadcast" "$LOG_DIR/stress-daemon.log" 2>/dev/null || echo "0")

log "   📤 Messages processed: $MESSAGES_SENT"
log "   📡 Broadcasts sent: $BROADCASTS"

if [[ $MESSAGES_SENT -gt 0 ]]; then
    log "   ✅ Message routing functional"
else
    log "   ⚠️  No message processing detected"
fi

log ""
log "⚡ Performance Summary:"

# Calculate success rate
if [[ $NUM_CLIENTS -gt 0 ]]; then
    SUCCESS_RATE=$((CONNECTIONS * 100 / NUM_CLIENTS))
    log "   Connection Success Rate: $SUCCESS_RATE%"
    
    if [[ $SUCCESS_RATE -eq 100 ]]; then
        log "   🏆 EXCELLENT: Ready for full Anbernic deployment!"
    elif [[ $SUCCESS_RATE -ge 80 ]]; then
        log "   👍 GOOD: Most devices can connect simultaneously"
    elif [[ $SUCCESS_RATE -ge 50 ]]; then
        log "   ⚠️  FAIR: Some devices may have connection issues"
    else
        log "   ❌ POOR: Network handling needs improvement"
    fi
fi

log ""
log "🚀 Real-World Implications:"
log "   This test simulates $NUM_CLIENTS Anbernics on your LAN"
log "   Each device typing different messages simultaneously"
log "   Perfect for game nights or collaborative text editing!"
log ""
log "📁 Detailed analysis in: test-cases/logs/stress-*"

# Wait for all clients to finish naturally
log "⏳ Waiting for all devices to finish..."
for pid in "${CLIENT_PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

log "✅ Stress test complete!"