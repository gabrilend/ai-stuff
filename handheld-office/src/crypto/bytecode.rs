/// Secure bytecode interface for Anbernic-to-laptop communication
/// Replaces external HTTP dependencies with VM-style instruction format
/// All instructions are encrypted using the crypto packet system

use crate::crypto::{CryptoResult, CryptoError, EncryptedPacket, InnerPacket, PacketType, PacketMetadata};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Virtual machine instruction opcodes
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum OpCode {
    // System operations
    Nop = 0x00,
    Halt = 0x01,
    Echo = 0x02,
    
    // LLM operations
    LlmQuery = 0x10,
    LlmChatCompletion = 0x11,
    LlmCodeGeneration = 0x12,
    LlmTextSummarization = 0x13,
    
    // Image generation operations
    ImageGenerate = 0x20,
    ImageEdit = 0x21,
    ImageUpscale = 0x22,
    ImageVariation = 0x23,
    
    // File operations
    FileTransfer = 0x30,
    FileList = 0x31,
    FileMetadata = 0x32,
    FileDelete = 0x33,
    
    // Computing operations
    ComputeTask = 0x40,
    ComputeStatus = 0x41,
    ComputeResult = 0x42,
    ComputeCancel = 0x43,
    
    // Status operations
    StatusQuery = 0x50,
    CapabilityQuery = 0x51,
    ResourceUsage = 0x52,
    HealthCheck = 0x53,
}

/// Bytecode instruction structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BytecodeInstruction {
    /// Instruction opcode
    pub opcode: OpCode,
    /// Operation-specific parameters
    pub parameters: HashMap<String, BytecodeValue>,
    /// Request ID for tracking responses
    pub request_id: String,
    /// Priority level (0-255)
    pub priority: u8,
    /// Timeout in seconds
    pub timeout_seconds: u32,
}

/// Values that can be passed as parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BytecodeValue {
    /// UTF-8 string
    String(String),
    /// 64-bit integer
    Integer(i64),
    /// 64-bit float
    Float(f64),
    /// Boolean value
    Boolean(bool),
    /// Binary data
    Bytes(Vec<u8>),
    /// Array of values
    Array(Vec<BytecodeValue>),
    /// Map of string keys to values
    Map(HashMap<String, BytecodeValue>),
}

/// Response from executing a bytecode instruction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BytecodeResponse {
    /// Original request ID
    pub request_id: String,
    /// Whether the operation succeeded
    pub success: bool,
    /// Response data (if successful)
    pub result: Option<BytecodeValue>,
    /// Error message (if failed)
    pub error: Option<String>,
    /// Execution time in milliseconds
    pub execution_time_ms: u64,
    /// Resource usage information
    pub resource_usage: Option<ResourceUsage>,
}

/// Resource usage statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceUsage {
    /// CPU time used (in milliseconds)
    pub cpu_time_ms: u64,
    /// Memory used (in bytes)
    pub memory_bytes: u64,
    /// GPU time used (in milliseconds, if applicable)
    pub gpu_time_ms: Option<u64>,
    /// Disk I/O operations
    pub disk_operations: u64,
}

/// Capability flags that a laptop daemon can support
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DaemonCapabilities {
    /// LLM processing capabilities
    pub llm_enabled: bool,
    pub llm_models: Vec<String>,
    pub llm_max_tokens: Option<u32>,
    
    /// Image generation capabilities
    pub image_generation_enabled: bool,
    pub image_models: Vec<String>,
    pub image_max_resolution: Option<(u32, u32)>,
    
    /// File transfer capabilities
    pub file_transfer_enabled: bool,
    pub file_max_size_bytes: u64,
    pub file_allowed_types: Vec<String>,
    
    /// Computing capabilities
    pub compute_enabled: bool,
    pub compute_max_duration_seconds: u32,
    pub compute_languages: Vec<String>,
    
    /// System information
    pub max_concurrent_requests: u32,
    pub daemon_version: String,
    pub supported_opcodes: Vec<OpCode>,
}

impl BytecodeInstruction {
    /// Create a new LLM query instruction
    pub fn llm_query(request_id: String, prompt: String, model: Option<String>) -> Self {
        let mut parameters = HashMap::new();
        parameters.insert("prompt".to_string(), BytecodeValue::String(prompt));
        if let Some(model) = model {
            parameters.insert("model".to_string(), BytecodeValue::String(model));
        }
        
        Self {
            opcode: OpCode::LlmQuery,
            parameters,
            request_id,
            priority: 128,
            timeout_seconds: 300, // 5 minutes default
        }
    }
    
