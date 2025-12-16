# Input System Crypto Integration

## Overview

This document describes how the core input system integrates with the cryptographic security system for secure device pairing, relationship management, and encrypted communications.

## Integration Architecture

### Crypto-Extended Input Manager

<details>
<summary>Crypto Extension Fields (click to expand)</summary>

```rust
// Additional fields in EnhancedInputManager for crypto features
pub struct EnhancedInputManager {
    // ... core fields (see input-core-system.md)
    
    // Secure P2P system with crypto integration
    pub secure_p2p: Option<P2PMigrationAdapter>,
    pub secure_p2p_enabled: bool,
    pub secure_relationships: Vec<RelationshipId>,
    pub pairing_mode_active: bool,
    pub discovered_secure_devices: Vec<CryptoPairingEmoji>,
}
```
</details>

### Crypto Input Modes

<details>
<summary>Crypto-Specific Modes (click to expand)</summary>

```rust
pub enum EnhancedInputMode {
    // ... core modes (see input-core-system.md)
    
    // Crypto-specific modes
    SecurePairing { stage: SecurePairingStage },
    SecureDeviceSelection { devices: Vec<CryptoPairingEmoji> },
    RelationshipManager,
}

pub enum SecurePairingStage {
    Initiating,           // Starting pairing mode
    Broadcasting,         // Broadcasting our emoji
    Scanning,            // Scanning for other devices
    DeviceSelection,     // Choosing peer device
    NicknameEntry,       // Entering nickname for peer
    Confirming,          // Confirming pairing
    Completed,           // Pairing successful
}
```
</details>

## Secure Device Pairing

### Emoji-Based Pairing Workflow

The crypto system uses visual emoji identification for secure pairing:

```rust
// Enter secure pairing mode
input.enter_secure_pairing_mode()?;

// System generates and displays emoji
let our_emoji = input.get_our_pairing_emoji()?;
println!("Our emoji: {} ({})", our_emoji.emoji, our_emoji.description);

// Scan for other devices
let discovered = input.scan_for_pairing_devices()?;

// User selects peer emoji
input.enter_mode(EnhancedInputMode::SecureDeviceSelection { 
    devices: discovered 
})?;

// Select device and enter nickname
let selected_device = input.select_discovered_device(device_index)?;
let nickname = input.prompt_for_nickname(&selected_device)?;

// Complete pairing
let relationship_id = input.complete_secure_pairing(selected_device, nickname)?;
```

### Pairing Interface

<details>
<summary>Secure Pairing UI (click to expand)</summary>

```
┌─ Secure Pairing ─────────────────┐
│ Stage: Device Selection          │
│                                  │
│ Our emoji: 🎮 (gamepad)         │
│                                  │
│ Discovered devices:              │
│ > 😊 (smiling face) - Alice     │
│   🚗 (car) - Unknown            │
│   ⚽ (soccer ball) - Bob         │
│                                  │
│ Controls:                        │
│ D-pad: Navigate | A: Select      │
│ B: Cancel | Start: Help          │
└──────────────────────────────────┘
```

**Controls:**
- **D-pad Up/Down**: Navigate device list
- **A Button**: Select highlighted device
- **B Button**: Cancel pairing
- **Start**: Show pairing help
</details>

### Nickname Entry

After device selection, users enter human-readable nicknames:

```rust
// Nickname entry mode
input.enter_mode(EnhancedInputMode::SecurePairing { 
    stage: SecurePairingStage::NicknameEntry 
})?;

// Use standard text input for nickname
let nickname = input.collect_text_input("Enter nickname for device:")?;

// Validate and confirm
if input.validate_nickname(&nickname)? {
    input.confirm_pairing(selected_device, nickname)?;
}
```

## Relationship Management

### Viewing Secure Relationships

```rust
// Enter relationship manager
input.enter_mode(EnhancedInputMode::RelationshipManager)?;

// List active relationships
let relationships = input.get_secure_relationships()?;

for relationship in relationships {
    println!("{}: {} (last contact: {})", 
        relationship.nickname,
        relationship.device_name,
        relationship.last_contact_ago()
    );
}
```

### Relationship Manager Interface

<details>
<summary>Relationship Manager UI (click to expand)</summary>

```
┌─ Relationship Manager ───────────┐
│ Secure Relationships (3):        │
│                                  │
│ > Alice's RG353V [●] (2 days)   │
│   Bob's RG35XX [●] (5 min)      │
│   Charlie's RG351P [○] (offline) │
│                                  │
│ Selected: Alice's RG353V         │
│ ○ Send Message                   │
│ ○ Share Document                 │
│ ○ View History                   │
│ ○ Forget Relationship           │
│                                  │
│ A: Select | B: Back | Start: Pair│
└──────────────────────────────────┘
```

