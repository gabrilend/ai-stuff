# Cryptographic Communication Vision - Implementation TODO

## Overview

This TODO list outlines the comprehensive implementation plan to achieve the cryptographic communication vision described in `/notes/cryptographic-communication-vision`. The vision transforms the current basic P2P file sharing into a sophisticated, encrypted, walkie-talkie-style communication system with PGP encryption, emoji-based pairing, and relationship-specific keypairs.

## Current State Analysis

### ✅ Already Implemented (Basic P2P)
- Basic file sharing with 32KB chunks
- UDP device discovery  
- TCP file transfers
- Integration into media player, paint program, word processor
- Battery-efficient networking
- SHA-256 file verification

### ❌ Missing from Vision
- PGP encryption for all communications
- Emoji-based device pairing
- Relationship-specific keypairs
- WiFi Direct (no router needed)
- Encrypted packet wrapping
- Contact management with nicknames
- Key expiration and automatic forgetting
- Permission system for server operations
- Bytecode instruction format
- Interactive terminal UI for server daemon
- Public key broadcasting while "walking around"
- Message queuing for offline peers

---

## Implementation Phases

## Phase 1: Cryptographic Foundation 🔐

**Yocto Integration**: Runs parallel with Yocto development - see `/todo/yocto-distribution-implementation.md` Phase 2 for OS-level integration

### 1.1 PGP Key Management System
- [ ] **Create PGP key generation module** (`src/crypto/pgp_manager.rs`)
  - Implement RSA-4096 key generation
  - Support key serialization/deserialization
  - Key storage in encrypted format
  - Per-relationship key generation (not per-device)

- [ ] **Implement key expiration system** (`src/crypto/key_expiration.rs`)
  - Configurable timeout periods (hours/days/weeks)
  - Automatic cleanup of expired keys
  - Warning system before key expiration
  - Graceful handling when one peer forgets but other doesn't

- [ ] **Create relationship key manager** (`src/crypto/relationship_keys.rs`)
  - Map emoji/nickname pairs to specific keypairs
  - Generate unique keypair for each peer relationship
  - Handle key rotation when relationships are re-established
  - Secure key storage with device-specific encryption

### 1.2 Encrypted Packet System
- [ ] **Design packet wrapper format** (`src/crypto/packet_wrapper.rs`)
  - Inner packet: encrypted with relationship-specific PGP key
  - Outer packet: unencrypted with recipient public key identifier
  - Packet integrity verification
  - Anti-replay protection with timestamps

- [ ] **Implement encryption/decryption pipeline** (`src/crypto/message_crypto.rs`)
  - Encrypt messages before sending
  - Decrypt received messages
  - Handle encryption failures gracefully
  - Support for different content types (text, files, commands)

---

## Phase 2: WiFi Direct Infrastructure 📡

**Yocto Integration**: Coordinated with WiFi Direct support in `/todo/yocto-distribution-implementation.md` Task 3.1

### 2.1 WiFi Direct Core
- [ ] **Research WiFi Direct APIs** 
  - Linux cfg80211/nl80211 integration
  - Android WiFi Direct APIs (for potential mobile support)
  - Cross-platform abstraction layer

- [ ] **Implement WiFi Direct manager** (`src/network/wifi_direct.rs`)
  - Device-to-device connections without router
  - Group formation and management
  - Connection state management
  - Fallback to traditional WiFi when needed

- [ ] **Create mesh topology manager** (`src/network/mesh_topology.rs`)
  - Dynamic mesh network formation
  - Route discovery between non-adjacent devices
  - Message forwarding through intermediate peers
  - Network healing when devices disconnect

### 2.2 Advanced Discovery System
- [ ] **Implement public key broadcasting** (`src/network/key_broadcast.rs`)
  - Continuous broadcasting of public keys for active relationships
  - Efficient broadcast scheduling to save battery
  - Public key recognition system
  - Range-based peer detection

- [ ] **Create smart presence system** (`src/network/presence_manager.rs`)
  - Detect when known peers come into range
  - Automatic connection establishment
  - Battery-efficient presence updates
  - "Walking around" simulation for testing

---

## Phase 3: Emoji-Based Pairing System 😊

### 3.1 Pairing Flow Implementation
- [ ] **Design emoji pairing protocol** (`src/pairing/emoji_pairing.rs`)
  - Random emoji assignment for each pairing session
  - Emoji uniqueness within pairing range
  - Fallback to numbers for crowded areas (>100 emojis)
  - Session-specific emoji (not device-persistent)

- [ ] **Create pairing UI components** (`src/ui/pairing_interface.rs`)
  - Pairing button integration with existing controllers
  - Emoji display system for handheld screens
  - List display of available pairing emojis
  - Nickname entry using radial keyboard system

- [ ] **Implement pairing state machine** (`src/pairing/pairing_state.rs`)
  - IDLE → DISCOVERING → PAIRING → PAIRED state flow
  - Timeout handling for abandoned pairing sessions
  - Concurrent pairing session management
  - Error recovery and retry logic

