/// P2P networking integration for OfficeOS cryptographic system
/// Provides a unified interface for all P2P communications through the crypto layer
use crate::crypto::{
    CryptoManager, CryptoResult, CryptoError, RelationshipId, PairingEmoji, 
    EncryptedPacket, InnerPacket, PacketType, PacketMetadata, PacketManager
};
use crate::p2p_mesh::{P2PMessage, PeerDevice, SharedFile, DeviceType};
use crate::wifi_direct_p2p::MessageContent;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::{broadcast, RwLock};
use tokio::net::{TcpListener, TcpStream, UdpSocket};

/// Unified P2P manager that integrates crypto with networking
pub struct SecureP2PManager {
    /// Core cryptographic manager
    crypto_manager: CryptoManager,
    /// Packet manager for sequence numbers and integrity
    packet_manager: PacketManager,
    /// Known peers indexed by relationship ID
    secure_peers: Arc<RwLock<HashMap<RelationshipId, SecurePeerDevice>>>,
    /// Network discovery state
    discovery_state: Arc<RwLock<DiscoveryState>>,
    /// Message routing and delivery
    message_router: MessageRouter,
    /// Network interfaces
    network_interfaces: NetworkInterfaces,
    /// Configuration
    config: SecureP2PConfig,
}

/// Secure peer device information with crypto context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurePeerDevice {
    /// Relationship ID for this peer
    pub relationship_id: RelationshipId,
    /// User-assigned nickname
    pub nickname: String,
    /// Device information
    pub device_info: PeerDeviceInfo,
    /// Network connectivity
    pub network_info: NetworkInfo,
    /// Security status
    pub security_status: SecurityStatus,
    /// Last successful communication
    pub last_contact: u64,
    /// Capabilities this peer supports
    pub capabilities: Vec<PeerCapability>,
}

/// Device information without sensitive data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDeviceInfo {
    /// Device identifier (public)
    pub device_id: String,
    /// Device name (user-assigned)
    pub device_name: String,
    /// Device type
    pub device_type: DeviceType,
    /// Battery level if available
    pub battery_level: Option<u8>,
    /// Shared files available
    pub shared_files: Vec<SharedFile>,
}

/// Network connectivity information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkInfo {
    /// Current IP address
    pub ip_address: IpAddr,
    /// Available ports
    pub ports: Vec<u16>,
    /// Signal strength (0-100)
    pub signal_strength: u8,
    /// Connection type
    pub connection_type: ConnectionType,
    /// Latency in milliseconds
    pub latency_ms: Option<u32>,
}

/// Security status for a peer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityStatus {
    /// Whether relationship is fully established
    pub authenticated: bool,
    /// Encryption status
    pub encrypted: bool,
    /// Last key rotation
    pub last_key_rotation: Option<u64>,
    /// Number of failed decryption attempts
    pub decryption_failures: u32,
    /// Trust level (0-100)
    pub trust_level: u8,
}

/// Connection type for network routing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionType {
    /// WiFi Direct connection
    WiFiDirect,
    /// LAN connection
    LocalNetwork,
    /// Mesh relay through another device
    MeshRelay { via_device: String },
    /// Unknown connection type
    Unknown,
}

/// Capabilities a peer device supports
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PeerCapability {
    /// File sharing
    FileSharing,
    /// Document collaboration
    DocumentCollaboration,
    /// LLM proxy services
    LLMProxy,
    /// Image generation
    ImageGeneration,
    /// Voice communication
    VoiceComm,
    /// Screen sharing
    ScreenSharing,
    /// Custom capability
    Custom(String),
}

/// Discovery state management
#[derive(Debug)]
pub struct DiscoveryState {
    /// Whether we're in pairing mode
    pub pairing_active: bool,
    /// Our current pairing emoji
    pub our_emoji: Option<PairingEmoji>,
    /// Discovered devices waiting for pairing
    pub discovered_devices: HashMap<String, PairingEmoji>,
    /// Discovery broadcast interval
    pub broadcast_interval: std::time::Duration,
    /// Last discovery broadcast
    pub last_broadcast: SystemTime,
}

