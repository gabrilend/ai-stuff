# Healer-TD Technical Specification

## System Architecture

### Core Components
- **Game Engine**: Turn-based simulation with real-time rendering
- **Network Layer**: Peer-to-peer Luasocket-based synchronization
- **UI Framework**: Terminal-based interface with multiple rendering modes
- **State Management**: Distributed game state with consensus protocol
- **Encryption Module**: Custom encryption for secure communication

### Technology Stack
- **Language**: Lua with C extensions for performance-critical sections
- **Networking**: Luasocket with custom P2P protocol
- **Encryption**: ChaCha20-Poly1305 or custom cipher suite
- **Graphics**: Terminal escape sequences, optional sixel support
- **Storage**: Local state persistence with conflict resolution

## Peer-to-Peer Network Architecture

### Network Topology
```
Player 1 (Client+Server) ←→ Player 2 (Client+Server)
        ↓                           ↓
Player 4 (Client+Server) ←→ Player 3 (Client+Server)
```

### Connection Management
- Each player runs integrated client/server application
- Discovery through local network broadcast or invite codes
- Automatic NAT traversal using STUN-like techniques
- Fallback relay server for impossible connections

### Message Protocol
```
Message Structure:
[4 bytes: Magic Header "HLTD"]
[2 bytes: Protocol Version]
[2 bytes: Message Type]
[4 bytes: Payload Length]
[N bytes: Encrypted Payload]
[16 bytes: Authentication Tag]
```

### Message Types
- **DISCOVERY**: Broadcast game availability
- **JOIN_REQUEST**: Request to join game
- **JOIN_RESPONSE**: Accept/reject join request
- **GAME_STATE**: Synchronized game state update
- **PLAYER_ACTION**: Individual player actions
- **HEARTBEAT**: Connection keepalive
- **DISCONNECT**: Graceful leave notification

## Encryption System

### Key Exchange
- **Initial**: Diffie-Hellman key exchange for session keys
- **Per-Game**: Derive game-specific keys using HKDF
- **Authentication**: HMAC-SHA256 for message authentication
- **Forward Secrecy**: Rotate keys every 100 game ticks

### Cipher Suite
```
Encryption: ChaCha20 (or custom stream cipher)
Authentication: Poly1305 MAC
Key Derivation: HKDF-SHA256
Random Generation: /dev/urandom or Windows CryptoAPI
```

### Security Features
- All game traffic encrypted end-to-end
- Perfect forward secrecy with key rotation
- Replay attack prevention with sequence numbers
- Tamper detection and automatic disconnection

## Game State Management

### Distributed State Structure
```
GameState {
  metadata: {
    gameId: uuid,
    tick: number,
    players: Map<PlayerId, PlayerInfo>,
    consensus: ConsensusState
  },
  gameData: {
    currentWave: number,
    globalEvents: Event[],
    playerStates: Map<PlayerId, PlayerState>
  }
}

PlayerState {
  lane: BattleField,
  towers: Map<Position, Tower>,
  resources: Resources,
  actions: ActionQueue,
  lastUpdate: timestamp
}
```

### Consensus Protocol
- **Leader Election**: Rotating leadership based on player join order
- **State Proposals**: Leader proposes state updates each tick
- **Validation**: All players validate proposed changes
- **Commitment**: 2/3 majority required for state advancement
- **Conflict Resolution**: Rollback and re-apply on disagreement

### Synchronization Process
1. **Collection Phase** (0-200ms): Gather player actions
2. **Proposal Phase** (200-400ms): Leader creates state update
3. **Validation Phase** (400-600ms): Players validate proposal
4. **Commitment Phase** (600-800ms): Apply agreed changes
5. **Distribution Phase** (800-1000ms): Sync final state

## NAT Traversal and Discovery

### Local Network Discovery
```lua
-- Broadcast discovery message
socket = require("socket")
udp = socket.udp()
udp:setsockname("*", 0)
udp:setoption("broadcast", true)
udp:sendto("HLTD_DISCOVER", "255.255.255.255", 7777)
```

