# Issue #009: Message Protocol Implementation (F005 partial)

**Priority**: High  
**Phase**: 3.3 (Networking Foundation)  
**Estimated Effort**: 3-4 days  
**Dependencies**: #008  

## Problem Description

Implement the binary message protocol for peer-to-peer communication 
including message serialization, routing, sequence numbers, and 
authentication tag verification as specified in the multiplayer protocol.

## Current Behavior

Cryptographic system exists but no structured message protocol.

## Expected Behavior

Robust message protocol handling all game communication with proper 
serialization, routing, sequence tracking, and error handling.

## Implementation Approach

### Message Structure Definition
```lua
-- {{{ MessageProtocol
local MessageProtocol = {
  MAGIC_HEADER = "HLTD",
  PROTOCOL_VERSION = 0x0001,
  
  MESSAGE_TYPES = {
    DISCOVERY = 0x0001,
    INVITE = 0x0002,
    JOIN_REQUEST = 0x0003,
    JOIN_ACCEPT = 0x0004,
    JOIN_REJECT = 0x0005,
    KEY_EXCHANGE = 0x0006,
    GAME_STATE = 0x0007,
    STATE_DELTA = 0x0008,
    PLAYER_ACTION = 0x0009,
    CONSENSUS_PROPOSAL = 0x000A,
    CONSENSUS_VOTE = 0x000B,
    CONSENSUS_COMMIT = 0x000C,
    HEARTBEAT = 0x000D,
    DISCONNECT = 0x000E,
    ERROR = 0x000F
  }
}

-- {{{ createMessage
function MessageProtocol:createMessage(messageType, payload, sequenceNum)
  local message = {
    header = {
      magic = self.MAGIC_HEADER,
      version = self.PROTOCOL_VERSION,
      messageType = messageType,
      sequenceNumber = sequenceNum or 0,
      payloadLength = #payload
    },
    payload = payload,
    authTag = nil -- Set during encryption
  }
  
  return message
end
-- }}}

-- {{{ serializeMessage
function MessageProtocol:serializeMessage(message)
  local buffer = {}
  
  -- Magic header (4 bytes)
  table.insert(buffer, message.header.magic)
  
  -- Protocol version (2 bytes)
  table.insert(buffer, string.pack("<I2", message.header.version))
  
  -- Message type (2 bytes)
  table.insert(buffer, string.pack("<I2", message.header.messageType))
  
  -- Sequence number (4 bytes)
  table.insert(buffer, string.pack("<I4", message.header.sequenceNumber))
  
  -- Payload length (4 bytes)
  table.insert(buffer, string.pack("<I4", message.header.payloadLength))
  
  -- Encrypted payload (N bytes)
  table.insert(buffer, message.payload)
  
  -- Authentication tag (16 bytes)
  table.insert(buffer, message.authTag or string.rep("\0", 16))
  
  return table.concat(buffer)
end
-- }}}

-- {{{ deserializeMessage
function MessageProtocol:deserializeMessage(data)
  if #data < 32 then
    return nil, "Message too short"
  end
  
  local offset = 1
  
  -- Magic header
  local magic = data:sub(offset, offset + 3)
  offset = offset + 4
  
  if magic ~= self.MAGIC_HEADER then
    return nil, "Invalid magic header"
  end
  
  -- Protocol version
  local version = string.unpack("<I2", data, offset)
  offset = offset + 2
  
  if version ~= self.PROTOCOL_VERSION then
    return nil, "Unsupported protocol version"
  end
  
  -- Message type
  local messageType = string.unpack("<I2", data, offset)
  offset = offset + 2
  
  -- Sequence number
  local sequenceNumber = string.unpack("<I4", data, offset)
  offset = offset + 4
  
  -- Payload length
  local payloadLength = string.unpack("<I4", data, offset)
  offset = offset + 4
  
  if #data < offset + payloadLength + 15 then
    return nil, "Incomplete message"
  end
  
  -- Encrypted payload
  local payload = data:sub(offset, offset + payloadLength - 1)
  offset = offset + payloadLength
  
  -- Authentication tag
  local authTag = data:sub(offset, offset + 15)
  
  return {
    header = {
      magic = magic,
      version = version,
      messageType = messageType,
      sequenceNumber = sequenceNumber,
      payloadLength = payloadLength
    },
    payload = payload,
    authTag = authTag
  }
end
-- }}}
```

