/// Desktop LLM Service - LAPTOP DAEMON COMPONENT
/// 
/// **DEPLOYMENT CONTEXT**: This service runs on laptop daemons as a secure proxy
/// **EXTERNAL ACCESS**: HTTP calls to LLM services are PERMITTED and CORRECT here
/// **COMMUNICATION**: Receives encrypted bytecode instructions from Anbernic devices via WiFi Direct P2P
/// 
/// ARCHITECTURE FLOW:
/// Anbernic Device → WiFi Direct P2P → Encrypted Bytecode → Laptop Daemon → HTTP API → External LLM Service
/// External LLM Service → HTTP Response → Laptop Daemon → Encrypted Bytecode → WiFi Direct P2P → Anbernic Device

use log::{error, info};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::process::Command;
use async_trait::async_trait;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmRequest {
    pub id: String,
    pub sender: String,
    pub prompt: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmResponse {
    pub id: String,
    pub request_id: String,
    pub response: String,
    pub timestamp: u64,
    pub model_used: String,
}

pub struct DesktopLlmService {
    pub daemon_connection: Option<TcpStream>,
    pub service_id: String,
    pub llm_model_path: Option<String>,
}

impl DesktopLlmService {
    pub fn new() -> Self {
        Self {
            daemon_connection: None,
            service_id: format!("desktop_llm_{}", std::process::id()),
            llm_model_path: None,
        }
    }

    pub async fn connect_to_daemon(
        &mut self,
        daemon_addr: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let stream = TcpStream::connect(daemon_addr).await?;
        self.daemon_connection = Some(stream);
        info!("LLM service connected to daemon at {}", daemon_addr);
        Ok(())
    }

    pub async fn start_listening(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 4096];

        loop {
            let stream = match &mut self.daemon_connection {
                Some(stream) => stream,
                None => break,
            };

            match stream.read(&mut buffer).await {
                Ok(0) => break, // Connection closed
                Ok(n) => {
                    let data = &buffer[..n];
                    if let Ok(message) = serde_json::from_slice::<serde_json::Value>(data) {
                        if message["message_type"] == "LlmRequest" {
                            // Extract data from message first to avoid borrow issues
                            let prompt = message["content"].as_str().unwrap_or("").to_string();
                            let request_id = message["id"].as_str().unwrap_or("").to_string();
                            let sender = message["sender"].as_str().unwrap_or("").to_string();

                            info!("Processing LLM request from {}: {}", sender, prompt);

                            // Process in a separate scope to avoid borrow conflicts
                            let response = self.process_llm_request(&prompt).await?;
                            self.send_llm_response(&request_id, &response).await?;
                        }
                    }
                }
                Err(e) => {
                    error!("Read error: {}", e);
                    break;
                }
            }
        }

        Ok(())
    }

    async fn process_llm_request(
        &self,
        prompt: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Try different LLM backends in order of preference
        self.try_llm_backends(prompt).await
    }

    async fn send_llm_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.send_response(request_id, response).await
    }

    async fn try_llm_backends(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // Try ollama first (most common local LLM setup)
        if let Ok(response) = self.try_ollama(prompt).await {
            return Ok(response);
        }

        // Try llamacpp
        if let Ok(response) = self.try_llamacpp(prompt).await {
            return Ok(response);
        }

        // Try koboldcpp
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }

        // Fallback to simple echo service for testing
        Ok(format!("Echo response: {}", prompt))
    }

    async fn try_ollama(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        let output = Command::new("ollama")
            .arg("run")
            .arg("llama2") // Default model, could be configurable
            .arg(prompt)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err("Ollama failed".into())
        }
    }

    async fn try_llamacpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:8000/v1/completions")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(choices) = json["choices"].as_array() {
                if let Some(first_choice) = choices.first() {
                    if let Some(text) = first_choice["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("LlamaCPP failed".into())
    }

    async fn try_koboldcpp(&self, prompt: &str) -> Result<String, Box<dyn std::error::Error>> {
        // LAPTOP DAEMON INTERNET ACCESS: Restored for off-site compute proxying
        // Anbernic devices remain air-gapped - they only communicate via P2P bytecode
        // Laptop daemon acts as secure proxy for internet-based LLM services
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:5001/api/v1/generate")
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_length": 256,
                "temperature": 0.7
            }))
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            if let Some(results) = json["results"].as_array() {
                if let Some(first_result) = results.first() {
                    if let Some(text) = first_result["text"].as_str() {
                        return Ok(text.to_string());
                    }
                }
            }
        }

        Err("KoboldCPP failed".into())
    }

    async fn send_response(
        &mut self,
        request_id: &str,
        response: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref mut stream) = self.daemon_connection {
            let message = serde_json::json!({
                "id": format!("{}_response_{}", self.service_id, chrono::Utc::now().timestamp()),
                "request_id": request_id,
                "sender": self.service_id,
                "content": response,
                "timestamp": chrono::Utc::now().timestamp() as u64,
                "message_type": "LlmResponse",
                "model_used": "local_llm"
            });

            let serialized = serde_json::to_vec(&message)?;
            stream.write_all(&serialized).await?;
        }

        Ok(())
    }
}

/// Implementation of LocalLLMProvider trait for bytecode integration
#[async_trait]
impl crate::crypto::bytecode_executor::LocalLLMProvider for DesktopLlmService {
    /// Process LLM query using external HTTP APIs (laptop daemon context)
    async fn process_query(&self, prompt: &str, model: Option<&str>) -> Result<String, String> {
        // Use the existing try_koboldcpp method for external API calls
        // This is correct for laptop daemon deployment
        
        // Try KoboldCPP first (most reliable local setup)
        if let Ok(response) = self.try_koboldcpp(prompt).await {
            return Ok(response);
        }
        
        // Try Llama CPP as fallback
        if let Ok(response) = self.try_llama_cpp(prompt).await {
            return Ok(response);
        }
        
        // If all external endpoints fail, return error
        Err("No LLM endpoints available".to_string())
    }
    
    /// Get list of available LLM models
    fn get_available_models(&self) -> Vec<String> {
        vec![
            "koboldcpp-local".to_string(),
            "llama-cpp-python".to_string(),
            "local-llm".to_string(),
        ]
    }
    
    /// Check if LLM service is available
    fn is_available(&self) -> bool {
        // For laptop daemon, always available (external APIs handle the actual availability)
        true
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let mut llm_service = DesktopLlmService::new();

    // Connect to daemon
    if let Err(e) = llm_service.connect_to_daemon("127.0.0.1:8080").await {
        error!("Failed to connect to daemon: {}", e);
        return Ok(());
    }

    info!("Desktop LLM service starting...");

    // Start listening for LLM requests
    llm_service.start_listening().await?;

    Ok(())
}