    /// Create a new image generation instruction
    pub fn image_generate(
        request_id: String, 
        prompt: String, 
        width: Option<u32>, 
        height: Option<u32>
    ) -> Self {
        let mut parameters = HashMap::new();
        parameters.insert("prompt".to_string(), BytecodeValue::String(prompt));
        if let Some(w) = width {
            parameters.insert("width".to_string(), BytecodeValue::Integer(w as i64));
        }
        if let Some(h) = height {
            parameters.insert("height".to_string(), BytecodeValue::Integer(h as i64));
        }
        
        Self {
            opcode: OpCode::ImageGenerate,
            parameters,
            request_id,
            priority: 128,
            timeout_seconds: 600, // 10 minutes for image generation
        }
    }
    
    /// Create a file transfer instruction
    pub fn file_transfer(request_id: String, filename: String, data: Vec<u8>) -> Self {
        let mut parameters = HashMap::new();
        parameters.insert("filename".to_string(), BytecodeValue::String(filename));
        parameters.insert("data".to_string(), BytecodeValue::Bytes(data));
        
        Self {
            opcode: OpCode::FileTransfer,
            parameters,
            request_id,
            priority: 100,
            timeout_seconds: 120,
        }
    }
    
    /// Create a capability query instruction
    pub fn capability_query(request_id: String) -> Self {
        Self {
            opcode: OpCode::CapabilityQuery,
            parameters: HashMap::new(),
            request_id,
            priority: 200, // High priority for system queries
            timeout_seconds: 30,
        }
    }
    
    /// Create an echo instruction for testing connectivity
    pub fn echo(request_id: String, message: String) -> Self {
        let mut parameters = HashMap::new();
        parameters.insert("message".to_string(), BytecodeValue::String(message));
        
        Self {
            opcode: OpCode::Echo,
            parameters,
            request_id,
            priority: 255, // Highest priority for testing
            timeout_seconds: 10,
        }
    }
    
    /// Serialize instruction to bytes for encryption
    pub fn to_bytes(&self) -> CryptoResult<Vec<u8>> {
        serde_json::to_vec(self)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }
    
    /// Deserialize instruction from decrypted bytes
    pub fn from_bytes(data: &[u8]) -> CryptoResult<Self> {
        serde_json::from_slice(data)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }
    
    /// Get parameter as string
    pub fn get_string_param(&self, key: &str) -> Option<&String> {
        match self.parameters.get(key) {
            Some(BytecodeValue::String(s)) => Some(s),
            _ => None,
        }
    }
    
    /// Get parameter as integer
    pub fn get_int_param(&self, key: &str) -> Option<i64> {
        match self.parameters.get(key) {
            Some(BytecodeValue::Integer(i)) => Some(*i),
            _ => None,
        }
    }
    
    /// Get parameter as bytes
    pub fn get_bytes_param(&self, key: &str) -> Option<&Vec<u8>> {
        match self.parameters.get(key) {
            Some(BytecodeValue::Bytes(b)) => Some(b),
            _ => None,
        }
    }
    
    /// Validate instruction structure
    pub fn validate(&self) -> CryptoResult<()> {
        // Check that request_id is not empty
        if self.request_id.is_empty() {
            return Err(CryptoError::InvalidKey("Request ID cannot be empty".to_string()));
        }
        
        // Check timeout is reasonable
        if self.timeout_seconds == 0 || self.timeout_seconds > 3600 {
            return Err(CryptoError::InvalidKey("Timeout must be 1-3600 seconds".to_string()));
        }
        
        // Validate parameters based on opcode
        match self.opcode {
            OpCode::LlmQuery | OpCode::LlmChatCompletion => {
                if self.get_string_param("prompt").is_none() {
                    return Err(CryptoError::InvalidKey("LLM operations require 'prompt' parameter".to_string()));
                }
            }
            OpCode::ImageGenerate => {
                if self.get_string_param("prompt").is_none() {
                    return Err(CryptoError::InvalidKey("Image generation requires 'prompt' parameter".to_string()));
                }
            }
            OpCode::FileTransfer => {
                if self.get_string_param("filename").is_none() || self.get_bytes_param("data").is_none() {
                    return Err(CryptoError::InvalidKey("File transfer requires 'filename' and 'data' parameters".to_string()));
                }
            }
            OpCode::Echo => {
                if self.get_string_param("message").is_none() {
                    return Err(CryptoError::InvalidKey("Echo requires 'message' parameter".to_string()));
                }
            }
            _ => {} // Other opcodes have no specific requirements
        }
        
        Ok(())
    }
}

