/// Cryptographic keypair management for OfficeOS
use crate::crypto::{CryptoError, CryptoResult};
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer, Verifier};
use x25519_dalek::{StaticSecret, PublicKey as X25519PublicKey};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use rand::rngs::OsRng;

/// A public key that can be used for encryption and verification
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PublicKey {
    /// Ed25519 public key for signature verification
    pub verify_key: VerifyingKey,
    /// X25519 public key for encryption
    pub encrypt_key: X25519PublicKey,
}

/// A private key that can be used for decryption and signing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrivateKey {
    /// Ed25519 private key for signing
    pub sign_key: SigningKey,
    /// X25519 private key for decryption
    pub decrypt_key: StaticSecret,
}

/// A complete keypair for cryptographic operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Keypair {
    pub public_key: PublicKey,
    pub private_key: PrivateKey,
}

/// Device master keypair (used for device identity and key storage encryption)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceKeypair {
    pub public_key: PublicKey,
    pub private_key: PrivateKey,
}

/// Relationship-specific keypair (unique per relationship)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipKeypair {
    pub public_key: PublicKey,
    pub private_key: PrivateKey,
}

impl PublicKey {
    /// Convert public key to bytes for hashing and storage
    pub fn as_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(self.verify_key.as_bytes());
        bytes.extend_from_slice(self.encrypt_key.as_bytes());
        bytes
    }

    /// Create public key from bytes
    pub fn from_bytes(bytes: &[u8]) -> CryptoResult<Self> {
        if bytes.len() != 64 {
            return Err(CryptoError::InvalidKey("Public key must be 64 bytes".to_string()));
        }

        let verify_key = VerifyingKey::from_bytes(&bytes[0..32].try_into().unwrap())
            .map_err(|e| CryptoError::InvalidKey(format!("Invalid Ed25519 key: {}", e)))?;
            
        let encrypt_key = X25519PublicKey::from(bytes[32..64].try_into().unwrap());

        Ok(Self {
            verify_key,
            encrypt_key,
        })
    }

    /// Verify a signature
    pub fn verify(&self, message: &[u8], signature: &[u8]) -> CryptoResult<()> {
        let sig = Signature::from_bytes(signature.try_into()
            .map_err(|_| CryptoError::SignatureVerification)?);
            
        self.verify_key.verify(message, &sig)
            .map_err(|_| CryptoError::SignatureVerification)
    }
}

impl PrivateKey {
    /// Sign a message
    pub fn sign(&self, message: &[u8]) -> Vec<u8> {
        self.sign_key.sign(message).to_bytes().to_vec()
    }

    /// Perform key exchange to get shared secret
    pub fn key_exchange(&self, peer_public: &PublicKey) -> [u8; 32] {
        self.decrypt_key.diffie_hellman(&peer_public.encrypt_key).to_bytes()
    }
}

impl Keypair {
    /// Generate a new random keypair
    pub fn generate() -> CryptoResult<Self> {
        let mut rng = OsRng;
        
        // Generate Ed25519 keypair for signing
        let sign_key = SigningKey::generate(&mut rng);
        let verify_key = sign_key.verifying_key();
        
        // Generate X25519 keypair for encryption
        let decrypt_key = StaticSecret::new(&mut rng);
        let encrypt_key = X25519PublicKey::from(&decrypt_key);

        Ok(Self {
            public_key: PublicKey {
                verify_key,
                encrypt_key,
            },
            private_key: PrivateKey {
                sign_key,
                decrypt_key,
            },
        })
    }

    /// Encrypt data using ChaCha20-Poly1305 with this keypair and a peer's public key
    pub fn encrypt(&self, data: &[u8], peer_public: &PublicKey) -> CryptoResult<Vec<u8>> {
        use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce, AeadCore, AeadInPlace, KeyInit};
        
        // Perform key exchange to get shared secret
        let shared_secret = self.private_key.key_exchange(peer_public);
        
