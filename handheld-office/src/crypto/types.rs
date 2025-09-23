//! Core type definitions for cryptographic communication system
//!
//! This module contains all the fundamental types used throughout the
//! cryptographic communication system, including relationship management,
//! bytecode execution, and LLM/image service integration.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Unique identifier for device relationships
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct RelationshipId(pub String);

impl RelationshipId {
    pub fn new() -> Self {
        Self(uuid::Uuid::new_v4().to_string())
    }
    
    pub fn from_string(id: String) -> Self {
        Self(id)
    }
    
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for RelationshipId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Default for RelationshipId {
    fn default() -> Self {
        Self::new()
    }
}

/// Batch of bytecode instructions for processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstructionBatch {
    pub batch_id: String,
    pub instructions: Vec<crate::crypto::BytecodeInstruction>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Context for bytecode instruction execution
#[derive(Debug, Clone)]
pub struct ExecutionContext {
    pub relationship_id: RelationshipId,
    pub sender_device_id: String,
    pub execution_id: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub permissions: Vec<crate::crypto::OpCode>,
    // Additional fields used by bytecode_executor
    pub device_id: String,
    pub request_id: String,
    pub start_time: std::time::Instant,
    pub max_execution_time: std::time::Duration,
}

/// Result of bytecode instruction execution
#[derive(Debug, Clone)]
pub struct ExecutionResult {
    pub success: bool,
    pub result_data: serde_json::Value,
    pub error_message: Option<String>,
    pub execution_time: std::time::Duration,
}

/// LLM service endpoint configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LLMEndpoint {
    pub name: String,
    pub url: String,
    pub api_key: String,
    pub model_name: String,
    pub max_tokens: u32,
    pub timeout_ms: u64,
    pub enabled: bool,
}

/// Image generation endpoint configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageEndpoint {
    pub name: String,
    pub url: String,
    pub api_key: Option<String>,
    pub model_name: String,
    pub max_width: u32,
    pub max_height: u32,
    pub timeout_ms: u64,
    pub enabled: bool,
}

/// Chat message for LLM conversations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: String, // "user", "assistant", "system"
    pub content: String,
    pub timestamp: Option<chrono::DateTime<chrono::Utc>>,
}

/// LLM processing errors
#[derive(Debug, thiserror::Error)]
pub enum LLMError {
    #[error("Network error: {0}")]
    Network(String),
    #[error("API error: {0}")]
    Api(String),
    #[error("Authentication failed")]
    Authentication,
    #[error("Rate limit exceeded")]
    RateLimit,
    #[error("Model not found: {0}")]
    ModelNotFound(String),
    #[error("Token limit exceeded")]
    TokenLimit,
    #[error("Processing timeout")]
    Timeout,
    #[error("Invalid request: {0}")]
    InvalidRequest(String),
}

/// Image generation errors
#[derive(Debug, thiserror::Error)]
pub enum ImageError {
    #[error("Network error: {0}")]
    Network(String),
    #[error("Generation failed: {0}")]
    Generation(String),
    #[error("Invalid dimensions: {width}x{height}")]
    InvalidDimensions { width: u32, height: u32 },
    #[error("Unsupported format: {0}")]
    UnsupportedFormat(String),
    #[error("Processing timeout")]
    Timeout,
    #[error("NSFW content detected")]
    ContentFilter,
    #[error("Invalid prompt: {0}")]
    InvalidPrompt(String),
}

// DeviceKeypair is defined in keypair.rs

/// Device identity for secure P2P communication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceIdentity {
    pub device_id: String,
    pub public_key: String,  // Base64 encoded
    pub private_key: String, // Base64 encoded (stored securely)
}

impl DeviceIdentity {
    pub fn generate() -> Result<Self, Box<dyn std::error::Error>> {
        let device_id = uuid::Uuid::new_v4().to_string();
        let mut rng = rand::rngs::OsRng;
        
        // Generate Ed25519 keypair
        let signing_key = ed25519_dalek::SigningKey::generate(&mut rng);
        let verifying_key = signing_key.verifying_key();
        
        Ok(Self {
            device_id,
            public_key: base64::encode(verifying_key.to_bytes()),
            private_key: base64::encode(signing_key.to_bytes()),
        })
    }
}

/// Discovered device in P2P network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveredDevice {
    pub device_id: String,
    pub name: String,
    pub public_key: String,
    pub address: String,
    pub port: u16,
    pub discovered_at: chrono::DateTime<chrono::Utc>,
    pub capabilities: Vec<String>,
}