### Message Routing System
```lua
-- {{{ MessageRouter
local MessageRouter = {
  handlers = {},
  sequenceNumbers = {},
  recentMessages = {} -- For duplicate detection
}

-- {{{ registerHandler
function MessageRouter:registerHandler(messageType, handler)
  self.handlers[messageType] = handler
end
-- }}}

-- {{{ routeMessage
function MessageRouter:routeMessage(message, sender)
  -- Validate message type
  if not self.handlers[message.header.messageType] then
    return false, "Unknown message type"
  end
  
  -- Check for duplicate messages
  local messageId = sender.id .. ":" .. message.header.sequenceNumber
  if self.recentMessages[messageId] then
    return false, "Duplicate message"
  end
  
  -- Validate sequence number
  local lastSeq = self.sequenceNumbers[sender.id] or 0
  if message.header.sequenceNumber <= lastSeq then
    return false, "Out of order message"
  end
  
  -- Update sequence tracking
  self.sequenceNumbers[sender.id] = message.header.sequenceNumber
  self.recentMessages[messageId] = os.time()
  
  -- Route to handler
  local handler = self.handlers[message.header.messageType]
  return handler(message, sender)
end
-- }}}

-- {{{ cleanupOldMessages
function MessageRouter:cleanupOldMessages()
  local cutoff = os.time() - 300 -- 5 minutes
  
  for messageId, timestamp in pairs(self.recentMessages) do
    if timestamp < cutoff then
      self.recentMessages[messageId] = nil
    end
  end
end
-- }}}
```

### Sequence Number Management
```lua
-- {{{ SequenceManager
local SequenceManager = {
  outgoingSequence = 0,
  incomingSequences = {},
  maxSequenceGap = 1000
}

-- {{{ getNextSequence
function SequenceManager:getNextSequence()
  self.outgoingSequence = self.outgoingSequence + 1
  return self.outgoingSequence
end
-- }}}

-- {{{ validateSequence
function SequenceManager:validateSequence(senderId, sequenceNum)
  local lastSeq = self.incomingSequences[senderId] or 0
  
  -- Check for reasonable sequence progression
  if sequenceNum <= lastSeq then
    return false, "Sequence number too old"
  end
  
  if sequenceNum > lastSeq + self.maxSequenceGap then
    return false, "Sequence number too far ahead"
  end
  
  self.incomingSequences[senderId] = sequenceNum
  return true
end
-- }}}

-- {{{ resetSequence
function SequenceManager:resetSequence(senderId)
  self.incomingSequences[senderId] = 0
end
-- }}}
```

### Message Serialization
```lua
-- {{{ Serializer
local Serializer = {}

-- {{{ serializeGameState
function Serializer:serializeGameState(gameState)
  local data = {
    tick = gameState.tick,
    players = {},
    towers = {},
    enemies = {},
    resources = gameState.resources,
    currentWave = gameState.currentWave,
    phase = gameState.phase
  }
  
  -- Serialize players
  for id, player in pairs(gameState.players) do
    data.players[id] = {
      id = player.id,
      name = player.name,
      lane = player.lane,
      resources = player.resources
    }
  end
  
  -- Serialize towers
  for id, tower in pairs(gameState.towers) do
    data.towers[id] = {
      id = tower.id,
      type = tower.type,
      position = tower.position,
      stats = tower.stats,
      state = tower.state
    }
  end
  
  -- Serialize enemies
  for id, enemy in pairs(gameState.enemies) do
    data.enemies[id] = {
      id = enemy.id,
      type = enemy.type,
      position = enemy.position,
      target = enemy.target,
      stats = enemy.stats,
      path = enemy.path
    }
  end
  
  return self:encodeTable(data)
end
-- }}}

-- {{{ serializePlayerAction
function Serializer:serializePlayerAction(action)
  local data = {
    type = action.type,
    playerId = action.playerId,
    timestamp = action.timestamp,
    parameters = action.parameters
  }
  
  return self:encodeTable(data)
end
-- }}}

-- {{{ encodeTable
function Serializer:encodeTable(table)
  -- Simple JSON-like encoding for Lua tables
  -- In production, consider using msgpack or similar
  local function encode(obj)
    if type(obj) == "table" then
      if #obj > 0 then
        -- Array
        local items = {}
        for i, v in ipairs(obj) do
          table.insert(items, encode(v))
        end
        return "[" .. table.concat(items, ",") .. "]"
      else
        -- Object
        local items = {}
        for k, v in pairs(obj) do
          table.insert(items, '"' .. tostring(k) .. '":' .. encode(v))
        end
        return "{" .. table.concat(items, ",") .. "}"
      end
    elseif type(obj) == "string" then
      return '"' .. obj:gsub('"', '\\"') .. '"'
    elseif type(obj) == "number" then
      return tostring(obj)
    elseif type(obj) == "boolean" then
      return obj and "true" or "false"
    else
      return "null"
    end
  end
  
  return encode(table)
end
-- }}}

-- {{{ decodeTable
function Serializer:decodeTable(data)
  -- Simple JSON-like decoding
  -- In production, use proper JSON parser
  local function decode(str)
    -- This is a simplified parser - use proper JSON library
    local func = load("return " .. str)
    if func then
      return func()
    end
    return nil
  end
  
  return decode(data)
end
-- }}}
```

