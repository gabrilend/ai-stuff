use handheld_office::crypto::*;
use tempfile::TempDir;
use serde_json::json;

#[cfg(test)]
mod bytecode_tests {
    use super::*;

    #[test]
    fn test_opcode_serialization() {
        // Test all OpCode variants can be serialized/deserialized
        let opcodes = vec![
            OpCode::LlmQuery,
            OpCode::ImageGenerate,
            OpCode::FileTransfer,
            OpCode::AudioProcess,
            OpCode::VideoProcess,
            OpCode::SystemInfo,
            OpCode::NetworkStatus,
            OpCode::DeviceControl,
        ];
        
        for opcode in opcodes {
            let serialized = serde_json::to_string(&opcode).expect("Serialization failed");
            let deserialized: OpCode = serde_json::from_str(&serialized)
                .expect("Deserialization failed");
            assert_eq!(opcode, deserialized);
        }
    }

    #[test]
    fn test_bytecode_instruction_creation() {
        let instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "What is the weather today?",
                "max_tokens": 150,
                "temperature": 0.7
            }),
            metadata: json!({
                "priority": "normal",
                "timeout": 30
            }),
        };
        
        assert_eq!(instruction.opcode, OpCode::LlmQuery);
        assert_eq!(instruction.payload["prompt"], "What is the weather today?");
        assert_eq!(instruction.metadata["priority"], "normal");
    }

    #[test]
    fn test_bytecode_instruction_serialization() {
        let instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "A sunset over mountains",
                "width": 512,
                "height": 512,
                "style": "photorealistic"
            }),
            metadata: json!({
                "quality": "high",
                "format": "png"
            }),
        };
        
        let serialized = serde_json::to_string(&instruction).expect("Serialization failed");
        let deserialized: BytecodeInstruction = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(instruction.opcode, deserialized.opcode);
        assert_eq!(instruction.payload["prompt"], deserialized.payload["prompt"]);
        assert_eq!(instruction.metadata["quality"], deserialized.metadata["quality"]);
    }

    #[test]
    fn test_bytecode_executor_creation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("executor_config.json");
        
        let executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        // Executor should be created with default providers
        assert!(executor.llm_provider.is_none()); // No provider set initially
        assert!(executor.image_provider.is_none()); // No provider set initially
    }

    #[test]
    fn test_permission_checking() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("executor_config.json");
        
        let mut executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        let alice = DeviceIdentity::generate().expect("Failed to generate Alice's identity");
        let relationship_id = RelationshipId::new();
        
        // Test default permissions (should be restrictive)
        assert!(!executor.check_permission(&relationship_id, &OpCode::LlmQuery));
        assert!(!executor.check_permission(&relationship_id, &OpCode::ImageGenerate));
        
        // Grant LLM permission
        executor.grant_permission(relationship_id.clone(), OpCode::LlmQuery);
        assert!(executor.check_permission(&relationship_id, &OpCode::LlmQuery));
        assert!(!executor.check_permission(&relationship_id, &OpCode::ImageGenerate)); // Still no image permission
        
        // Grant image permission
        executor.grant_permission(relationship_id.clone(), OpCode::ImageGenerate);
        assert!(executor.check_permission(&relationship_id, &OpCode::ImageGenerate));
    }

    #[test]
    fn test_instruction_validation() {
        // Valid LLM instruction
        let valid_llm = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "Hello world",
                "max_tokens": 100
            }),
            metadata: json!({}),
        };
        
        assert!(valid_llm.validate().is_ok());
        
        // Invalid LLM instruction (missing prompt)
        let invalid_llm = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "max_tokens": 100
            }),
            metadata: json!({}),
        };
        
        assert!(invalid_llm.validate().is_err());
        
        // Valid image instruction
        let valid_image = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "A beautiful landscape",
                "width": 512,
                "height": 512
            }),
            metadata: json!({}),
        };
        
        assert!(valid_image.validate().is_ok());
        
        // Invalid image instruction (invalid dimensions)
        let invalid_image = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({
                "prompt": "A beautiful landscape",
                "width": -1,
                "height": 512
            }),
            metadata: json!({}),
        };
        
        assert!(invalid_image.validate().is_err());
    }

    #[test]
    fn test_file_transfer_instruction() {
        let instruction = BytecodeInstruction {
            opcode: OpCode::FileTransfer,
            payload: json!({
                "operation": "upload",
                "filename": "test.txt",
                "file_size": 1024,
                "file_hash": "sha256:abc123def456",
                "chunk_size": 256
            }),
            metadata: json!({
                "compression": "gzip",
                "encryption": true
            }),
        };
        
        assert!(instruction.validate().is_ok());
        assert_eq!(instruction.payload["operation"], "upload");
        assert_eq!(instruction.payload["filename"], "test.txt");
        assert_eq!(instruction.payload["file_size"], 1024);
    }

    #[test]
    fn test_system_info_instruction() {
        let instruction = BytecodeInstruction {
            opcode: OpCode::SystemInfo,
            payload: json!({
                "info_type": "device_status",
                "include_capabilities": true,
                "include_performance": false
            }),
            metadata: json!({
                "format": "json"
            }),
        };
        
        assert!(instruction.validate().is_ok());
        assert_eq!(instruction.payload["info_type"], "device_status");
        assert_eq!(instruction.payload["include_capabilities"], true);
    }

    #[test]
    fn test_execution_context_creation() {
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
        
        let context = ExecutionContext {
            relationship_id: relationship.id.clone(),
            sender_device_id: alice.device_id.clone(),
            execution_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            permissions: vec![OpCode::LlmQuery, OpCode::SystemInfo],
        };
        
        assert_eq!(context.relationship_id, relationship.id);
        assert_eq!(context.sender_device_id, alice.device_id);
        assert!(context.permissions.contains(&OpCode::LlmQuery));
        assert!(context.permissions.contains(&OpCode::SystemInfo));
        assert!(!context.permissions.contains(&OpCode::ImageGenerate));
    }

    #[test]
    fn test_execution_result_handling() {
        let success_result = ExecutionResult {
            success: true,
            result_data: json!({
                "response": "Hello from LLM",
                "tokens_used": 25,
                "processing_time_ms": 150
            }),
            error_message: None,
            execution_time: std::time::Duration::from_millis(150),
        };
        
        assert!(success_result.success);
        assert_eq!(success_result.result_data["response"], "Hello from LLM");
        assert_eq!(success_result.result_data["tokens_used"], 25);
        assert!(success_result.error_message.is_none());
        
        let error_result = ExecutionResult {
            success: false,
            result_data: json!({}),
            error_message: Some("Permission denied".to_string()),
            execution_time: std::time::Duration::from_millis(10),
        };
        
        assert!(!error_result.success);
        assert_eq!(error_result.error_message.as_ref().unwrap(), "Permission denied");
    }

    #[test]
    fn test_large_payload_handling() {
        // Test with large JSON payload (simulating large file or image data)
        let large_data = "x".repeat(1024 * 1024); // 1MB string
        
        let instruction = BytecodeInstruction {
            opcode: OpCode::FileTransfer,
            payload: json!({
                "operation": "upload",
                "filename": "large_file.txt",
                "data": large_data,
                "compression": "gzip"
            }),
            metadata: json!({}),
        };
        
        // Should serialize/deserialize successfully
        let serialized = serde_json::to_string(&instruction).expect("Serialization failed");
        let deserialized: BytecodeInstruction = serde_json::from_str(&serialized)
            .expect("Deserialization failed");
        
        assert_eq!(instruction.payload["data"], deserialized.payload["data"]);
        assert_eq!(instruction.payload["filename"], deserialized.payload["filename"]);
    }

    #[test]
    fn test_concurrent_instruction_execution() {
        use std::sync::Arc;
        use std::thread;
        
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("concurrent_config.json");
        
        let mut executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        let relationship_id = RelationshipId::new();
        
        // Grant permissions for multiple operations
        executor.grant_permission(relationship_id.clone(), OpCode::LlmQuery);
        executor.grant_permission(relationship_id.clone(), OpCode::SystemInfo);
        
        let executor = Arc::new(executor);
        let mut handles = vec![];
        
        // Spawn multiple threads executing different instructions
        for i in 0..5 {
            let exec_clone = Arc::clone(&executor);
            let rel_id = relationship_id.clone();
            
            let handle = thread::spawn(move || {
                let instruction = BytecodeInstruction {
                    opcode: OpCode::LlmQuery,
                    payload: json!({
                        "prompt": format!("Test query {}", i),
                        "max_tokens": 50
                    }),
                    metadata: json!({}),
                };
                
                let context = ExecutionContext {
                    relationship_id: rel_id,
                    sender_device_id: format!("device-{}", i),
                    execution_id: uuid::Uuid::new_v4().to_string(),
                    timestamp: chrono::Utc::now(),
                    permissions: vec![OpCode::LlmQuery],
                };
                
                // This would normally execute the instruction
                // For now, just validate permission checking works
                assert!(exec_clone.check_permission(&context.relationship_id, &instruction.opcode));
            });
            
            handles.push(handle);
        }
        
        // Wait for all threads to complete
        for handle in handles {
            handle.join().expect("Thread panicked");
        }
    }

    #[test]
    fn test_instruction_batching() {
        let instructions = vec![
            BytecodeInstruction {
                opcode: OpCode::LlmQuery,
                payload: json!({"prompt": "First query", "max_tokens": 50}),
                metadata: json!({}),
            },
            BytecodeInstruction {
                opcode: OpCode::SystemInfo,
                payload: json!({"info_type": "device_status"}),
                metadata: json!({}),
            },
            BytecodeInstruction {
                opcode: OpCode::LlmQuery,
                payload: json!({"prompt": "Second query", "max_tokens": 100}),
                metadata: json!({}),
            },
        ];
        
        let batch = InstructionBatch {
            batch_id: uuid::Uuid::new_v4().to_string(),
            instructions,
            created_at: chrono::Utc::now(),
        };
        
        assert_eq!(batch.instructions.len(), 3);
        assert_eq!(batch.instructions[0].opcode, OpCode::LlmQuery);
        assert_eq!(batch.instructions[1].opcode, OpCode::SystemInfo);
        assert_eq!(batch.instructions[2].opcode, OpCode::LlmQuery);
        
        // Test batch serialization
        let serialized = serde_json::to_string(&batch).expect("Batch serialization failed");
        let deserialized: InstructionBatch = serde_json::from_str(&serialized)
            .expect("Batch deserialization failed");
        
        assert_eq!(batch.batch_id, deserialized.batch_id);
        assert_eq!(batch.instructions.len(), deserialized.instructions.len());
    }

    #[test]
    fn test_permission_inheritance() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("permission_config.json");
        
        let mut executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        let relationship_id = RelationshipId::new();
        
        // Test permission levels
        executor.grant_permission(relationship_id.clone(), OpCode::SystemInfo); // Basic permission
        
        // Basic permissions should not inherit advanced permissions
        assert!(executor.check_permission(&relationship_id, &OpCode::SystemInfo));
        assert!(!executor.check_permission(&relationship_id, &OpCode::DeviceControl));
        
        // Grant device control (advanced permission)
        executor.grant_permission(relationship_id.clone(), OpCode::DeviceControl);
        assert!(executor.check_permission(&relationship_id, &OpCode::DeviceControl));
        
        // Revoke permission
        executor.revoke_permission(relationship_id.clone(), OpCode::SystemInfo);
        assert!(!executor.check_permission(&relationship_id, &OpCode::SystemInfo));
        assert!(executor.check_permission(&relationship_id, &OpCode::DeviceControl)); // Should still have this
    }

    #[test]
    fn test_execution_timeout_handling() {
        let instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({
                "prompt": "This is a very long and complex query that might take a while to process",
                "max_tokens": 1000
            }),
            metadata: json!({
                "timeout_ms": 5000, // 5 second timeout
                "priority": "low"
            }),
        };
        
        // Test timeout metadata extraction
        assert_eq!(instruction.metadata["timeout_ms"], 5000);
        assert_eq!(instruction.metadata["priority"], "low");
        
        // Test instruction validation with timeout
        assert!(instruction.validate().is_ok());
    }

    #[test]
    fn test_error_propagation() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("error_config.json");
        
        let executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        let relationship_id = RelationshipId::new();
        
        // Test permission denied error
        let instruction = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            payload: json!({"prompt": "test"}),
            metadata: json!({}),
        };
        
        // Should fail due to lack of permission
        assert!(!executor.check_permission(&relationship_id, &instruction.opcode));
        
        // Test invalid instruction error
        let invalid_instruction = BytecodeInstruction {
            opcode: OpCode::ImageGenerate,
            payload: json!({}), // Missing required fields
            metadata: json!({}),
        };
        
        assert!(invalid_instruction.validate().is_err());
    }

    #[test]
    fn test_provider_integration() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().join("provider_config.json");
        
        let mut executor = BytecodeExecutor::new(config_path)
            .expect("Failed to create bytecode executor");
        
        // Test setting LLM provider
        let llm_provider = InternetLLMProvider::new();
        executor.set_llm_provider(Arc::new(llm_provider));
        assert!(executor.llm_provider.is_some());
        
        // Test setting image provider
        let image_provider = InternetImageProvider::new();
        executor.set_image_provider(Arc::new(image_provider));
        assert!(executor.image_provider.is_some());
    }
}