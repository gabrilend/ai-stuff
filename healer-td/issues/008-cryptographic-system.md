# Issue #008: Cryptographic System (F005 partial)

**Priority**: High  
**Phase**: 3.2 (Networking Foundation)  
**Estimated Effort**: 4-5 days  
**Dependencies**: #007  

## Problem Description

Implement the cryptographic system for secure peer-to-peer communication 
including ChaCha20-Poly1305 encryption, X25519 key exchange, HKDF key 
derivation, and secure random number generation.

## Current Behavior

Basic networking exists but no encryption or security.

## Expected Behavior

Production-grade cryptographic system providing end-to-end encryption, 
perfect forward secrecy, and authentication for all multiplayer 
communication.

## Implementation Approach

### Core Cryptographic Primitives
```lua
-- {{{ Crypto
local Crypto = {
  initialized = false,
  randomSource = nil
}

-- {{{ init
function Crypto:init()
  -- Initialize platform-specific CSPRNG
  -- Test cryptographic functions
  -- Set up secure memory handling
  self.randomSource = self:initRandomSource()
  self.initialized = true
  return self.randomSource ~= nil
end
-- }}}

-- {{{ initRandomSource
function Crypto:initRandomSource()
  local platform = self:detectPlatform()
  
  if platform == "linux" or platform == "macos" then
    -- Use /dev/urandom
    local file = io.open("/dev/urandom", "rb")
    if file then
      return {
        type = "urandom",
        file = file
      }
    end
  elseif platform == "windows" then
    -- Use Windows CryptoAPI
    return {
      type = "cryptoapi"
    }
  end
  
  -- Fallback to Lua math.random (NOT cryptographically secure)
  math.randomseed(os.time())
  return {
    type = "fallback"
  }
end
-- }}}

-- {{{ randomBytes
function Crypto:randomBytes(count)
  if not self.initialized then
    error("Crypto not initialized")
  end
  
  if self.randomSource.type == "urandom" then
    return self.randomSource.file:read(count)
  elseif self.randomSource.type == "cryptoapi" then
    return self:windowsRandomBytes(count)
  else
    -- Fallback - NOT secure for production
    local bytes = {}
    for i = 1, count do
      bytes[i] = string.char(math.random(0, 255))
    end
    return table.concat(bytes)
  end
end
-- }}}
```

### ChaCha20 Stream Cipher
```lua
-- {{{ ChaCha20
local ChaCha20 = {}

-- {{{ encrypt
function ChaCha20:encrypt(plaintext, key, nonce)
  -- ChaCha20 encryption implementation
  -- Key: 32 bytes, Nonce: 12 bytes
  assert(#key == 32, "Key must be 32 bytes")
  assert(#nonce == 12, "Nonce must be 12 bytes")
  
  local keystream = self:generateKeystream(key, nonce, #plaintext)
  local ciphertext = {}
  
  for i = 1, #plaintext do
    local p = string.byte(plaintext, i)
    local k = string.byte(keystream, i)
    ciphertext[i] = string.char(p ~ k) -- XOR
  end
  
  return table.concat(ciphertext)
end
-- }}}

-- {{{ generateKeystream
function ChaCha20:generateKeystream(key, nonce, length)
  -- ChaCha20 quarter round and block function
  local blocks = math.ceil(length / 64)
  local keystream = {}
  
  for block = 0, blocks - 1 do
    local state = self:initializeState(key, nonce, block)
    local blockOutput = self:chachaBlock(state)
    
    for i = 1, math.min(64, length - block * 64) do
      keystream[block * 64 + i] = string.char(blockOutput[i])
    end
  end
  
  return table.concat(keystream)
end
-- }}}

-- {{{ chachaBlock
function ChaCha20:chachaBlock(state)
  local working = {}
  for i = 1, 16 do
    working[i] = state[i]
  end
  
  -- 20 rounds (10 double rounds)
  for i = 1, 10 do
    self:doubleRound(working)
  end
  
  -- Add original state
  for i = 1, 16 do
    working[i] = (working[i] + state[i]) & 0xFFFFFFFF
  end
  
  -- Convert to bytes
  local output = {}
  for i = 1, 16 do
    local word = working[i]
    for j = 0, 3 do
      output[i * 4 - 3 + j] = (word >> (j * 8)) & 0xFF
    end
  end
  
  return output
end
-- }}}
```

