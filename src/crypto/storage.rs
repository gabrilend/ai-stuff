/// Secure key storage for OfficeOS cryptographic system
use crate::crypto::{CryptoError, CryptoResult, RelationshipContext, RelationshipId, DeviceKeypair};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// Secure storage manager for cryptographic keys and relationships
pub struct KeyStorage {
    /// Directory for storing encrypted key files
    storage_dir: PathBuf,
    /// Cache of loaded relationships
    relationship_cache: HashMap<RelationshipId, RelationshipContext>,
    /// Storage configuration
    config: StorageConfig,
}

/// Configuration for key storage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageConfig {
    /// Whether to encrypt relationship files with device master key
    pub encrypt_relationships: bool,
    /// Whether to use cache for frequently accessed relationships
    pub use_cache: bool,
    /// Maximum number of relationships to keep in cache
    pub cache_size: usize,
    /// File extension for relationship files
    pub relationship_extension: String,
    /// File extension for backup files
    pub backup_extension: String,
}

/// Information about stored relationships
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageInfo {
    /// Total number of stored relationships
    pub total_relationships: usize,
    /// Size of relationship files in bytes
    pub total_size: u64,
    /// Number of relationships in cache
    pub cached_relationships: usize,
    /// Storage directory path
    pub storage_path: String,
    /// Whether storage directory is accessible
    pub is_accessible: bool,
}

/// Backup metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupMetadata {
    /// When the backup was created
    pub created_at: u64,
    /// Number of relationships in backup
    pub relationship_count: usize,
    /// Version of backup format
    pub format_version: u32,
    /// Checksum of backup data
    pub checksum: String,
}

impl Default for StorageConfig {
    fn default() -> Self {
        Self {
            encrypt_relationships: true,
            use_cache: true,
            cache_size: 50,
            relationship_extension: "rel".to_string(),
            backup_extension: "bak".to_string(),
        }
    }
}

impl KeyStorage {
    /// Create a new key storage manager
    pub fn new(storage_dir: &PathBuf) -> CryptoResult<Self> {
        Self::with_config(storage_dir, StorageConfig::default())
    }

    /// Create a new key storage manager with specific configuration
    pub fn with_config(storage_dir: &PathBuf, config: StorageConfig) -> CryptoResult<Self> {
        // Create storage directory if it doesn't exist
        fs::create_dir_all(storage_dir)?;

        // Verify we can write to the directory
        let test_file = storage_dir.join(".write_test");
        fs::write(&test_file, b"test")?;
        fs::remove_file(&test_file)?;

        Ok(Self {
            storage_dir: storage_dir.clone(),
            relationship_cache: HashMap::new(),
            config,
        })
    }

    /// Store a relationship to encrypted file
    pub fn store_relationship(&mut self, relationship: &RelationshipContext) -> CryptoResult<()> {
        let file_path = self.get_relationship_file_path(&relationship.id);
        
        // Serialize relationship
        let serialized = serde_json::to_vec(relationship)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        // Encrypt if configured to do so
        let data_to_store = if self.config.encrypt_relationships {
            // For simplicity, we'll use a basic encryption scheme
            // In production, this would use the device master key
            self.encrypt_relationship_data(&serialized)?
        } else {
            serialized
        };

        // Write to file
        fs::write(&file_path, data_to_store)?;

        // Update cache if enabled
        if self.config.use_cache {
            self.update_cache(relationship.clone());
        }

        Ok(())
    }

    /// Load a relationship from storage
    pub fn load_relationship(&mut self, id: &RelationshipId) -> CryptoResult<RelationshipContext> {
        // Check cache first
        if self.config.use_cache {
            if let Some(relationship) = self.relationship_cache.get(id) {
                return Ok(relationship.clone());
            }
        }

        // Load from file
        let file_path = self.get_relationship_file_path(id);
        if !file_path.exists() {
            return Err(CryptoError::RelationshipNotFound(id.0.clone()));
        }

        let stored_data = fs::read(&file_path)?;

        // Decrypt if necessary
        let serialized = if self.config.encrypt_relationships {
            self.decrypt_relationship_data(&stored_data)?
        } else {
            stored_data
        };

        // Deserialize
        let relationship: RelationshipContext = serde_json::from_slice(&serialized)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        // Update cache
        if self.config.use_cache {
            self.update_cache(relationship.clone());
        }

        Ok(relationship)
    }

