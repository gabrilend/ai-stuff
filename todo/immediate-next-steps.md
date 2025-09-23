# Immediate Next Steps - Cryptographic Communication Implementation

## Priority 1: Foundation Setup (This Week)

### Day 1-2: Project Structure and Dependencies

#### ✅ **TASK 1.1: Create Crypto Module Structure**
```bash
# Create the crypto module directory structure
mkdir -p src/crypto
touch src/crypto/mod.rs
touch src/crypto/pgp_manager.rs
touch src/crypto/key_expiration.rs
touch src/crypto/relationship_keys.rs
touch src/crypto/packet_wrapper.rs
touch src/crypto/message_crypto.rs
```

#### ✅ **TASK 1.2: Add Crypto Dependencies**
Add to `Cargo.toml`:
```toml
[dependencies]
# Existing dependencies...

# Cryptographic dependencies
sequoia-openpgp = "1.17"
rand = "0.8"
uuid = { version = "1.0", features = ["v4", "serde"] }
argon2 = "0.5"
chacha20poly1305 = "0.10"
hex = "0.4"
base64 = "0.21"

# Additional utilities
thiserror = "1.0"
anyhow = "1.0"
dirs = "5.0"
```

#### ✅ **TASK 1.3: Update Module Exports**
Update `src/lib.rs`:
```rust
pub mod crypto;
pub use crypto::*;
```

Create `src/crypto/mod.rs`:
```rust
pub mod pgp_manager;
pub mod key_expiration;
pub mod relationship_keys;
pub mod packet_wrapper;
pub mod message_crypto;

pub use pgp_manager::*;
pub use key_expiration::*;
pub use relationship_keys::*;
pub use packet_wrapper::*;
pub use message_crypto::*;

// Re-export important types
pub use sequoia_openpgp;
```

### Day 3-4: Core Crypto Implementation

#### ✅ **TASK 2.1: Implement Basic PGP Key Generation**
Create `src/crypto/pgp_manager.rs`:
```rust
use sequoia_openpgp::prelude::*;
use sequoia_openpgp::policy::StandardPolicy;
use std::time::SystemTime;
use anyhow::Result;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PGPKeyPair {
    pub private_key_armor: String,
    pub public_key_armor: String,
    pub key_id: String,
    pub created_at: u64,
    pub expires_at: Option<u64>,
    pub relationship_id: String,
}

impl PGPKeyPair {
    pub async fn generate_for_relationship(
        relationship_id: String,
        user_name: String,
        expiration_hours: Option<u64>
    ) -> Result<Self> {
        // Implementation here
        todo!("Implement PGP key generation")
    }
    
    pub fn get_cert(&self) -> Result<Cert> {
        // Parse the armored key back to a Cert
        todo!("Implement cert parsing")
    }
}

#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("Key generation failed: {0}")]
    KeyGeneration(String),
    
    #[error("Key not found for relationship: {0}")]
    KeyNotFound(String),
    
    #[error("Encryption failed: {0}")]
    EncryptionFailed(String),
    
    #[error("Decryption failed: {0}")]
    DecryptionFailed(String),
}
```

#### ✅ **TASK 2.2: Create Basic Crypto Test**
Create `tests/crypto_basic_test.rs`:
```rust
use handheld_office::crypto::*;
use tokio;

#[tokio::test]
async fn test_key_generation() {
    let keypair = PGPKeyPair::generate_for_relationship(
        "test_relationship_1".to_string(),
        "test_user".to_string(),
        Some(24) // 24 hours
    ).await;
    
    assert!(keypair.is_ok());
    let keypair = keypair.unwrap();
    assert!(!keypair.private_key_armor.is_empty());
    assert!(!keypair.public_key_armor.is_empty());
    assert_eq!(keypair.relationship_id, "test_relationship_1");
}

#[tokio::test]
async fn test_basic_encryption_roundtrip() {
    // Test that we can encrypt and decrypt a message
    todo!("Implement basic encryption test");
}
```

### Day 5-7: Storage and Key Management

#### ✅ **TASK 3.1: Implement Secure Key Storage**
Create `src/crypto/key_storage.rs`:
```rust
use crate::crypto::CryptoError;
use anyhow::Result;
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::path::PathBuf;
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::{SaltString, rand_core::OsRng}};

#[derive(Debug, Serialize, Deserialize)]
pub struct EncryptedKeyStore {
    pub version: u32,
    pub device_id: String,
    pub salt: String,
    pub encrypted_keys: HashMap<String, EncryptedKeyData>,
    pub created_at: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EncryptedKeyData {
    pub encrypted_private_key: String,
    pub public_key_armor: String,
    pub relationship_metadata: RelationshipMetadata,
}

pub struct KeyStorageManager {
    storage_path: PathBuf,
    device_passphrase: String,
}

impl KeyStorageManager {
    pub fn new() -> Result<Self> {
        let storage_dir = dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("handheld-office")
            .join("crypto");
        
        std::fs::create_dir_all(&storage_dir)?;
        
        Ok(Self {
            storage_path: storage_dir.join("keystore.json"),
            device_passphrase: Self::generate_device_passphrase()?,
        })
    }
    
    fn generate_device_passphrase() -> Result<String> {
        // Generate device-specific passphrase from hardware info
        todo!("Implement device-specific passphrase generation")
    }
    
    pub async fn save_keypair(&mut self, keypair: PGPKeyPair) -> Result<()> {
        todo!("Implement encrypted key storage")
    }
    
    pub async fn load_keypair(&self, relationship_id: &str) -> Result<Option<PGPKeyPair>> {
        todo!("Implement encrypted key loading")
    }
}
```