impl BytecodeResponse {
    /// Create a successful response
    pub fn success(request_id: String, result: BytecodeValue, execution_time_ms: u64) -> Self {
        Self {
            request_id,
            success: true,
            result: Some(result),
            error: None,
            execution_time_ms,
            resource_usage: None,
        }
    }
    
    /// Create an error response
    pub fn error(request_id: String, error_message: String, execution_time_ms: u64) -> Self {
        Self {
            request_id,
            success: false,
            result: None,
            error: Some(error_message),
            execution_time_ms,
            resource_usage: None,
        }
    }
    
    /// Add resource usage information
    pub fn with_resource_usage(mut self, usage: ResourceUsage) -> Self {
        self.resource_usage = Some(usage);
        self
    }
    
    /// Serialize response to bytes for encryption
    pub fn to_bytes(&self) -> CryptoResult<Vec<u8>> {
        serde_json::to_vec(self)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }
    
    /// Deserialize response from decrypted bytes
    pub fn from_bytes(data: &[u8]) -> CryptoResult<Self> {
        serde_json::from_slice(data)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }
}

impl BytecodeValue {
    /// Try to convert to string
    pub fn as_string(&self) -> Option<&String> {
        match self {
            BytecodeValue::String(s) => Some(s),
            _ => None,
        }
    }
    
    /// Try to convert to integer
    pub fn as_integer(&self) -> Option<i64> {
        match self {
            BytecodeValue::Integer(i) => Some(*i),
            _ => None,
        }
    }
    
    /// Try to convert to bytes
    pub fn as_bytes(&self) -> Option<&Vec<u8>> {
        match self {
            BytecodeValue::Bytes(b) => Some(b),
            _ => None,
        }
    }
    
    /// Get the type name as a string
    pub fn type_name(&self) -> &'static str {
        match self {
            BytecodeValue::String(_) => "string",
            BytecodeValue::Integer(_) => "integer",
            BytecodeValue::Float(_) => "float",
            BytecodeValue::Boolean(_) => "boolean",
            BytecodeValue::Bytes(_) => "bytes",
            BytecodeValue::Array(_) => "array",
            BytecodeValue::Map(_) => "map",
        }
    }
}

/// Bytecode packet wrapper for network transmission
pub struct BytecodePacket;

impl BytecodePacket {
    /// Create an encrypted packet containing a bytecode instruction
    pub fn create_instruction_packet(
        instruction: &BytecodeInstruction,
        sender_private_key: &crate::crypto::PrivateKey,
        recipient_public_key: &crate::crypto::PublicKey,
        sender_public_key: &crate::crypto::PublicKey,
    ) -> CryptoResult<EncryptedPacket> {
        // Validate instruction first
        instruction.validate()?;
        
        // Create inner packet
        let inner = InnerPacket::with_metadata(
            PacketType::Data,
            instruction.to_bytes()?,
            PacketMetadata::request(
                "bytecode_executor",
                "laptop_daemon",
                instruction.request_id.clone(),
            ),
        );
        
        // Encrypt the inner packet
        let inner_bytes = inner.to_bytes()?;
        EncryptedPacket::create(
            &inner_bytes,
            sender_private_key,
            recipient_public_key,
            sender_public_key,
        )
    }
    
    /// Create an encrypted packet containing a bytecode response
    pub fn create_response_packet(
        response: &BytecodeResponse,
        sender_private_key: &crate::crypto::PrivateKey,
        recipient_public_key: &crate::crypto::PublicKey,
        sender_public_key: &crate::crypto::PublicKey,
    ) -> CryptoResult<EncryptedPacket> {
        // Create inner packet
        let inner = InnerPacket::with_metadata(
            PacketType::Data,
            response.to_bytes()?,
            PacketMetadata::basic("laptop_daemon", "bytecode_executor"),
        );
        
        // Encrypt the inner packet
        let inner_bytes = inner.to_bytes()?;
        EncryptedPacket::create(
            &inner_bytes,
            sender_private_key,
            recipient_public_key,
            sender_public_key,
        )
    }
    
    /// Extract bytecode instruction from decrypted packet
    pub fn extract_instruction(packet_data: &[u8]) -> CryptoResult<BytecodeInstruction> {
        let inner = InnerPacket::from_bytes(packet_data)?;
        BytecodeInstruction::from_bytes(&inner.payload)
    }
    
