# Phase 1: Cryptographic Foundation - Detailed Implementation Tasks

## Overview
This document breaks down Phase 1 of the cryptographic communication implementation into specific, actionable tasks. Phase 1 establishes the cryptographic foundation required for the vision of secure, relationship-based communication.

---

## Task 1: PGP Key Management System

### 1.1 Core PGP Module Setup
- [ ] **Create crypto module structure**
  ```
  src/crypto/
  ├── mod.rs
  ├── pgp_manager.rs
  ├── key_expiration.rs
  ├── relationship_keys.rs
  ├── packet_wrapper.rs
  └── message_crypto.rs
  ```

- [ ] **Add PGP dependencies to Cargo.toml**
  ```toml
  [dependencies]
  sequoia-openpgp = "1.17"
  rand = "0.8"
  uuid = { version = "1.0", features = ["v4"] }
  serde_json = "1.0"
  tokio-fs = "0.1"
  ```

- [ ] **Export crypto module in lib.rs**
  ```rust
  pub mod crypto;
  pub use crypto::*;
  ```

### 1.2 PGP Key Generation (`src/crypto/pgp_manager.rs`)
- [ ] **Implement key generation function**
  ```rust
  pub struct PGPKeyPair {
      pub private_key: Vec<u8>,
      pub public_key: Vec<u8>, 
      pub key_id: String,
      pub created_at: u64,
      pub expires_at: Option<u64>,
  }
  
  pub fn generate_relationship_keypair(
      relationship_id: &str,
      user_name: &str,
      email: &str,
      expiration_hours: Option<u64>
  ) -> Result<PGPKeyPair, CryptoError>
  ```

- [ ] **Implement key serialization/deserialization**
  ```rust
  impl PGPKeyPair {
      pub fn to_armored_private(&self) -> Result<String, CryptoError>
      pub fn to_armored_public(&self) -> Result<String, CryptoError>
      pub fn from_armored_private(armored: &str) -> Result<Self, CryptoError>
      pub fn from_armored_public(armored: &str) -> Result<PublicKey, CryptoError>
  }
  ```

- [ ] **Create key strength validation**
  - Minimum RSA-4096 or Ed25519 keys
  - Validate key parameters before generation
  - Security policy enforcement

### 1.3 Secure Key Storage (`src/crypto/key_storage.rs`)
- [ ] **Design encrypted key storage format**
  ```rust
  #[derive(Serialize, Deserialize)]
  pub struct EncryptedKeyStore {
      pub version: u32,
      pub device_id: String,
      pub salt: Vec<u8>,
      pub encrypted_keys: HashMap<String, EncryptedKeyData>,
      pub relationships: HashMap<String, RelationshipInfo>,
  }
  ```

- [ ] **Implement key storage manager**
  ```rust
  pub struct KeyStorageManager {
      storage_path: PathBuf,
      device_passphrase: String, // Derived from device-specific data
  }
  
  impl KeyStorageManager {
      pub async fn save_keypair(&mut self, relationship_id: &str, keypair: PGPKeyPair) -> Result<(), CryptoError>
      pub async fn load_keypair(&self, relationship_id: &str) -> Result<Option<PGPKeyPair>, CryptoError>
      pub async fn delete_keypair(&mut self, relationship_id: &str) -> Result<(), CryptoError>
      pub async fn list_relationships(&self) -> Result<Vec<String>, CryptoError>
  }
  ```

- [ ] **Add device-specific encryption**
  - Use device MAC address + hardware serial for key derivation
  - PBKDF2 with high iteration count
  - Argon2 for password-based key derivation

---

## Task 2: Key Expiration System

### 2.1 Expiration Policy Engine (`src/crypto/key_expiration.rs`)
- [ ] **Create expiration policy configuration**
  ```rust
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct ExpirationPolicy {
      pub default_expiration_hours: u64,
      pub max_expiration_hours: u64,
      pub warning_before_expiry_hours: u64,
      pub cleanup_expired_after_hours: u64,
      pub auto_renewal_enabled: bool,
  }
  ```