### 3.2 Contact Management
- [ ] **Create contact database** (`src/contacts/contact_manager.rs`)
  - Store nickname mappings to public keys
  - Relationship metadata (pairing date, last seen)
  - Contact categorization and tagging
  - Export/import functionality for contact backup

- [ ] **Implement relationship tracking** (`src/contacts/relationship_tracker.rs`)
  - Track communication frequency
  - Monitor key expiration status
  - Relationship health indicators
  - Activity timeline per contact

---

## Phase 4: Enhanced Input Integration 🎮

**Yocto Integration**: Radial input system development coordinated with `/todo/yocto-distribution-implementation.md` Task 2.3

### 4.1 Controller Integration for Crypto Features
- [ ] **Add pairing mode to input system** (`src/enhanced_input_crypto.rs`)
  - New input mode: `CryptoPairingMode`
  - Configurable pairing button (physical button on device)
  - Emoji navigation with D-pad
  - Nickname entry using existing radial keyboard

- [ ] **Extend P2P browser for encrypted messaging** 
  - Browse encrypted messages from contacts
  - Send encrypted messages to nearby peers
  - Message composition with encryption status indicators
  - Delivery confirmation system

- [ ] **Create secure document sharing mode**
  - Document encryption before P2P sharing
  - Key selection for document recipients
  - Encrypted collaboration sessions
  - Document access control and permissions

### 4.2 UI/UX for Cryptographic Features
- [ ] **Design encryption status indicators**
  - Visual indicators for encryption status
  - Key strength and expiration warnings
  - Connection security level display
  - Error state visualization

- [ ] **Create secure messaging interface**
  - Message composition with emoji keyboard
  - Recipient selection from nearby contacts
  - Message queue display for offline recipients
  - Read receipts and delivery confirmation

---

## Phase 5: Server Daemon Implementation 💻

### 5.1 Interactive Terminal Interface
- [ ] **Create terminal UI framework** (`src/server/terminal_ui.rs`)
  - Interactive menu system for server daemon
  - Real-time status display
  - Command input and output handling
  - Cross-platform terminal compatibility

- [ ] **Implement server pairing interface**
  - Menu-based pairing initiation
  - Emoji display in terminal (text fallback)
  - Contact management through terminal
  - Server-specific configuration options

### 5.2 Permission Management System
- [ ] **Design permission framework** (`src/server/permissions.rs`)
  - Three-level system: Deny, Allow, Ask
  - Per-contact permission settings
  - Per-operation permission granularity
  - No "allow all" shortcut (security by design)

- [ ] **Implement operation-specific permissions**
  - LLM access permissions
  - File torrenting permissions
  - System resource access
  - Network operation permissions

### 5.3 Bytecode Instruction System
- [ ] **Design VM instruction set** (`src/server/bytecode_vm.rs`)
  - Safe instruction set for handheld → server operations
  - Memory and resource limits
  - Instruction validation and sandboxing
  - Result serialization back to handheld

- [ ] **Create instruction compiler** (`src/client/instruction_compiler.rs`)
  - Compile high-level operations to bytecode
  - Client-side instruction building
  - Error handling and validation
  - Instruction queue management

---

## Phase 6: Advanced Messaging & Queuing 📬

### 6.1 Message Queuing System
- [ ] **Implement offline message storage** (`src/messaging/message_queue.rs`)
  - Store messages for offline contacts
  - Message expiration and cleanup
  - Priority-based message delivery
  - Storage size limits and rotation

- [ ] **Create message delivery system** (`src/messaging/delivery_manager.rs`)
  - Automatic delivery when peers come online
  - Retry logic for failed deliveries
  - Delivery confirmation and read receipts
  - Bandwidth-aware delivery scheduling

### 6.2 Scuttlebutt Integration
- [ ] **Enhance existing Scuttlebutt module** (`src/scuttlebutt.rs`)
  - Integration with crypto communication system
  - Message queuing for offline contacts
  - Key migration for expired relationships
  - Encrypted feed synchronization

- [ ] **Create message reassignment system**
  - Handle messages when keys expire
  - UI for reassigning queued messages to new keys
  - Batch reassignment tools
  - Message retention policies

---

## Phase 7: Integration & Testing 🧪

### 7.1 Cross-Application Integration
- [ ] **Update media player for crypto communication**
  - Encrypted media sharing
  - Secure playlist collaboration
  - Media access permissions
  - Encrypted media streaming between devices

- [ ] **Update paint program for crypto communication**
  - Encrypted collaborative art sessions
  - Secure artwork sharing
  - Artist identity verification
  - Encrypted art galleries

- [ ] **Update word processor for crypto communication**
  - End-to-end encrypted document collaboration
  - Secure document sharing
  - Version control with cryptographic signatures
  - Collaborative editing with identity verification

