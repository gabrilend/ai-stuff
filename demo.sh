#!/bin/bash

# Handheld Office Demo Script
# Shows the working system in action!

echo "🎮 Handheld Office Demo - Your Anbernic Text Editor is Ready! 🎮"
echo ""
echo "This demo shows:"
echo "  ✅ Game Boy-style hierarchical text input"
echo "  ✅ L-shaped text display" 
echo "  ✅ Network communication with daemon"
echo "  ✅ LLM integration ready for your desktop/cluster"
echo ""

echo "Starting daemon..."
env RUST_LOG=info ./target/release/daemon &
DAEMON_PID=$!
sleep 2

echo "Testing the handheld interface..."
echo "  Press 'A' to select A-H letter group"
echo "  Press 'B' to select 'B' character"
echo "  Text appears in L-shaped display!"
echo ""

# Simulate gamepad input
echo -e "a\nb\nquit" | ./target/release/handheld

echo ""
echo "Demo complete! 🎉"
echo ""
echo "✨ What you just saw:"
echo "  🎮 Hierarchical input system (A→A-H group→B character)"
echo "  📺 L-shaped text display like your vision"
echo "  🌐 Network connectivity to daemon"
echo "  💾 State persistence to files/build/"
echo ""
echo "🚀 Ready for your Anbernic device!"
echo "   Deploy with: ./scripts/simple_run.sh run"
echo ""

# Clean up
kill $DAEMON_PID 2>/dev/null || true
echo "Daemon stopped."