- [ ] **Implement expiration checker**
  ```rust
  pub struct KeyExpirationManager {
      policy: ExpirationPolicy,
      storage: Arc<KeyStorageManager>,
  }
  
  impl KeyExpirationManager {
      pub async fn check_expiring_keys(&self) -> Result<Vec<ExpiringKey>, CryptoError>
      pub async fn cleanup_expired_keys(&mut self) -> Result<Vec<String>, CryptoError>
      pub async fn renew_key(&mut self, relationship_id: &str) -> Result<PGPKeyPair, CryptoError>
      pub async fn schedule_expiration_check(&self) -> Result<(), CryptoError>
  }
  ```

- [ ] **Create expiration warning system**
  ```rust
  #[derive(Debug)]
  pub struct ExpiringKey {
      pub relationship_id: String,
      pub contact_name: String,
      pub expires_at: u64,
      pub hours_remaining: u64,
  }
  
  pub async fn get_expiration_warnings() -> Result<Vec<ExpiringKey>, CryptoError>
  ```

### 2.2 Automatic Cleanup System
- [ ] **Implement background cleanup task**
  ```rust
  pub async fn start_expiration_monitor(
      manager: Arc<KeyExpirationManager>,
      check_interval_minutes: u64
  ) -> Result<tokio::task::JoinHandle<()>, CryptoError>
  ```

- [ ] **Create cleanup notifications**
  - Log expired key removals
  - Notify user of upcoming expirations
  - Provide renewal options before expiration

---

## Task 3: Relationship Key Manager

### 3.1 Relationship Tracking (`src/crypto/relationship_keys.rs`)
- [ ] **Design relationship data structure**
  ```rust
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct Relationship {
      pub id: String,           // UUID for this relationship
      pub contact_name: String, // User-assigned nickname
      pub pairing_emoji: String,// Emoji used during pairing
      pub public_key_id: String,// Their public key identifier
      pub our_key_id: String,   // Our key for this relationship
      pub created_at: u64,
      pub last_seen: u64,
      pub is_active: bool,
      pub trust_level: TrustLevel,
  }
  
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub enum TrustLevel {
      Untrusted,    // Just paired, not verified
      Verified,     // We've confirmed their identity
      Trusted,      // Long-term trusted relationship
  }
  ```

- [ ] **Implement relationship manager**
  ```rust
  pub struct RelationshipManager {
      storage: Arc<KeyStorageManager>,
      relationships: HashMap<String, Relationship>,
  }
  
  impl RelationshipManager {
      pub async fn create_relationship(&mut self, contact_name: String, emoji: String) -> Result<Relationship, CryptoError>
      pub async fn update_last_seen(&mut self, relationship_id: &str) -> Result<(), CryptoError>
      pub async fn get_active_relationships(&self) -> Vec<Relationship>
      pub async fn find_by_public_key(&self, public_key_id: &str) -> Option<Relationship>
      pub async fn delete_relationship(&mut self, relationship_id: &str) -> Result<(), CryptoError>
  }
  ```

### 3.2 Key Mapping System
- [ ] **Implement key-to-relationship mapping**
  ```rust
  pub struct KeyRelationshipMapper {
      relationships: Arc<RelationshipManager>,
  }
  
  impl KeyRelationshipMapper {
      pub async fn get_keypair_for_relationship(&self, relationship_id: &str) -> Result<PGPKeyPair, CryptoError>
      pub async fn identify_sender(&self, public_key_id: &str) -> Option<Relationship>
      pub async fn get_encryption_key(&self, contact_name: &str) -> Result<PublicKey, CryptoError>
  }
  ```

---

## Task 4: Encrypted Packet System

### 4.1 Packet Format Design (`src/crypto/packet_wrapper.rs`)
- [ ] **Define packet structures**
  ```rust
  #[derive(Debug, Serialize, Deserialize)]
  pub struct EncryptedPacket {
      pub version: u8,
      pub packet_type: PacketType,
      pub timestamp: u64,
      pub nonce: Vec<u8>,
      pub encrypted_payload: Vec<u8>,
  }
  
  #[derive(Debug, Serialize, Deserialize)]
  pub struct PacketWrapper {
      pub recipient_key_id: String,  // Public key ID of intended recipient
      pub sender_key_id: String,     // Our public key ID for this relationship
      pub encrypted_packet: EncryptedPacket,
  }
  
  #[derive(Debug, Serialize, Deserialize)]
  pub enum PacketType {
      Message,
      FileTransfer,
      KeyExchange,
      Heartbeat,
      Command,
  }
  ```

