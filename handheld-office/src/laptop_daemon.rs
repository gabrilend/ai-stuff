/// Laptop Daemon Service
/// Provides AI services (LLM, Image Generation) to Anbernic devices via WiFi Direct P2P
/// Runs without GUI, terminal interface only for service management

use crate::ai_image_service::{AIImageService, ImageGenerationRequest, ImageGenerationResponse};
use crate::wifi_direct_p2p::{WiFiDirectP2P, WiFiDirectIntegration};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::io::{AsyncBufReadExt, BufReader};
use log::info;
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
    pub ai_image_service: Option<AIImageService>,
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
        
        let ai_image_service = if config.image_generation_enabled {
            Some(AIImageService::new(
                config.models_path.clone(),
                config.output_path.clone(),
            )?)
        } else {
            None
        };

        Ok(Self {
            config,
            wifi_direct,
            ai_image_service,
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

        // Start AI image service if enabled
        if let Some(ref mut ai_service) = self.ai_image_service {
            ai_service.start().await?;
        }

        // Start message processing loop
        self.start_message_processing().await;

        // Start stats tracking
        self.start_stats_tracking().await;

        // Start interactive terminal interface
        self.start_terminal_interface().await;

        info!("Laptop Daemon started successfully");
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

    /// Start message processing loop
    async fn start_message_processing(&self) {
        let device_permissions = Arc::clone(&self.device_permissions);
        let active_requests = Arc::clone(&self.active_requests);
        let service_stats = Arc::clone(&self.service_stats);
        
        tokio::spawn(async move {
            // In a real implementation, this would listen for WiFi Direct messages
            // and process them accordingly
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                // Process pending requests, handle timeouts, etc.
            }
        });
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

    /// Process image generation request
    pub async fn handle_image_request(
        &mut self,
        request: ImageGenerationRequest,
        sender_device_id: &str,
    ) -> Result<ImageGenerationResponse, Box<dyn std::error::Error>> {
        // Check permissions
        let permissions = self.device_permissions.read().await;
        if let Some(device_perm) = permissions.get(sender_device_id) {
            match device_perm.image_generation_permission {
                PermissionLevel::Deny => {
                    return Ok(ImageGenerationResponse {
                        request_id: request.request_id,
                        success: false,
                        image_path: None,
                        image_data: None,
                        error_message: Some("Image generation permission denied".to_string()),
                        generation_time_ms: 0,
                        model_used: "none".to_string(),
                        timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                    });
                }
                PermissionLevel::AllowWithConfirmation => {
                    println!("🎨 Image generation request from {}", device_perm.device_nickname);
                    println!("📝 Prompt: {}", request.prompt);
                    println!("❓ Allow this request? (y/n)");
                    // In a real implementation, would wait for user input
                }
                PermissionLevel::AllowWithoutAsking => {
                    // Proceed without confirmation
                }
            }
        }

        // Track the request
        {
            let mut active = self.active_requests.write().await;
            active.insert(request.request_id.clone(), ActiveRequest {
                request_id: request.request_id.clone(),
                device_id: sender_device_id.to_string(),
                request_type: RequestType::ImageGeneration(request.prompt.clone()),
                timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
            });
        }

        // Process the request
        let response = if let Some(ref mut ai_service) = self.ai_image_service {
            info!("🎨 Processing image generation: {}", request.prompt);
            ai_service.generate_image(request).await?
        } else {
            ImageGenerationResponse {
                request_id: request.request_id,
                success: false,
                image_path: None,
                image_data: None,
                error_message: Some("Image generation service not available".to_string()),
                generation_time_ms: 0,
                model_used: "none".to_string(),
                timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
            }
        };

        // Update stats
        {
            let mut stats = self.service_stats.write().await;
            if response.success {
                stats.images_generated += 1;
            }
        }

        // Remove from active requests
        {
            let mut active = self.active_requests.write().await;
            active.remove(&response.request_id);
        }

        Ok(response)
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