        // Use shared secret as ChaCha20-Poly1305 key
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&shared_secret));
        let nonce = ChaCha20Poly1305::generate_nonce(&mut OsRng);
        
        let mut buffer = data.to_vec();
        cipher.encrypt_in_place(&nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Encryption(e.to_string()))?;
        
        // Prepend nonce to encrypted data
        let mut result = nonce.to_vec();
        result.extend_from_slice(&buffer);
        
        Ok(result)
    }

    /// Decrypt data using ChaCha20-Poly1305 with this keypair and a peer's public key
    pub fn decrypt(&self, encrypted_data: &[u8], peer_public: &PublicKey) -> CryptoResult<Vec<u8>> {
        use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce, AeadInPlace, KeyInit};
        
        if encrypted_data.len() < 12 {
            return Err(CryptoError::Decryption("Data too short".to_string()));
        }
        
        // Extract nonce and ciphertext
        let (nonce_bytes, ciphertext) = encrypted_data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);
        
        // Perform key exchange to get shared secret
        let shared_secret = self.private_key.key_exchange(peer_public);
        
        // Use shared secret as ChaCha20-Poly1305 key
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&shared_secret));
        
        let mut buffer = ciphertext.to_vec();
        cipher.decrypt_in_place(nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Decryption(e.to_string()))?;
        
        Ok(buffer)
    }

    /// Sign data with this keypair
    pub fn sign(&self, data: &[u8]) -> Vec<u8> {
        self.private_key.sign(data)
    }

    /// Verify a signature using the public key
    pub fn verify(&self, data: &[u8], signature: &[u8]) -> CryptoResult<()> {
        self.public_key.verify(data, signature)
    }
}

impl DeviceKeypair {
    /// Generate a new device keypair or load from storage
    pub fn generate_or_load(storage_dir: &PathBuf) -> CryptoResult<Self> {
        let key_file = storage_dir.join("device_master.key");
        
        if key_file.exists() {
            Self::load_from_file(&key_file)
        } else {
            let keypair = Self::generate()?;
            keypair.save_to_file(&key_file)?;
            Ok(keypair)
        }
    }

    /// Generate a new device keypair
    pub fn generate() -> CryptoResult<Self> {
        let keypair = Keypair::generate()?;
        Ok(Self {
            public_key: keypair.public_key,
            private_key: keypair.private_key,
        })
    }

    /// Save device keypair to encrypted file
    pub fn save_to_file(&self, path: &PathBuf) -> CryptoResult<()> {
        use std::fs;
        
        // Create directory if it doesn't exist
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        
        // Serialize keypair
        let serialized = serde_json::to_vec(self)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
        
        // For device master key, we use simple AES-GCM with hardware-derived key
        // In production, this would use hardware security module or device-specific key
        let encrypted = self.encrypt_device_key(&serialized)?;
        
        fs::write(path, encrypted)?;
        Ok(())
    }

    /// Load device keypair from encrypted file
    pub fn load_from_file(path: &PathBuf) -> CryptoResult<Self> {
        use std::fs;
        
        let encrypted = fs::read(path)?;
        let decrypted = Self::decrypt_device_key(&encrypted)?;
        
        let keypair: Self = serde_json::from_slice(&decrypted)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;
            
        Ok(keypair)
    }

    /// Encrypt data with the device master key
    pub fn encrypt(&self, data: &[u8]) -> CryptoResult<Vec<u8>> {
        // For device encryption, we use our own public key as the peer
        let dummy_keypair = Keypair {
            public_key: self.public_key.clone(),
            private_key: self.private_key.clone(),
        };
        dummy_keypair.encrypt(data, &self.public_key)
    }

    /// Decrypt data with the device master key
    pub fn decrypt(&self, encrypted_data: &[u8]) -> CryptoResult<Vec<u8>> {
        let dummy_keypair = Keypair {
            public_key: self.public_key.clone(),
            private_key: self.private_key.clone(),
        };
        dummy_keypair.decrypt(encrypted_data, &self.public_key)
    }

    /// Encrypt device key for storage (simplified - would use hardware security in production)
    fn encrypt_device_key(&self, data: &[u8]) -> CryptoResult<Vec<u8>> {
        use aes_gcm::{Aes256Gcm, Key, Nonce, AeadCore, AeadInPlace, KeyInit};
        
        // In production, derive this from hardware or device-specific entropy
        // For now, use a deterministic key based on some device characteristics
        let device_key = self.derive_device_storage_key();
        
        let cipher = Aes256Gcm::new(&device_key);
        let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
        
        let mut buffer = data.to_vec();
        cipher.encrypt_in_place(&nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Encryption(e.to_string()))?;
        
        let mut result = nonce.to_vec();
        result.extend_from_slice(&buffer);
        
        Ok(result)
    }

    /// Decrypt device key from storage
    fn decrypt_device_key(encrypted_data: &[u8]) -> CryptoResult<Vec<u8>> {
        use aes_gcm::{Aes256Gcm, Key, Nonce, AeadInPlace, KeyInit};
        
        if encrypted_data.len() < 12 {
            return Err(CryptoError::Decryption("Data too short".to_string()));
        }
        
        let (nonce_bytes, ciphertext) = encrypted_data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);
        