/// Message routing and delivery system
pub struct MessageRouter {
    /// Outgoing message queue
    outgoing_queue: Arc<RwLock<Vec<QueuedMessage>>>,
    /// Message delivery receipts
    delivery_receipts: Arc<RwLock<HashMap<String, DeliveryStatus>>>,
    /// Message sender for broadcasting
    message_sender: broadcast::Sender<SecureP2PMessage>,
    /// Retry configuration
    retry_config: RetryConfig,
}

/// Network interface management
pub struct NetworkInterfaces {
    /// TCP listener for file transfers
    tcp_listener: Option<TcpListener>,
    /// UDP socket for discovery
    udp_socket: Option<UdpSocket>,
    /// WiFi Direct interface
    wifi_direct_interface: Option<String>,
    /// Ports in use
    active_ports: Vec<u16>,
}

/// Configuration for secure P2P
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecureP2PConfig {
    /// Discovery port
    pub discovery_port: u16,
    /// File transfer port
    pub transfer_port: u16,
    /// Maximum concurrent connections
    pub max_connections: usize,
    /// Discovery interval
    pub discovery_interval_secs: u64,
    /// Heartbeat interval
    pub heartbeat_interval_secs: u64,
    /// Message timeout
    pub message_timeout_secs: u64,
    /// Whether to enable mesh relay
    pub enable_mesh_relay: bool,
    /// Maximum hops for mesh messages
    pub max_mesh_hops: u8,
}

/// Queued message for delivery
#[derive(Debug, Clone)]
struct QueuedMessage {
    /// Target relationship
    target_relationship: RelationshipId,
    /// Message content
    content: SecureP2PMessage,
    /// Attempts made
    attempts: u32,
    /// Next retry time
    next_retry: SystemTime,
    /// Message ID for tracking
    message_id: String,
}

/// Delivery status tracking
#[derive(Debug, Clone)]
pub enum DeliveryStatus {
    /// Message queued for delivery
    Queued,
    /// Message sent successfully
    Sent,
    /// Message delivered and acknowledged
    Delivered,
    /// Message failed after all retries
    Failed { reason: String },
    /// Message expired
    Expired,
}

/// Retry configuration
#[derive(Debug, Clone)]
struct RetryConfig {
    /// Maximum retry attempts
    max_attempts: u32,
    /// Initial retry delay
    initial_delay: std::time::Duration,
    /// Exponential backoff multiplier
    backoff_multiplier: f32,
    /// Maximum retry delay
    max_delay: std::time::Duration,
}

/// Unified secure P2P message type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SecureP2PMessage {
    /// Device discovery announcement
    Discovery {
        device_info: PeerDeviceInfo,
        capabilities: Vec<PeerCapability>,
    },
    /// Pairing request/response
    Pairing {
        stage: PairingStage,
        emoji: Option<PairingEmoji>,
        nickname: Option<String>,
    },
    /// File sharing operations
    FileShare {
        operation: FileOperation,
        file_info: Option<SharedFile>,
        chunk_data: Option<Vec<u8>>,
    },
    /// Document collaboration
    DocumentSync {
        document_id: String,
        operation: DocumentOperation,
        content: Option<String>,
    },
    /// LLM proxy request/response
    LLMProxy {
        request_id: String,
        operation: LLMOperation,
    },
    /// Image generation request/response
    ImageGeneration {
        request_id: String,
        operation: ImageOperation,
    },
    /// Heartbeat and status
    Heartbeat {
        battery_level: Option<u8>,
        capabilities: Vec<PeerCapability>,
    },
    /// Generic application message
    Application {
        app_name: String,
        payload: Vec<u8>,
    },
}

/// Pairing stage enumeration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PairingStage {
    /// Requesting pairing
    Request,
    /// Accepting pairing
    Accept,
    /// Rejecting pairing
    Reject,
    /// Pairing completed
    Complete,
}

/// File operation types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FileOperation {
    /// List available files
    List,
    /// Request file download
    Request { file_id: String },
    /// Send file chunk
    Chunk { 
        file_id: String,
        chunk_index: u32,
        total_chunks: u32,
    },
    /// File transfer complete
    Complete { file_id: String },
    /// File transfer error
    Error { file_id: String, error: String },
}

