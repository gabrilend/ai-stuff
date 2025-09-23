/// Cryptographic operations for OfficeOS
/// Implements relationship-based PGP encryption as specified in cryptographic-communication-vision
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use thiserror::Error;
use base64::Engine;

pub mod keypair;
pub mod relationship;
pub mod storage;
pub mod pairing;
pub mod packet;
pub mod p2p_integration;
pub mod migration_adapter;

pub use keypair::*;
pub use relationship::*;
pub use storage::*;
pub use pairing::*;
pub use packet::*;
pub use p2p_integration::*;
pub use migration_adapter::*;

/// Main cryptographic manager for OfficeOS
pub struct CryptoManager {
    /// Our device's master keypair
    device_keypair: DeviceKeypair,
    /// Storage for relationship-specific keys
    key_storage: KeyStorage,
    /// Active relationships with other devices
    relationships: HashMap<RelationshipId, RelationshipContext>,
    /// Pairing session manager
    pairing_manager: PairingManager,
    /// Configuration
    config: CryptoConfig,
}

/// Configuration for cryptographic operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoConfig {
    /// Directory for storing encrypted key files
    pub key_storage_dir: PathBuf,
    /// How long to remember relationships without contact (seconds)
    pub relationship_timeout: u64,
    /// Whether to use hardware security features if available
    pub use_hardware_security: bool,
    /// Encryption algorithm preferences
    pub cipher_preferences: Vec<CipherSuite>,
}

/// Supported cipher suites
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum CipherSuite {
    /// ChaCha20-Poly1305 (recommended for embedded devices)
    ChaCha20Poly1305,
    /// AES-256-GCM (when hardware acceleration available)
    Aes256Gcm,
    /// Ed25519 for signing
    Ed25519,
}

/// Unique identifier for a relationship between two devices
#[derive(Debug, Clone, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct RelationshipId(pub String);

/// Context for a specific relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipContext {
    /// Unique identifier for this relationship
    pub id: RelationshipId,
    /// User-assigned nickname for the other device
    pub nickname: String,
    /// Keypair specific to this relationship
    pub keypair: RelationshipKeypair,
    /// Other device's public key for this relationship
    pub peer_public_key: PublicKey,
    /// When this relationship was established
    pub created_at: u64,
    /// Last time we communicated with this device
    pub last_contact: u64,
    /// Whether this relationship should be forgotten after timeout
    pub auto_forget: bool,
}

/// Error types for cryptographic operations
#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Key generation failed: {0}")]
    KeyGeneration(String),
    #[error("Encryption failed: {0}")]
    Encryption(String),
    #[error("Decryption failed: {0}")]
    Decryption(String),
    #[error("Invalid key format: {0}")]
    InvalidKey(String),
    #[error("Relationship not found: {0}")]
    RelationshipNotFound(String),
    #[error("Storage error: {0}")]
    Storage(String),
    #[error("Pairing failed: {0}")]
    Pairing(String),
    #[error("Signature verification failed")]
    SignatureVerification,
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type CryptoResult<T> = Result<T, CryptoError>;

impl Default for CryptoConfig {
    fn default() -> Self {
        Self {
            key_storage_dir: PathBuf::from("./keys"),
            relationship_timeout: 30 * 24 * 60 * 60, // 30 days
            use_hardware_security: true,
            cipher_preferences: vec![
                CipherSuite::ChaCha20Poly1305,
                CipherSuite::Ed25519,
                CipherSuite::Aes256Gcm,
            ],
        }
    }
}

impl CryptoManager {
    /// Create a new crypto manager with default configuration
    pub fn new() -> CryptoResult<Self> {
        Self::with_config(CryptoConfig::default())
    }

    /// Create a new crypto manager with specific configuration
    pub fn with_config(config: CryptoConfig) -> CryptoResult<Self> {
        // Generate or load device master keypair
        let device_keypair = DeviceKeypair::generate_or_load(&config.key_storage_dir)?;
        
        // Initialize key storage
        let key_storage = KeyStorage::new(&config.key_storage_dir)?;
        
        // Initialize pairing manager
        let pairing_manager = PairingManager::new(device_keypair.public_key.clone());

        Ok(Self {
            device_keypair,
            key_storage,
            relationships: HashMap::new(),
            pairing_manager,
            config,
        })
    }

    /// Get our device's public key for pairing
    pub fn get_device_public_key(&self) -> &PublicKey {
        &self.device_keypair.public_key
    }

    /// Start pairing mode and return our emoji
    pub fn enter_pairing_mode(&mut self) -> CryptoResult<PairingEmoji> {
        self.pairing_manager.enter_pairing_mode()
    }

    /// Get list of devices currently in pairing mode
    pub fn get_discovered_devices(&mut self) -> Vec<PairingEmoji> {
        self.pairing_manager.get_discovered_devices()
    }