        // Use the same deterministic key derivation
        let device_key = Self::derive_device_storage_key_static();
        
        let cipher = Aes256Gcm::new(&device_key);
        
        let mut buffer = ciphertext.to_vec();
        cipher.decrypt_in_place(nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Decryption(e.to_string()))?;
        
        Ok(buffer)
    }

    /// Derive device-specific key for storage encryption
    fn derive_device_storage_key(&self) -> aes_gcm::Key<aes_gcm::Aes256Gcm> {
        use sha2::{Digest, Sha256};
        
        // In production, this would use:
        // - Hardware security module
        // - CPU serial number
        // - Device-specific entropy
        // - User password/PIN
        
        let mut hasher = Sha256::new();
        hasher.update(b"OfficeOS-Device-Key-V1");
        hasher.update(&self.public_key.as_bytes());
        
        // Add some system-specific data (simplified)
        if let Ok(hostname) = std::env::var("HOSTNAME") {
            hasher.update(hostname.as_bytes());
        }
        
        let hash = hasher.finalize();
        aes_gcm::Key::<aes_gcm::Aes256Gcm>::from_slice(&hash).clone()
    }

    /// Static version for decryption (since we don't have the keypair yet)
    fn derive_device_storage_key_static() -> aes_gcm::Key<aes_gcm::Aes256Gcm> {
        use sha2::{Digest, Sha256};
        
        let mut hasher = Sha256::new();
        hasher.update(b"OfficeOS-Device-Key-V1");
        
        // This is a placeholder - in production we'd need to store
        // device-specific data securely or use hardware features
        if let Ok(hostname) = std::env::var("HOSTNAME") {
            hasher.update(hostname.as_bytes());
        }
        
        let hash = hasher.finalize();
        aes_gcm::Key::<aes_gcm::Aes256Gcm>::from_slice(&hash).clone()
    }
}

impl RelationshipKeypair {
    /// Generate a new relationship-specific keypair
    pub fn generate() -> CryptoResult<Self> {
        let keypair = Keypair::generate()?;
        Ok(Self {
            public_key: keypair.public_key,
            private_key: keypair.private_key,
        })
    }

    /// Encrypt data for the peer in this relationship
    pub fn encrypt(&self, data: &[u8], peer_public: &PublicKey) -> CryptoResult<Vec<u8>> {
        let keypair = Keypair {
            public_key: self.public_key.clone(),
            private_key: self.private_key.clone(),
        };
        keypair.encrypt(data, peer_public)
    }

    /// Decrypt data from the peer in this relationship
    pub fn decrypt(&self, encrypted_data: &[u8], peer_public: &PublicKey) -> CryptoResult<Vec<u8>> {
        let keypair = Keypair {
            public_key: self.public_key.clone(),
            private_key: self.private_key.clone(),
        };
        keypair.decrypt(encrypted_data, peer_public)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_keypair_generation() {
        let keypair = Keypair::generate().unwrap();
        assert_eq!(keypair.public_key.as_bytes().len(), 64);
    }

    #[test]
    fn test_encryption_decryption() {
        let alice = Keypair::generate().unwrap();
        let bob = Keypair::generate().unwrap();
        
        let message = b"Hello, secure world!";
        
        let encrypted = alice.encrypt(message, &bob.public_key).unwrap();
        let decrypted = bob.decrypt(&encrypted, &alice.public_key).unwrap();
        
        assert_eq!(message, decrypted.as_slice());
    }

    #[test]
    fn test_signing_verification() {
        let keypair = Keypair::generate().unwrap();
        let message = b"Sign this message";
        
        let signature = keypair.sign(message);
        assert!(keypair.verify(message, &signature).is_ok());
    }

    #[test]
    fn test_device_keypair_storage() {
        let temp_dir = TempDir::new().unwrap();
        let key_path = temp_dir.path().join("test_device.key");
        
        let original = DeviceKeypair::generate().unwrap();
        original.save_to_file(&key_path).unwrap();
        
        let loaded = DeviceKeypair::load_from_file(&key_path).unwrap();
        
        assert_eq!(original.public_key.as_bytes(), loaded.public_key.as_bytes());
    }

    #[test]
    fn test_public_key_serialization() {
        let keypair = Keypair::generate().unwrap();
        let bytes = keypair.public_key.as_bytes();
        let restored = PublicKey::from_bytes(&bytes).unwrap();
        
        assert_eq!(keypair.public_key.as_bytes(), restored.as_bytes());
    }
}