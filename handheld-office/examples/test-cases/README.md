# Handheld Office Test Cases 🎮

Perfect for lazy testing without plugging in your Anbernic! Each test simulates real network scenarios you'll encounter when deploying to actual handhelds.

## Available Tests

### 🎯 `dual-client-messaging.sh`
**Two Anbernics talking to each other**
- Simulates Alice and Bob's devices on the same LAN
- Tests basic peer-to-peer communication
- Validates hierarchical input and L-shaped display
- Perfect starting point for network testing

```bash
./examples/test-cases/dual-client-messaging.sh
```

**What it tests:**
- ✅ Daemon handles multiple clients
- ✅ Each client can type independently 
- ✅ Message routing between devices
- ✅ Real network protocols (TCP over 127.0.0.1)

### 🤖 `llm-chat-demo.sh`
**AI-powered handheld messaging**
- Tests the full AI pipeline: Anbernic → Daemon → LLM → Response
- Simulates typing `llm:hello world` on gameboy
- Shows fallback AI responses (until you install Ollama)
- Validates desktop/cluster AI integration

```bash
./examples/test-cases/llm-chat-demo.sh
```

**What it tests:**
- ✅ LLM service connects to daemon
- ✅ `llm:prompt` command processing
- ✅ AI response routing back to handheld
- ✅ Full vision: type on gameboy, get AI help

### ⚡ `network-stress-test.sh`
**Multiple Anbernics simultaneously**
- Simulates 5 handhelds all typing at once
- Tests daemon's concurrent connection handling
- Validates network capacity for game nights
- Shows real-world multi-device scenarios

```bash
./examples/test-cases/network-stress-test.sh
```

**What it tests:**
- ✅ Concurrent connection handling (5+ devices)
- ✅ Message broadcasting under load
- ✅ Network error handling
- ✅ Performance metrics and success rates

## Quick Test Run

Want to see everything work? Run the basic messaging test:

```bash
./examples/test-cases/dual-client-messaging.sh
```

This will:
1. Start the daemon on port 8080
2. Launch two "Anbernic" clients (Alice & Bob)
3. Each types different text using A/B/L/R navigation
4. Show network activity and message exchange
5. Validate the full communication pipeline

## Log Analysis

All tests save detailed logs to `examples/test-cases/logs/`:
- `daemon.log` - Central message broker activity
- `alice.log` / `bob.log` - Individual client sessions
- `llm.log` - AI service processing
- `stress-*.log` - Performance testing data

## Real-World Translation

These tests use the **exact same networking protocols** your Anbernics will use:
- TCP connections to daemon on port 8080
- JSON message passing between components  
- State persistence to `files/build/`
- Same binary executables as production

The only difference: instead of WiFi between devices, we use localhost loopback (127.0.0.1). The protocol stack is identical!

## Extending Tests

Want to add more test scenarios? Each test follows this pattern:

1. **Setup**: Start daemon and services
2. **Execute**: Run client(s) with scripted input
3. **Capture**: Log all network activity 
4. **Validate**: Check expected behaviors
5. **Report**: Show success/failure with details
6. **Cleanup**: Kill all processes gracefully

Perfect for testing new features before deploying to actual Anbernic hardware!

## Performance Expectations

**Dual Client Test:**
- Expected: 2/2 connections successful
- Message latency: <10ms on localhost
- Zero network errors

**LLM Chat Test:**
- Expected: 3+ AI requests processed
- Fallback responses until Ollama installed
- Full pipeline validation

**Stress Test:**
- Expected: 5/5 connections (100% success rate)
- Concurrent message handling
- No daemon crashes or memory leaks

Ready to test your handheld network without leaving your chair! 🛋️✨