- [ ] **Implement packet wrapping/unwrapping**
  ```rust
  pub struct PacketManager {
      key_manager: Arc<RelationshipManager>,
  }
  
  impl PacketManager {
      pub async fn wrap_message(&self, content: &[u8], relationship_id: &str, packet_type: PacketType) -> Result<PacketWrapper, CryptoError>
      pub async fn unwrap_packet(&self, wrapper: PacketWrapper) -> Result<(Vec<u8>, String), CryptoError>
      pub fn validate_packet_integrity(&self, packet: &EncryptedPacket) -> bool
  }
  ```

### 4.2 Anti-Replay Protection
- [ ] **Implement replay attack protection**
  ```rust
  pub struct ReplayProtection {
      seen_nonces: HashMap<String, u64>, // nonce -> timestamp
      cleanup_interval: Duration,
  }
  
  impl ReplayProtection {
      pub fn check_nonce(&mut self, nonce: &[u8], timestamp: u64) -> bool
      pub async fn cleanup_old_nonces(&mut self)
  }
  ```

---

## Task 5: Message Encryption Pipeline

### 5.1 Encryption/Decryption Engine (`src/crypto/message_crypto.rs`)
- [ ] **Implement core crypto operations**
  ```rust
  pub struct MessageCrypto {
      key_storage: Arc<KeyStorageManager>,
  }
  
  impl MessageCrypto {
      pub async fn encrypt_message(&self, plaintext: &[u8], relationship_id: &str) -> Result<Vec<u8>, CryptoError>
      pub async fn decrypt_message(&self, ciphertext: &[u8], sender_key_id: &str) -> Result<Vec<u8>, CryptoError>
      pub async fn sign_message(&self, message: &[u8], relationship_id: &str) -> Result<Vec<u8>, CryptoError>
      pub async fn verify_signature(&self, message: &[u8], signature: &[u8], sender_key_id: &str) -> Result<bool, CryptoError>
  }
  ```

### 5.2 Error Handling and Recovery
- [ ] **Define comprehensive error types**
  ```rust
  #[derive(Debug, thiserror::Error)]
  pub enum CryptoError {
      #[error("Key not found for relationship: {0}")]
      KeyNotFound(String),
      
      #[error("Encryption failed: {0}")]
      EncryptionFailed(String),
      
      #[error("Decryption failed: {0}")]
      DecryptionFailed(String),
      
      #[error("Key generation failed: {0}")]
      KeyGenerationFailed(String),
      
      #[error("Key expired for relationship: {0}")]
      KeyExpired(String),
      
      #[error("Invalid packet format")]
      InvalidPacketFormat,
      
      #[error("Replay attack detected")]
      ReplayAttack,
      
      #[error("Storage error: {0}")]
      StorageError(String),
  }
  ```

- [ ] **Implement graceful error recovery**
  ```rust
  pub async fn handle_crypto_error(error: CryptoError, relationship_id: &str) -> RecoveryAction {
      match error {
          CryptoError::KeyExpired(_) => RecoveryAction::RequestKeyRenewal,
          CryptoError::KeyNotFound(_) => RecoveryAction::InitiatePairing,
          CryptoError::DecryptionFailed(_) => RecoveryAction::RequestRetransmission,
          _ => RecoveryAction::LogAndContinue,
      }
  }
  ```

---

## Task 6: Integration with Existing P2P System

### 6.1 Update P2P Manager
- [ ] **Modify P2PMeshManager to use crypto system**
  ```rust
  // Add to existing P2PMeshManager struct
  pub struct P2PMeshManager {
      // ... existing fields
      crypto_manager: Option<Arc<MessageCrypto>>,
      relationship_manager: Option<Arc<RelationshipManager>>,
      encryption_enabled: bool,
  }
  ```