### Message Batching
```lua
-- {{{ MessageBatcher
local MessageBatcher = {
  pendingMessages = {},
  batchTimeout = 0.016, -- 16ms (60 FPS)
  maxBatchSize = 8
}

-- {{{ addMessage
function MessageBatcher:addMessage(message, recipient)
  if not self.pendingMessages[recipient] then
    self.pendingMessages[recipient] = {
      messages = {},
      deadline = socket.gettime() + self.batchTimeout
    }
  end
  
  local batch = self.pendingMessages[recipient]
  table.insert(batch.messages, message)
  
  -- Send immediately if batch is full
  if #batch.messages >= self.maxBatchSize then
    self:sendBatch(recipient)
  end
end
-- }}}

-- {{{ processBatches
function MessageBatcher:processBatches()
  local now = socket.gettime()
  
  for recipient, batch in pairs(self.pendingMessages) do
    if now >= batch.deadline or #batch.messages >= self.maxBatchSize then
      self:sendBatch(recipient)
    end
  end
end
-- }}}

-- {{{ sendBatch
function MessageBatcher:sendBatch(recipient)
  local batch = self.pendingMessages[recipient]
  if not batch or #batch.messages == 0 then
    return
  end
  
  if #batch.messages == 1 then
    -- Send single message
    NetworkLayer:sendMessage(batch.messages[1], recipient)
  else
    -- Send as batch
    local batchMessage = {
      type = "BATCH",
      count = #batch.messages,
      messages = batch.messages
    }
    NetworkLayer:sendMessage(batchMessage, recipient)
  end
  
  self.pendingMessages[recipient] = nil
end
-- }}}
```

## Acceptance Criteria

- [ ] Messages serialize and deserialize correctly
- [ ] Message routing works for all message types
- [ ] Sequence numbers prevent replay attacks
- [ ] Duplicate message detection functional
- [ ] Message batching reduces network overhead
- [ ] Authentication tags verified properly
- [ ] Invalid messages rejected with clear errors
- [ ] Message handlers can be registered and unregistered
- [ ] Performance adequate for real-time gaming
- [ ] Memory usage bounded and reasonable
- [ ] Cross-platform compatibility maintained
- [ ] Error conditions handled gracefully

## Technical Notes

### Performance Requirements
- Message serialization < 1ms for typical messages
- Message routing < 0.5ms per message
- Batch processing < 5ms per batch
- Memory usage < 10MB for message buffers

### Protocol Considerations
- Big-endian vs little-endian handling
- Variable-length payload support
- Future protocol version compatibility
- Message size limits and validation

## Test Cases

1. **Message Serialization**
   - Round-trip serialization accuracy
   - Large message handling
   - Invalid data rejection

2. **Message Routing**
   - Correct handler invocation
   - Unknown message type handling
   - Sequence validation

3. **Batching**
   - Batch size optimization
   - Timeout handling
   - Single vs batch messages

4. **Error Handling**
   - Malformed message rejection
   - Network error recovery
   - Resource exhaustion handling

## Integration Points

- **Cryptographic System**: Message encryption/decryption
- **Network Layer**: Transport and delivery
- **Game Engine**: Game state synchronization
- **Connection Management**: Peer communication

## Future Considerations

- Compression for large messages
- Priority queuing for urgent messages
- Message acknowledgment system
- Advanced routing algorithms