    /// Extract bytecode response from decrypted packet
    pub fn extract_response(packet_data: &[u8]) -> CryptoResult<BytecodeResponse> {
        let inner = InnerPacket::from_bytes(packet_data)?;
        BytecodeResponse::from_bytes(&inner.payload)
    }
}

impl Default for DaemonCapabilities {
    fn default() -> Self {
        Self {
            llm_enabled: false,
            llm_models: vec![],
            llm_max_tokens: None,
            image_generation_enabled: false,
            image_models: vec![],
            image_max_resolution: None,
            file_transfer_enabled: true,
            file_max_size_bytes: 10 * 1024 * 1024, // 10MB
            file_allowed_types: vec!["txt".to_string(), "json".to_string(), "md".to_string()],
            compute_enabled: false,
            compute_max_duration_seconds: 300,
            compute_languages: vec![],
            max_concurrent_requests: 10,
            daemon_version: "1.0.0".to_string(),
            supported_opcodes: vec![
                OpCode::Nop,
                OpCode::Echo,
                OpCode::StatusQuery,
                OpCode::CapabilityQuery,
                OpCode::FileTransfer,
                OpCode::FileList,
            ],
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::Keypair;

    #[test]
    fn test_instruction_creation() {
        let instruction = BytecodeInstruction::llm_query(
            "test_123".to_string(),
            "What is the meaning of life?".to_string(),
            Some("gpt-3.5".to_string()),
        );
        
        assert_eq!(instruction.opcode, OpCode::LlmQuery);
        assert_eq!(instruction.request_id, "test_123");
        assert!(instruction.validate().is_ok());
    }
    
    #[test]
    fn test_instruction_serialization() {
        let instruction = BytecodeInstruction::echo(
            "echo_test".to_string(),
            "Hello, world!".to_string(),
        );
        
        let bytes = instruction.to_bytes().unwrap();
        let restored = BytecodeInstruction::from_bytes(&bytes).unwrap();
        
        assert_eq!(restored.opcode, OpCode::Echo);
        assert_eq!(restored.request_id, "echo_test");
        assert_eq!(
            restored.get_string_param("message").unwrap(),
            "Hello, world!"
        );
    }
    
    #[test]
    fn test_response_creation() {
        let response = BytecodeResponse::success(
            "test_456".to_string(),
            BytecodeValue::String("Success!".to_string()),
            150,
        );
        
        assert!(response.success);
        assert_eq!(response.request_id, "test_456");
        assert_eq!(response.execution_time_ms, 150);
    }
    
    #[test]
    fn test_bytecode_packet_creation() {
        let alice = Keypair::generate().unwrap();
        let bob = Keypair::generate().unwrap();
        
        let instruction = BytecodeInstruction::echo(
            "packet_test".to_string(),
            "Hello via packet!".to_string(),
        );
        
        let packet = BytecodePacket::create_instruction_packet(
            &instruction,
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();
        
        // Decrypt and verify
        let decrypted = packet.decrypt(&bob.private_key).unwrap();
        let extracted = BytecodePacket::extract_instruction(&decrypted).unwrap();
        
        assert_eq!(extracted.opcode, OpCode::Echo);
        assert_eq!(extracted.request_id, "packet_test");
    }
    
    #[test]
    fn test_instruction_validation() {
        // Valid instruction
        let valid = BytecodeInstruction::llm_query(
            "valid_123".to_string(),
            "Valid prompt".to_string(),
            None,
        );
        assert!(valid.validate().is_ok());
        
        // Invalid instruction - empty request ID
        let mut invalid = valid.clone();
        invalid.request_id = "".to_string();
        assert!(invalid.validate().is_err());
        
        // Invalid instruction - missing required parameter
        let mut invalid2 = BytecodeInstruction {
            opcode: OpCode::LlmQuery,
            parameters: HashMap::new(), // Missing prompt
            request_id: "test".to_string(),
            priority: 128,
            timeout_seconds: 300,
        };
        assert!(invalid2.validate().is_err());
    }
    
    #[test]
    fn test_bytecode_value_types() {
        let string_val = BytecodeValue::String("test".to_string());
        let int_val = BytecodeValue::Integer(42);
        let bytes_val = BytecodeValue::Bytes(vec![1, 2, 3]);
        
        assert_eq!(string_val.type_name(), "string");
        assert_eq!(int_val.type_name(), "integer");
        assert_eq!(bytes_val.type_name(), "bytes");
        
        assert_eq!(string_val.as_string().unwrap(), "test");
        assert_eq!(int_val.as_integer().unwrap(), 42);
        assert_eq!(bytes_val.as_bytes().unwrap(), &vec![1, 2, 3]);
    }
}