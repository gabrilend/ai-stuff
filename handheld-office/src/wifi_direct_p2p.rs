/// WiFi Direct peer-to-peer communication system
/// Implements direct device-to-device communication without LAN infrastructure
/// Based on the cryptographic communication vision document

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::IpAddr;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::{broadcast, RwLock};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use std::sync::Arc;
use rand::Rng;
use sha2::{Digest, Sha256};

/// Emoji used for device discovery during pairing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairingEmoji {
    pub emoji: String,
    pub device_id: String,
    pub public_key_preview: String, // First 8 characters of public key for verification
    pub timestamp: u64,
}

/// Cryptographic relationship between two devices
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoRelationship {
    pub relationship_id: String,
    pub peer_device_id: String,
    pub peer_nickname: String,
    pub our_private_key: String,
    pub our_public_key: String,
    pub their_public_key: String,
    pub created_time: u64,
    pub last_used: u64,
    pub expiry_time: Option<u64>, // Auto-forget after this time
}

/// Encrypted message packet structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedPacket {
    pub outer_packet: OuterPacket,
    pub encrypted_payload: Vec<u8>,
}

/// Unencrypted outer packet wrapper
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OuterPacket {
    pub target_public_key: String, // Relationship-specific public key
    pub sender_device_id: String,
    pub packet_type: PacketType,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PacketType {
    Discovery,
    PairingRequest,
    PairingResponse,
    DocumentShare,
    LlmRequest,
    LlmResponse,
    Heartbeat,
}

/// Inner decrypted message content
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageContent {
    Text(String),
    Document { filename: String, content: String },
    LlmRequest { prompt: String, request_id: String },
    LlmResponse { response: String, request_id: String },
    ImageGenerationRequest { 
        request_id: String,
        prompt: String,
        style: String,
        resolution: String,
        steps: u32,
        guidance_scale: f32,
    },
    ImageGenerationResponse {
        request_id: String,
        success: bool,
        image_data: Option<Vec<u8>>,
        error_message: Option<String>,
    },
    Heartbeat { battery_level: Option<u8> },
}

/// WiFi Direct P2P manager for Anbernic devices
#[derive(Clone)]
pub struct WiFiDirectP2P {
    pub device_id: String,
    pub device_name: String,
    pub relationships: Arc<RwLock<HashMap<String, CryptoRelationship>>>,
    pub pairing_mode: Arc<RwLock<bool>>,
    pub our_pairing_emoji: Arc<RwLock<Option<PairingEmoji>>>,
    pub discovered_emojis: Arc<RwLock<Vec<PairingEmoji>>>,
    pub message_sender: broadcast::Sender<EncryptedPacket>,
    pub wifi_direct_interface: Option<String>, // WiFi interface name
    pub ap_mode_enabled: bool,
}

impl WiFiDirectP2P {
    /// Create new WiFi Direct P2P manager
    pub fn new(device_name: String) -> Result<Self, Box<dyn std::error::Error>> {
        let device_id = Self::generate_device_id();
        let (message_sender, _) = broadcast::channel(1000);

        Ok(Self {
            device_id,
            device_name,
            relationships: Arc::new(RwLock::new(HashMap::new())),
            pairing_mode: Arc::new(RwLock::new(false)),
            our_pairing_emoji: Arc::new(RwLock::new(None)),
            discovered_emojis: Arc::new(RwLock::new(Vec::new())),
            message_sender,
            wifi_direct_interface: None,
            ap_mode_enabled: false,
        })
    }

    /// Generate unique device ID
    fn generate_device_id() -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", SystemTime::now()));
        hasher.update(std::process::id().to_string());
        format!("anbernic_{}", hex::encode(hasher.finalize())[..16].to_string())
    }

    /// Start WiFi Direct mode (create AP for other devices to discover)
    pub async fn start_wifi_direct(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        log::info!("Starting WiFi Direct for device: {}", self.device_name);

        // Enable WiFi Direct AP mode
        self.enable_ap_mode().await?;

        // Start discovery broadcasts
        self.start_discovery_broadcasts().await;

        // Start listening for connections
        self.start_connection_listener().await?;

        // Start relationship maintenance tasks
        self.start_maintenance_tasks().await;

        log::info!("WiFi Direct P2P started successfully");
        Ok(())
    }

    /// Enable AP mode for WiFi Direct
    async fn enable_ap_mode(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // This would interface with the actual WiFi hardware
        // For now, we'll simulate the WiFi Direct setup
        
        self.ap_mode_enabled = true;
        self.wifi_direct_interface = Some("wlan0".to_string());
        
        log::info!("WiFi Direct AP mode enabled");
        Ok(())
    }

    /// Enter pairing mode - generates a random emoji for this session
    pub async fn enter_pairing_mode(&self) -> Result<PairingEmoji, Box<dyn std::error::Error>> {
        let emojis = vec![
            "😀", "😢", "🚗", "🍎", "☕", "🌟", "🎨", "🎵", "🔥", "⚡",
            "🌸", "🌙", "🦄", "🍕", "🎯", "💎", "🚀", "🌈", "🏆", "🎪"
        ];

        let emoji = emojis[rand::thread_rng().gen_range(0..emojis.len())].to_string();
        let (private_key, public_key) = self.generate_keypair()?;
        
        let pairing_emoji = PairingEmoji {
            emoji,
            device_id: self.device_id.clone(),
            public_key_preview: public_key[..8].to_string(),
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };

        *self.pairing_mode.write().await = true;
        *self.our_pairing_emoji.write().await = Some(pairing_emoji.clone());

        log::info!("Entering pairing mode with emoji: {}", pairing_emoji.emoji);
        Ok(pairing_emoji)
    }

    /// Exit pairing mode
    pub async fn exit_pairing_mode(&self) {
        *self.pairing_mode.write().await = false;
        *self.our_pairing_emoji.write().await = None;
        self.discovered_emojis.write().await.clear();
        log::info!("Exited pairing mode");
    }

    /// Get list of discovered pairing emojis from other devices
    pub async fn get_discovered_emojis(&self) -> Vec<PairingEmoji> {
        self.discovered_emojis.read().await.clone()
    }

    /// Pair with a device by selecting their emoji and providing a nickname
    pub async fn pair_with_device(
        &self,
        their_emoji: &PairingEmoji,
        nickname: String,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let (our_private_key, our_public_key) = self.generate_relationship_keypair(&their_emoji.device_id)?;
        
        let relationship = CryptoRelationship {
            relationship_id: format!("{}_{}", self.device_id, their_emoji.device_id),
            peer_device_id: their_emoji.device_id.clone(),
            peer_nickname: nickname,
            our_private_key,
            our_public_key: our_public_key.clone(),
            their_public_key: String::new(), // Will be filled when they respond
            created_time: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            last_used: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            expiry_time: None, // Can be set later
        };

        let relationship_id = relationship.relationship_id.clone();
        let peer_nickname = relationship.peer_nickname.clone();
        self.relationships.write().await.insert(relationship_id.clone(), relationship);

        // Send pairing request
        self.send_pairing_request(&their_emoji.device_id, &our_public_key).await?;

        log::info!("Paired with device: {} ({})", their_emoji.emoji, peer_nickname);
        Ok(relationship_id)
    }

    /// Send encrypted message to a peer
    pub async fn send_message(
        &self,
        peer_device_id: &str,
        content: MessageContent,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let relationships = self.relationships.read().await;
        let relationship = relationships
            .values()
            .find(|r| r.peer_device_id == peer_device_id)
            .ok_or("No relationship found with peer")?;

        let encrypted_payload = self.encrypt_message(&content, &relationship.our_private_key)?;
        
        let packet = EncryptedPacket {
            outer_packet: OuterPacket {
                target_public_key: relationship.their_public_key.clone(),
                sender_device_id: self.device_id.clone(),
                packet_type: match content {
                    MessageContent::Document { .. } => PacketType::DocumentShare,
                    MessageContent::LlmRequest { .. } => PacketType::LlmRequest,
                    MessageContent::LlmResponse { .. } => PacketType::LlmResponse,
                    MessageContent::Heartbeat { .. } => PacketType::Heartbeat,
                    _ => PacketType::Discovery,
                },
                timestamp: SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
            },
            encrypted_payload,
        };

        self.broadcast_packet(&packet).await?;
        Ok(())
    }

    /// Receive message from P2P network
    pub async fn receive_message(&self) -> Result<MessageContent, Box<dyn std::error::Error>> {
        // For now, return a placeholder - this would typically interface with network stack
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        Err("No messages available".into())
    }

    /// Get list of active peer relationships
    pub async fn get_active_peers(&self) -> Vec<(String, String)> {
        let relationships = self.relationships.read().await;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        relationships
            .values()
            .filter(|r| {
                // Check if relationship is still active (used within last hour)
                now - r.last_used < 3600
            })
            .map(|r| (r.peer_device_id.clone(), r.peer_nickname.clone()))
            .collect()
    }

    /// Laptop daemon connection for LLM services
    pub async fn connect_to_laptop_daemon(&self, laptop_device_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        // This would establish a connection to a paired laptop for LLM services
        log::info!("Connecting to laptop daemon: {}", laptop_device_id);
        Ok(())
    }

    /// Send LLM request to connected laptop daemon
    pub async fn send_llm_request(
        &self,
        laptop_device_id: &str,
        prompt: String,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let request_id = format!("llm_req_{}", SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos());

        let content = MessageContent::LlmRequest {
            prompt,
            request_id: request_id.clone(),
        };

        self.send_message(laptop_device_id, content).await?;
        
        // In a real implementation, we'd wait for the response
        // For now, return a placeholder
        Ok(format!("LLM response for request: {}", request_id))
    }

    /// Send image generation request to connected laptop daemon
    pub async fn send_image_generation_request(
        &self,
        laptop_device_id: &str,
        prompt: String,
        style: String,
        resolution: String,
        steps: u32,
        guidance_scale: f32,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let request_id = format!("img_req_{}", SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos());

        let content = MessageContent::ImageGenerationRequest {
            request_id: request_id.clone(),
            prompt,
            style,
            resolution,
            steps,
            guidance_scale,
        };

        self.send_message(laptop_device_id, content).await?;
        
        // In a real implementation, we'd wait for the response with image data
        Ok(format!("Image generation request sent: {}", request_id))
    }

    // Private helper methods

    fn generate_keypair(&self) -> Result<(String, String), Box<dyn std::error::Error>> {
        let mut rng = rand::thread_rng();
        let private_key = format!("PRIV_{:032x}", rng.gen::<u128>());
        let public_key = format!("PUB_{:032x}", rng.gen::<u128>());
        Ok((private_key, public_key))
    }

    fn generate_relationship_keypair(&self, peer_device_id: &str) -> Result<(String, String), Box<dyn std::error::Error>> {
        let mut hasher = Sha256::new();
        hasher.update(self.device_id.as_bytes());
        hasher.update(peer_device_id.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>());
        let key_seed = hasher.finalize();

        let private_key = format!("REL_PRIV_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("REL_PUB_{}", hex::encode(&key_seed[16..]));
        Ok((private_key, public_key))
    }

    fn encrypt_message(&self, content: &MessageContent, private_key: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        // Simplified encryption - in real implementation would use actual cryptography
        let serialized = serde_json::to_vec(content)?;
        let encrypted = format!("ENCRYPTED[{}]:{}", private_key, base64::encode(&serialized));
        Ok(encrypted.into_bytes())
    }

    fn decrypt_message(&self, encrypted_data: &[u8], private_key: &str) -> Result<MessageContent, Box<dyn std::error::Error>> {
        // Simplified decryption - in real implementation would use actual cryptography
        let data_str = String::from_utf8(encrypted_data.to_vec())?;
        if let Some(content) = data_str.strip_prefix(&format!("ENCRYPTED[{}]:", private_key)) {
            let decoded = base64::decode(content)?;
            let message: MessageContent = serde_json::from_slice(&decoded)?;
            Ok(message)
        } else {
            Err("Failed to decrypt message".into())
        }
    }

    async fn send_pairing_request(&self, target_device_id: &str, our_public_key: &str) -> Result<(), Box<dyn std::error::Error>> {
        // Send pairing request over WiFi Direct
        log::info!("Sending pairing request to: {}", target_device_id);
        Ok(())
    }

    async fn broadcast_packet(&self, packet: &EncryptedPacket) -> Result<(), Box<dyn std::error::Error>> {
        // Broadcast packet over WiFi Direct
        let _serialized = serde_json::to_vec(packet)?;
        // In real implementation, this would send over the WiFi Direct interface
        Ok(())
    }

    async fn start_discovery_broadcasts(&self) {
        let pairing_mode = Arc::clone(&self.pairing_mode);
        let our_emoji = Arc::clone(&self.our_pairing_emoji);
        let device_id = self.device_id.clone();

        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(5));
            
            loop {
                interval.tick().await;
                
                if *pairing_mode.read().await {
                    if let Some(emoji) = &*our_emoji.read().await {
                        log::debug!("Broadcasting pairing emoji: {} from {}", emoji.emoji, device_id);
                        // Broadcast our emoji for others to discover
                    }
                }
            }
        });
    }

    async fn start_connection_listener(&self) -> Result<(), Box<dyn std::error::Error>> {
        // Start listening for incoming WiFi Direct connections
        log::info!("Starting WiFi Direct connection listener");
        Ok(())
    }

    async fn start_maintenance_tasks(&self) {
        let relationships = Arc::clone(&self.relationships);
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(300)); // 5 minutes
            
            loop {
                interval.tick().await;
                
                // Clean up expired relationships
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_secs();
                
                let mut relationships_write = relationships.write().await;
                relationships_write.retain(|_, relationship| {
                    if let Some(expiry) = relationship.expiry_time {
                        now < expiry
                    } else {
                        true // No expiry set
                    }
                });
            }
        });
    }
}

/// Helper trait for applications to integrate WiFi Direct P2P
pub trait WiFiDirectIntegration {
    fn get_wifi_direct(&self) -> &WiFiDirectP2P;

    async fn enter_pairing_mode(&self) -> Result<PairingEmoji, Box<dyn std::error::Error>> {
        self.get_wifi_direct().enter_pairing_mode().await
    }

    async fn get_discovered_devices(&self) -> Vec<PairingEmoji> {
        self.get_wifi_direct().get_discovered_emojis().await
    }

    async fn pair_with_emoji(&self, emoji: &PairingEmoji, nickname: String) -> Result<String, Box<dyn std::error::Error>> {
        self.get_wifi_direct().pair_with_device(emoji, nickname).await
    }

    async fn send_text_message(&self, peer_id: &str, text: String) -> Result<(), Box<dyn std::error::Error>> {
        self.get_wifi_direct().send_message(peer_id, MessageContent::Text(text)).await
    }

    async fn send_document(&self, peer_id: &str, filename: String, content: String) -> Result<(), Box<dyn std::error::Error>> {
        self.get_wifi_direct().send_message(peer_id, MessageContent::Document { filename, content }).await
    }
}