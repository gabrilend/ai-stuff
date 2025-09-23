/// Laptop Daemon Service
/// Provides AI services (LLM, Image Generation) to Anbernic devices via WiFi Direct P2P
/// Uses secure bytecode instructions instead of external HTTP dependencies
/// Runs without GUI, terminal interface only for service management

use crate::crypto::{
    BytecodeExecutor, BytecodeInstruction, BytecodeResponse, BytecodePacket,
    EncryptedPacket, InnerPacket, PacketType, CryptoManager, CryptoConfig, OpCode
};
use crate::wifi_direct_p2p::WiFiDirectP2P;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::io::{AsyncBufReadExt, BufReader};
use log::{info, warn, error};
use std::time::{SystemTime, UNIX_EPOCH};

/// Laptop daemon configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaptopDaemonConfig {
    pub device_name: String,
    pub models_path: PathBuf,
    pub output_path: PathBuf,
    pub max_paired_devices: usize,
    pub llm_enabled: bool,
    pub image_generation_enabled: bool,
    pub auto_accept_pairing: bool,
    pub permission_level: PermissionLevel,
}

/// Permission levels for services
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PermissionLevel {
    Deny,
    AllowWithConfirmation,
    AllowWithoutAsking,
}

/// Service permissions for specific devices
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DevicePermissions {
    pub device_id: String,
    pub device_nickname: String,
    pub llm_permission: PermissionLevel,
    pub image_generation_permission: PermissionLevel,
    pub file_transfer_permission: PermissionLevel,
    pub last_activity: u64,
}

/// Laptop daemon main service
pub struct LaptopDaemon {
    pub config: LaptopDaemonConfig,
    pub wifi_direct: WiFiDirectP2P,
    pub bytecode_executor: Arc<BytecodeExecutor>,
    pub crypto_manager: Arc<RwLock<CryptoManager>>,
    pub device_permissions: Arc<RwLock<HashMap<String, DevicePermissions>>>,
    pub active_requests: Arc<RwLock<HashMap<String, ActiveRequest>>>,
    pub service_stats: Arc<RwLock<ServiceStats>>,
}

/// Active request tracking
#[derive(Debug, Clone)]
pub struct ActiveRequest {
    pub request_id: String,
    pub device_id: String,
    pub request_type: RequestType,
    pub timestamp: u64,
}

#[derive(Debug, Clone)]
pub enum RequestType {
    LLM(String),           // prompt
    ImageGeneration(String), // prompt
    FileTransfer(String),  // filename
}

/// Service usage statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceStats {
    pub llm_requests_served: u64,
    pub images_generated: u64,
    pub files_transferred: u64,
    pub uptime_seconds: u64,
    pub connected_devices: usize,
}

impl LaptopDaemon {
    /// Create new laptop daemon
    pub fn new(config: LaptopDaemonConfig) -> Result<Self, Box<dyn std::error::Error>> {
        let wifi_direct = WiFiDirectP2P::new(config.device_name.clone())?;
        
        // Initialize cryptographic manager for secure P2P communication
        let crypto_config = CryptoConfig {
            key_storage_dir: config.models_path.join("crypto_keys"),
            ..Default::default()
        };
        let crypto_manager = Arc::new(RwLock::new(CryptoManager::with_config(crypto_config)?));
        
        // Initialize bytecode executor for secure instruction processing
        let mut bytecode_executor = BytecodeExecutor::new();
        
        // Configure internet-capable providers for off-site compute proxying
        if config.llm_enabled {
            info!("LLM services enabled via bytecode interface (internet proxy mode)");
            let internet_llm = Arc::new(crate::crypto::InternetLLMProvider::new());
            bytecode_executor.set_llm_provider(internet_llm);
        }
        if config.image_generation_enabled {
            info!("Image generation services enabled via bytecode interface (internet proxy mode)");
            let internet_image = Arc::new(crate::crypto::InternetImageProvider::new());
            bytecode_executor.set_image_provider(internet_image);
        }
        
        let bytecode_executor = Arc::new(bytecode_executor);

        Ok(Self {
            config,
            wifi_direct,
            bytecode_executor,
            crypto_manager,
            device_permissions: Arc::new(RwLock::new(HashMap::new())),
            active_requests: Arc::new(RwLock::new(HashMap::new())),
            service_stats: Arc::new(RwLock::new(ServiceStats {
                llm_requests_served: 0,
                images_generated: 0,
                files_transferred: 0,
                uptime_seconds: 0,
                connected_devices: 0,
            })),
        })
    }

    /// Start the laptop daemon service
    pub async fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        info!("Starting Laptop Daemon Service: {}", self.config.device_name);