/// Document operation types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DocumentOperation {
    /// Request document
    Request,
    /// Document update
    Update,
    /// Document sync
    Sync,
    /// Conflict resolution
    Conflict,
}

/// LLM operation types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LLMOperation {
    /// Request LLM processing
    Request { prompt: String, parameters: HashMap<String, String> },
    /// LLM response
    Response { response: String },
    /// LLM error
    Error { error: String },
}

/// Image operation types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ImageOperation {
    /// Request image generation
    Request { 
        prompt: String,
        style: String,
        resolution: String,
        parameters: HashMap<String, String>,
    },
    /// Image generation response
    Response { 
        image_data: Vec<u8>,
        metadata: HashMap<String, String>,
    },
    /// Image generation error
    Error { error: String },
}

impl Default for SecureP2PConfig {
    fn default() -> Self {
        Self {
            discovery_port: 8091,
            transfer_port: 8090,
            max_connections: 10,
            discovery_interval_secs: 30,
            heartbeat_interval_secs: 60,
            message_timeout_secs: 300,
            enable_mesh_relay: true,
            max_mesh_hops: 3,
        }
    }
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            initial_delay: std::time::Duration::from_secs(1),
            backoff_multiplier: 2.0,
            max_delay: std::time::Duration::from_secs(60),
        }
    }
}

impl SecureP2PManager {
    /// Create a new secure P2P manager
    pub fn new(
        device_name: String,
        device_type: DeviceType,
    ) -> CryptoResult<Self> {
        Self::with_config(device_name, device_type, SecureP2PConfig::default())
    }

    /// Create secure P2P manager with custom configuration
    pub fn with_config(
        device_name: String,
        device_type: DeviceType,
        config: SecureP2PConfig,
    ) -> CryptoResult<Self> {
        // Initialize crypto manager
        let crypto_manager = CryptoManager::new()?;
        let packet_manager = PacketManager::new();

        // Initialize message router
        let (message_sender, _) = broadcast::channel(1000);
        let message_router = MessageRouter {
            outgoing_queue: Arc::new(RwLock::new(Vec::new())),
            delivery_receipts: Arc::new(RwLock::new(HashMap::new())),
            message_sender,
            retry_config: RetryConfig::default(),
        };

        // Initialize discovery state
        let discovery_state = Arc::new(RwLock::new(DiscoveryState {
            pairing_active: false,
            our_emoji: None,
            discovered_devices: HashMap::new(),
            broadcast_interval: std::time::Duration::from_secs(config.discovery_interval_secs),
            last_broadcast: SystemTime::now(),
        }));

        // Initialize network interfaces
        let network_interfaces = NetworkInterfaces {
            tcp_listener: None,
            udp_socket: None,
            wifi_direct_interface: None,
            active_ports: Vec::new(),
        };

        Ok(Self {
            crypto_manager,
            packet_manager,
            secure_peers: Arc::new(RwLock::new(HashMap::new())),
            discovery_state,
            message_router,
            network_interfaces,
            config,
        })
    }

    /// Start secure P2P networking
    pub async fn start(&mut self) -> CryptoResult<()> {
        log::info!("Starting secure P2P networking with crypto integration");

        // Load existing relationships
        self.crypto_manager.load_relationships()?;

        // Start network listeners
        self.start_network_listeners().await?;

        // Start background tasks
        self.start_discovery_task().await;
        self.start_heartbeat_task().await;
        self.start_message_processor().await;
        self.start_cleanup_task().await;

        log::info!("Secure P2P networking started successfully");
        Ok(())
    }

    /// Enter pairing mode to discover and pair with new devices
    pub async fn enter_pairing_mode(&mut self) -> CryptoResult<PairingEmoji> {
        let emoji = self.crypto_manager.enter_pairing_mode()?;
        
        let mut discovery_state = self.discovery_state.write().await;
        discovery_state.pairing_active = true;
        discovery_state.our_emoji = Some(emoji.clone());
        discovery_state.discovered_devices.clear();

        // Start broadcasting our emoji
        self.broadcast_pairing_emoji(&emoji).await?;

        log::info!("Entered pairing mode with emoji: {}", emoji.emoji);
        Ok(emoji)
    }

