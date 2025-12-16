# Hybrid Networking System

## Overview
Custom networking solution that combines UDP packet delivery with TCP-style reliability, designed for deterministic multiplayer simulation synchronization.

## Advanced Network Architecture Design
The hybrid networking system addresses one of multiplayer gaming's most fundamental challenges: achieving the low latency benefits of UDP communication while maintaining the reliability guarantees essential for deterministic simulation synchronization. Traditional networking solutions force developers to choose between UDP's speed and TCP's reliability, but this system transcends that limitation by implementing a custom protocol that delivers UDP packets with TCP-style confirmation and retransmission mechanisms. This approach is particularly crucial for Dark Volcano's innovative architecture, where GPU-calculated game states require perfect synchronization across all clients to maintain simulation coherence.

The system's elegance lies in its "assume success" philosophy combined with robust failure recovery. Every packet is sent with the optimistic assumption that it will reach its destination, allowing the game to continue processing without waiting for confirmations. However, an underlying reliability layer tracks all unconfirmed packets and manages automatic retransmission when confirmations don't arrive within calculated timeout windows. This creates the best of both worlds: the immediate responsiveness of UDP for successful packet delivery, combined with the eventual consistency guarantees of TCP for packet recovery.

The deterministic simulation component represents perhaps the most sophisticated aspect of this networking approach. Rather than transmitting complete game state updates, the system sends compact bytecode instructions that recreate simulation changes on each client's local game instance. This bytecode represents a form of distributed computing where each client maintains an identical deterministic engine that processes the same sequence of operations in the same order, guaranteeing that all clients arrive at identical game states despite network latency variations and packet delivery irregularities.

The client-side server architecture ensures that each participant maintains a complete, authoritative copy of the game simulation, reducing dependency on any single network node while maintaining perfect synchronization. When conflicts arise—such as simultaneous actions from different players—the server authority model provides definitive resolution while the rollback capabilities allow clients to correct their local simulations retroactively. This creates a multiplayer experience that feels immediate and responsive while maintaining the mathematical precision required for competitive fairness.

## Core Architecture

### Packet Delivery Strategy
- **Base Protocol**: UDP for speed and reduced overhead
- **Reliability Layer**: TCP-style confirmation system for critical data
- **Assumption Model**: Packets assumed delivered until proven otherwise
- **Retry Mechanism**: Unconfirmed packets resent after timeout

The packet delivery strategy optimizes for the common case while preparing for failure scenarios, creating a network protocol that performs like UDP under ideal conditions while maintaining TCP-level reliability under adverse circumstances. This approach is particularly well-suited to Dark Volcano's real-time requirements, where even small network hiccups can cascade into visible gameplay disruptions if not handled gracefully. The assumption model allows the game to maintain its responsive feel even during network instability, while the retry mechanisms ensure that critical game state changes eventually reach all participants, maintaining long-term synchronization integrity.

### Packet Types
1. **Simulation Changes**: Player actions that modify game state
2. **Confirmation Packets**: Acknowledgment of received simulation changes  
3. **State Sync**: Periodic full state synchronization for error correction
4. **Heartbeat**: Connection status and timing synchronization

## Technical Implementation

### Packet Structure
```
Packet {
    id: unique_identifier
    type: enum(simulation_change, confirmation, state_sync, heartbeat)
    timestamp: game_time
    bytecode: simulation_commands
    checksum: integrity_validation
}
```

### Unconfirmed Packets List
- **Storage**: Queue of sent packets awaiting confirmation
- **Timeout Tracking**: Timestamp when each packet should be retransmitted
- **Retry Limit**: Maximum attempts before considering connection lost
- **Cleanup**: Remove confirmed packets from list

### Client-Side Deterministic Simulation
- **Bytecode Execution**: Received packets contain commands to modify simulation
- **Deterministic Engine**: Same inputs always produce same outputs
- **State Synchronization**: All clients maintain identical game state
- **Conflict Resolution**: Server authority for disputed states

## Simulation Bytecode System

### Command Structure
```
SimulationCommand {
    opcode: enum(move_unit, attack_target, build_structure, etc.)
    parameters: array<variant>
    player_id: identifier
    sequence_number: ordering
}
```

### Execution Pipeline
1. **Validation**: Verify command legality and player authority
2. **Queuing**: Add to deterministic execution queue
3. **Execution**: Apply changes to simulation state
4. **Broadcasting**: Send changes to all connected clients
5. **Confirmation**: Track receipt confirmation from each client

## Reliability Mechanisms

### Confirmation Cycle
1. Client sends simulation change packet
2. Server processes and broadcasts to all clients
3. Each client sends confirmation packet back
4. Server removes packet from unconfirmed list
5. If no confirmation received within timeout, packet is retransmitted

### Timeout Management
- **Dynamic Timeout**: Adjust based on measured round-trip time
- **Exponential Backoff**: Increase timeout with each retry
- **Connection Health**: Monitor packet loss and adjust strategy

### Error Handling
- **Packet Loss**: Automatic retransmission with timeout
- **Out-of-Order Delivery**: Sequence numbering and reordering
- **Duplicate Packets**: ID-based deduplication
- **Corruption**: Checksum validation and rejection

## Performance Optimizations

### Bandwidth Efficiency
- **Delta Compression**: Only send changes, not full state
- **Batch Processing**: Combine multiple small changes
- **Priority Queuing**: Critical packets sent first
- **Adaptive Rate**: Adjust packet frequency based on network conditions

### Latency Minimization
- **Predictive Input**: Local simulation of player actions
- **Rollback System**: Correct predictions when server state differs
- **Interpolation**: Smooth visual representation between network updates
- **Priority Routing**: Use fastest available network path

## Synchronization Strategy

### State Consistency
- **Deterministic Core**: Same inputs always produce same results
- **Hash Verification**: Periodic state hash comparison between clients
- **Rollback Capability**: Revert to last known good state if desync detected
- **Authority Model**: Server has final say on disputed states

### Clock Synchronization
- **Game Time**: Separate from wall clock time
- **Tick-Based Updates**: Fixed timestep simulation
- **Lag Compensation**: Account for network delay in input processing
- **Catch-Up Mechanism**: Fast-forward slow clients to current state

## Security Considerations

### Anti-Cheat Measures
- **Server Validation**: All commands validated on server before broadcast
- **Rate Limiting**: Prevent command spam attacks
- **Signature Verification**: Cryptographic packet signing
- **State Auditing**: Regular comparison of client states with server

### Connection Security
- **Encrypted Channels**: Secure packet transmission
- **Authentication**: Verify client identity before accepting commands
- **Session Management**: Secure session tokens and timeout handling
- **DDoS Protection**: Rate limiting and connection filtering

## Integration with Game Systems

### Combat System
- **Tick Synchronization**: Combat calculations synchronized across clients
- **Animation Separation**: Visual effects independent of network simulation
- **Damage Application**: Server authoritative damage calculation

### Building System
- **Resource Validation**: Server verifies resource availability
- **Construction Queues**: Synchronized building progress
- **Placement Validation**: Server confirms valid building locations

### Unit Management
- **Position Synchronization**: Regular position updates
- **Command Queuing**: Movement and action commands
- **Formation Maintenance**: Coordinated group movement