        // Start WiFi Direct networking
        self.wifi_direct.start_wifi_direct().await?;

        // Load existing cryptographic relationships
        {
            let mut crypto = self.crypto_manager.write().await;
            crypto.load_relationships().unwrap_or_else(|e| {
                warn!("Failed to load existing relationships: {}", e);
            });
        }

        // Start bytecode message processing loop
        self.start_bytecode_processing().await;

        // Start stats tracking
        self.start_stats_tracking().await;

        // Start interactive terminal interface
        self.start_terminal_interface().await;

        info!("Laptop Daemon started successfully with bytecode interface");
        Ok(())
    }

    /// Start terminal interface for service management
    async fn start_terminal_interface(&self) {
        let wifi_direct = self.wifi_direct.clone();
        let device_permissions = Arc::clone(&self.device_permissions);
        let service_stats = Arc::clone(&self.service_stats);
        let config = self.config.clone();

        tokio::spawn(async move {
            let stdin = tokio::io::stdin();
            let reader = BufReader::new(stdin);
            let mut lines = reader.lines();

            println!("\n=== Laptop Daemon Terminal Interface ===");
            println!("Available commands:");
            println!("  status    - Show service status");
            println!("  pair      - Enter pairing mode");
            println!("  devices   - List paired devices");
            println!("  permissions <device_id> - Manage device permissions");
            println!("  stats     - Show usage statistics");
            println!("  config    - Show configuration");
            println!("  quit      - Shutdown daemon");
            println!("==========================================\n");

            while let Ok(Some(line)) = lines.next_line().await {
                let command = line.trim();
                
                match command {
                    "status" => {
                        Self::show_status(&wifi_direct, &service_stats).await;
                    }
                    "pair" => {
                        match wifi_direct.enter_pairing_mode().await {
                            Ok(emoji) => {
                                println!("📱 Pairing mode active!");
                                println!("🎯 Your pairing emoji: {}", emoji.emoji);
                                println!("💡 Other devices can now select this emoji to pair");
                            }
                            Err(e) => println!("❌ Failed to enter pairing mode: {}", e),
                        }
                    }
                    "devices" => {
                        Self::list_devices(&device_permissions).await;
                    }
                    "stats" => {
                        Self::show_stats(&service_stats).await;
                    }
                    "config" => {
                        println!("📋 Configuration:");
                        println!("  Device Name: {}", config.device_name);
                        println!("  Models Path: {}", config.models_path.display());
                        println!("  Output Path: {}", config.output_path.display());
                        println!("  LLM Enabled: {}", config.llm_enabled);
                        println!("  Image Generation: {}", config.image_generation_enabled);
                        println!("  Max Paired Devices: {}", config.max_paired_devices);
                    }
                    "quit" => {
                        println!("🔌 Shutting down laptop daemon...");
                        break;
                    }
                    cmd if cmd.starts_with("permissions ") => {
                        let device_id = &cmd[12..];
                        Self::manage_permissions(device_id, &device_permissions).await;
                    }
                    "" => {
                        // Empty line, do nothing
                    }
                    _ => {
                        println!("❓ Unknown command: {}", command);
                        println!("💡 Type one of: status, pair, devices, permissions <id>, stats, config, quit");
                    }
                }
            }
        });
    }

    /// Show service status
    async fn show_status(
        wifi_direct: &WiFiDirectP2P,
        service_stats: &Arc<RwLock<ServiceStats>>,
    ) {
        let peers = wifi_direct.get_active_peers().await;
        let stats = service_stats.read().await;
        
        println!("📊 Service Status:");
        println!("  🔗 Connected Devices: {}", peers.len());
        println!("  🧠 LLM Requests: {}", stats.llm_requests_served);
        println!("  🎨 Images Generated: {}", stats.images_generated);
        println!("  📁 Files Transferred: {}", stats.files_transferred);
        println!("  ⏱️  Uptime: {} hours", stats.uptime_seconds / 3600);
        
        if !peers.is_empty() {
            println!("  📱 Active Peers:");
            for (id, nickname) in peers {
                println!("    - {} ({})", nickname, id);
            }
        }
    }

    /// List paired devices and their permissions
    async fn list_devices(device_permissions: &Arc<RwLock<HashMap<String, DevicePermissions>>>) {
        let permissions = device_permissions.read().await;
        
        if permissions.is_empty() {
            println!("📱 No devices paired yet");
            return;
        }
        
        println!("📱 Paired Devices ({}):", permissions.len());
        for permission in permissions.values() {
            println!("  🔗 {} ({})", permission.device_nickname, permission.device_id);
            println!("    🧠 LLM: {:?}", permission.llm_permission);
            println!("    🎨 Images: {:?}", permission.image_generation_permission);
            println!("    📁 Files: {:?}", permission.file_transfer_permission);
            println!("    ⏰ Last Active: {} mins ago", 
                (SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() - permission.last_activity) / 60);
        }
    }

    /// Show usage statistics
    async fn show_stats(service_stats: &Arc<RwLock<ServiceStats>>) {
        let stats = service_stats.read().await;
        
        println!("📈 Usage Statistics:");
        println!("  🧠 LLM Requests Served: {}", stats.llm_requests_served);
        println!("  🎨 Images Generated: {}", stats.images_generated);
        println!("  📁 Files Transferred: {}", stats.files_transferred);
        println!("  🔗 Connected Devices: {}", stats.connected_devices);
        println!("  ⏱️  Service Uptime: {} hours {} minutes", 
            stats.uptime_seconds / 3600,
            (stats.uptime_seconds % 3600) / 60
        );
    }

    /// Manage permissions for a specific device
    async fn manage_permissions(
        device_id: &str,
        device_permissions: &Arc<RwLock<HashMap<String, DevicePermissions>>>,
    ) {
        let mut permissions = device_permissions.write().await;
        
        if let Some(device_perm) = permissions.get_mut(device_id) {
            println!("🔐 Managing permissions for: {} ({})", 
                device_perm.device_nickname, device_id);
            println!("Current permissions:");
            println!("  1. LLM: {:?}", device_perm.llm_permission);
            println!("  2. Image Generation: {:?}", device_perm.image_generation_permission);
            println!("  3. File Transfer: {:?}", device_perm.file_transfer_permission);
            println!("💡 Permission management interface would go here");
        } else {
            println!("❌ Device not found: {}", device_id);
        }
    }

    /// Start bytecode message processing loop
    async fn start_bytecode_processing(&self) {
        let device_permissions = Arc::clone(&self.device_permissions);
        let active_requests = Arc::clone(&self.active_requests);
        let service_stats = Arc::clone(&self.service_stats);
        let bytecode_executor = Arc::clone(&self.bytecode_executor);
        let crypto_manager = Arc::clone(&self.crypto_manager);
        let wifi_direct = self.wifi_direct.clone();
        
        tokio::spawn(async move {
            info!("Starting secure bytecode message processing loop");
            
            loop {
                // Check for incoming P2P messages
                if let Ok(message) = wifi_direct.receive_message().await {
                    Self::process_encrypted_message(
                        message,
                        &bytecode_executor,
                        &crypto_manager,
                        &device_permissions,
                        &active_requests,
                        &service_stats,
                        &wifi_direct,
                    ).await;
                }
                
                // Small delay to prevent busy-waiting
                tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            }
        });
    }

    /// Process an encrypted message containing bytecode instructions
    async fn process_encrypted_message(
        encrypted_data: Vec<u8>,
        bytecode_executor: &Arc<BytecodeExecutor>,
        crypto_manager: &Arc<RwLock<CryptoManager>>,
        device_permissions: &Arc<RwLock<HashMap<String, DevicePermissions>>>,
        active_requests: &Arc<RwLock<HashMap<String, ActiveRequest>>>,
        service_stats: &Arc<RwLock<ServiceStats>>,
        wifi_direct: &WiFiDirectP2P,
    ) {
        // Deserialize encrypted packet
        let encrypted_packet: EncryptedPacket = match serde_json::from_slice(&encrypted_data) {
            Ok(packet) => packet,
            Err(e) => {
                warn!("Failed to deserialize encrypted packet: {}", e);
                return;
            }
        };

        // Decrypt the packet using crypto manager
        let decrypted_data = {
            let crypto = crypto_manager.read().await;
            match crypto.decrypt_packet(&encrypted_packet) {
                Ok(data) => data,
                Err(e) => {
                    warn!("Failed to decrypt packet: {}", e);
                    return;
                }
            }
        };

        // Extract bytecode instruction from decrypted data
        let instruction = match BytecodePacket::extract_instruction(&decrypted_data) {
            Ok(instr) => instr,
            Err(e) => {
                warn!("Failed to extract bytecode instruction: {}", e);
                return;
            }
        };

        // Get device ID from packet sender key
        let device_id = hex::encode(encrypted_packet.sender_key.as_bytes());
        
        info!("Processing bytecode instruction {:?} from device {}", 
              instruction.opcode, device_id);

        // Update device permissions if needed
        Self::update_device_permissions(
            &device_id,
            &instruction,
            device_permissions,
        ).await;

        // Execute the bytecode instruction
        let response = bytecode_executor.execute_instruction(instruction, device_id.clone()).await;
        
        let response = match response {
            Ok(resp) => resp,
            Err(e) => {
                error!("Failed to execute bytecode instruction: {}", e);
                return;
            }
        };

        // Update statistics
        {
            let mut stats = service_stats.write().await;
            match response.success {
                true => {
                    match instruction.opcode {
                        OpCode::LlmQuery | OpCode::LlmChatCompletion => {
                            stats.llm_requests_served += 1;
                        }
                        OpCode::ImageGenerate => {
                            stats.images_generated += 1;
                        }
                        OpCode::FileTransfer => {
                            stats.files_transferred += 1;
                        }
                        _ => {}
                    }
                }
                false => {
                    warn!("Bytecode instruction failed: {:?}", response.error);
                }
            }
        }

        // Send response back to device
        Self::send_bytecode_response(
            response,
            &encrypted_packet.sender_key,
            crypto_manager,
            wifi_direct,
        ).await;
    }

    /// Update device permissions based on instruction
    async fn update_device_permissions(
        device_id: &str,
        instruction: &BytecodeInstruction,
        device_permissions: &Arc<RwLock<HashMap<String, DevicePermissions>>>,
    ) {
        let mut permissions = device_permissions.write().await;
        
        // Create default permissions for new devices
        if !permissions.contains_key(device_id) {
            let device_perm = DevicePermissions {
                device_id: device_id.to_string(),
                device_nickname: format!("Device_{}", &device_id[..8]),
                llm_permission: PermissionLevel::AllowWithConfirmation,
                image_generation_permission: PermissionLevel::AllowWithConfirmation,
                file_transfer_permission: PermissionLevel::AllowWithConfirmation,
                last_activity: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
            };
            permissions.insert(device_id.to_string(), device_perm);
            info!("Created default permissions for new device: {}", device_id);
        } else {
            // Update last activity
            if let Some(perm) = permissions.get_mut(device_id) {
                perm.last_activity = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
            }
        }
    }

    /// Send bytecode response back to device
    async fn send_bytecode_response(
        response: BytecodeResponse,
        recipient_public_key: &crate::crypto::PublicKey,
        crypto_manager: &Arc<RwLock<CryptoManager>>,
        wifi_direct: &WiFiDirectP2P,
    ) {
        // Find the relationship to encrypt the response
        let encrypted_packet = {
            let crypto = crypto_manager.read().await;
            
            // This is simplified - in a real implementation we'd need to find the correct relationship
            // For now, we'll use the device keypair to encrypt directly
            let device_key = crypto.get_device_public_key().clone();
            
            match BytecodePacket::create_response_packet(
                &response,
                &crypto.device_keypair.private_key, // This field doesn't exist in current implementation
                recipient_public_key,
                &device_key,
            ) {
                Ok(packet) => packet,
                Err(e) => {
                    error!("Failed to create response packet: {}", e);
                    return;
                }
            }
        };

        // Serialize and send via WiFi Direct
        match serde_json::to_vec(&encrypted_packet) {
            Ok(data) => {
                if let Err(e) = wifi_direct.send_message(data).await {
                    error!("Failed to send response: {}", e);
                }
            }
            Err(e) => {
                error!("Failed to serialize response packet: {}", e);
            }
        }
    }

    /// Start statistics tracking
    async fn start_stats_tracking(&self) {
        let service_stats = Arc::clone(&self.service_stats);
        let start_time = SystemTime::now();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
            
            loop {
                interval.tick().await;
                
                let mut stats = service_stats.write().await;
                stats.uptime_seconds = start_time.elapsed()
                    .unwrap_or_default()
                    .as_secs();
            }
        });
    }

    /// Get bytecode executor capabilities
    pub async fn get_bytecode_capabilities(&self) -> String {
        match serde_json::to_string_pretty(&self.bytecode_executor.capabilities) {
            Ok(json) => json,
            Err(_) => "Unable to serialize capabilities".to_string(),
        }
    }

    /// Grant bytecode permissions to a device
    pub async fn grant_bytecode_permissions(&self, device_id: String, opcodes: Vec<OpCode>) {
        self.bytecode_executor.grant_permissions(device_id, opcodes).await;
    }
}

impl Default for LaptopDaemonConfig {
    fn default() -> Self {
        Self {
            device_name: "LaptopDaemon".to_string(),
            models_path: PathBuf::from("./models"),
            output_path: PathBuf::from("./generated_images"),
            max_paired_devices: 10,
            llm_enabled: true,
            image_generation_enabled: true,
            auto_accept_pairing: false,
            permission_level: PermissionLevel::AllowWithConfirmation,
        }
    }
}

