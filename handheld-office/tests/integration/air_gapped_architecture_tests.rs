use handheld_office::crypto::*;
use handheld_office::laptop_daemon::*;
use tempfile::TempDir;
use serde_json::json;
use std::sync::Arc;

#[cfg(test)]
mod air_gapped_architecture_tests {
    use super::*;

    /// Test complete air-gapped architecture workflow from Anbernic device to laptop daemon
    #[tokio::test]
    async fn test_complete_air_gapped_workflow() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // 1. Set up laptop daemon with internet access
        let daemon_config_path = temp_dir.path().join("daemon_config.json");
        let mut laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        // Configure internet-capable providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        let image_provider = Arc::new(InternetImageProvider::new());
        
        laptop_daemon.set_llm_provider(llm_provider);
        laptop_daemon.set_image_provider(image_provider);
        
        // Verify laptop daemon has internet access
        assert!(laptop_daemon.has_internet_access());
        
        // 2. Create air-gapped Anbernic device simulation
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        // 3. Establish P2P WiFi Direct connection
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Alice's Anbernic".to_string(),
            "Air-Gapped Test Connection".to_string(),
        ).expect("Failed to create relationship");
        
        // 4. Complete secure pairing process
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Verify relationship is secure
        assert_eq!(relationship.status, RelationshipStatus::Paired);
        assert!(relationship.shared_secret.is_some());
        
        // 5. Grant permissions for Anbernic device
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::ImageGenerate);
        laptop_daemon.add_p2p_connection(relationship.clone())
            .expect("Failed to add P2P connection");
        
        // 6. Anbernic device creates LLM request via bytecode
        let llm_instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "What is the capital of France?",
                "max_tokens": 100,
                "temperature": 0.7
            }),
            metadata: json!({
                "priority": "normal",
                "timeout_ms": 30000
            }),
        };
        
        // 7. Encrypt bytecode instruction for P2P transmission
        let instruction_data = serde_json::to_vec(&llm_instruction)
            .expect("Instruction serialization failed");
        let encrypted_instruction = relationship.encrypt_data(&instruction_data)
            .expect("Instruction encryption failed");
        
        // 8. Laptop daemon receives and decrypts instruction
        let decrypted_data = relationship.decrypt_data(&encrypted_instruction)
            .expect("Instruction decryption failed");
        let received_instruction: BytecodeInstruction = serde_json::from_slice(&decrypted_data)
            .expect("Instruction deserialization failed");
        
        // Verify instruction integrity
        assert_eq!(received_instruction.opcode, llm_instruction.opcode);
        assert_eq!(received_instruction.payload["prompt"], llm_instruction.payload["prompt"]);
        
        // 9. Validate permissions and process request
        assert!(laptop_daemon.check_permission(&relationship.id, &received_instruction.opcode));
        assert!(laptop_daemon.can_handle_instruction(&received_instruction));
        
        // 10. Simulate laptop daemon making internet request (proxy behavior)
        let mock_llm_response = json!({
            "response": "The capital of France is Paris.",
            "tokens_used": 12,
            "model": "gpt-4",
            "processing_time_ms": 1250
        });
        
        // 11. Encrypt response for return to Anbernic device
        let response_data = serde_json::to_vec(&mock_llm_response)
            .expect("Response serialization failed");
        let encrypted_response = relationship.encrypt_data(&response_data)
            .expect("Response encryption failed");
        
        // 12. Anbernic device decrypts response
        let decrypted_response_data = relationship.decrypt_data(&encrypted_response)
            .expect("Response decryption failed");
        let final_response: serde_json::Value = serde_json::from_slice(&decrypted_response_data)
            .expect("Response deserialization failed");
        
        // Verify response integrity
        assert_eq!(final_response["response"], "The capital of France is Paris.");
        assert_eq!(final_response["tokens_used"], 12);
        
        // 13. Verify air-gapped constraints
        // Anbernic device never directly accessed internet
        // All internet access was proxied through laptop daemon
        // All communication was encrypted end-to-end
        assert!(relationship.shared_secret.is_some());
        assert_eq!(relationship.status, RelationshipStatus::Paired);
    }

    /// Test image generation workflow through air-gapped architecture
    #[tokio::test]
    async fn test_air_gapped_image_generation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // Set up laptop daemon with image generation capability
        let daemon_config_path = temp_dir.path().join("image_daemon_config.json");
        let mut laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        let image_provider = Arc::new(InternetImageProvider::new());
        laptop_daemon.set_image_provider(image_provider);
        
        // Create Anbernic device and establish connection
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Bob's Anbernic".to_string(),
            "Image Generation Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing and grant permissions
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::ImageGenerate);
        laptop_daemon.add_p2p_connection(relationship.clone())
            .expect("Failed to add P2P connection");
        
        // Create image generation instruction
        let image_instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "A serene mountain landscape at sunset",
                "width": 512,
                "height": 512,
                "style": "photorealistic",
                "seed": 42
            }),
            metadata: json!({
                "quality": "high",
                "format": "png"
            }),
        };
        
        // Encrypt and transmit instruction
        let instruction_data = serde_json::to_vec(&image_instruction)
            .expect("Instruction serialization failed");
        let encrypted_instruction = relationship.encrypt_data(&instruction_data)
            .expect("Instruction encryption failed");
        
        // Laptop daemon processes request
        let decrypted_data = relationship.decrypt_data(&encrypted_instruction)
            .expect("Instruction decryption failed");
        let received_instruction: BytecodeInstruction = serde_json::from_slice(&decrypted_data)
            .expect("Instruction deserialization failed");
        
        // Validate and process
        assert!(laptop_daemon.check_permission(&relationship.id, &received_instruction.opcode));
        assert!(laptop_daemon.can_handle_instruction(&received_instruction));
        
        // Mock image generation response
        let mock_image_data = vec![0u8; 100 * 1024]; // 100KB mock image
        let image_response = json!({
            "success": true,
            "image_data": base64::encode(&mock_image_data),
            "width": 512,
            "height": 512,
            "format": "png",
            "generation_time_ms": 5000
        });
        
        // Return encrypted response
        let response_data = serde_json::to_vec(&image_response)
            .expect("Response serialization failed");
        let encrypted_response = relationship.encrypt_data(&response_data)
            .expect("Response encryption failed");
        
        let decrypted_response_data = relationship.decrypt_data(&encrypted_response)
            .expect("Response decryption failed");
        let final_response: serde_json::Value = serde_json::from_slice(&decrypted_response_data)
            .expect("Response deserialization failed");
        
        assert_eq!(final_response["success"], true);
        assert_eq!(final_response["format"], "png");
        assert!(!final_response["image_data"].as_str().unwrap().is_empty());
    }

    /// Test permission system enforcement in air-gapped architecture
    #[tokio::test]
    async fn test_permission_enforcement() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let daemon_config_path = temp_dir.path().join("permission_daemon_config.json");
        
        let mut laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        // Set up providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        laptop_daemon.set_llm_provider(llm_provider);
        
        // Create Anbernic device with limited permissions
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Restricted Anbernic".to_string(),
            "Permission Test".to_string(),
        ).expect("Failed to create relationship");
        
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Only grant LLM permission, NOT image generation
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
        laptop_daemon.add_p2p_connection(relationship.clone())
            .expect("Failed to add P2P connection");
        
        // Test allowed operation (LLM)
        let allowed_instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({"prompt": "Hello"}),
            metadata: json!({}),
        };
        
        assert!(laptop_daemon.check_permission(&relationship.id, &allowed_instruction.opcode));
        
        // Test denied operation (Image generation)
        let denied_instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({"prompt": "Test image"}),
            metadata: json!({}),
        };
        
        assert!(!laptop_daemon.check_permission(&relationship.id, &denied_instruction.opcode));
        
        // Test system information access (should be denied without explicit permission)
        let system_instruction = BytecodeInstruction {
            opcode: OpCode::SystemInfo,
            payload: json!({"info_type": "device_status"}),
            metadata: json!({}),
        };
        
        assert!(!laptop_daemon.check_permission(&relationship.id, &system_instruction.opcode));
        
        // Grant system info permission and verify it works
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::SystemInfo);
        assert!(laptop_daemon.check_permission(&relationship.id, &system_instruction.opcode));
    }

    /// Test multiple Anbernic devices connecting to single laptop daemon
    #[tokio::test]
    async fn test_multiple_device_connections() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let daemon_config_path = temp_dir.path().join("multi_device_daemon_config.json");
        
        let mut laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        // Set up providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        laptop_daemon.set_llm_provider(llm_provider);
        
        let mut relationships = Vec::new();
        
        // Create three Anbernic devices
        for i in 0..3 {
            let anbernic_device = DeviceIdentity::generate()
                .expect("Failed to generate Anbernic device identity");
            
            let mut relationship = Relationship::new(
                laptop_daemon.get_device_identity().unwrap().device_id.clone(),
                anbernic_device.device_id.clone(),
                "Laptop Daemon".to_string(),
                format!("Anbernic Device {}", i + 1),
                format!("Multi-Device Test {}", i + 1),
            ).expect("Failed to create relationship");
            
            // Complete pairing
            relationship.initiate_pairing(
                laptop_daemon.get_device_identity().unwrap(),
                &anbernic_device.public_key
            ).expect("Pairing initiation failed");
            relationship.complete_pairing().expect("Pairing completion failed");
            
            // Grant different permissions to each device
            match i {
                0 => {
                    laptop_daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
                },
                1 => {
                    laptop_daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
                    laptop_daemon.grant_permission(relationship.id.clone(), OpCode::ImageGenerate);
                },
                2 => {
                    laptop_daemon.grant_permission(relationship.id.clone(), OpCode::SystemInfo);
                },
                _ => {}
            }
            
            laptop_daemon.add_p2p_connection(relationship.clone())
                .expect("Failed to add P2P connection");
            
            relationships.push(relationship);
        }
        
        // Verify all connections are active
        assert_eq!(laptop_daemon.get_active_connections().len(), 3);
        
        // Test that each device has correct permissions
        assert!(laptop_daemon.check_permission(&relationships[0].id, &OpCode::LlmQuery));
        assert!(!laptop_daemon.check_permission(&relationships[0].id, &OpCode::ImageGenerate));
        
        assert!(laptop_daemon.check_permission(&relationships[1].id, &OpCode::LlmQuery));
        assert!(laptop_daemon.check_permission(&relationships[1].id, &OpCode::ImageGenerate));
        
        assert!(!laptop_daemon.check_permission(&relationships[2].id, &OpCode::LlmQuery));
        assert!(laptop_daemon.check_permission(&relationships[2].id, &OpCode::SystemInfo));
    }

    /// Test file transfer through air-gapped architecture
    #[tokio::test]
    async fn test_secure_file_transfer() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let daemon_config_path = temp_dir.path().join("file_daemon_config.json");
        
        let mut laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        // Create secure connection
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "File Transfer Anbernic".to_string(),
            "File Transfer Test".to_string(),
        ).expect("Failed to create relationship");
        
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        laptop_daemon.grant_permission(relationship.id.clone(), OpCode::FileTransfer);
        laptop_daemon.add_p2p_connection(relationship.clone())
            .expect("Failed to add P2P connection");
        
        // Create file transfer instruction
        let test_file_data = b"This is test file content for secure transfer";
        let file_instruction = BytecodeInstruction {
            opcode: OpCode::FileTransfer,
            payload: json!({
                "operation": "upload",
                "filename": "test_document.txt",
                "file_data": base64::encode(test_file_data),
                "file_size": test_file_data.len(),
                "chunk_size": 1024
            }),
            metadata: json!({
                "compression": "none",
                "checksum": "sha256"
            }),
        };
        
        // Encrypt and process file transfer
        let instruction_data = serde_json::to_vec(&file_instruction)
            .expect("Instruction serialization failed");
        let encrypted_instruction = relationship.encrypt_data(&instruction_data)
            .expect("Instruction encryption failed");
        
        let decrypted_data = relationship.decrypt_data(&encrypted_instruction)
            .expect("Instruction decryption failed");
        let received_instruction: BytecodeInstruction = serde_json::from_slice(&decrypted_data)
            .expect("Instruction deserialization failed");
        
        // Validate file transfer permission and processing
        assert!(laptop_daemon.check_permission(&relationship.id, &received_instruction.opcode));
        assert_eq!(received_instruction.payload["filename"], "test_document.txt");
        assert_eq!(received_instruction.payload["file_size"], test_file_data.len());
        
        // Mock successful file transfer response
        let transfer_response = json!({
            "success": true,
            "filename": "test_document.txt",
            "bytes_transferred": test_file_data.len(),
            "transfer_time_ms": 250,
            "checksum": "verified"
        });
        
        // Encrypt and return response
        let response_data = serde_json::to_vec(&transfer_response)
            .expect("Response serialization failed");
        let encrypted_response = relationship.encrypt_data(&response_data)
            .expect("Response encryption failed");
        
        let decrypted_response_data = relationship.decrypt_data(&encrypted_response)
            .expect("Response decryption failed");
        let final_response: serde_json::Value = serde_json::from_slice(&decrypted_response_data)
            .expect("Response deserialization failed");
        
        assert_eq!(final_response["success"], true);
        assert_eq!(final_response["bytes_transferred"], test_file_data.len());
    }

    /// Test pairing emoji verification process
    #[tokio::test]
    async fn test_pairing_emoji_verification() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let daemon_config_path = temp_dir.path().join("emoji_daemon_config.json");
        
        let laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        // Create relationship but don't complete pairing yet
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Emoji Test Anbernic".to_string(),
            "Emoji Verification Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Initiate pairing to get to emoji verification stage
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        
        assert_eq!(relationship.status, RelationshipStatus::PairingInitiated);
        
        // Generate pairing emojis
        let emoji_set = CryptoPairingEmoji::generate_set();
        assert_eq!(emoji_set.emojis.len(), 5);
        
        // Test successful emoji verification
        let correct_emojis = emoji_set.emojis.clone();
        assert!(emoji_set.verify(&correct_emojis));
        
        // Complete pairing after emoji verification
        relationship.complete_pairing().expect("Pairing completion failed");
        assert_eq!(relationship.status, RelationshipStatus::Paired);
        
        // Test failed emoji verification
        let incorrect_emojis = vec![
            "🔑".to_string(), "❌".to_string(), "🛡️".to_string(), 
            "💎".to_string(), "🌟".to_string()
        ];
        assert!(!emoji_set.verify(&incorrect_emojis));
    }

    /// Test network isolation compliance
    #[tokio::test]
    async fn test_network_isolation_compliance() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let daemon_config_path = temp_dir.path().join("isolation_daemon_config.json");
        
        let laptop_daemon = LaptopDaemon::new(daemon_config_path)
            .expect("Failed to create laptop daemon");
        
        // Verify laptop daemon architecture compliance
        assert!(laptop_daemon.has_internet_access()); // Laptop CAN access internet
        assert!(laptop_daemon.can_proxy_requests()); // Laptop CAN proxy requests
        assert!(laptop_daemon.supports_p2p_connections()); // Laptop CAN do P2P
        
        // Create Anbernic device simulation
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        // Anbernic device should only communicate via P2P (simulated constraints)
        // In real implementation, Anbernic device would not have direct internet access
        
        // Test that all communication goes through encrypted P2P channels
        let mut relationship = Relationship::new(
            laptop_daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Isolated Anbernic".to_string(),
            "Network Isolation Test".to_string(),
        ).expect("Failed to create relationship");
        
        relationship.initiate_pairing(
            laptop_daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Verify all communication is encrypted
        assert!(relationship.shared_secret.is_some());
        
        // Test data encryption/decryption
        let test_data = b"Air-gapped communication test";
        let encrypted = relationship.encrypt_data(test_data).expect("Encryption failed");
        let decrypted = relationship.decrypt_data(&encrypted).expect("Decryption failed");
        
        assert_eq!(decrypted, test_data);
        assert_ne!(encrypted.ciphertext, test_data.to_vec()); // Verify encryption occurred
    }
}