- [ ] **Update message sending to use encryption**
  ```rust
  impl P2PMeshManager {
      pub async fn send_encrypted_message(&self, message: &[u8], contact_name: &str) -> Result<(), CryptoError>
      pub async fn handle_encrypted_message(&self, packet: PacketWrapper) -> Result<Vec<u8>, CryptoError>
  }
  ```

### 6.2 Backward Compatibility
- [ ] **Implement compatibility layer**
  ```rust
  pub enum MessageFormat {
      Plaintext(Vec<u8>),      // Legacy format
      Encrypted(PacketWrapper), // New encrypted format
  }
  
  pub async fn detect_message_format(data: &[u8]) -> MessageFormat
  pub async fn handle_mixed_format_communication(data: &[u8]) -> Result<Vec<u8>, CryptoError>
  ```

---

## Task 7: Testing Infrastructure

### 7.1 Unit Tests
- [ ] **Create crypto operation tests** (`tests/crypto_tests.rs`)
  ```rust
  #[tokio::test]
  async fn test_key_generation()
  
  #[tokio::test]
  async fn test_encrypt_decrypt_roundtrip()
  
  #[tokio::test]
  async fn test_key_expiration()
  
  #[tokio::test]
  async fn test_replay_protection()
  ```

### 7.2 Integration Tests  
- [ ] **Create relationship management tests**
  ```rust
  #[tokio::test]
  async fn test_create_and_use_relationship()
  
  #[tokio::test]
  async fn test_key_renewal_process()
  
  #[tokio::test]
  async fn test_message_encryption_between_relationships()
  ```

### 7.3 Performance Tests
- [ ] **Benchmark crypto operations**
  ```rust
  #[bench]
  fn bench_key_generation()
  
  #[bench]
  fn bench_message_encryption()
  
  #[bench]
  fn bench_message_decryption()
  ```

---

## Task 8: Configuration and Documentation

### 8.1 Configuration Integration
- [ ] **Add crypto settings to existing config system**
  ```toml
  [crypto]
  default_expiration_hours = 168  # 1 week
  max_expiration_hours = 8760     # 1 year
  key_strength = "rsa4096"        # or "ed25519"
  auto_cleanup_enabled = true
  warning_hours_before_expiry = 24
  ```

### 8.2 Developer Documentation
- [ ] **Create crypto module documentation** (`docs/crypto-foundation.md`)
  - Key generation process
  - Relationship management
  - Encryption/decryption workflows
  - Error handling patterns
  - Security considerations

---

## Acceptance Criteria for Phase 1

### Functional Requirements
- [ ] Generate RSA-4096 or Ed25519 keypairs for relationships
- [ ] Store keys securely with device-specific encryption
- [ ] Encrypt and decrypt messages using relationship-specific keys
- [ ] Handle key expiration with automatic cleanup
- [ ] Prevent replay attacks with nonce tracking
- [ ] Integrate with existing P2P system transparently

### Security Requirements
- [ ] Keys are never stored in plaintext
- [ ] All inter-device communication is encrypted
- [ ] Perfect forward secrecy for expired relationships
- [ ] Secure random number generation for all crypto operations
- [ ] Timing attack resistance in crypto operations

### Performance Requirements
- [ ] Key generation < 2 seconds on target hardware
- [ ] Message encryption/decryption < 100ms for typical messages
- [ ] Memory usage < 10MB for crypto operations
- [ ] Battery impact < 5% for typical usage patterns

### Testing Requirements
- [ ] 95%+ code coverage for crypto modules
- [ ] Successful round-trip testing for all crypto operations
- [ ] Performance benchmarks meet target requirements
- [ ] Security review by external party (if possible)

---

## Timeline for Phase 1

**Week 1:** Tasks 1-2 (PGP key management and expiration system)
**Week 2:** Tasks 3-4 (Relationship management and packet system)  
**Week 3:** Tasks 5-6 (Message crypto and P2P integration)
**Week 4:** Tasks 7-8 (Testing and documentation)

**Dependencies:** 
- Sequoia-OpenPGP library integration
- Secure storage location for keys
- Testing hardware for performance validation

**Risks:**
- Crypto library compatibility issues
- Performance bottlenecks on handheld hardware
- Complexity of key management UX