    /// Establish a new relationship with a device
    pub fn establish_relationship(
        &mut self,
        peer_emoji: PairingEmoji,
        nickname: String,
    ) -> CryptoResult<RelationshipId> {
        // Complete pairing process to get peer's public key
        let peer_public_key = self.pairing_manager.complete_pairing(&peer_emoji)?;
        
        // Generate relationship-specific keypair
        let relationship_keypair = RelationshipKeypair::generate()?;
        
        // Create relationship ID from both public keys
        let relationship_id = RelationshipId::from_keys(
            &self.device_keypair.public_key,
            &peer_public_key,
        );
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let context = RelationshipContext {
            id: relationship_id.clone(),
            nickname,
            keypair: relationship_keypair,
            peer_public_key,
            created_at: now,
            last_contact: now,
            auto_forget: true, // Default to auto-forget as per vision
        };
        
        // Store relationship
        self.key_storage.store_relationship(&context)?;
        self.relationships.insert(relationship_id.clone(), context);
        
        Ok(relationship_id)
    }

    /// Encrypt data for a specific relationship
    pub fn encrypt_for_relationship(
        &self,
        relationship_id: &RelationshipId,
        data: &[u8],
    ) -> CryptoResult<EncryptedPacket> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Create encrypted packet with relationship public key in header
        EncryptedPacket::create(
            data,
            &relationship.keypair.private_key,
            &relationship.peer_public_key,
            &relationship.keypair.public_key,
        )
    }

    /// Decrypt data using the appropriate relationship key
    pub fn decrypt_packet(&self, packet: &EncryptedPacket) -> CryptoResult<Vec<u8>> {
        // Find relationship by the public key in packet header
        for (_, relationship) in &self.relationships {
            if relationship.keypair.public_key == packet.intended_recipient_key {
                return packet.decrypt(&relationship.keypair.private_key);
            }
        }
        
        Err(CryptoError::RelationshipNotFound(
            "No matching relationship for packet".to_string()
        ))
    }

    /// Update last contact time for a relationship
    pub fn update_last_contact(&mut self, relationship_id: &RelationshipId) {
        if let Some(relationship) = self.relationships.get_mut(relationship_id) {
            relationship.last_contact = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
        }
    }

    /// Clean up expired relationships
    pub fn cleanup_expired_relationships(&mut self) -> CryptoResult<usize> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let mut expired = Vec::new();
        
        for (id, relationship) in &self.relationships {
            if relationship.auto_forget && 
               (now - relationship.last_contact) > self.config.relationship_timeout {
                expired.push(id.clone());
            }
        }
        
        let count = expired.len();
        for id in expired {
            self.relationships.remove(&id);
            self.key_storage.remove_relationship(&id)?;
        }
        
        Ok(count)
    }

    /// Load all stored relationships
    pub fn load_relationships(&mut self) -> CryptoResult<()> {
        let relationships = self.key_storage.load_all_relationships()?;
        for relationship in relationships {
            self.relationships.insert(relationship.id.clone(), relationship);
        }
        Ok(())
    }

    /// Get list of active relationships
    pub fn get_relationships(&self) -> Vec<&RelationshipContext> {
        self.relationships.values().collect()
    }

    /// Export relationship for backup (encrypted with device key)
    pub fn export_relationship(&self, relationship_id: &RelationshipId) -> CryptoResult<String> {
        let relationship = self.relationships.get(relationship_id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(relationship_id.0.clone()))?;
            
        // Serialize and encrypt with device master key
        let serialized = serde_json::to_vec(relationship)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let encrypted = self.device_keypair.encrypt(&serialized)?;
        Ok(base64::engine::general_purpose::STANDARD.encode(encrypted))
    }

    /// Import relationship from backup
    pub fn import_relationship(&mut self, encrypted_data: &str) -> CryptoResult<RelationshipId> {
        let encrypted = base64::engine::general_purpose::STANDARD.decode(encrypted_data)
            .map_err(|e| CryptoError::InvalidKey(e.to_string()))?;
            
        let decrypted = self.device_keypair.decrypt(&encrypted)?;
        let relationship: RelationshipContext = serde_json::from_slice(&decrypted)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        let id = relationship.id.clone();
        self.key_storage.store_relationship(&relationship)?;
        self.relationships.insert(id.clone(), relationship);
        
        Ok(id)
    }
}

impl RelationshipId {
    /// Generate a relationship ID from two public keys
    pub fn from_keys(key1: &PublicKey, key2: &PublicKey) -> Self {
        use sha2::{Digest, Sha256};
        
        // Sort keys to ensure consistent ID regardless of order
        let mut keys = vec![key1.as_bytes(), key2.as_bytes()];
        keys.sort();
        
        let mut hasher = Sha256::new();
        for key in keys {
            hasher.update(key);
        }
        
        let hash = hasher.finalize();
        Self(hex::encode(&hash[..16])) // Use first 16 bytes as relationship ID
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_crypto_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let config = CryptoConfig {
            key_storage_dir: temp_dir.path().to_path_buf(),
            ..Default::default()
        };
        
        let manager = CryptoManager::with_config(config).unwrap();
        assert!(!manager.get_device_public_key().as_bytes().is_empty());
    }

    #[test]
    fn test_relationship_id_consistency() {
        let keypair1 = RelationshipKeypair::generate().unwrap();
        let keypair2 = RelationshipKeypair::generate().unwrap();
        
        let id1 = RelationshipId::from_keys(&keypair1.public_key, &keypair2.public_key);
        let id2 = RelationshipId::from_keys(&keypair2.public_key, &keypair1.public_key);
        
        assert_eq!(id1, id2);
    }
}