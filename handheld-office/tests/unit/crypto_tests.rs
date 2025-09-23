use handheld_office::crypto::*;
use tempfile::TempDir;
use std::path::PathBuf;

#[cfg(test)]
mod crypto_tests {
    use super::*;

    #[test]
    fn test_device_identity_generation() {
        let identity = DeviceIdentity::generate().expect("Failed to generate identity");
        
        // Check that identity has required components
        assert!(!identity.device_id.is_empty());
        assert!(!identity.public_key.is_empty());
        assert!(!identity.private_key.is_empty());
        
        // Device ID should be valid UUID format
        assert!(identity.device_id.len() >= 32);
        
        // Public key should be Ed25519 format (32 bytes base64 encoded)
        let decoded_pubkey = base64::decode(&identity.public_key).expect("Invalid base64");
        assert_eq!(decoded_pubkey.len(), 32);
    }

    #[test]
    fn test_device_identity_serialization() {
        let identity = DeviceIdentity::generate().expect("Failed to generate identity");
        
        // Serialize to JSON
        let serialized = serde_json::to_string(&identity).expect("Serialization failed");
        
        // Deserialize back
        let deserialized: DeviceIdentity = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        // Should be identical
        assert_eq!(identity.device_id, deserialized.device_id);
        assert_eq!(identity.public_key, deserialized.public_key);
        assert_eq!(identity.private_key, deserialized.private_key);
    }

