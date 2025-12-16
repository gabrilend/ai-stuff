# Healer-TD Peer-to-Peer Protocol Specification

## Overview

The Healer-TD multiplayer system uses a distributed peer-to-peer 
architecture built on Luasocket. Each player runs an integrated 
client-server application that communicates directly with other players 
using encrypted bytecode messages. This design eliminates the need for 
dedicated servers while providing security and ease of use.

## Protocol Architecture

### Design Principles
- **Zero Configuration**: Works immediately without setup
- **NAT Friendly**: Functions on public wifi and restricted networks
- **Encrypted**: All traffic secured with modern cryptography
- **Fault Tolerant**: Handles network issues and player disconnections
- **Bandwidth Efficient**: Minimal data transfer requirements

### Network Topology
```
    Player A ←────────→ Player B
       ↑                   ↑
       │      Mesh P2P     │
       ↓                   ↓
    Player D ←────────→ Player C
```

Each player maintains direct connections to all other players in the game, 
forming a complete mesh network for optimal performance and redundancy.

## Message Protocol

### Binary Message Format
```
Healer-TD Message Structure (32+ bytes):
┌─────────────────────────────────────────────────────────────┐
│ Magic Header (4 bytes): "HLTD"                             │
├─────────────────────────────────────────────────────────────┤
│ Protocol Version (2 bytes): 0x0001                         │
├─────────────────────────────────────────────────────────────┤
│ Message Type (2 bytes): See message types below            │
├─────────────────────────────────────────────────────────────┤
│ Sequence Number (4 bytes): Monotonic counter               │
├─────────────────────────────────────────────────────────────┤
│ Payload Length (4 bytes): Length of encrypted data         │
├─────────────────────────────────────────────────────────────┤
│ Encrypted Payload (N bytes): Game data                     │
├─────────────────────────────────────────────────────────────┤
│ Authentication Tag (16 bytes): Poly1305 MAC                │
└─────────────────────────────────────────────────────────────┘
```

### Message Types
- **0x0001 DISCOVERY**: Broadcast game availability on local network
- **0x0002 INVITE**: Share invite code for remote connections
- **0x0003 JOIN_REQUEST**: Request to join existing game
- **0x0004 JOIN_ACCEPT**: Accept player into game
- **0x0005 JOIN_REJECT**: Reject player (game full/private)
- **0x0006 KEY_EXCHANGE**: Diffie-Hellman key negotiation
- **0x0007 GAME_STATE**: Complete game state synchronization
- **0x0008 STATE_DELTA**: Incremental state changes
- **0x0009 PLAYER_ACTION**: Individual player actions
- **0x000A CONSENSUS_PROPOSAL**: Leader's state update proposal
- **0x000B CONSENSUS_VOTE**: Vote on proposed state change
- **0x000C CONSENSUS_COMMIT**: Commit agreed state change
- **0x000D HEARTBEAT**: Connection keepalive
- **0x000E DISCONNECT**: Graceful disconnection
- **0x000F ERROR**: Error notification

## Connection Establishment

### Local Network Discovery
```lua
-- Broadcast discovery on local subnet
function broadcastDiscovery()
  local udp = socket.udp()
  udp:setsockname("*", 0)
  udp:setoption("broadcast", true)
  
  local message = {
    type = "DISCOVERY",
    gameId = generateGameId(),
    playerName = getPlayerName(),
    gameMode = "cooperative",
    currentPlayers = 1,
    maxPlayers = 4
  }
  
  udp:sendto(serialize(message), "255.255.255.255", 7777)
  udp:close()
end
```

### Invite Code System
Invite codes encode connection information in a user-friendly format:
```
Format: [2 chars: checksum][4 chars: encoded data]
Example: "AB1234"

Encoded data contains:
- External IP address (32 bits)
- Port number (16 bits)
- Game ID hash (16 bits)
```

### Connection Process
1. **Initiation**: Player creates game or uses invite code
2. **Discovery**: Attempt local network discovery first
3. **Direct Connect**: Try direct TCP connection to target
4. **NAT Traversal**: Simultaneous TCP connect for NAT punch-through
5. **Relay Fallback**: Use public relay server if direct fails
6. **Encryption Setup**: Perform Diffie-Hellman key exchange
7. **Authentication**: Verify game compatibility and permissions

## Encryption and Security

### Key Management
```lua
-- Key derivation using HKDF
function deriveKeys(sharedSecret, gameId, playerId)
  local info = gameId .. "|" .. playerId
  local key = hkdf(sharedSecret, "", info, 32)
  return {
    encryptionKey = key:sub(1, 16),
    authKey = key:sub(17, 32)
  }
end
```

### Cipher Suite
- **Key Exchange**: X25519 Elliptic Curve Diffie-Hellman
- **Encryption**: ChaCha20 stream cipher
- **Authentication**: Poly1305 MAC
- **Key Derivation**: HKDF-SHA256
- **Random Generation**: Platform cryptographic API

### Security Features
- Perfect forward secrecy with ephemeral keys
- Replay protection using sequence numbers
- Message authentication preventing tampering
- Key rotation every 1000 messages or 10 minutes
- Secure memory clearing on key destruction

## Distributed Consensus Protocol