    /// Get discovered devices available for pairing
    pub async fn get_discovered_devices(&mut self) -> Vec<PairingEmoji> {
        self.crypto_manager.get_discovered_devices()
    }

    /// Pair with a discovered device
    pub async fn pair_with_device(
        &mut self,
        target_emoji: &PairingEmoji,
        nickname: String,
    ) -> CryptoResult<RelationshipId> {
        // Establish cryptographic relationship
        let relationship_id = self.crypto_manager.establish_relationship(
            target_emoji.clone(),
            nickname.clone(),
        )?;

        // Create secure peer entry
        let secure_peer = SecurePeerDevice {
            relationship_id: relationship_id.clone(),
            nickname,
            device_info: PeerDeviceInfo {
                device_id: target_emoji.session_id.clone(),
                device_name: "Unknown".to_string(), // Will be updated on first contact
                device_type: DeviceType::Unknown,
                battery_level: None,
                shared_files: Vec::new(),
            },
            network_info: NetworkInfo {
                ip_address: "0.0.0.0".parse().unwrap(), // Will be discovered
                ports: Vec::new(),
                signal_strength: target_emoji.signal_strength,
                connection_type: ConnectionType::WiFiDirect,
                latency_ms: None,
            },
            security_status: SecurityStatus {
                authenticated: true,
                encrypted: true,
                last_key_rotation: None,
                decryption_failures: 0,
                trust_level: 50, // Default trust level
            },
            last_contact: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            capabilities: Vec::new(), // Will be discovered
        };

        // Store secure peer
        self.secure_peers.write().await.insert(relationship_id.clone(), secure_peer);

        // Exit pairing mode
        let mut discovery_state = self.discovery_state.write().await;
        discovery_state.pairing_active = false;
        discovery_state.our_emoji = None;

        log::info!("Successfully paired with device: {}", target_emoji.emoji);
        Ok(relationship_id)
    }

    /// Send a secure message to a peer
    pub async fn send_message(
        &mut self,
        relationship_id: &RelationshipId,
        message: SecureP2PMessage,
    ) -> CryptoResult<String> {
        // Serialize message to inner packet
        let inner_packet = InnerPacket::new(
            PacketType::Data,
            serde_json::to_vec(&message)
                .map_err(|e| CryptoError::Storage(e.to_string()))?,
            "secure_p2p".to_string(),
            "peer_device".to_string(),
        );

        let inner_packet_bytes = inner_packet.to_bytes()?;

        // Encrypt for the specific relationship
        let encrypted_packet = self.crypto_manager.encrypt_for_relationship(
            relationship_id,
            &inner_packet_bytes,
        )?;

        // Set sequence number
        let final_packet = self.packet_manager.prepare_outgoing_packet(encrypted_packet);

        // Queue for delivery
        let message_id = self.queue_message_for_delivery(relationship_id.clone(), final_packet).await;

        log::debug!("Queued secure message {} for relationship {}", message_id, relationship_id.0);
        Ok(message_id)
    }

    /// Process incoming encrypted packet
    pub async fn process_incoming_packet(&mut self, packet: EncryptedPacket) -> CryptoResult<()> {
        // Verify packet integrity and check sequence
        let process_result = self.packet_manager.process_incoming_packet(&packet);
        match process_result {
            crate::crypto::PacketProcessResult::Valid => {},
            crate::crypto::PacketProcessResult::Duplicate => {
                log::debug!("Ignoring duplicate packet");
                return Ok(());
            },
            crate::crypto::PacketProcessResult::Expired => {
                log::debug!("Ignoring expired packet");
                return Ok(());
            },
            crate::crypto::PacketProcessResult::MacFailure => {
                self.packet_manager.record_mac_failure();
                return Err(CryptoError::SignatureVerification);
            },
            crate::crypto::PacketProcessResult::DecryptionFailure => {
                self.packet_manager.record_decryption_failure();
                return Err(CryptoError::Decryption("Packet decryption failed".to_string()));
            },
        }

        // Decrypt packet
        let decrypted_data = self.crypto_manager.decrypt_packet(&packet)?;

        // Parse inner packet
        let inner_packet = InnerPacket::from_bytes(&decrypted_data)?;

        // Parse application message
        let message: SecureP2PMessage = serde_json::from_slice(&inner_packet.payload)
            .map_err(|e| CryptoError::Storage(e.to_string()))?;

        // Route message to appropriate handler
        self.handle_received_message(message, &packet).await?;

        Ok(())
    }