**Functions:**
- **View Relationships**: See all paired devices
- **Send Messages**: Encrypted P2P messaging  
- **Share Documents**: Secure file transfers
- **Forget Relationships**: Remove expired/unwanted pairings
</details>

### Relationship Actions

```rust
// Send encrypted message
input.send_secure_message(relationship_id, "Hello!")?;

// Share document securely
input.share_document_securely(relationship_id, document_path)?;

// Forget relationship (removes keys)
input.forget_relationship(relationship_id)?;

// Re-pair with device (new keys)
input.initiate_re_pairing(device_emoji)?;
```

## Encrypted Communications

### Automatic Encryption

All communications through the input system are automatically encrypted:

```rust
// Text sent via input system is automatically encrypted
input.send_text_to_peer(relationship_id, "This is encrypted")?;

// Files shared through input are encrypted in transit
input.share_file_with_peer(relationship_id, file_path)?;

// Collaboration data is encrypted
input.sync_document_changes_securely(relationship_id, changes)?;
```

### Security Indicators

The input system provides visual security feedback:

- **🔐 Lock Icon**: Secure connection active
- **🔓 Unlock Icon**: Insecure/fallback mode
- **⚠️ Warning**: Encryption failure
- **❌ No Connection**: No secure relationship

## Key Management Integration

### Automatic Key Rotation

```rust
// Keys automatically rotated on relationship renewal
if input.relationship_needs_renewal(relationship_id)? {
    input.suggest_key_renewal(relationship_id)?;
}

// User-triggered key rotation
input.rotate_relationship_keys(relationship_id)?;
```

### Auto-Forget Functionality

Relationships automatically expire based on configuration:

```rust
// Check for expired relationships
let expired = input.check_expired_relationships()?;

for relationship_id in expired {
    input.notify_relationship_expiring(relationship_id)?;
    
    // Auto-forget after timeout
    if input.should_auto_forget(relationship_id)? {
        input.forget_relationship(relationship_id)?;
    }
}
```

## Security Features

### Input Security

#### Secure Text Entry
- **Visual Obfuscation**: Hide sensitive input when needed
- **Secure Memory**: Clear sensitive data from memory
- **Audit Trail**: Log security-relevant input events

#### Pairing Security
- **Visual Verification**: Emoji-based identity confirmation
- **Man-in-the-Middle Protection**: Visual pairing prevents MITM
- **Forward Secrecy**: Unique keys per relationship

### Error Handling

```rust
match input.attempt_secure_communication(relationship_id, data) {
    Err(CryptoError::RelationshipExpired) => {
        input.suggest_re_pairing(relationship_id)?;
    },
    Err(CryptoError::EncryptionFailure) => {
        input.fallback_to_insecure_mode()?;
        input.show_security_warning()?;
    },
    Err(CryptoError::KeyNotFound) => {
        input.initiate_key_exchange(relationship_id)?;
    },
    Ok(result) => {
        // Process successful secure communication
    }
}
```

## Configuration

### Crypto Settings

<details>
<summary>Crypto Configuration Options (click to expand)</summary>

```rust
pub struct CryptoInputConfig {
    pub auto_pairing_enabled: bool,
    pub relationship_timeout_days: u32,
    pub auto_forget_enabled: bool,
    pub encryption_required: bool,
    pub visual_security_indicators: bool,
    pub pairing_emoji_pool_size: usize,
}
```
</details>

### Security Levels
- **Paranoid**: Maximum security, frequent key rotation
- **Balanced**: Security with usability (default)
- **Relaxed**: Minimal security overhead

## Performance Considerations

### Crypto Overhead
- **Encryption Latency**: < 5ms for typical text input
- **Memory Usage**: Minimal key storage overhead
- **Battery Impact**: Optimized for handheld devices

### Optimization Strategies
- **Crypto Hardware**: Use ARM crypto extensions when available
- **Key Caching**: Cache frequently-used keys
- **Batch Operations**: Group crypto operations for efficiency

## Privacy Protection

### Data Handling
- **No Plaintext Storage**: All sensitive data encrypted at rest
- **Minimal Metadata**: Reduce tracking possibilities
- **Local Processing**: Crypto operations on-device

### User Control
- **Granular Permissions**: Fine-grained relationship control
- **Transparency**: Clear indication of security status
- **User Choice**: Enable/disable crypto features as needed

## Related Documentation

- **Core Input**: `docs/input-core-system.md`
- **P2P Integration**: `docs/input-p2p-integration.md`  
- **Crypto Architecture**: `docs/cryptographic-architecture.md`
- **Security Implementation**: `/src/crypto/` modules

---

**Dependencies**: Core input system + Cryptographic modules  
**Security**: End-to-end encrypted, relationship-based trust  
**Performance**: Optimized for real-time handheld input