### Poly1305 MAC
```lua
-- {{{ Poly1305
local Poly1305 = {}

-- {{{ authenticate
function Poly1305:authenticate(message, key)
  -- Poly1305 MAC implementation
  assert(#key == 32, "Key must be 32 bytes")
  
  local r = self:clampR(key:sub(1, 16))
  local s = key:sub(17, 32)
  
  local accumulator = 0
  local blocks = math.ceil(#message / 16)
  
  for i = 0, blocks - 1 do
    local blockStart = i * 16 + 1
    local blockEnd = math.min(blockStart + 15, #message)
    local block = message:sub(blockStart, blockEnd)
    
    -- Pad block and convert to number
    local blockNum = self:blockToNumber(block, blockEnd == #message)
    
    -- Accumulate
    accumulator = (accumulator + blockNum) % self.P
    accumulator = (accumulator * r) % self.P
  end
  
  -- Add s
  accumulator = (accumulator + self:bytesToNumber(s)) % (2^128)
  
  return self:numberToBytes(accumulator, 16)
end
-- }}}

-- {{{ clampR
function Poly1305:clampR(r)
  local rBytes = {}
  for i = 1, 16 do
    rBytes[i] = string.byte(r, i)
  end
  
  -- Clamp r according to Poly1305 spec
  rBytes[4] = rBytes[4] & 0x0F
  rBytes[8] = rBytes[8] & 0x0F
  rBytes[12] = rBytes[12] & 0x0F
  rBytes[16] = rBytes[16] & 0x0F
  
  for i = 1, 16, 4 do
    rBytes[i] = rBytes[i] & 0xFC
  end
  
  return string.char(table.unpack(rBytes))
end
-- }}}
```

### X25519 Key Exchange
```lua
-- {{{ X25519
local X25519 = {}

-- {{{ generateKeyPair
function X25519:generateKeyPair()
  local privateKey = Crypto:randomBytes(32)
  local publicKey = self:scalarMultBase(privateKey)
  
  return {
    private = privateKey,
    public = publicKey
  }
end
-- }}}

-- {{{ computeSharedSecret
function X25519:computeSharedSecret(privateKey, publicKey)
  assert(#privateKey == 32, "Private key must be 32 bytes")
  assert(#publicKey == 32, "Public key must be 32 bytes")
  
  return self:scalarMult(privateKey, publicKey)
end
-- }}}

-- {{{ scalarMultBase
function X25519:scalarMultBase(scalar)
  -- Multiply scalar by curve25519 base point
  local basePoint = string.char(9) .. string.rep(string.char(0), 31)
  return self:scalarMult(scalar, basePoint)
end
-- }}}

-- {{{ scalarMult
function X25519:scalarMult(scalar, point)
  -- Curve25519 scalar multiplication
  -- This is a simplified placeholder - use proven implementation
  -- in production (e.g., libsodium bindings)
  
  -- Clamp scalar
  local k = {}
  for i = 1, 32 do
    k[i] = string.byte(scalar, i)
  end
  
  k[1] = k[1] & 0xF8
  k[32] = (k[32] & 0x7F) | 0x40
  
  -- Montgomery ladder implementation would go here
  -- For now, return placeholder
  return Crypto:randomBytes(32) -- PLACEHOLDER
end
-- }}}
```

### HKDF Key Derivation
```lua
-- {{{ HKDF
local HKDF = {}

-- {{{ derive
function HKDF:derive(inputKey, salt, info, length)
  -- HKDF-SHA256 implementation
  salt = salt or string.rep(string.char(0), 32)
  info = info or ""
  
  -- Extract phase
  local prk = self:hmacSha256(salt, inputKey)
  
  -- Expand phase
  local output = {}
  local t = ""
  local counter = 1
  
  while #table.concat(output) < length do
    t = self:hmacSha256(prk, t .. info .. string.char(counter))
    table.insert(output, t)
    counter = counter + 1
  end
  
  return table.concat(output):sub(1, length)
end
-- }}}

-- {{{ hmacSha256
function HKDF:hmacSha256(key, message)
  -- HMAC-SHA256 implementation
  local blockSize = 64
  local outputSize = 32
  
  if #key > blockSize then
    key = self:sha256(key)
  end
  
  if #key < blockSize then
    key = key .. string.rep(string.char(0), blockSize - #key)
  end
  
  local oKeyPad = {}
  local iKeyPad = {}
  
  for i = 1, blockSize do
    local keyByte = string.byte(key, i)
    oKeyPad[i] = string.char(keyByte ~ 0x5C)
    iKeyPad[i] = string.char(keyByte ~ 0x36)
  end
  
  local innerHash = self:sha256(table.concat(iKeyPad) .. message)
  return self:sha256(table.concat(oKeyPad) .. innerHash)
end
-- }}}
```

