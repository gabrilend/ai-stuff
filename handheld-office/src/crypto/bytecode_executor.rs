/// Bytecode executor for laptop daemon
/// Executes secure bytecode instructions from Anbernic devices
/// Replaces external HTTP dependencies with secure P2P instruction processing

use crate::crypto::bytecode::{
    BytecodeInstruction, BytecodeResponse, BytecodeValue, OpCode, 
    DaemonCapabilities, ResourceUsage
};
use crate::crypto::{CryptoResult, CryptoError, LLMEndpoint, ImageEndpoint, ExecutionContext};
use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use std::time::{SystemTime, UNIX_EPOCH, Instant};
use log::{info, warn, error};

/// Request tracking for async operations
#[derive(Debug, Clone)]
pub struct PendingRequest {
    pub request_id: String,
    pub instruction: BytecodeInstruction,
    pub start_time: Instant,
    pub device_id: String,
}

// ExecutionContext is now defined in types.rs

/// Local LLM interface (replaces external HTTP calls)
#[async_trait]
pub trait LocalLLMProvider: Send + Sync {
    /// Process LLM query locally
    async fn process_query(&self, prompt: &str, model: Option<&str>) -> Result<String, String>;
    
    /// Get available models
    fn get_available_models(&self) -> Vec<String>;
    
    /// Check if LLM is available
    fn is_available(&self) -> bool;
}

/// Local image generation interface (replaces external HTTP calls)
#[async_trait]
pub trait LocalImageProvider: Send + Sync {
    /// Generate image locally
    async fn generate_image(
        &self, 
        prompt: &str, 
        width: Option<u32>, 
        height: Option<u32>
    ) -> Result<Vec<u8>, String>;
    
    /// Get available models
    fn get_available_models(&self) -> Vec<String>;
    
    /// Check if image generation is available
    fn is_available(&self) -> bool;
}

/// Simple echo LLM provider for testing
pub struct EchoLLMProvider;

#[async_trait]
impl LocalLLMProvider for EchoLLMProvider {
    async fn process_query(&self, prompt: &str, _model: Option<&str>) -> Result<String, String> {
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        Ok(format!("Echo response to: {}", prompt))
    }
    
    fn get_available_models(&self) -> Vec<String> {
        vec!["echo-model".to_string()]
    }
    
    fn is_available(&self) -> bool {
        true
    }
}

/// Internet-capable LLM provider for laptop daemon (proxies to external services)
pub struct InternetLLMProvider {
    /// Available LLM endpoints
    pub endpoints: Vec<LLMEndpoint>,
}

// LLMEndpoint is now defined in types.rs

impl InternetLLMProvider {
    /// Create new internet LLM provider with default endpoints
    pub fn new() -> Self {
        Self {
            endpoints: vec![
                LLMEndpoint {
                    name: "llama-cpp-python".to_string(),
                    url: "http://localhost:8000/v1/completions".to_string(),
                    model_name: "llama-cpp".to_string(),
                    enabled: true,
                },
                LLMEndpoint {
                    name: "koboldcpp".to_string(),
                    url: "http://localhost:5001/api/v1/generate".to_string(),
                    model_name: "koboldcpp".to_string(),
                    enabled: true,
                },
                LLMEndpoint {
                    name: "ollama".to_string(),
                    url: "http://localhost:11434/api/generate".to_string(),
                    model_name: "llama2".to_string(),
                    enabled: true,
                },
            ],
        }
    }
    