    /// Remove a relationship from storage
    pub fn remove_relationship(&mut self, id: &RelationshipId) -> CryptoResult<()> {
        let file_path = self.get_relationship_file_path(id);
        
        if file_path.exists() {
            fs::remove_file(&file_path)?;
        }

        // Remove from cache
        self.relationship_cache.remove(id);

        Ok(())
    }

    /// Load all stored relationships
    pub fn load_all_relationships(&mut self) -> CryptoResult<Vec<RelationshipContext>> {
        let mut relationships = Vec::new();

        // Read all .rel files in storage directory
        let entries = fs::read_dir(&self.storage_dir)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            
            if path.extension()
                .and_then(|ext| ext.to_str())
                .map(|ext| ext == self.config.relationship_extension)
                .unwrap_or(false)
            {
                // Extract relationship ID from filename
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    let id = RelationshipId(stem.to_string());
                    
                    match self.load_relationship(&id) {
                        Ok(relationship) => relationships.push(relationship),
                        Err(e) => {
                            // Log error but continue loading other relationships
                            eprintln!("Error loading relationship {}: {}", stem, e);
                        }
                    }
                }
            }
        }

        Ok(relationships)
    }

    /// Get information about storage
    pub fn get_storage_info(&self) -> CryptoResult<StorageInfo> {
        let mut total_relationships = 0;
        let mut total_size = 0;

        if self.storage_dir.exists() {
            let entries = fs::read_dir(&self.storage_dir)?;

            for entry in entries {
                let entry = entry?;
                let path = entry.path();
                
                if path.extension()
                    .and_then(|ext| ext.to_str())
                    .map(|ext| ext == self.config.relationship_extension)
                    .unwrap_or(false)
                {
                    total_relationships += 1;
                    if let Ok(metadata) = entry.metadata() {
                        total_size += metadata.len();
                    }
                }
            }
        }

        Ok(StorageInfo {
            total_relationships,
            total_size,
            cached_relationships: self.relationship_cache.len(),
            storage_path: self.storage_dir.to_string_lossy().to_string(),
            is_accessible: self.storage_dir.exists() && self.storage_dir.is_dir(),
        })
    }

    /// Create a backup of all relationships
    pub fn create_backup(&self, backup_path: &PathBuf) -> CryptoResult<BackupMetadata> {
        let relationships = self.list_stored_relationships()?;
        let mut backup_data = Vec::new();

        // Load all relationships
        for id in &relationships {
            if let Ok(relationship) = self.load_relationship_without_cache(id) {
                backup_data.push(relationship);
            }
        }

        // Create backup metadata
        let metadata = BackupMetadata {
            created_at: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            relationship_count: backup_data.len(),
            format_version: 1,
            checksum: self.calculate_backup_checksum(&backup_data)?,
        };

        // Serialize backup
        let backup = BackupData {
            metadata: metadata.clone(),
            relationships: backup_data,
        };

        let serialized = serde_json::to_vec(&backup)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        // Encrypt backup
        let encrypted = self.encrypt_backup_data(&serialized)?;

        // Write backup file
        fs::write(backup_path, encrypted)?;

        Ok(metadata)
    }

    /// Restore from backup
    pub fn restore_from_backup(&mut self, backup_path: &PathBuf) -> CryptoResult<BackupMetadata> {
        // Read and decrypt backup
        let encrypted = fs::read(backup_path)?;
        let decrypted = self.decrypt_backup_data(&encrypted)?;

        // Deserialize backup
        let backup: BackupData = serde_json::from_slice(&decrypted)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        // Verify checksum
        let calculated_checksum = self.calculate_backup_checksum(&backup.relationships)?;
        if calculated_checksum != backup.metadata.checksum {
            return Err(CryptoError::Storage("Backup checksum mismatch".to_string()));
        }

        // Restore relationships
        for relationship in backup.relationships {
            self.store_relationship(&relationship)?;
        }

        Ok(backup.metadata)
    }

    /// List all stored relationship IDs
    pub fn list_stored_relationships(&self) -> CryptoResult<Vec<RelationshipId>> {
        let mut ids = Vec::new();

        if self.storage_dir.exists() {
            let entries = fs::read_dir(&self.storage_dir)?;

            for entry in entries {
                let entry = entry?;
                let path = entry.path();
                
                if path.extension()
                    .and_then(|ext| ext.to_str())
                    .map(|ext| ext == self.config.relationship_extension)
                    .unwrap_or(false)
                {
                    if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                        ids.push(RelationshipId(stem.to_string()));
                    }
                }
            }
        }

        Ok(ids)
    }

    /// Clear all cached relationships
    pub fn clear_cache(&mut self) {
        self.relationship_cache.clear();
    }

    /// Get the file path for a relationship
    fn get_relationship_file_path(&self, id: &RelationshipId) -> PathBuf {
        self.storage_dir.join(format!("{}.{}", id.0, self.config.relationship_extension))
    }

    /// Update the relationship cache
    fn update_cache(&mut self, relationship: RelationshipContext) {
        if self.relationship_cache.len() >= self.config.cache_size {
            // Remove oldest entry
            if let Some(oldest_id) = self.relationship_cache.keys().next().cloned() {
                self.relationship_cache.remove(&oldest_id);
            }
        }
        
        self.relationship_cache.insert(relationship.id.clone(), relationship);
    }

    /// Load relationship without updating cache
    fn load_relationship_without_cache(&self, id: &RelationshipId) -> CryptoResult<RelationshipContext> {
        let file_path = self.get_relationship_file_path(id);
        if !file_path.exists() {
            return Err(CryptoError::RelationshipNotFound(id.0.clone()));
        }

        let stored_data = fs::read(&file_path)?;

        let serialized = if self.config.encrypt_relationships {
            self.decrypt_relationship_data(&stored_data)?
        } else {
            stored_data
        };

        let relationship: RelationshipContext = serde_json::from_slice(&serialized)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        Ok(relationship)
    }

    /// Encrypt relationship data for storage
    fn encrypt_relationship_data(&self, data: &[u8]) -> CryptoResult<Vec<u8>> {
        use aes_gcm::{Aes256Gcm, Key, Nonce, AeadCore, AeadInPlace, KeyInit};
        use rand::rngs::OsRng;

        // In production, this would use the device master key
        let key = self.derive_storage_key();
        let cipher = Aes256Gcm::new(&key);
        let nonce = Aes256Gcm::generate_nonce(&mut OsRng);

        let mut buffer = data.to_vec();
        cipher.encrypt_in_place(&nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Encryption(e.to_string()))?;

        let mut result = nonce.to_vec();
        result.extend_from_slice(&buffer);

        Ok(result)
    }

    /// Decrypt relationship data from storage
    fn decrypt_relationship_data(&self, encrypted_data: &[u8]) -> CryptoResult<Vec<u8>> {
        use aes_gcm::{Aes256Gcm, Key, Nonce, AeadInPlace, KeyInit};

        if encrypted_data.len() < 12 {
            return Err(CryptoError::Decryption("Data too short".to_string()));
        }

        let (nonce_bytes, ciphertext) = encrypted_data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);

        let key = self.derive_storage_key();
        let cipher = Aes256Gcm::new(&key);

        let mut buffer = ciphertext.to_vec();
        cipher.decrypt_in_place(nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Decryption(e.to_string()))?;

        Ok(buffer)
    }

    /// Encrypt backup data
    fn encrypt_backup_data(&self, data: &[u8]) -> CryptoResult<Vec<u8>> {
        // Use the same encryption as relationship data
        self.encrypt_relationship_data(data)
    }

    /// Decrypt backup data
    fn decrypt_backup_data(&self, encrypted_data: &[u8]) -> CryptoResult<Vec<u8>> {
        // Use the same decryption as relationship data
        self.decrypt_relationship_data(encrypted_data)
    }

    /// Derive encryption key for storage
    fn derive_storage_key(&self) -> aes_gcm::Key<aes_gcm::Aes256Gcm> {
        use sha2::{Digest, Sha256};

        // In production, this would be derived from the device master key
        let mut hasher = Sha256::new();
        hasher.update(b"OfficeOS-Storage-Key-V1");
        hasher.update(self.storage_dir.to_string_lossy().as_bytes());

        let hash = hasher.finalize();
        aes_gcm::Key::<aes_gcm::Aes256Gcm>::from_slice(&hash).clone()
    }

    /// Calculate checksum for backup verification
    fn calculate_backup_checksum(&self, relationships: &[RelationshipContext]) -> CryptoResult<String> {
        use sha2::{Digest, Sha256};

        let mut hasher = Sha256::new();
        
        for relationship in relationships {
            let serialized = serde_json::to_vec(relationship)
                .map_err(|e| CryptoError::Storage(e.to_string()))?;
            hasher.update(&serialized);
        }

        Ok(hex::encode(hasher.finalize()))
    }
}