#### ✅ **TASK 3.2: Add Storage Tests**
```rust
#[tokio::test]
async fn test_key_storage_roundtrip() {
    let mut storage = KeyStorageManager::new().unwrap();
    
    let keypair = PGPKeyPair::generate_for_relationship(
        "storage_test".to_string(),
        "test_user".to_string(),
        Some(24)
    ).await.unwrap();
    
    // Store the key
    storage.save_keypair(keypair.clone()).await.unwrap();
    
    // Load it back
    let loaded = storage.load_keypair("storage_test").await.unwrap();
    assert!(loaded.is_some());
    assert_eq!(loaded.unwrap().relationship_id, keypair.relationship_id);
}
```

---

## Priority 2: Integration Planning (Next Week)

### Week 2 Goals

#### ✅ **TASK 4.1: Design Integration Points**
Create `docs/crypto-integration-plan.md`:
- Map out where crypto hooks into existing P2P system
- Identify controller input changes needed
- Plan UI changes for encryption status
- Design migration strategy from current P2P

#### ✅ **TASK 4.2: Create Prototype Pairing Flow**
Create basic emoji pairing prototype:
- Simple emoji selection interface
- Basic relationship creation
- Integration with existing input system
- Test on actual handheld device

#### ✅ **TASK 4.3: Performance Baseline**
Benchmark current P2P system:
- Message transfer speeds
- Memory usage
- Battery consumption
- Connection establishment time

---

## Priority 3: Proof of Concept (Week 3-4)

### End-to-End Demo Goals

#### ✅ **TASK 5.1: Basic Encrypted Messaging**
Implement minimal encrypted messaging:
```rust
// Two devices can:
// 1. Generate relationship keys
// 2. Exchange public keys (manually for now)
// 3. Send encrypted messages
// 4. Decrypt and display messages
```

#### ✅ **TASK 5.2: Simple Pairing Demo**
Create basic pairing demonstration:
- Device A generates emoji
- Device B sees emoji list
- Manual selection creates relationship
- Keys generated and exchanged
- Test encrypted communication

#### ✅ **TASK 5.3: Controller Integration**
Add crypto features to enhanced input:
- Pairing mode accessible via button combination
- Encryption status display
- Basic contact selection
- Message composition interface

---

## Development Environment Setup

### Required Tools
```bash
# Rust crypto development
cargo install cargo-audit      # Security auditing
cargo install cargo-benchcmp   # Performance comparison
cargo install cargo-tarpaulin  # Code coverage

# Testing tools
sudo apt install valgrind      # Memory leak detection
pip install cryptofuzz         # Crypto fuzzing (if available)
```

### Hardware Requirements
- **Minimum 2 Anbernic devices** for pairing/communication testing
- **1 laptop/desktop** for server daemon development
- **USB-C cables** for debugging and log access
- **External WiFi adapter** for WiFi Direct testing (optional)

### Security Setup
```bash
# Create isolated development environment
mkdir -p ~/handheld-crypto-dev
cd ~/handheld-crypto-dev

# Use separate keypair for development
gpg --generate-key
# (Use development-only identity)

# Set up encrypted backup storage
encfs ~/crypto-backup ~/crypto-backup-decrypted
```

---

## Success Criteria for First Month

### Week 1: ✅ Foundation Complete
- [ ] Crypto module structure created
- [ ] Dependencies added and compiling
- [ ] Basic PGP key generation working
- [ ] Secure storage implementation started

### Week 2: ✅ Core Functionality
- [ ] Key storage and retrieval working
- [ ] Basic encrypt/decrypt operations
- [ ] Relationship management basics
- [ ] Integration plan documented

### Week 3: ✅ Proof of Concept
- [ ] Two devices can pair (manually)
- [ ] Encrypted message exchange working
- [ ] Controller integration prototype
- [ ] Performance baseline established

### Week 4: ✅ Demo Ready
- [ ] End-to-end encrypted communication
- [ ] Basic emoji pairing interface
- [ ] Integration with existing input system
- [ ] Documentation for next phase

### Quality Gates
- [ ] All crypto tests passing
- [ ] No memory leaks in crypto operations
- [ ] Performance within 2x of current P2P system
- [ ] Security review of crypto implementation
- [ ] Works on actual Anbernic hardware

---

## Risk Mitigation

### Technical Risks
1. **Sequoia-OpenPGP Performance**: May be too slow for handheld
   - *Plan B*: Try RustCrypto libraries or simpler crypto schemes
   
2. **Memory Usage**: Crypto operations may use too much RAM
   - *Plan B*: Streaming encryption, smaller key sizes
   
3. **Cross-Compilation**: Crypto libraries may not work on ARM
   - *Plan B*: Use different crypto library or pure Rust implementation

### Development Risks
1. **Complexity Creep**: Feature scope expanding beyond timeline
   - *Mitigation*: Strict focus on MVP for first phase
   
2. **Security Errors**: Implementing crypto incorrectly  
   - *Mitigation*: Use well-tested libraries, security review
   
3. **Hardware Compatibility**: Anbernic device limitations
   - *Mitigation*: Test early and often on real hardware

---

## Communication and Reporting

### Weekly Progress Reports
- **Monday**: Previous week accomplishments
- **Wednesday**: Mid-week blockers and status  
- **Friday**: Week completion and next week planning

### Documentation Updates
- Keep implementation docs current with code changes
- Update roadmap based on discoveries and changes
- Maintain security considerations document

### Testing Protocol
- Daily: Unit tests for new code
- Weekly: Integration tests on hardware
- Monthly: Security review and performance analysis

---

This immediate action plan provides concrete, actionable steps to begin implementing the cryptographic communication vision while maintaining momentum and delivering measurable progress each week.