    /// Try llama-cpp-python endpoint
    async fn try_llamacpp(&self, prompt: &str) -> Result<String, String> {
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:8000/v1/completions")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 512,
                "temperature": 0.7
            }))
            .timeout(std::time::Duration::from_secs(30))
            .send()
            .await
            .map_err(|e| format!("LlamaCPP request failed: {}", e))?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await
                .map_err(|e| format!("LlamaCPP JSON parse failed: {}", e))?;
            if let Some(choices) = json["choices"].as_array() {
                if let Some(first_choice) = choices.first() {
                    if let Some(text) = first_choice["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("LlamaCPP API response invalid".to_string())
    }
    
    /// Try KoboldCPP endpoint
    async fn try_koboldcpp(&self, prompt: &str) -> Result<String, String> {
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:5001/api/v1/generate")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_length": 512,
                "temperature": 0.7
            }))
            .timeout(std::time::Duration::from_secs(30))
            .send()
            .await
            .map_err(|e| format!("KoboldCPP request failed: {}", e))?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await
                .map_err(|e| format!("KoboldCPP JSON parse failed: {}", e))?;
            if let Some(results) = json["results"].as_array() {
                if let Some(first_result) = results.first() {
                    if let Some(text) = first_result["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("KoboldCPP API response invalid".to_string())
    }
    
    /// Try Ollama endpoint
    async fn try_ollama(&self, prompt: &str, model: Option<&str>) -> Result<String, String> {
        let client = reqwest::Client::new();
        let model_name = model.unwrap_or("llama2");
        
        let response = client
            .post("http://localhost:11434/api/generate")
            .json(&serde_json::json!({
                "model": model_name,
                "prompt": prompt,
                "stream": false,
                "options": {
                    "temperature": 0.7,
                    "num_predict": 512
                }
            }))
            .timeout(std::time::Duration::from_secs(60))
            .send()
            .await
            .map_err(|e| format!("Ollama request failed: {}", e))?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await
                .map_err(|e| format!("Ollama JSON parse failed: {}", e))?;
            if let Some(response_text) = json["response"].as_str() {
                return Ok(response_text.to_string());
            }
        }

        Err("Ollama API response invalid".to_string())
    }
}

#[async_trait]
impl LocalLLMProvider for InternetLLMProvider {
    async fn process_query(&self, prompt: &str, model: Option<&str>) -> Result<String, String> {
        // Try multiple endpoints in order of preference
        
        // 1. Try requested model if specified
        if let Some(model_name) = model {
            if model_name.contains("ollama") || model_name.contains("llama") {
                if let Ok(response) = self.try_ollama(prompt, Some(model_name)).await {
                    return Ok(response);
                }
            }
        }
        
        // 2. Try Ollama (usually most capable)
        if let Ok(response) = self.try_ollama(prompt, model).await {
            return Ok(response);
        }
        
        // 3. Try llama-cpp-python
        if let Ok(response) = self.try_llamacpp(prompt).await {
            return Ok(response);
        }
        
        // 4. Try KoboldCPP
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }
        
        // 5. Fallback to echo response
        Ok(format!("LLM Proxy Response: All external LLM services unavailable. Echo: {}", prompt))
    }
    
    fn get_available_models(&self) -> Vec<String> {
        self.endpoints.iter()
            .filter(|ep| ep.enabled)
            .map(|ep| ep.model_name.clone())
            .collect()
    }
    
    fn is_available(&self) -> bool {
        self.endpoints.iter().any(|ep| ep.enabled)
    }
}

/// Simple test image provider
pub struct TestImageProvider;

#[async_trait]
impl LocalImageProvider for TestImageProvider {
    async fn generate_image(
        &self, 
        prompt: &str, 
        width: Option<u32>, 
        height: Option<u32>
    ) -> Result<Vec<u8>, String> {
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        
        let w = width.unwrap_or(512);
        let h = height.unwrap_or(512);
        
        // Generate a simple test image (just random bytes for now)
        let size = (w * h * 3) as usize; // RGB
        let mut image_data = vec![0u8; size];
        
        // Create a simple pattern based on the prompt
        let prompt_hash = prompt.chars().map(|c| c as u8).sum::<u8>();
        for (i, byte) in image_data.iter_mut().enumerate() {
            *byte = ((i as u8).wrapping_add(prompt_hash)) % 256;
        }
        
        Ok(image_data)
    }
    
    fn get_available_models(&self) -> Vec<String> {
        vec!["test-image-model".to_string()]
    }
    
    fn is_available(&self) -> bool {
        true
    }
}

/// Internet-capable image provider for laptop daemon (proxies to external services)
pub struct InternetImageProvider {
    /// Available image generation endpoints
    pub endpoints: Vec<ImageEndpoint>,
}

// ImageEndpoint is now defined in types.rs