### Encryption Suite Integration
```lua
-- {{{ EncryptionSuite
local EncryptionSuite = {}

-- {{{ encryptMessage
function EncryptionSuite:encryptMessage(plaintext, sharedSecret, context)
  -- Generate message-specific key
  local messageKey = HKDF:derive(sharedSecret, "", context, 32)
  local nonce = Crypto:randomBytes(12)
  
  -- Encrypt with ChaCha20
  local ciphertext = ChaCha20:encrypt(plaintext, messageKey, nonce)
  
  -- Authenticate with Poly1305
  local authKey = HKDF:derive(messageKey, "", "auth", 32)
  local tag = Poly1305:authenticate(nonce .. ciphertext, authKey)
  
  return {
    nonce = nonce,
    ciphertext = ciphertext,
    tag = tag
  }
end
-- }}}

-- {{{ decryptMessage
function EncryptionSuite:decryptMessage(encrypted, sharedSecret, context)
  -- Derive same keys
  local messageKey = HKDF:derive(sharedSecret, "", context, 32)
  local authKey = HKDF:derive(messageKey, "", "auth", 32)
  
  -- Verify authentication tag
  local expectedTag = Poly1305:authenticate(
    encrypted.nonce .. encrypted.ciphertext, 
    authKey
  )
  
  if not self:constantTimeCompare(encrypted.tag, expectedTag) then
    return nil, "Authentication failed"
  end
  
  -- Decrypt message
  local plaintext = ChaCha20:encrypt( -- ChaCha20 encrypt = decrypt
    encrypted.ciphertext, 
    messageKey, 
    encrypted.nonce
  )
  
  return plaintext
end
-- }}}

-- {{{ constantTimeCompare
function EncryptionSuite:constantTimeCompare(a, b)
  if #a ~= #b then
    return false
  end
  
  local result = 0
  for i = 1, #a do
    result = result | (string.byte(a, i) ~ string.byte(b, i))
  end
  
  return result == 0
end
-- }}}
```

## Acceptance Criteria

- [ ] Secure random number generation works on all platforms
- [ ] ChaCha20 encryption/decryption functional and correct
- [ ] Poly1305 authentication provides message integrity
- [ ] X25519 key exchange generates shared secrets
- [ ] HKDF derives keys correctly from shared secrets
- [ ] End-to-end encryption suite working
- [ ] Key rotation and management implemented
- [ ] Constant-time comparison prevents timing attacks
- [ ] Memory clearing prevents key leakage
- [ ] Performance adequate for real-time gaming
- [ ] Test vectors pass for all algorithms
- [ ] Cross-platform compatibility verified

## Technical Notes

### Security Considerations
- Use proven cryptographic implementations when possible
- Secure memory handling for keys
- Constant-time operations to prevent side-channel attacks
- Perfect forward secrecy through ephemeral keys

### Performance Requirements
- Encryption/decryption < 1ms for typical messages
- Key exchange < 10ms
- Key derivation < 5ms
- Memory usage < 1MB for crypto state

### Implementation Notes
- Consider using LuaCrypto or libsodium bindings for production
- Implement test vectors for all algorithms
- Use secure coding practices throughout
- Plan for hardware acceleration where available

## Test Cases

1. **Basic Cryptographic Operations**
   - Random number generation quality
   - ChaCha20 encryption round-trip
   - Poly1305 authentication verification

2. **Key Exchange**
   - X25519 key pair generation
   - Shared secret computation
   - Key derivation consistency

3. **Integration Testing**
   - End-to-end message encryption
   - Authentication failure detection
   - Key rotation functionality

4. **Security Testing**
   - Timing attack resistance
   - Memory leak detection
   - Invalid input handling

5. **Performance Testing**
   - Encryption throughput measurement
   - Key operation timing
   - Memory usage profiling

## Integration Points

- **Network Layer**: Message encryption/decryption
- **Connection Management**: Key exchange integration
- **Game Protocol**: Authenticated message handling
- **Configuration**: Cryptographic parameter settings

## Future Considerations

- Hardware acceleration support
- Post-quantum cryptography preparation
- Certificate-based authentication
- Advanced key management features