### 7.2 Testing Framework
- [ ] **Create crypto testing suite** (`tests/crypto_tests.rs`)
  - Key generation and expiration testing
  - Encryption/decryption round-trip tests
  - Pairing protocol testing
  - Permission system testing

- [ ] **Implement integration tests** (`tests/integration_tests.rs`)
  - Multi-device pairing scenarios
  - Message delivery testing
  - Network failure recovery
  - Key expiration handling

- [ ] **Create performance benchmarks** (`tests/performance_tests.rs`)
  - Encryption/decryption performance
  - Message throughput testing
  - Battery usage measurement
  - Memory usage optimization

---

## Phase 8: Configuration & Deployment 🔧

### 8.1 Configuration System
- [ ] **Create crypto configuration** (`src/config/crypto_config.rs`)
  - Key expiration timeout settings
  - Pairing button configuration
  - Encryption algorithm selection
  - Performance tuning parameters

- [ ] **Implement device-specific optimizations**
  - Anbernic model-specific settings
  - Battery level-based crypto optimization
  - Screen size adaptations for UI
  - Hardware-specific performance tuning

### 8.2 User Documentation
- [ ] **Create crypto communication user guide** (`docs/crypto-communication-guide.md`)
  - Pairing walkthrough with screenshots
  - Security best practices
  - Key management guidelines
  - Troubleshooting common issues

- [ ] **Update existing documentation**
  - Integrate crypto features into P2P documentation
  - Update controller mappings for crypto features
  - Add security considerations to all guides
  - Create migration guide from basic P2P

---

## Implementation Timeline Estimates

### Phase 1 (Cryptographic Foundation): **3-4 weeks**
- Complex crypto implementation
- Security review required
- Testing and validation

### Phase 2 (WiFi Direct Infrastructure): **2-3 weeks**  
- Platform-specific research needed
- Hardware compatibility testing
- Cross-platform abstraction

### Phase 3 (Emoji-Based Pairing): **2 weeks**
- UI/UX implementation
- Emoji handling and display
- State machine complexity

### Phase 4 (Enhanced Input Integration): **1-2 weeks**
- Building on existing input system
- Controller integration
- UI adaptations

### Phase 5 (Server Daemon): **2-3 weeks**
- Terminal UI framework
- Permission system complexity
- Bytecode VM implementation

### Phase 6 (Advanced Messaging): **2 weeks**
- Message queuing system
- Scuttlebutt integration
- Delivery management

### Phase 7 (Integration & Testing): **2-3 weeks**
- Cross-application updates
- Comprehensive testing
- Performance optimization

### Phase 8 (Configuration & Deployment): **1 week**
- Documentation and deployment
- Configuration system
- User guides

**Total Estimated Timeline: 15-20 weeks**

---

## Dependencies and Prerequisites

### External Dependencies
- **OpenPGP Library**: `sequoia-openpgp` or `rpgp` for Rust
- **WiFi Direct Support**: Platform-specific WiFi Direct libraries
- **Terminal UI**: `crossterm` and `tui-rs` for server interface
- **Emoji Support**: Unicode emoji handling libraries

### Hardware Requirements
- **WiFi Direct Capable Devices**: Modern Anbernic devices with WiFi Direct support
- **Dedicated Pairing Button**: Physical button mapping or UI-based pairing
- **Sufficient Storage**: Space for encrypted key storage and message queues

### Security Considerations
- **Secure Key Storage**: Hardware-backed key storage where available
- **Forward Secrecy**: Consider implementing Perfect Forward Secrecy
- **Side-Channel Attacks**: Timing attack protection for crypto operations
- **Social Engineering**: User education about pairing verification

---

## Risk Factors and Mitigations

### Technical Risks
1. **WiFi Direct Compatibility**: Limited device support
   - *Mitigation*: Fallback to traditional WiFi infrastructure
   
2. **Crypto Performance**: Battery drain from encryption
   - *Mitigation*: Hardware acceleration where available, optimized algorithms
   
3. **Key Management Complexity**: User confusion with key expiration
   - *Mitigation*: Clear UI indicators and automated key renewal prompts

### Security Risks
1. **Key Compromise**: Device theft or compromise
   - *Mitigation*: Short key expiration times, secure storage
   
2. **Man-in-the-Middle**: Pairing interception
   - *Mitigation*: Visual verification through emoji system
   
3. **Replay Attacks**: Message replay by attackers
   - *Mitigation*: Timestamp validation and nonce systems

### User Experience Risks
1. **Complexity**: Too complex for casual users
   - *Mitigation*: Progressive disclosure, sane defaults
   
2. **Pairing Confusion**: Users pairing with wrong devices
   - *Mitigation*: Clear emoji display, confirmation steps
   
3. **Key Loss**: Users losing access to conversations
   - *Mitigation*: Key backup options, recovery mechanisms

---

This implementation plan transforms the current basic P2P system into the sophisticated cryptographic communication platform described in the vision document. The phased approach allows for incremental development and testing while building toward the complete vision of secure, emoji-paired, relationship-based communication between handheld devices.