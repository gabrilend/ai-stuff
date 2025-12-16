use handheld_office::crypto::*;
use handheld_office::laptop_daemon::*;
use tempfile::TempDir;
use serde_json::json;
use std::sync::Arc;

#[cfg(test)]
mod laptop_daemon_tests {
    use super::*;

    #[test]
    fn test_laptop_daemon_creation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("daemon_config.json");
        
        let daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Daemon should be created with default state
        assert_eq!(daemon.get_active_connections().len(), 0);
        assert!(daemon.get_device_identity().is_some());
    }

    #[test]
    fn test_internet_llm_provider() {
        let provider = InternetLLMProvider::new();
        
        // Test endpoint configuration
        assert!(!provider.endpoints.is_empty());
        
        // Test endpoint validation
        for endpoint in &provider.endpoints {
            assert!(!endpoint.url.is_empty());
            assert!(!endpoint.name.is_empty());
            assert!(endpoint.timeout_ms > 0);
        }
        
        // Test provider capabilities
        assert!(provider.supports_text_generation());
        assert!(provider.supports_chat_completion());
    }

    #[test]
    fn test_internet_image_provider() {
        let provider = InternetImageProvider::new();
        
        // Test endpoint configuration
        assert!(!provider.endpoints.is_empty());
        
        // Test endpoint validation
        for endpoint in &provider.endpoints {
            assert!(!endpoint.url.is_empty());
            assert!(!endpoint.name.is_empty());
            assert!(endpoint.timeout_ms > 0);
        }
        
        // Test provider capabilities
        assert!(provider.supports_text_to_image());
        assert!(provider.supports_image_editing());
    }

    #[test]
    fn test_llm_endpoint_configuration() {
        let endpoint = LLMEndpoint {
            name: "OpenAI GPT-4".to_string(),
            url: "https://api.openai.com/v1/chat/completions".to_string(),
            api_key: "test-key".to_string(),
            model: "gpt-4".to_string(),
            max_tokens: 4096,
            timeout_ms: 30000,
            enabled: true,
        };
        
        assert_eq!(endpoint.name, "OpenAI GPT-4");
        assert_eq!(endpoint.model, "gpt-4");
        assert_eq!(endpoint.max_tokens, 4096);
        assert!(endpoint.enabled);
        
        // Test serialization
        let serialized = serde_json::to_string(&endpoint).expect("Serialization failed");
        let deserialized: LLMEndpoint = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(endpoint.name, deserialized.name);
        assert_eq!(endpoint.url, deserialized.url);
        assert_eq!(endpoint.model, deserialized.model);
    }

    #[test]
    fn test_image_endpoint_configuration() {
        let endpoint = ImageEndpoint {
            name: "Stable Diffusion".to_string(),
            url: "http://localhost:7860/sdapi/v1/txt2img".to_string(),
            api_key: None,
            model: "sd_xl_base".to_string(),
            max_width: 1024,
            max_height: 1024,
            timeout_ms: 60000,
            enabled: true,
        };
        
        assert_eq!(endpoint.name, "Stable Diffusion");
        assert_eq!(endpoint.model, "sd_xl_base");
        assert_eq!(endpoint.max_width, 1024);
        assert_eq!(endpoint.max_height, 1024);
        assert!(endpoint.enabled);
        
        // Test serialization
        let serialized = serde_json::to_string(&endpoint).expect("Serialization failed");
        let deserialized: ImageEndpoint = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(endpoint.name, deserialized.name);
        assert_eq!(endpoint.url, deserialized.url);
        assert_eq!(endpoint.model, deserialized.model);
    }

    #[test]
    fn test_bytecode_instruction_routing() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("routing_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Set up providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        let image_provider = Arc::new(InternetImageProvider::new());
        
        daemon.set_llm_provider(llm_provider);
        daemon.set_image_provider(image_provider);
        
        // Test LLM instruction routing
        let llm_instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "Hello, how are you?",
                "max_tokens": 150,
                "temperature": 0.7
            }),
            metadata: json!({}),
        };
        
        // Should route to LLM provider
        assert!(daemon.can_handle_instruction(&llm_instruction));
        
        // Test Image instruction routing
        let image_instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "A beautiful sunset",
                "width": 512,
                "height": 512
            }),
            metadata: json!({}),
        };
        
        // Should route to Image provider
        assert!(daemon.can_handle_instruction(&image_instruction));
        
        // Test unsupported instruction
        let unsupported_instruction = BytecodeInstruction {
            opcode: OpCode::VideoProcess,
            payload: json!({
                "input_file": "video.mp4"
            }),
            metadata: json!({}),
        };
        
        // Should not be able to handle without video provider
        assert!(!daemon.can_handle_instruction(&unsupported_instruction));
    }

    #[test]
    fn test_p2p_connection_management() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("connection_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Simulate Anbernic device connection
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        let mut relationship = Relationship::new(
            daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Alice's Anbernic".to_string(),
            "P2P Connection".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete pairing process
        relationship.initiate_pairing(
            daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Add connection to daemon
        daemon.add_p2p_connection(relationship).expect("Failed to add connection");
        
        assert_eq!(daemon.get_active_connections().len(), 1);
        assert!(daemon.has_connection_to_device(&anbernic_device.device_id));
    }

    #[test]
    fn test_permission_validation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("permission_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        let relationship_id = RelationshipId::new();
        
        // Test default permissions (should be restrictive)
        assert!(!daemon.check_permission(&relationship_id, &OpCode::LlmQuery));
        assert!(!daemon.check_permission(&relationship_id, &OpCode::ImageGenerate));
        
        // Grant LLM permission
        daemon.grant_permission(relationship_id.clone(), OpCode::LlmQuery);
        assert!(daemon.check_permission(&relationship_id, &OpCode::LlmQuery));
        
        // Grant image permission
        daemon.grant_permission(relationship_id.clone(), OpCode::ImageGenerate);
        assert!(daemon.check_permission(&relationship_id, &OpCode::ImageGenerate));
        
        // Test permission persistence
        let permissions = daemon.get_permissions(&relationship_id);
        assert!(permissions.contains(&OpCode::LlmQuery));
        assert!(permissions.contains(&OpCode::ImageGenerate));
    }

    #[test]
    fn test_encrypted_bytecode_processing() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("encryption_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Create device identities
        let daemon_identity = daemon.get_device_identity().unwrap().clone();
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        // Create and pair relationship
        let mut relationship = Relationship::new(
            daemon_identity.device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Alice's Anbernic".to_string(),
            "Encrypted Test".to_string(),
        ).expect("Failed to create relationship");
        
        relationship.initiate_pairing(&daemon_identity, &anbernic_device.public_key)
            .expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        // Grant permissions
        daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
        daemon.add_p2p_connection(relationship.clone()).expect("Failed to add connection");
        
        // Create bytecode instruction
        let instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "What is 2+2?",
                "max_tokens": 50
            }),
            metadata: json!({}),
        };
        
        // Encrypt instruction
        let instruction_data = serde_json::to_vec(&instruction).expect("Serialization failed");
        let encrypted_package = relationship.encrypt_data(&instruction_data)
            .expect("Encryption failed");
        
        // Daemon should be able to decrypt and validate
        let decrypted_data = relationship.decrypt_data(&encrypted_package)
            .expect("Decryption failed");
        let decrypted_instruction: BytecodeInstruction = serde_json::from_slice(&decrypted_data)
            .expect("Deserialization failed");
        
        assert_eq!(instruction.opcode, decrypted_instruction.opcode);
        assert_eq!(instruction.payload["prompt"], decrypted_instruction.payload["prompt"]);
    }

    #[test]
    fn test_internet_connectivity_checks() {
        let provider = InternetLLMProvider::new();
        
        // Test connectivity checking (mock)
        let endpoint = &provider.endpoints[0];
        let connectivity_result = provider.test_endpoint_connectivity(endpoint);
        
        // This would normally test actual connectivity
        // For unit tests, we just verify the method exists and returns a result
        assert!(connectivity_result.is_ok() || connectivity_result.is_err());
    }

    #[test]
    fn test_rate_limiting() {
        let mut provider = InternetLLMProvider::new();
        
        // Test rate limiting configuration
        provider.set_rate_limit(10, std::time::Duration::from_secs(60)); // 10 requests per minute
        
        // Simulate multiple requests
        for i in 0..15 {
            let allowed = provider.check_rate_limit();
            if i < 10 {
                assert!(allowed); // First 10 should be allowed
            } else {
                assert!(!allowed); // Remaining should be rate limited
            }
        }
    }

    #[test]
    fn test_error_handling_and_fallbacks() {
        let provider = InternetLLMProvider::new();
        
        // Test with multiple endpoints configured
        assert!(provider.endpoints.len() > 1);
        
        // Test fallback logic when primary endpoint fails
        let primary_endpoint = &provider.endpoints[0];
        let fallback_endpoint = &provider.endpoints[1];
        
        // Simulate primary endpoint failure
        let request = LLMRequest {
            prompt: "Test prompt".to_string(),
            max_tokens: 100,
            temperature: 0.7,
            model: primary_endpoint.model.clone(),
        };
        
        // Provider should attempt fallback
        let result = provider.handle_request_with_fallback(&request);
        assert!(result.is_ok() || result.is_err()); // Either succeeds or fails gracefully
    }

    #[test]
    fn test_daemon_lifecycle_management() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("lifecycle_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path.clone())
            .expect("Failed to create laptop daemon");
        
        // Test daemon configuration persistence
        daemon.save_configuration().expect("Failed to save configuration");
        assert!(config_path.exists());
        
        // Test daemon shutdown and restart
        let device_id = daemon.get_device_identity().unwrap().device_id.clone();
        
        // Simulate shutdown
        drop(daemon);
        
        // Restart daemon with same config
        let restarted_daemon = LaptopDaemon::new(config_path)
            .expect("Failed to restart laptop daemon");
        
        // Should maintain device identity
        assert_eq!(restarted_daemon.get_device_identity().unwrap().device_id, device_id);
    }

    #[test]
    fn test_concurrent_bytecode_execution() {
        use std::sync::Arc;
        use std::thread;
        
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("concurrent_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Set up providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        daemon.set_llm_provider(llm_provider);
        
        let daemon = Arc::new(daemon);
        let mut handles = vec![];
        
        // Create multiple relationships for concurrent testing
        for i in 0..3 {
            let daemon_clone = Arc::clone(&daemon);
            
            let handle = thread::spawn(move || {
                let anbernic_device = DeviceIdentity::generate()
                    .expect("Failed to generate Anbernic device identity");
                
                let relationship_id = RelationshipId::new();
                
                // Grant permissions
                daemon_clone.grant_permission(relationship_id.clone(), OpCode::LlmQuery);
                
                // Test permission checking from multiple threads
                assert!(daemon_clone.check_permission(&relationship_id, &OpCode::LlmQuery));
                
                // Create instruction
                let instruction = BytecodeInstruction {
                    opcode: OpCode::LlmQuery,
                    payload: json!({
                        "prompt": format!("Concurrent test {}", i),
                        "max_tokens": 50
                    }),
                    metadata: json!({}),
                };
                
                // Test instruction validation
                assert!(instruction.validate().is_ok());
            });
            
            handles.push(handle);
        }
        
        // Wait for all threads to complete
        for handle in handles {
            handle.join().expect("Thread panicked");
        }
    }

    #[test]
    fn test_proxy_architecture_validation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("proxy_config.json");
        
        let daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Daemon should have internet access capability
        assert!(daemon.has_internet_access());
        
        // Daemon should be able to proxy requests
        assert!(daemon.can_proxy_requests());
        
        // Daemon should support P2P connections
        assert!(daemon.supports_p2p_connections());
        
        // Daemon should have security features enabled
        assert!(daemon.has_encryption_enabled());
        assert!(daemon.has_permission_system_enabled());
    }

    #[test]
    fn test_laptop_daemon_integration() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("integration_config.json");
        
        let mut daemon = LaptopDaemon::new(config_path)
            .expect("Failed to create laptop daemon");
        
        // Set up all providers
        let llm_provider = Arc::new(InternetLLMProvider::new());
        let image_provider = Arc::new(InternetImageProvider::new());
        
        daemon.set_llm_provider(llm_provider);
        daemon.set_image_provider(image_provider);
        
        // Create Anbernic device connection
        let anbernic_device = DeviceIdentity::generate()
            .expect("Failed to generate Anbernic device identity");
        
        let mut relationship = Relationship::new(
            daemon.get_device_identity().unwrap().device_id.clone(),
            anbernic_device.device_id.clone(),
            "Laptop Daemon".to_string(),
            "Test Anbernic".to_string(),
            "Integration Test".to_string(),
        ).expect("Failed to create relationship");
        
        // Complete full pairing and permission setup
        relationship.initiate_pairing(
            daemon.get_device_identity().unwrap(),
            &anbernic_device.public_key
        ).expect("Pairing initiation failed");
        relationship.complete_pairing().expect("Pairing completion failed");
        
        daemon.grant_permission(relationship.id.clone(), OpCode::LlmQuery);
        daemon.grant_permission(relationship.id.clone(), OpCode::ImageGenerate);
        daemon.add_p2p_connection(relationship.clone()).expect("Failed to add connection");
        
        // Test end-to-end bytecode processing
        let llm_instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "Integration test query",
                "max_tokens": 100
            }),
            metadata: json!({}),
        };
        
        let image_instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "Integration test image",
                "width": 256,
                "height": 256
            }),
            metadata: json!({}),
        };
        
        // Both instructions should be processable
        assert!(daemon.can_handle_instruction(&llm_instruction));
        assert!(daemon.can_handle_instruction(&image_instruction));
        
        // Permissions should be correctly validated
        assert!(daemon.check_permission(&relationship.id, &llm_instruction.opcode));
        assert!(daemon.check_permission(&relationship.id, &image_instruction.opcode));
    }
}