    /// Get list of secure peers
    pub async fn get_secure_peers(&self) -> Vec<SecurePeerDevice> {
        self.secure_peers.read().await.values().cloned().collect()
    }

    /// Update last contact time for a peer
    pub async fn update_peer_contact(&mut self, relationship_id: &RelationshipId) {
        if let Some(peer) = self.secure_peers.write().await.get_mut(relationship_id) {
            peer.last_contact = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
        }
        
        self.crypto_manager.update_last_contact(relationship_id);
    }

    /// Get message delivery status
    pub async fn get_delivery_status(&self, message_id: &str) -> Option<DeliveryStatus> {
        self.message_router.delivery_receipts.read().await.get(message_id).cloned()
    }

    // Private implementation methods
    
    async fn start_network_listeners(&mut self) -> CryptoResult<()> {
        // Implementation for starting TCP/UDP listeners
        // This would integrate with the existing P2P mesh networking code
        // but route all traffic through our crypto layer
        Ok(())
    }

    async fn start_discovery_task(&self) {
        // Background task for device discovery
    }

    async fn start_heartbeat_task(&self) {
        // Background task for heartbeat management  
    }

    async fn start_message_processor(&self) {
        // Background task for processing message queue
    }

    async fn start_cleanup_task(&self) {
        // Background task for cleaning up expired relationships
    }

    async fn broadcast_pairing_emoji(&self, emoji: &PairingEmoji) -> CryptoResult<()> {
        // Implementation for broadcasting pairing emoji
        Ok(())
    }

    async fn queue_message_for_delivery(&self, relationship_id: RelationshipId, packet: EncryptedPacket) -> String {
        // Generate unique message ID and queue for delivery
        let message_id = format!("msg_{}", SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos());
        // Implementation would queue the message
        message_id
    }

    async fn handle_received_message(&mut self, message: SecureP2PMessage, packet: &EncryptedPacket) -> CryptoResult<()> {
        match message {
            SecureP2PMessage::Discovery { device_info, capabilities } => {
                self.handle_discovery_message(device_info, capabilities, packet).await
            },
            SecureP2PMessage::Pairing { stage, emoji, nickname } => {
                self.handle_pairing_message(stage, emoji, nickname, packet).await
            },
            SecureP2PMessage::Heartbeat { battery_level, capabilities } => {
                self.handle_heartbeat_message(battery_level, capabilities, packet).await
            },
            _ => {
                // Route to application-specific handlers
                log::debug!("Received application message, routing to handlers");
                Ok(())
            }
        }
    }

    async fn handle_discovery_message(&mut self, _device_info: PeerDeviceInfo, _capabilities: Vec<PeerCapability>, _packet: &EncryptedPacket) -> CryptoResult<()> {
        // Handle device discovery
        Ok(())
    }

    async fn handle_pairing_message(&mut self, _stage: PairingStage, _emoji: Option<PairingEmoji>, _nickname: Option<String>, _packet: &EncryptedPacket) -> CryptoResult<()> {
        // Handle pairing messages
        Ok(())
    }

    async fn handle_heartbeat_message(&mut self, _battery_level: Option<u8>, _capabilities: Vec<PeerCapability>, _packet: &EncryptedPacket) -> CryptoResult<()> {
        // Handle heartbeat messages
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_secure_p2p_creation() {
        let manager = SecureP2PManager::new(
            "test_device".to_string(),
            DeviceType::Anbernic("rg353v".to_string()),
        ).unwrap();

        assert!(!manager.secure_peers.read().await.is_empty() == false);
    }

    #[tokio::test]
    async fn test_pairing_mode() {
        let mut manager = SecureP2PManager::new(
            "test_device".to_string(),
            DeviceType::Anbernic("rg353v".to_string()),
        ).unwrap();

        let emoji = manager.enter_pairing_mode().await.unwrap();
        assert!(!emoji.emoji.is_empty());
        assert!(!emoji.session_id.is_empty());
    }
}