### Connection Establishment
1. **Local Discovery**: UDP broadcast on subnet
2. **Direct Connect**: Attempt direct TCP connection
3. **Hole Punching**: Simultaneous connect through NAT
4. **Relay Fallback**: Use public relay server if needed

### Invite Code System
- Generate shareable 6-character codes
- Encode IP address and port in base32
- Optional QR code generation for mobile sharing
- Expire codes after 30 minutes

## Performance Optimization

### Network Efficiency
- **Delta Compression**: Only send state changes
- **Message Batching**: Combine small messages
- **Adaptive Quality**: Reduce update frequency on slow connections
- **Predictive Updates**: Client-side prediction with rollback

### Memory Management
- **Object Pooling**: Reuse network message objects
- **Garbage Collection**: Minimize allocations in hot paths
- **State Pruning**: Remove old game history periodically
- **Efficient Serialization**: Custom binary format for game data

### CPU Optimization
- **Incremental Processing**: Spread work across multiple ticks
- **Spatial Partitioning**: Optimize collision detection
- **Cached Calculations**: Store expensive computation results
- **Async I/O**: Non-blocking network operations

## Security Considerations

### Attack Prevention
- **Rate Limiting**: Prevent message flooding
- **Input Validation**: Sanitize all received data
- **Resource Limits**: Cap memory and CPU usage
- **Cryptographic Verification**: Validate all state changes

### Privacy Protection
- **No Persistent Storage**: Clear game data on exit
- **Local Processing**: Minimize data sent over network
- **Anonymous Play**: No required user registration
- **Secure Cleanup**: Overwrite memory on deallocation

## Error Handling and Recovery

### Network Failures
- **Connection Timeout**: Automatic reconnection attempts
- **Partial Connectivity**: Continue with available players
- **State Desync**: Detect and recover from inconsistencies
- **Byzantine Faults**: Handle malicious or corrupted players

### Recovery Procedures
```lua
function handleNetworkError(error, player)
  if error.type == "timeout" then
    return retryConnection(player, exponentialBackoff)
  elseif error.type == "desync" then
    return initiateStateRecovery(player)
  elseif error.type == "byzantine" then
    return removePlayer(player)
  end
end
```

## Platform Support

### Primary Targets
- **Linux**: Full feature support with epoll networking
- **macOS**: Full support with kqueue networking
- **Windows**: Full support with IOCP networking

### Dependencies
- **Luasocket**: Core networking functionality
- **LuaCrypto**: Encryption and hashing (or custom implementation)
- **LuaFileSystem**: File operations
- **Terminal Libraries**: Platform-specific terminal control

## Development and Testing

### Network Simulation
- **Latency Injection**: Simulate high-latency connections
- **Packet Loss**: Test resilience to network issues
- **Bandwidth Limiting**: Verify low-bandwidth operation
- **Connection Drops**: Test reconnection logic

### Security Testing
- **Penetration Testing**: Attempt to break encryption
- **Fuzzing**: Send malformed messages
- **Load Testing**: Stress test with many players
- **Privacy Auditing**: Verify no data leakage

### Debug Features
- **Network Inspector**: Real-time message logging
- **State Visualizer**: Display consensus process
- **Performance Profiler**: Identify bottlenecks
- **Encryption Validator**: Verify cryptographic correctness

## Deployment Considerations

### Binary Distribution
- **Single Executable**: Bundle all dependencies
- **Cross-Platform**: Support major operating systems
- **Auto-Update**: Secure update mechanism
- **Portable Mode**: No installation required

### Configuration
- **Zero Configuration**: Work out of box
- **Advanced Options**: Network tuning parameters
- **Firewall Friendly**: Minimize required ports
- **Offline Mode**: Single-player functionality

This specification enables secure, easy-to-use multiplayer gaming without 
complex network setup while maintaining the terminal-based design philosophy.