impl InternetImageProvider {
    /// Create new internet image provider with default endpoints
    pub fn new() -> Self {
        Self {
            endpoints: vec![
                ImageEndpoint {
                    name: "automatic1111".to_string(),
                    url: "http://127.0.0.1:7860/sdapi/v1/txt2img".to_string(),
                    api_key: None,
                    model_name: "stable-diffusion".to_string(),
                    max_width: 1024,
                    max_height: 1024,
                    timeout_ms: 60000,
                    enabled: true,
                },
                ImageEndpoint {
                    name: "comfyui".to_string(),
                    url: "http://127.0.0.1:8188/prompt".to_string(),
                    api_key: None,
                    model_name: "comfyui".to_string(),
                    max_width: 512,
                    max_height: 512,
                    timeout_ms: 45000,
                    enabled: true,
                },
                ImageEndpoint {
                    name: "invokeai".to_string(),
                    url: "http://127.0.0.1:9090/api/v1/images/generate".to_string(),
                    api_key: None,
                    model_name: "invokeai".to_string(),
                    max_width: 512,
                    max_height: 512,
                    timeout_ms: 30000,
                    enabled: true,
                },
            ],
        }
    }
    
    /// Try Automatic1111 WebUI
    async fn try_automatic1111(
        &self,
        prompt: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<u8>, String> {
        let client = reqwest::Client::new();
        
        let payload = serde_json::json!({
            "prompt": prompt,
            "negative_prompt": "",
            "width": width,
            "height": height,
            "steps": 20,
            "cfg_scale": 7.5,
            "seed": -1,
            "sampler_name": "DPM++ 2M Karras",
            "batch_size": 1,
            "n_iter": 1
        });

        let response = client
            .post("http://127.0.0.1:7860/sdapi/v1/txt2img")
            .json(&payload)
            .timeout(std::time::Duration::from_secs(120))
            .send()
            .await
            .map_err(|e| format!("Automatic1111 request failed: {}", e))?;

        if response.status().is_success() {
            let result: serde_json::Value = response.json().await
                .map_err(|e| format!("Automatic1111 JSON parse failed: {}", e))?;
            
            if let Some(images) = result["images"].as_array() {
                if let Some(image_b64) = images.first().and_then(|img| img.as_str()) {
                    let image_data = base64::decode(image_b64)
                        .map_err(|e| format!("Base64 decode failed: {}", e))?;
                    return Ok(image_data);
                }
            }
        }

        Err("Automatic1111 API response invalid".to_string())
    }
    
    /// Try ComfyUI (simplified - would need proper workflow)
    async fn try_comfyui(
        &self,
        prompt: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<u8>, String> {
        // ComfyUI requires more complex workflow setup
        // For now, return an error to fall back to other providers
        Err("ComfyUI not implemented yet".to_string())
    }
    
    /// Try InvokeAI
    async fn try_invokeai(
        &self,
        prompt: &str,
        width: u32,
        height: u32,
    ) -> Result<Vec<u8>, String> {
        let client = reqwest::Client::new();
        
        let payload = serde_json::json!({
            "prompt": prompt,
            "width": width,
            "height": height,
            "steps": 20,
            "cfg_scale": 7.5,
            "seed": null,
            "sampler_name": "k_dpmpp_2m"
        });

        let response = client
            .post("http://127.0.0.1:9090/api/v1/images/generate")
            .json(&payload)
            .timeout(std::time::Duration::from_secs(120))
            .send()
            .await
            .map_err(|e| format!("InvokeAI request failed: {}", e))?;

        if response.status().is_success() {
            let result: serde_json::Value = response.json().await
                .map_err(|e| format!("InvokeAI JSON parse failed: {}", e))?;
            
            if let Some(image_b64) = result["image"].as_str() {
                let image_data = base64::decode(image_b64)
                    .map_err(|e| format!("Base64 decode failed: {}", e))?;
                return Ok(image_data);
            }
        }

        Err("InvokeAI API response invalid".to_string())
    }
}

#[async_trait]
impl LocalImageProvider for InternetImageProvider {
    async fn generate_image(
        &self, 
        prompt: &str, 
        width: Option<u32>, 
        height: Option<u32>
    ) -> Result<Vec<u8>, String> {
        let w = width.unwrap_or(512);
        let h = height.unwrap_or(512);
        
        // Try multiple endpoints in order of preference
        
        // 1. Try Automatic1111 (most common)
        if let Ok(image_data) = self.try_automatic1111(prompt, w, h).await {
            return Ok(image_data);
        }
        
        // 2. Try InvokeAI
        if let Ok(image_data) = self.try_invokeai(prompt, w, h).await {
            return Ok(image_data);
        }
        
        // 3. Try ComfyUI
        if let Ok(image_data) = self.try_comfyui(prompt, w, h).await {
            return Ok(image_data);
        }
        
        // 4. Fallback to test pattern
        let size = (w * h * 3) as usize; // RGB
        let mut image_data = vec![0u8; size];
        let prompt_hash = prompt.chars().map(|c| c as u8).sum::<u8>();
        for (i, byte) in image_data.iter_mut().enumerate() {
            *byte = ((i as u8).wrapping_add(prompt_hash)) % 256;
        }
        
        Ok(image_data)
    }
    
    fn get_available_models(&self) -> Vec<String> {
        self.endpoints.iter()
            .filter(|ep| ep.enabled)
            .map(|ep| ep.model_name.clone())
            .collect()
    }
    
    fn is_available(&self) -> bool {
        self.endpoints.iter().any(|ep| ep.enabled)
    }
}

/// Bytecode executor that processes instructions securely
pub struct BytecodeExecutor {
    /// Daemon capabilities
    pub capabilities: DaemonCapabilities,
    /// Pending requests
    pub pending_requests: Arc<RwLock<HashMap<String, PendingRequest>>>,
    /// Local LLM provider
    pub llm_provider: Option<Arc<dyn LocalLLMProvider>>,
    /// Local image provider
    pub image_provider: Option<Arc<dyn LocalImageProvider>>,
    /// Device permissions (device_id -> allowed operations)
    pub device_permissions: Arc<RwLock<HashMap<String, Vec<OpCode>>>>,
    /// Execution statistics
    pub stats: Arc<RwLock<ExecutionStats>>,
    /// Maximum concurrent requests
    pub max_concurrent_requests: usize,
}

/// Execution statistics
#[derive(Debug, Clone, Default)]
pub struct ExecutionStats {
    pub total_instructions: u64,
    pub successful_instructions: u64,
    pub failed_instructions: u64,
    pub average_execution_time_ms: f64,
    pub instructions_by_opcode: HashMap<OpCode, u64>,
}

impl BytecodeExecutor {
    /// Create a new bytecode executor
    pub fn new() -> Self {
        let capabilities = DaemonCapabilities {
            llm_enabled: true,
            llm_models: vec!["echo-model".to_string()],
            llm_max_tokens: Some(4096),
            image_generation_enabled: true,
            image_models: vec!["test-image-model".to_string()],
            image_max_resolution: Some((1024, 1024)),
            file_transfer_enabled: true,
            file_max_size_bytes: 50 * 1024 * 1024, // 50MB
            file_allowed_types: vec![
                "txt".to_string(), 
                "md".to_string(), 
                "json".to_string(),
                "png".to_string(),
                "jpg".to_string(),
            ],
            compute_enabled: true,
            compute_max_duration_seconds: 600,
            compute_languages: vec!["rust".to_string(), "python".to_string()],
            max_concurrent_requests: 10,
            daemon_version: "1.0.0".to_string(),
            supported_opcodes: vec![
                OpCode::Nop,
                OpCode::Echo,
                OpCode::LlmQuery,
                OpCode::LlmChatCompletion,
                OpCode::ImageGenerate,
                OpCode::FileTransfer,
                OpCode::FileList,
                OpCode::StatusQuery,
                OpCode::CapabilityQuery,
                OpCode::HealthCheck,
            ],
        };

        Self {
            capabilities,
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            llm_provider: Some(Arc::new(EchoLLMProvider)),
            image_provider: Some(Arc::new(TestImageProvider)),
            device_permissions: Arc::new(RwLock::new(HashMap::new())),
            stats: Arc::new(RwLock::new(ExecutionStats::default())),
            max_concurrent_requests: 10,
        }
    }
    
    /// Set LLM provider
    pub fn set_llm_provider(&mut self, provider: Arc<dyn LocalLLMProvider>) {
        self.capabilities.llm_models = provider.get_available_models();
        self.llm_provider = Some(provider);
        self.capabilities.llm_enabled = true;
    }
    
    /// Set image provider
    pub fn set_image_provider(&mut self, provider: Arc<dyn LocalImageProvider>) {
        self.capabilities.image_models = provider.get_available_models();
        self.image_provider = Some(provider);
        self.capabilities.image_generation_enabled = true;
    }
    
    /// Grant permissions to a device
    pub async fn grant_permissions(&self, device_id: String, allowed_opcodes: Vec<OpCode>) {
        let mut permissions = self.device_permissions.write().await;
        permissions.insert(device_id, allowed_opcodes);
    }
    
    /// Check if device has permission for opcode
    pub async fn check_permission(&self, device_id: &str, opcode: OpCode) -> bool {
        let permissions = self.device_permissions.read().await;
        match permissions.get(device_id) {
            Some(allowed) => allowed.contains(&opcode),
            None => false, // Default deny
        }
    }
    
    /// Execute a bytecode instruction
    pub async fn execute_instruction(
        &self,
        instruction: BytecodeInstruction,
        device_id: String,
    ) -> CryptoResult<BytecodeResponse> {
        let start_time = Instant::now();
        let context = ExecutionContext {
            device_id: device_id.clone(),
            request_id: instruction.request_id.clone(),
            start_time,
            max_execution_time: std::time::Duration::from_secs(instruction.timeout_seconds as u64),
        };
        
        info!("Executing bytecode instruction: {:?} from device {}", 
              instruction.opcode, device_id);
        
        // Update statistics
        {
            let mut stats = self.stats.write().await;
            stats.total_instructions += 1;
            *stats.instructions_by_opcode.entry(instruction.opcode).or_insert(0) += 1;
        }
        
        // Validate instruction
        if let Err(e) = instruction.validate() {
            warn!("Invalid instruction from {}: {}", device_id, e);
            return Ok(BytecodeResponse::error(
                instruction.request_id,
                format!("Invalid instruction: {}", e),
                start_time.elapsed().as_millis() as u64,
            ));
        }
        
        // Check permissions
        if !self.check_permission(&device_id, instruction.opcode).await {
            warn!("Permission denied for {:?} from device {}", instruction.opcode, device_id);
            return Ok(BytecodeResponse::error(
                instruction.request_id,
                "Permission denied for this operation".to_string(),
                start_time.elapsed().as_millis() as u64,
            ));
        }
        
        // Check concurrent request limit
        {
            let pending = self.pending_requests.read().await;
            if pending.len() >= self.max_concurrent_requests {
                return Ok(BytecodeResponse::error(
                    instruction.request_id,
                    "Maximum concurrent requests exceeded".to_string(),
                    start_time.elapsed().as_millis() as u64,
                ));
            }
        }
        
        // Add to pending requests
        {
            let mut pending = self.pending_requests.write().await;
            pending.insert(instruction.request_id.clone(), PendingRequest {
                request_id: instruction.request_id.clone(),
                instruction: instruction.clone(),
                start_time,
                device_id: device_id.clone(),
            });
        }
        
        // Execute the instruction
        let result = self.execute_opcode(&instruction, &context).await;
        
        // Remove from pending requests
        {
            let mut pending = self.pending_requests.write().await;
            pending.remove(&instruction.request_id);
        }
        
        // Update statistics
        let execution_time = start_time.elapsed().as_millis() as u64;
        {
            let mut stats = self.stats.write().await;
            if result.success {
                stats.successful_instructions += 1;
            } else {
                stats.failed_instructions += 1;
            }
            
            // Update average execution time
            let total = stats.successful_instructions + stats.failed_instructions;
            stats.average_execution_time_ms = 
                (stats.average_execution_time_ms * (total - 1) as f64 + execution_time as f64) / total as f64;
        }
        
        info!("Completed instruction {} in {}ms", 
              instruction.request_id, execution_time);
        
        Ok(result)
    }
    
    /// Execute specific opcode
    async fn execute_opcode(
        &self,
        instruction: &BytecodeInstruction,
        context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        let result = match instruction.opcode {
            OpCode::Nop => {
                BytecodeResponse::success(
                    instruction.request_id.clone(),
                    BytecodeValue::String("NOP completed".to_string()),
                    0,
                )
            }
            
            OpCode::Echo => {
                self.execute_echo(instruction, context).await
            }
            
            OpCode::LlmQuery | OpCode::LlmChatCompletion => {
                self.execute_llm_query(instruction, context).await
            }
            
            OpCode::ImageGenerate => {
                self.execute_image_generation(instruction, context).await
            }
            
            OpCode::FileTransfer => {
                self.execute_file_transfer(instruction, context).await
            }
            
            OpCode::FileList => {
                self.execute_file_list(instruction, context).await
            }
            
            OpCode::StatusQuery => {
                self.execute_status_query(instruction, context).await
            }
            
            OpCode::CapabilityQuery => {
                self.execute_capability_query(instruction, context).await
            }
            
            OpCode::HealthCheck => {
                self.execute_health_check(instruction, context).await
            }
            
            _ => {
                BytecodeResponse::error(
                    instruction.request_id.clone(),
                    format!("Unsupported opcode: {:?}", instruction.opcode),
                    start_time.elapsed().as_millis() as u64,
                )
            }
        };
        
        // Add resource usage information
        let execution_time = start_time.elapsed().as_millis() as u64;
        result.with_resource_usage(ResourceUsage {
            cpu_time_ms: execution_time,
            memory_bytes: 1024 * 1024, // Placeholder - would measure actual usage
            gpu_time_ms: None,
            disk_operations: 0,
        })
    }
    
    /// Execute echo operation
    async fn execute_echo(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        if let Some(message) = instruction.get_string_param("message") {
            BytecodeResponse::success(
                instruction.request_id.clone(),
                BytecodeValue::String(format!("Echo: {}", message)),
                start_time.elapsed().as_millis() as u64,
            )
        } else {
            BytecodeResponse::error(
                instruction.request_id.clone(),
                "Missing 'message' parameter".to_string(),
                start_time.elapsed().as_millis() as u64,
            )
        }
    }
    
    /// Execute LLM query (secure replacement for external HTTP calls)
    async fn execute_llm_query(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        if let Some(llm) = &self.llm_provider {
            if !llm.is_available() {
                return BytecodeResponse::error(
                    instruction.request_id.clone(),
                    "LLM service not available".to_string(),
                    start_time.elapsed().as_millis() as u64,
                );
            }
            
            let prompt = match instruction.get_string_param("prompt") {
                Some(p) => p,
                None => {
                    return BytecodeResponse::error(
                        instruction.request_id.clone(),
                        "Missing 'prompt' parameter".to_string(),
                        start_time.elapsed().as_millis() as u64,
                    );
                }
            };
            
            let model = instruction.get_string_param("model");
            
            match llm.process_query(prompt, model.map(|s| s.as_str())).await {
                Ok(response) => {
                    BytecodeResponse::success(
                        instruction.request_id.clone(),
                        BytecodeValue::String(response),
                        start_time.elapsed().as_millis() as u64,
                    )
                }
                Err(error) => {
                    BytecodeResponse::error(
                        instruction.request_id.clone(),
                        format!("LLM processing failed: {}", error),
                        start_time.elapsed().as_millis() as u64,
                    )
                }
            }
        } else {
            BytecodeResponse::error(
                instruction.request_id.clone(),
                "LLM provider not configured".to_string(),
                start_time.elapsed().as_millis() as u64,
            )
        }
    }
    
    /// Execute image generation (secure replacement for external HTTP calls)
    async fn execute_image_generation(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        if let Some(image_gen) = &self.image_provider {
            if !image_gen.is_available() {
                return BytecodeResponse::error(
                    instruction.request_id.clone(),
                    "Image generation service not available".to_string(),
                    start_time.elapsed().as_millis() as u64,
                );
            }
            
            let prompt = match instruction.get_string_param("prompt") {
                Some(p) => p,
                None => {
                    return BytecodeResponse::error(
                        instruction.request_id.clone(),
                        "Missing 'prompt' parameter".to_string(),
                        start_time.elapsed().as_millis() as u64,
                    );
                }
            };
            
            let width = instruction.get_int_param("width").map(|i| i as u32);
            let height = instruction.get_int_param("height").map(|i| i as u32);
            
            match image_gen.generate_image(prompt, width, height).await {
                Ok(image_data) => {
                    BytecodeResponse::success(
                        instruction.request_id.clone(),
                        BytecodeValue::Bytes(image_data),
                        start_time.elapsed().as_millis() as u64,
                    )
                }
                Err(error) => {
                    BytecodeResponse::error(
                        instruction.request_id.clone(),
                        format!("Image generation failed: {}", error),
                        start_time.elapsed().as_millis() as u64,
                    )
                }
            }
        } else {
            BytecodeResponse::error(
                instruction.request_id.clone(),
                "Image generation provider not configured".to_string(),
                start_time.elapsed().as_millis() as u64,
            )
        }
    }
    
    /// Execute file transfer
    async fn execute_file_transfer(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        let filename = match instruction.get_string_param("filename") {
            Some(f) => f,
            None => {
                return BytecodeResponse::error(
                    instruction.request_id.clone(),
                    "Missing 'filename' parameter".to_string(),
                    start_time.elapsed().as_millis() as u64,
                );
            }
        };
        
        let data = match instruction.get_bytes_param("data") {
            Some(d) => d,
            None => {
                return BytecodeResponse::error(
                    instruction.request_id.clone(),
                    "Missing 'data' parameter".to_string(),
                    start_time.elapsed().as_millis() as u64,
                );
            }
        };
        
        // Validate file size
        if data.len() > self.capabilities.file_max_size_bytes as usize {
            return BytecodeResponse::error(
                instruction.request_id.clone(),
                "File too large".to_string(),
                start_time.elapsed().as_millis() as u64,
            );
        }
        
        // For now, just simulate saving the file
        info!("Received file transfer: {} ({} bytes)", filename, data.len());
        
        BytecodeResponse::success(
            instruction.request_id.clone(),
            BytecodeValue::String(format!("File '{}' transferred successfully", filename)),
            start_time.elapsed().as_millis() as u64,
        )
    }
    
    /// Execute file list
    async fn execute_file_list(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        // Return a mock file list
        let files = vec![
            "document1.txt".to_string(),
            "image.png".to_string(),
            "config.json".to_string(),
        ];
        
        BytecodeResponse::success(
            instruction.request_id.clone(),
            BytecodeValue::Array(files.into_iter().map(BytecodeValue::String).collect()),
            start_time.elapsed().as_millis() as u64,
        )
    }
    
    /// Execute status query
    async fn execute_status_query(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        let stats = self.stats.read().await;
        let pending = self.pending_requests.read().await;
        
        let mut status = HashMap::new();
        status.insert("active_requests".to_string(), 
                     BytecodeValue::Integer(pending.len() as i64));
        status.insert("total_instructions".to_string(), 
                     BytecodeValue::Integer(stats.total_instructions as i64));
        status.insert("successful_instructions".to_string(), 
                     BytecodeValue::Integer(stats.successful_instructions as i64));
        status.insert("failed_instructions".to_string(), 
                     BytecodeValue::Integer(stats.failed_instructions as i64));
        status.insert("average_execution_time_ms".to_string(), 
                     BytecodeValue::Float(stats.average_execution_time_ms));
        
        BytecodeResponse::success(
            instruction.request_id.clone(),
            BytecodeValue::Map(status),
            start_time.elapsed().as_millis() as u64,
        )
    }
    
    /// Execute capability query
    async fn execute_capability_query(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        // Serialize capabilities as JSON and return as string
        match serde_json::to_string(&self.capabilities) {
            Ok(json) => {
                BytecodeResponse::success(
                    instruction.request_id.clone(),
                    BytecodeValue::String(json),
                    start_time.elapsed().as_millis() as u64,
                )
            }
            Err(e) => {
                BytecodeResponse::error(
                    instruction.request_id.clone(),
                    format!("Failed to serialize capabilities: {}", e),
                    start_time.elapsed().as_millis() as u64,
                )
            }
        }
    }
    
    /// Execute health check
    async fn execute_health_check(
        &self,
        instruction: &BytecodeInstruction,
        _context: &ExecutionContext,
    ) -> BytecodeResponse {
        let start_time = Instant::now();
        
        let mut health = HashMap::new();
        health.insert("status".to_string(), 
                     BytecodeValue::String("healthy".to_string()));
        health.insert("llm_available".to_string(), 
                     BytecodeValue::Boolean(
                         self.llm_provider.as_ref().map(|p| p.is_available()).unwrap_or(false)
                     ));
        health.insert("image_available".to_string(), 
                     BytecodeValue::Boolean(
                         self.image_provider.as_ref().map(|p| p.is_available()).unwrap_or(false)
                     ));
        health.insert("timestamp".to_string(), 
                     BytecodeValue::Integer(
                         SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64
                     ));
        
        BytecodeResponse::success(
            instruction.request_id.clone(),
            BytecodeValue::Map(health),
            start_time.elapsed().as_millis() as u64,
        )
    }
    
    /// Get current execution statistics
    pub async fn get_stats(&self) -> ExecutionStats {
        self.stats.read().await.clone()
    }
    
    /// Get pending requests count
    pub async fn get_pending_count(&self) -> usize {
        self.pending_requests.read().await.len()
    }
    
    /// Cancel all pending requests for a device
    pub async fn cancel_device_requests(&self, device_id: &str) -> usize {
        let mut pending = self.pending_requests.write().await;
        let mut cancelled = 0;
        
        pending.retain(|_, request| {
            if request.device_id == device_id {
                cancelled += 1;
                false
            } else {
                true
            }
        });
        
        cancelled
    }
}

impl Default for BytecodeExecutor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio;

    #[tokio::test]
    async fn test_echo_instruction() {
        let executor = BytecodeExecutor::new();
        let device_id = "test_device".to_string();
        
        // Grant echo permission
        executor.grant_permissions(device_id.clone(), vec![OpCode::Echo]).await;
        
        let instruction = BytecodeInstruction::echo(
            "test_echo".to_string(),
            "Hello, world!".to_string(),
        );
        
        let response = executor.execute_instruction(instruction, device_id).await.unwrap();
        
        assert!(response.success);
        assert_eq!(response.request_id, "test_echo");
        assert!(response.result.is_some());
        
        if let Some(BytecodeValue::String(result)) = response.result {
            assert!(result.contains("Hello, world!"));
        } else {
            panic!("Expected string result");
        }
    }
    
    #[tokio::test]
    async fn test_permission_denial() {
        let executor = BytecodeExecutor::new();
        let device_id = "unauthorized_device".to_string();
        
        // Don't grant any permissions
        
        let instruction = BytecodeInstruction::echo(
            "test_denied".to_string(),
            "This should be denied".to_string(),
        );
        
        let response = executor.execute_instruction(instruction, device_id).await.unwrap();
        
        assert!(!response.success);
        assert!(response.error.unwrap().contains("Permission denied"));
    }
    
    #[tokio::test]
    async fn test_llm_query() {
        let executor = BytecodeExecutor::new();
        let device_id = "llm_device".to_string();
        
        // Grant LLM permission
        executor.grant_permissions(device_id.clone(), vec![OpCode::LlmQuery]).await;
        
        let instruction = BytecodeInstruction::llm_query(
            "test_llm".to_string(),
            "What is 2+2?".to_string(),
            None,
        );
        
        let response = executor.execute_instruction(instruction, device_id).await.unwrap();
        
        assert!(response.success);
        assert!(response.result.is_some());
    }
    
    #[tokio::test]
    async fn test_capability_query() {
        let executor = BytecodeExecutor::new();
        let device_id = "capability_device".to_string();
        
        // Grant capability query permission
        executor.grant_permissions(device_id.clone(), vec![OpCode::CapabilityQuery]).await;
        
        let instruction = BytecodeInstruction::capability_query("test_cap".to_string());
        
        let response = executor.execute_instruction(instruction, device_id).await.unwrap();
        
        assert!(response.success);
        assert!(response.result.is_some());
        
        if let Some(BytecodeValue::String(capabilities_json)) = response.result {
            // Should be valid JSON containing capabilities
            assert!(capabilities_json.contains("llm_enabled"));
            assert!(capabilities_json.contains("daemon_version"));
        } else {
            panic!("Expected string result with capabilities JSON");
        }
    }
    
    #[tokio::test]
    async fn test_statistics_tracking() {
        let executor = BytecodeExecutor::new();
        let device_id = "stats_device".to_string();
        
        executor.grant_permissions(device_id.clone(), vec![OpCode::Echo]).await;
        
        // Execute multiple instructions
        for i in 0..5 {
            let instruction = BytecodeInstruction::echo(
                format!("test_{}", i),
                format!("Message {}", i),
            );
            executor.execute_instruction(instruction, device_id.clone()).await.unwrap();
        }
        
        let stats = executor.get_stats().await;
        assert_eq!(stats.total_instructions, 5);
        assert_eq!(stats.successful_instructions, 5);
        assert_eq!(stats.failed_instructions, 0);
        assert!(stats.average_execution_time_ms > 0.0);
    }
}