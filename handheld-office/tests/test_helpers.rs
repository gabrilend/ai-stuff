//! Test helper functions and utilities for the handheld-office test suite

use handheld_office::crypto::*;

/// Create a test device identity with a given name
pub fn create_test_device_identity(name: &str) -> DeviceIdentity {
    DeviceIdentity::generate().unwrap_or_else(|_| {
        DeviceIdentity {
            device_id: format!("test-device-{}", name),
            public_key: base64::encode(&[0u8; 32]),
            private_key: base64::encode(&[1u8; 32]),
        }
    })
}

/// Create a test relationship between two devices
pub fn create_test_relationship(
    local_name: &str,
    remote_name: &str,
) -> Result<Relationship, Box<dyn std::error::Error>> {
    let local_identity = create_test_device_identity(local_name);
    let remote_identity = create_test_device_identity(remote_name);
    
    Relationship::new(
        local_identity.device_id,
        remote_identity.device_id,
        local_name.to_string(),
        remote_name.to_string(),
        format!("Test relationship: {} <-> {}", local_name, remote_name),
    )
}

/// Create a test LLM endpoint configuration
pub fn create_test_llm_endpoint() -> LLMEndpoint {
    LLMEndpoint {
        name: "test-llm".to_string(),
        url: "http://localhost:11434".to_string(),
        api_key: "test-key".to_string(),
        model: "test-model".to_string(),
        max_tokens: 1000,
        timeout_ms: 30000,
        enabled: true,
    }
}

/// Create a test image endpoint configuration
pub fn create_test_image_endpoint() -> ImageEndpoint {
    ImageEndpoint {
        name: "test-image".to_string(),
        url: "http://localhost:8080".to_string(),
        api_key: Some("test-key".to_string()),
        model: "test-image-model".to_string(),
        max_width: 1024,
        max_height: 1024,
        timeout_ms: 60000,
        enabled: true,
    }
}

/// Create a test chat message
pub fn create_test_chat_message(role: &str, content: &str) -> ChatMessage {
    ChatMessage {
        role: role.to_string(),
        content: content.to_string(),
        timestamp: Some(chrono::Utc::now()),
    }
}

/// Create a test execution context
pub fn create_test_execution_context(relationship_id: RelationshipId) -> ExecutionContext {
    ExecutionContext {
        relationship_id,
        sender_device_id: "test-sender".to_string(),
        execution_id: uuid::Uuid::new_v4().to_string(),
        timestamp: chrono::Utc::now(),
        permissions: vec![OpCode::LlmQuery, OpCode::SystemInfo],
    }
}

/// Create a test instruction batch
pub fn create_test_instruction_batch() -> InstructionBatch {
    InstructionBatch {
        batch_id: uuid::Uuid::new_v4().to_string(),
        instructions: vec![
            BytecodeInstruction {
                instruction_id: uuid::Uuid::new_v4().to_string(),
                opcode: OpCode::LlmQuery,
                payload: serde_json::json!({
                    "prompt": "Hello, world!",
                    "max_tokens": 100
                }),
                created_at: chrono::Utc::now(),
            }
        ],
        created_at: chrono::Utc::now(),
    }
}