    #[test]
    fn test_relationship_creation_and_validation() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        // Create relationship from Alice's perspective
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test Chat".to_string(),
        ).expect("Failed to create relationship");
        
        assert_eq!(relationship.local_device_id, alice.device_id);
        assert_eq!(relationship.remote_device_id, bob.device_id);
        assert_eq!(relationship.local_name, "Alice");
        assert_eq!(relationship.remote_name, "Bob");
        assert_eq!(relationship.status, RelationshipStatus::PendingPairing);
        
        // Test pairing process
        let pairing_result = relationship.initiate_pairing(&alice, &bob.public_key);
        assert!(pairing_result.is_ok());
        assert_eq!(relationship.status, RelationshipStatus::PairingInitiated);
        
        // Complete pairing
        relationship.complete_pairing().expect("Failed to complete pairing");
        assert_eq!(relationship.status, RelationshipStatus::Paired);
        assert!(relationship.shared_secret.is_some());
    }

    #[test]
    fn test_encryption_decryption_roundtrip() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing to get shared secret
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing failed");
        relationship.complete_pairing().expect("Failed to complete pairing");
        
        let test_data = b"Hello, secure world!";
        
        // Encrypt data
        let encrypted = relationship.encrypt_data(test_data).expect("Encryption failed");
        assert_ne!(encrypted.ciphertext, test_data.to_vec());
        assert!(!encrypted.nonce.is_empty());
        
        // Decrypt data
        let decrypted = relationship.decrypt_data(&encrypted).expect("Decryption failed");
        assert_eq!(decrypted, test_data);
    }

    #[test]
    fn test_pairing_emoji_generation() {
        let emoji_set = CryptoPairingEmoji::generate_set();
        
        // Should generate exactly 5 emojis
        assert_eq!(emoji_set.emojis.len(), 5);
        
        // All emojis should be from the allowed set
        let allowed_emojis = [
            "🔑", "🛡️", "💎", "🌟", "🔒", "🌙", "🎯", "🎪", "🎨", "🎵",
            "🚀", "⚡", "🌈", "🔥", "💫", "🏆", "🎁", "🎭", "🎪", "🎯"
        ];
        
        for emoji in &emoji_set.emojis {
            assert!(allowed_emojis.contains(&emoji.as_str()));
        }
        
        // Test emoji verification
        let correct_emojis = emoji_set.emojis.clone();
        assert!(emoji_set.verify(&correct_emojis));
        
        let incorrect_emojis = vec!["🔑".to_string(), "❌".to_string(), "🛡️".to_string(), "💎".to_string(), "🌟".to_string()];
        assert!(!emoji_set.verify(&incorrect_emojis));
    }

    #[test]
    fn test_device_discovery_lifecycle() {
        let device = DiscoveredDevice {
            device_id: "test-device-123".to_string(),
            name: "Alice's Anbernic".to_string(),
            public_key: "test-public-key".to_string(),
            device_type: DeviceType::Anbernic,
            last_seen: chrono::Utc::now(),
            signal_strength: -45,
            capabilities: vec![DeviceCapability::LLM, DeviceCapability::ImageGeneration],
        };
        
        assert_eq!(device.device_id, "test-device-123");
        assert_eq!(device.name, "Alice's Anbernic");
        assert!(device.capabilities.contains(&DeviceCapability::LLM));
        assert!(device.capabilities.contains(&DeviceCapability::ImageGeneration));
        
        // Test signal strength categorization
        assert!(device.signal_strength > -50); // Good signal
        
        // Test serialization
        let serialized = serde_json::to_string(&device).expect("Serialization failed");
        let deserialized: DiscoveredDevice = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(device.device_id, deserialized.device_id);
        assert_eq!(device.capabilities, deserialized.capabilities);
    }

    #[test]
    fn test_cryptographic_key_management() {
        // Test key generation
        let keypair = CryptoKeyManager::generate_keypair().expect("Key generation failed");
        assert_eq!(keypair.public_key.len(), 32);
        assert_eq!(keypair.private_key.len(), 32);
        
        // Test key derivation
        let shared_secret = CryptoKeyManager::derive_shared_secret(
            &keypair.private_key,
            &keypair.public_key,
        ).expect("Key derivation failed");
        assert_eq!(shared_secret.len(), 32);
        
        // Test encryption key derivation
        let encryption_key = CryptoKeyManager::derive_encryption_key(&shared_secret)
            .expect("Encryption key derivation failed");
        assert_eq!(encryption_key.len(), 32);
    }

    #[test]
    fn test_secure_message_packaging() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        let test_message = "Hello from secure messaging!";
        
        // Package message
        let package = SecureMessagePackage::create(
            &relationship.id,
            test_message.as_bytes(),
            MessageType::Text,
            &alice.device_id,
        ).expect("Message packaging failed");
        
        assert_eq!(package.sender_id, alice.device_id);
        assert_eq!(package.message_type, MessageType::Text);
        assert!(!package.encrypted_payload.ciphertext.is_empty());
        assert!(!package.encrypted_payload.nonce.is_empty());
        
        // Verify package integrity
        let decrypted = relationship.decrypt_data(&package.encrypted_payload)
            .expect("Message decryption failed");
        assert_eq!(decrypted, test_message.as_bytes());
    }

    #[test]
    fn test_p2p_migration_adapter() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("p2p_config.json");
        
        let adapter = P2PMigrationAdapter::new(config_path.clone())
            .expect("Failed to create P2P adapter");
        
        // Test device addition
        let device = DiscoveredDevice {
            device_id: "test-device".to_string(),
            name: "Test Device".to_string(),
            public_key: "test-key".to_string(),
            device_type: DeviceType::Anbernic,
            last_seen: chrono::Utc::now(),
            signal_strength: -40,
            capabilities: vec![DeviceCapability::LLM],
        };
        
        assert!(adapter.add_discovered_device(device).is_ok());
        assert_eq!(adapter.get_discovered_devices().len(), 1);
        
        // Test configuration persistence
        assert!(config_path.exists());
    }

    #[test]
    fn test_encryption_with_different_algorithms() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        let test_data = b"Test data for encryption algorithms";
        
        // Test with different message types
        let text_package = SecureMessagePackage::create(
            &relationship.id,
            test_data,
            MessageType::Text,
            &alice.device_id,
        ).expect("Text packaging failed");
        
        let file_package = SecureMessagePackage::create(
            &relationship.id,
            test_data,
            MessageType::File,
            &alice.device_id,
        ).expect("File packaging failed");
        
        // Both should decrypt to same data
        let text_decrypted = relationship.decrypt_data(&text_package.encrypted_payload)
            .expect("Text decryption failed");
        let file_decrypted = relationship.decrypt_data(&file_package.encrypted_payload)
            .expect("File decryption failed");
        
        assert_eq!(text_decrypted, test_data);
        assert_eq!(file_decrypted, test_data);
        assert_eq!(text_decrypted, file_decrypted);
    }

    #[test]
    fn test_relationship_status_transitions() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Test status progression
        assert_eq!(relationship.status, RelationshipStatus::PendingPairing);
        
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing initiation failed");
        assert_eq!(relationship.status, RelationshipStatus::PairingInitiated);
        
        relationship.complete_pairing().expect("Pairing completion failed");
        assert_eq!(relationship.status, RelationshipStatus::Paired);
        
        // Test trusted status
        relationship.mark_as_trusted().expect("Marking as trusted failed");
        assert_eq!(relationship.status, RelationshipStatus::Trusted);
        
        // Test verification
        relationship.mark_as_verified().expect("Marking as verified failed");
        assert_eq!(relationship.status, RelationshipStatus::Verified);
    }

    #[test]
    fn test_large_message_encryption() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Test with large data (1MB)
        let large_data = vec![42u8; 1024 * 1024];
        
        let encrypted = relationship.encrypt_data(&large_data).expect("Large data encryption failed");
        let decrypted = relationship.decrypt_data(&encrypted).expect("Large data decryption failed");
        
        assert_eq!(decrypted, large_data);
        assert_eq!(decrypted.len(), 1024 * 1024);
    }

    #[test]
    fn test_concurrent_encryption_operations() {
        use std::sync::Arc;
        use std::thread;
        
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let bob = DeviceIdentity::generate().expect("Failed to generate Bob's identity");
        
        let mut relationship = Relationship::new(
            alice.device_id.clone(),
            bob.device_id.clone(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing
        relationship.initiate_pairing(&alice, &bob.public_key).expect("Pairing failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        let relationship = Arc::new(relationship);
        let mut handles = vec![];
        
        // Spawn multiple threads doing encryption/decryption
        for i in 0..5 {
            let rel_clone = Arc::clone(&relationship);
            let handle = thread::spawn(move || {
                let test_data = format!("Test message {}", i);
                let encrypted = rel_clone.encrypt_data(test_data.as_bytes()).unwrap();
                let decrypted = rel_clone.decrypt_data(&encrypted).unwrap();
                assert_eq!(decrypted, test_data.as_bytes());
            });
            handles.push(handle);
        }
        
        // Wait for all threads to complete
        for handle in handles {
            handle.join().expect("Thread panicked");
        }
    }

    #[test]
    fn test_error_handling_invalid_keys() {
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        
        // Test with invalid public key
        let invalid_public_key = "invalid-key-data";
        let result = Relationship::new(
            alice.device_id.clone(),
            "bob-device".to_string(),
            "Alice".to_string(),
            "Bob".to_string(),
            "Test".to_string(),
        );
        
        assert!(result.is_ok()); // Relationship creation should work
        
        let mut relationship = result.unwrap();
        let pairing_result = relationship.initiate_pairing(&alice, invalid_public_key);
        assert!(pairing_result.is_err()); // But pairing with invalid key should fail
    }

    #[test]
    fn test_configuration_persistence() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("crypto_config.json");
        
        // Create configuration
        let mut config = CryptoConfig::new();
        config.add_device_identity(DeviceIdentity::generate().unwrap());
        config.add_device_identity(DeviceIdentity::generate().unwrap());
        
        // Save configuration
        config.save_to_file(&config_path).expect("Failed to save config");
        assert!(config_path.exists());
        
        // Load configuration
        let loaded_config = CryptoConfig::load_from_file(&config_path)
            .expect("Failed to load config");
        
        assert_eq!(config.device_identities.len(), loaded_config.device_identities.len());
        assert_eq!(config.relationships.len(), loaded_config.relationships.len());
    }

    #[test]
    fn test_device_capability_management() {
        let capabilities = vec![
            DeviceCapability::LLM,
            DeviceCapability::ImageGeneration,
            DeviceCapability::FileTransfer,
        ];
        
        // Test capability checking
        assert!(capabilities.contains(&DeviceCapability::LLM));
        assert!(capabilities.contains(&DeviceCapability::ImageGeneration));
        assert!(!capabilities.contains(&DeviceCapability::VideoProcessing));
        
        // Test serialization
        let serialized = serde_json::to_string(&capabilities).expect("Serialization failed");
        let deserialized: Vec<DeviceCapability> = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(capabilities, deserialized);
    }
}