### Leader Election
```lua
function electLeader(players)
  -- Deterministic leader selection based on player IDs
  table.sort(players, function(a, b) return a.id < b.id end)
  return players[1] -- Player with lexicographically smallest ID
end
```

### State Synchronization
1. **Proposal Phase** (Leader):
   - Collect player actions from previous tick
   - Calculate new game state
   - Propose state update to all players

2. **Validation Phase** (All Players):
   - Verify proposed state changes are valid
   - Check against local game rules
   - Send vote (accept/reject) to leader

3. **Commitment Phase** (Leader):
   - Require 2/3 majority for state advancement
   - Broadcast commitment message to all players
   - Begin next tick cycle

### Conflict Resolution
```lua
function handleConflict(localState, proposedState)
  if not validateStateTransition(localState, proposedState) then
    return "REJECT"
  end
  
  -- Apply deterministic conflict resolution
  local resolvedState = mergeStates(localState, proposedState)
  
  if checkStateConsistency(resolvedState) then
    return "ACCEPT"
  else
    return "REJECT"
  end
end
```

## NAT Traversal Techniques

### UDP Hole Punching
```lua
function punchHole(targetIP, targetPort)
  local udp = socket.udp()
  udp:setsockname("*", 0)
  
  -- Send packets to establish NAT mapping
  for i = 1, 5 do
    udp:sendto("PUNCH", targetIP, targetPort)
    socket.sleep(0.1)
  end
  
  return udp
end
```

### Simultaneous TCP Connect
For symmetric NATs, both players attempt connection simultaneously:
```lua
function simultaneousConnect(targetIP, targetPort, localPort)
  local sock = socket.tcp()
  sock:bind("*", localPort)
  sock:settimeout(0) -- Non-blocking
  
  local result = sock:connect(targetIP, targetPort)
  -- Handle EINPROGRESS and retry logic
  
  return sock
end
```

### Relay Server Fallback
When direct connection fails, use public relay:
```lua
function connectViaRelay(gameId, playerId)
  local relay = socket.tcp()
  relay:connect("relay.healer-td.net", 443)
  
  local request = {
    action = "join",
    gameId = gameId,
    playerId = playerId
  }
  
  relay:send(serialize(request))
  return relay
end
```

## Performance Optimization

### Message Batching
```lua
function batchMessages(messages)
  local batch = {
    type = "BATCH",
    count = #messages,
    messages = messages
  }
  return serialize(batch)
end
```

### Delta Compression
Only transmit changed game state:
```lua
function createStateDelta(oldState, newState)
  local delta = {}
  
  for key, value in pairs(newState) do
    if oldState[key] ~= value then
      delta[key] = value
    end
  end
  
  return delta
end
```

### Adaptive Quality
Adjust update frequency based on network conditions:
```lua
function adaptQuality(latency, packetLoss)
  if latency > 200 or packetLoss > 0.05 then
    return "LOW_QUALITY"  -- Reduce update frequency
  elseif latency < 50 and packetLoss < 0.01 then
    return "HIGH_QUALITY" -- Maximum update rate
  else
    return "NORMAL_QUALITY"
  end
end
```

## Error Handling and Recovery

### Network Fault Detection
```lua
function detectNetworkFault(player)
  local now = getTime()
  
  if now - player.lastHeartbeat > HEARTBEAT_TIMEOUT then
    return "TIMEOUT"
  elseif player.consecutiveErrors > MAX_ERRORS then
    return "EXCESSIVE_ERRORS"
  elseif player.sequenceGap > MAX_SEQUENCE_GAP then
    return "DESYNC"
  end
  
  return "OK"
end
```

### Automatic Recovery
- **Timeout**: Attempt reconnection with exponential backoff
- **Desync**: Request full state resync from majority consensus
- **Corruption**: Disconnect and ban malicious players
- **Partition**: Continue with available players, allow rejoin

## Implementation Examples

### Basic Server Loop
```lua
function serverLoop()
  local server = socket.tcp()
  server:bind("*", getRandomPort())
  server:listen(4)
  server:settimeout(0)
  
  while running do
    local client = server:accept()
    if client then
      handleNewConnection(client)
    end
    
    processExistingConnections()
    updateGameState()
    socket.sleep(0.016) -- 60 FPS
  end
end
```

### Message Processing
```lua
function processMessage(data, sender)
  local message = deserialize(data)
  
  if not validateMessage(message, sender) then
    return false
  end
  
  local decrypted = decrypt(message.payload, sender.key)
  local parsed = deserialize(decrypted)
  
  return handleGameMessage(parsed, sender)
end
```

### Game State Synchronization
```lua
function synchronizeState()
  if isLeader() then
    proposeStateUpdate()
  else
    waitForProposal()
  end
  
  local votes = collectVotes()
  
  if hasConsensus(votes) then
    commitStateChange()
  else
    rollbackToLastValidState()
  end
end
```

## Security Considerations

### Attack Prevention
- Rate limiting prevents message flooding
- Input validation on all received data
- Cryptographic verification of state changes
- Resource limits prevent memory exhaustion

### Privacy Protection
- No persistent user data storage
- Anonymous gameplay without registration
- Automatic cleanup of temporary files
- Secure deletion of cryptographic keys

This protocol enables secure, easy-to-use multiplayer gaming that works 
anywhere without complex setup while maintaining high performance and 
reliability.