/// Backup data structure
#[derive(Debug, Serialize, Deserialize)]
struct BackupData {
    metadata: BackupMetadata,
    relationships: Vec<RelationshipContext>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::{RelationshipKeypair, PublicKey};
    use tempfile::TempDir;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn create_test_relationship(nickname: &str) -> RelationshipContext {
        let keypair = RelationshipKeypair::generate().unwrap();
        let peer_keypair = RelationshipKeypair::generate().unwrap();
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        RelationshipContext {
            id: RelationshipId(format!("test_{}", nickname)),
            nickname: nickname.to_string(),
            keypair,
            peer_public_key: peer_keypair.public_key,
            created_at: now,
            last_contact: now,
            auto_forget: true,
        }
    }

    #[test]
    fn test_key_storage_basic() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = KeyStorage::new(&temp_dir.path().to_path_buf()).unwrap();

        let relationship = create_test_relationship("alice");
        let id = relationship.id.clone();

        storage.store_relationship(&relationship).unwrap();
        let loaded = storage.load_relationship(&id).unwrap();

        assert_eq!(relationship.nickname, loaded.nickname);
        assert_eq!(relationship.id, loaded.id);
    }

    #[test]
    fn test_storage_info() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = KeyStorage::new(&temp_dir.path().to_path_buf()).unwrap();

        storage.store_relationship(&create_test_relationship("alice")).unwrap();
        storage.store_relationship(&create_test_relationship("bob")).unwrap();

        let info = storage.get_storage_info().unwrap();
        assert_eq!(info.total_relationships, 2);
        assert!(info.is_accessible);
    }

    #[test]
    fn test_backup_restore() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = KeyStorage::new(&temp_dir.path().to_path_buf()).unwrap();

        // Store some relationships
        storage.store_relationship(&create_test_relationship("alice")).unwrap();
        storage.store_relationship(&create_test_relationship("bob")).unwrap();

        // Create backup
        let backup_path = temp_dir.path().join("backup.bak");
        let metadata = storage.create_backup(&backup_path).unwrap();
        assert_eq!(metadata.relationship_count, 2);

        // Clear storage
        storage.remove_relationship(&RelationshipId("test_alice".to_string())).unwrap();
        storage.remove_relationship(&RelationshipId("test_bob".to_string())).unwrap();

        // Restore from backup
        let restored_metadata = storage.restore_from_backup(&backup_path).unwrap();
        assert_eq!(restored_metadata.relationship_count, 2);

        // Verify relationships are restored
        let info = storage.get_storage_info().unwrap();
        assert_eq!(info.total_relationships, 2);
    }

    #[test]
    fn test_cache_functionality() {
        let temp_dir = TempDir::new().unwrap();
        let config = StorageConfig {
            use_cache: true,
            cache_size: 2,
            ..Default::default()
        };
        let mut storage = KeyStorage::with_config(&temp_dir.path().to_path_buf(), config).unwrap();

        let rel1 = create_test_relationship("alice");
        let rel2 = create_test_relationship("bob");
        let rel3 = create_test_relationship("charlie");

        storage.store_relationship(&rel1).unwrap();
        storage.store_relationship(&rel2).unwrap();
        storage.store_relationship(&rel3).unwrap(); // Should evict oldest from cache

        assert_eq!(storage.relationship_cache.len(), 2);
    }
}