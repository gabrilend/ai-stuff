use chrono::{DateTime, Utc};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, HashMap, VecDeque};
use std::hash::Hasher;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{Duration, Instant, UNIX_EPOCH};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::sync::RwLock;

/// Scuttlebutt-inspired peer-to-peer messaging system for Anbernic devices
/// Implements StreetPass-style data exchange with PGP encryption
/// Supports both "leashed" (laptop backpack) and "unleashed" (pure P2P) modes
#[derive(Debug, Clone)]
pub struct ScuttlebuttNode {
    pub identity: NodeIdentity,
    pub message_log: Arc<RwLock<MessageLog>>,
    pub peer_discovery: PeerDiscovery,
    pub crypto: Arc<RwLock<CryptoManager>>,
    pub mode: OperatingMode,
    pub streetpass: StreetPassManager,
    pub replication: ReplicationManager,
}

/// Unique identity for each Anbernic device
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeIdentity {
    pub device_id: String,    // Unique device identifier (hash of hardware info)
    pub public_key: String,   // PGP public key for encryption
    pub display_name: String, // Human-readable name
    pub device_type: String,  // "anbernic_rg35xx", "anbernic_rg353p", etc.
    pub capabilities: Vec<String>, // ["email", "games", "paint", "music"]
    pub created_at: DateTime<Utc>, // Device first boot
    pub last_seen: DateTime<Utc>, // Last activity timestamp
}

/// Operating mode determines network behavior
#[derive(Debug, Clone, PartialEq)]
pub enum OperatingMode {
    Leashed {
        laptop_address: SocketAddr, // Backpack laptop IP
        laptop_public_key: String,  // Laptop's PGP key
        last_heartbeat: Instant,    // Connection health
    },
    Unleashed {
        ad_hoc_network: String, // WiFi network name for P2P
        discovery_port: u16,    // UDP port for peer discovery
    },
    Hybrid {
        prefer_laptop: bool,        // Prefer laptop when available
        fallback_timeout: Duration, // Switch to P2P after timeout
    },
}

/// Scuttlebutt message log - append-only, cryptographically signed
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageLog {
    pub messages: BTreeMap<u64, LoggedMessage>, // Sequence number -> message
    pub sequence: u64,                          // Current sequence number
    pub author: String,                         // Device ID of log owner
    pub signature_chain: Vec<String>,           // Cryptographic signatures
}

impl MessageLog {
    /// Add a message to the log
    pub async fn add_message(
        &mut self,
        message: ScuttlebuttMessage,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.sequence += 1;

        let logged_message = LoggedMessage {
            sequence: self.sequence,
            timestamp: message.timestamp,
            author: message.author,
            content_type: match message.message_type {
                MessageType::Text => ContentType::Text,
                MessageType::MediaShare => ContentType::Paint, // Simplified mapping
                _ => ContentType::Text,
            },
            content: message.content,
            recipients: message.recipients,
            signature: message.signature,
            prev_hash: self
                .messages
                .last_key_value()
                .map(|(_, last_msg)| last_msg.content_hash.clone()),
            content_hash: format!("hash_{}", self.sequence), // Simplified hash
        };

        self.messages.insert(self.sequence, logged_message);
        Ok(())
    }
}

/// Individual message in the log
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggedMessage {
    pub sequence: u64,
    pub timestamp: DateTime<Utc>,
    pub author: String, // Device ID
    pub content_type: ContentType,
    pub content: String,           // Encrypted content
    pub recipients: Vec<String>,   // Target device IDs (empty = public)
    pub signature: String,         // PGP signature
    pub prev_hash: Option<String>, // Hash of previous message (chain integrity)
    pub content_hash: String,      // Hash of content (tamper detection)
}

/// Types of content that can be shared via Scuttlebutt
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ContentType {
    Text,           // Plain text messages
    Email,          // Email messages with full headers
    GameState,      // Save games, high scores
    Paint,          // Pixel art creations
    Music,          // Tracker music files
    Contact,        // Contact information exchange
    Code,           // Source code snippets
    SystemStatus,   // Device status updates
    StreetPassData, // Nintendo 3DS style exchange data
}

/// StreetPass-style automatic data exchange
#[derive(Debug, Clone)]
pub struct StreetPassManager {
    pub exchange_radius: f32, // Meters - how close devices need to be
    pub exchange_data: StreetPassData,
    pub encounter_history: VecDeque<StreetPassEncounter>,
    pub auto_exchange: bool, // Automatically exchange when devices meet
    pub exchange_filter: ExchangeFilter,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreetPassData {
    pub profile: UserProfile,
    pub recent_achievements: Vec<Achievement>,
    pub public_messages: Vec<String>,
    pub game_data: HashMap<String, GameData>, // Game -> save data
    pub art_showcase: Vec<PixelArt>,
    pub music_tracks: Vec<TrackerMusic>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    pub nickname: String,
    pub avatar: PixelArt, // 32x32 pixel avatar
    pub favorite_game: String,
    pub current_mood: String,
    pub location_hint: String,           // "Coffee shop", "Park", etc.
    pub play_time: HashMap<String, u64>, // Game -> minutes played
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreetPassEncounter {
    pub peer_device_id: String,
    pub encounter_time: DateTime<Utc>,
    pub location: Option<String>,
    pub data_exchanged: bool,
    pub signal_strength: Option<i8>, // WiFi signal strength in dBm
    pub exchange_duration: Duration,
}

/// WiFi-based peer discovery without requiring router
#[derive(Debug, Clone)]
pub struct PeerDiscovery {
    pub discovery_socket: Option<Arc<UdpSocket>>,
    pub broadcast_interval: Duration,
    pub discovery_port: u16,
    pub ad_hoc_ssid: String, // WiFi network for P2P
    pub known_peers: Arc<RwLock<HashMap<String, PeerInfo>>>,
    pub discovery_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub device_id: String,
    pub address: SocketAddr,
    pub public_key: String,
    pub last_seen: DateTime<Utc>,
    pub signal_strength: Option<i8>,
    pub capabilities: Vec<String>,
    pub distance_estimate: Option<f32>, // Meters, estimated from signal strength
}

/// PGP-based encryption for all communications
#[derive(Debug, Clone)]
pub struct CryptoManager {
    pub private_key: String, // PGP private key (encrypted with device PIN)
    pub public_key: String,  // PGP public key
    pub known_keys: HashMap<String, String>, // Device ID -> public key
    pub relationship_keys: HashMap<String, (String, String)>, // Device ID -> (private_key, public_key) for this relationship
    pub trust_web: TrustWeb,
    pub encryption_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustWeb {
    pub trusted_devices: HashMap<String, TrustLevel>,
    pub trust_signatures: HashMap<String, Vec<TrustSignature>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrustLevel {
    Unknown,  // Never encountered
    Seen,     // Encountered but not verified
    Verified, // Key exchange completed successfully
    Trusted,  // Manually marked as trusted
    Friend,   // High trust level (family/close friends)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustSignature {
    pub signer: String,  // Device ID of signer
    pub subject: String, // Device ID being vouched for
    pub trust_level: TrustLevel,
    pub signature: String, // PGP signature
    pub timestamp: DateTime<Utc>,
}

/// Replication manager for syncing message logs between peers
#[derive(Debug, Clone)]
pub struct ReplicationManager {
    pub sync_state: HashMap<String, SyncState>, // Peer -> sync status
    pub max_message_age: Duration,              // Don't sync very old messages
    pub sync_batch_size: usize,                 // Messages per sync batch
    pub priority_peers: Vec<String>,            // Prioritize these devices
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncState {
    pub peer_device_id: String,
    pub last_sync: DateTime<Utc>,
    pub their_sequence: u64,       // Last sequence number we saw from them
    pub our_sequence_at_sync: u64, // Our sequence when we last synced
    pub sync_in_progress: bool,
}

/// Game-specific data for StreetPass exchange
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameData {
    pub game_id: String,
    pub save_data: Vec<u8>, // Encrypted save file
    pub high_scores: Vec<HighScore>,
    pub achievements: Vec<Achievement>,
    pub play_statistics: PlayStats,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HighScore {
    pub game: String,
    pub score: u64,
    pub player_name: String,
    pub achieved_at: DateTime<Utc>,
    pub difficulty: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Achievement {
    pub id: String,
    pub name: String,
    pub description: String,
    pub unlocked_at: DateTime<Utc>,
    pub rarity: f32, // 0.0 to 1.0, lower = rarer
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayStats {
    pub total_playtime: Duration,
    pub sessions_played: u32,
    pub last_played: DateTime<Utc>,
    pub favorite_level: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PixelArt {
    pub width: u32,
    pub height: u32,
    pub palette: Vec<u32>, // RGBA colors
    pub pixels: Vec<u8>,   // Palette indices
    pub title: String,
    pub author: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrackerMusic {
    pub title: String,
    pub artist: String,
    pub bpm: u16,
    pub pattern_data: Vec<u8>, // MOD/XM/IT tracker format
    pub sample_data: Vec<u8>,  // Audio samples
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExchangeFilter {
    pub accept_from_strangers: bool,
    pub require_mutual_games: bool, // Only exchange if we play same games
    pub max_encounters_per_day: u32,
    pub blocked_devices: Vec<String>,
}

/// Message types supported by the Scuttlebutt protocol
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    GameData,
    PixelArt,
    TrackerMusic,
    TrustSignature,
    MediaShare,
}

/// A message in the Scuttlebutt log
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScuttlebuttMessage {
    pub id: String,
    pub author: String,
    pub content: String,
    pub message_type: MessageType,
    pub timestamp: DateTime<Utc>,
    pub recipients: Vec<String>,
    pub signature: String,

    // Media sharing fields
    pub encrypted_media_data: Option<Vec<u8>>,
    pub media_filename: Option<String>,
    pub media_content_type: Option<String>,
}

impl ScuttlebuttNode {
    /// Create a new Scuttlebutt node for an Anbernic device
    pub fn new(device_name: String, device_type: String) -> Self {
        let device_id = Self::generate_device_id(&device_type);
        let (private_key, public_key) = Self::generate_keypair();

        let identity = NodeIdentity {
            device_id: device_id.clone(),
            public_key: public_key.clone(),
            display_name: device_name,
            device_type,
            capabilities: vec![
                "email".to_string(),
                "games".to_string(),
                "paint".to_string(),
                "music".to_string(),
            ],
            created_at: Utc::now(),
            last_seen: Utc::now(),
        };

        let message_log = MessageLog {
            messages: BTreeMap::new(),
            sequence: 0,
            author: device_id.clone(),
            signature_chain: Vec::new(),
        };

        let peer_discovery = PeerDiscovery {
            discovery_socket: None,
            broadcast_interval: Duration::from_secs(5),
            discovery_port: 7777,
            ad_hoc_ssid: "AnbernicMesh".to_string(),
            known_peers: Arc::new(RwLock::new(HashMap::new())),
            discovery_active: false,
        };

        let crypto = CryptoManager {
            private_key,
            public_key,
            known_keys: HashMap::new(),
            relationship_keys: HashMap::new(),
            trust_web: TrustWeb {
                trusted_devices: HashMap::new(),
                trust_signatures: HashMap::new(),
            },
            encryption_enabled: true,
        };

        let streetpass = StreetPassManager {
            exchange_radius: 10.0, // 10 meters
            exchange_data: StreetPassData {
                profile: UserProfile {
                    nickname: "AnbernicUser".to_string(),
                    avatar: Self::default_avatar(),
                    favorite_game: "rocketship-bacterium".to_string(),
                    current_mood: "Gaming".to_string(),
                    location_hint: "Somewhere".to_string(),
                    play_time: HashMap::new(),
                },
                recent_achievements: Vec::new(),
                public_messages: Vec::new(),
                game_data: HashMap::new(),
                art_showcase: Vec::new(),
                music_tracks: Vec::new(),
            },
            encounter_history: VecDeque::new(),
            auto_exchange: true,
            exchange_filter: ExchangeFilter {
                accept_from_strangers: true,
                require_mutual_games: false,
                max_encounters_per_day: 100,
                blocked_devices: Vec::new(),
            },
        };

        let replication = ReplicationManager {
            sync_state: HashMap::new(),
            max_message_age: Duration::from_secs(30 * 24 * 60 * 60), // 30 days
            sync_batch_size: 50,
            priority_peers: Vec::new(),
        };

        Self {
            identity,
            message_log: Arc::new(RwLock::new(message_log)),
            peer_discovery,
            crypto: Arc::new(RwLock::new(crypto)),
            mode: OperatingMode::Unleashed {
                ad_hoc_network: "AnbernicMesh".to_string(),
                discovery_port: 7777,
            },
            streetpass,
            replication,
        }
    }

    /// Start peer discovery and listening for connections
    pub async fn start_networking(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        match &self.mode {
            OperatingMode::Unleashed { discovery_port, .. } => {
                self.start_peer_discovery(*discovery_port).await?;
                self.start_tcp_listener(8080).await?;
            }
            OperatingMode::Leashed { laptop_address, .. } => {
                self.connect_to_laptop(*laptop_address).await?;
            }
            OperatingMode::Hybrid { .. } => {
                // Try laptop first, fall back to P2P
                // Implementation would check for laptop and switch modes
            }
        }
        Ok(())
    }

    /// Start UDP-based peer discovery
    async fn start_peer_discovery(&mut self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
        let socket = UdpSocket::bind(format!("0.0.0.0:{}", port)).await?;
        socket.set_broadcast(true)?;

        let discovery_socket = Arc::new(socket);
        self.peer_discovery.discovery_socket = Some(discovery_socket.clone());
        self.peer_discovery.discovery_active = true;

        // Start broadcasting our presence
        let identity = self.identity.clone();
        let broadcast_socket = discovery_socket.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(5));
            loop {
                interval.tick().await;

                let announcement = PeerAnnouncement {
                    device_id: identity.device_id.clone(),
                    public_key: identity.public_key.clone(),
                    display_name: identity.display_name.clone(),
                    capabilities: identity.capabilities.clone(),
                    timestamp: Utc::now(),
                };

                if let Ok(data) = serde_json::to_vec(&announcement) {
                    // Broadcast to local network
                    let _ = broadcast_socket
                        .send_to(&data, "255.255.255.255:7777")
                        .await;
                }
            }
        });

        // Start listening for peer announcements
        let listen_socket = discovery_socket.clone();
        let known_peers = self.peer_discovery.known_peers.clone();
        tokio::spawn(async move {
            let mut buffer = vec![0; 1024];
            loop {
                if let Ok((size, addr)) = listen_socket.recv_from(&mut buffer).await {
                    if let Ok(announcement) =
                        serde_json::from_slice::<PeerAnnouncement>(&buffer[..size])
                    {
                        let peer_info = PeerInfo {
                            device_id: announcement.device_id.clone(),
                            address: addr,
                            public_key: announcement.public_key,
                            last_seen: announcement.timestamp,
                            signal_strength: None, // Would be calculated from WiFi
                            capabilities: announcement.capabilities,
                            distance_estimate: None,
                        };

                        let mut peers = known_peers.write().await;
                        peers.insert(announcement.device_id, peer_info);
                    }
                }
            }
        });

        Ok(())
    }

    /// Start TCP listener for incoming peer connections
    async fn start_tcp_listener(&self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
        let message_log = self.message_log.clone();
        let crypto = self.crypto.clone();

        tokio::spawn(async move {
            loop {
                if let Ok((stream, addr)) = listener.accept().await {
                    let log_clone = message_log.clone();
                    let crypto_clone = crypto.clone();

                    tokio::spawn(async move {
                        if let Err(e) =
                            Self::handle_peer_connection(stream, log_clone, crypto_clone).await
                        {
                            eprintln!("Peer connection error: {}", e);
                        }
                    });
                }
            }
        });

        Ok(())
    }

    /// Handle incoming peer connection for message sync
    async fn handle_peer_connection(
        mut stream: TcpStream,
        message_log: Arc<RwLock<MessageLog>>,
        crypto: Arc<RwLock<CryptoManager>>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};

        let mut buffer = vec![0; 4096];

        loop {
            match stream.read(&mut buffer).await {
                Ok(0) => break, // Connection closed
                Ok(n) => {
                    if let Ok(sync_request) = serde_json::from_slice::<SyncRequest>(&buffer[..n]) {
                        let response =
                            Self::process_sync_request(sync_request, &message_log, &crypto).await?;
                        let response_data = serde_json::to_vec(&response)?;
                        stream.write_all(&response_data).await?;
                    }
                }
                Err(_) => break,
            }
        }

        Ok(())
    }

    /// Process a sync request from another peer
    async fn process_sync_request(
        request: SyncRequest,
        message_log: &Arc<RwLock<MessageLog>>,
        crypto: &Arc<RwLock<CryptoManager>>,
    ) -> Result<SyncResponse, Box<dyn std::error::Error>> {
        let log = message_log.read().await;

        match request {
            SyncRequest::GetMessages { since_sequence } => {
                let messages: Vec<LoggedMessage> = log
                    .messages
                    .range(since_sequence..)
                    .map(|(_, msg)| msg.clone())
                    .collect();

                Ok(SyncResponse::Messages {
                    messages,
                    current_sequence: log.sequence,
                })
            }
            SyncRequest::AddMessage { message } => {
                // Try to decrypt message using per-relationship keys
                let mut crypto_manager = crypto.write().await;
                let sender_id = &message.author;

                // Attempt to decrypt the message content
                match crypto_manager.decrypt_message(&message.content, sender_id) {
                    Ok(decrypted_content) => {
                        // Create a new message with decrypted content for local storage
                        let mut decrypted_message = message.clone();
                        decrypted_message.content = decrypted_content;

                        // Verify signature and add to log
                        if Self::verify_message_signature(&decrypted_message, &*crypto_manager) {
                            // In a real implementation, would add to log here
                            Ok(SyncResponse::Ack { success: true })
                        } else {
                            Ok(SyncResponse::Ack { success: false })
                        }
                    }
                    Err(_) => {
                        // If decryption fails, store message as-is (might be public or for different recipient)
                        if Self::verify_message_signature(&message, &*crypto_manager) {
                            Ok(SyncResponse::Ack { success: true })
                        } else {
                            Ok(SyncResponse::Ack { success: false })
                        }
                    }
                }
            }
        }
    }

    /// Connect to laptop in leashed mode
    async fn connect_to_laptop(
        &self,
        laptop_addr: SocketAddr,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let stream = TcpStream::connect(laptop_addr).await?;

        // Send handshake with device identity
        let handshake = LeashedHandshake {
            device_id: self.identity.device_id.clone(),
            public_key: self.identity.public_key.clone(),
            capabilities: self.identity.capabilities.clone(),
            mode: "leashed".to_string(),
        };

        // Implementation would handle laptop communication
        Ok(())
    }

    /// Perform StreetPass data exchange with nearby peer
    pub async fn streetpass_exchange(
        &mut self,
        peer_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(peer_info) = self.peer_discovery.known_peers.read().await.get(peer_id) {
            // Check if we should exchange with this peer
            if self.should_exchange_with_peer(peer_info) {
                let exchange_data = self.prepare_streetpass_data().await;

                // Connect to peer and exchange data
                if let Ok(mut stream) = TcpStream::connect(peer_info.address).await {
                    use tokio::io::AsyncWriteExt;

                    let exchange_packet = StreetPassExchange {
                        sender_id: self.identity.device_id.clone(),
                        data: exchange_data,
                        timestamp: Utc::now(),
                    };

                    let packet_data = serde_json::to_vec(&exchange_packet)?;
                    stream.write_all(&packet_data).await?;

                    // Record the encounter
                    let encounter = StreetPassEncounter {
                        peer_device_id: peer_id.to_string(),
                        encounter_time: Utc::now(),
                        location: None,
                        data_exchanged: true,
                        signal_strength: peer_info.signal_strength,
                        exchange_duration: Duration::from_millis(100), // Estimated
                    };

                    self.streetpass.encounter_history.push_back(encounter);

                    // Keep only recent encounters
                    if self.streetpass.encounter_history.len() > 1000 {
                        self.streetpass.encounter_history.pop_front();
                    }
                }
            }
        }
        Ok(())
    }

    /// Post a message to the Scuttlebutt log
    pub async fn post_message(
        &mut self,
        content_type: ContentType,
        content: String,
        recipients: Vec<String>,
    ) -> Result<u64, Box<dyn std::error::Error>> {
        let mut log = self.message_log.write().await;

        let sequence = log.sequence + 1;
        let timestamp = Utc::now();

        // Calculate previous hash for chain integrity
        let prev_hash = if sequence > 1 {
            log.messages
                .get(&(sequence - 1))
                .map(|msg| msg.content_hash.clone())
        } else {
            None
        };

        // Encrypt content if recipients specified using per-relationship keys
        let encrypted_content = if recipients.is_empty() {
            content // Public message
        } else {
            // For simplicity, encrypt for the first recipient (in real implementation, would support multiple)
            if let Some(recipient) = recipients.first() {
                let mut crypto_manager = self.crypto.write().await;
                crypto_manager.encrypt_message(&content, recipient)?
            } else {
                content
            }
        };

        let content_hash = format!("{:x}", Sha256::digest(encrypted_content.as_bytes()));

        let message = LoggedMessage {
            sequence,
            timestamp,
            author: self.identity.device_id.clone(),
            content_type,
            content: encrypted_content,
            recipients,
            signature: self.sign_message(&content_hash)?,
            prev_hash,
            content_hash,
        };

        log.messages.insert(sequence, message);
        log.sequence = sequence;

        Ok(sequence)
    }

    /// Generate unique device ID from hardware characteristics
    fn generate_device_id(device_type: &str) -> String {
        // In real implementation, would use:
        // - MAC address
        // - CPU serial number
        // - Storage device UUID
        // - Anbernic model number
        let mut hasher = Sha256::new();
        hasher.update(device_type.as_bytes());
        hasher.update(
            std::time::SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
                .to_le_bytes(),
        );
        format!("{:x}", hasher.finalize())[..16].to_string()
    }

    /// Generate PGP keypair for device
    fn generate_keypair() -> (String, String) {
        // Placeholder - would use actual PGP library
        let private_key = format!("PRIVATE_KEY_{}", rand::thread_rng().gen::<u64>());
        let public_key = format!("PUBLIC_KEY_{}", rand::thread_rng().gen::<u64>());
        (private_key, public_key)
    }

    /// Create default 32x32 avatar
    fn default_avatar() -> PixelArt {
        PixelArt {
            width: 32,
            height: 32,
            palette: vec![0x000000, 0xFFFFFF, 0xFF0000, 0x00FF00], // Black, White, Red, Green
            pixels: vec![0; 32 * 32],                              // All black pixels
            title: "Default Avatar".to_string(),
            author: "System".to_string(),
            created_at: Utc::now(),
        }
    }

    // Helper methods (simplified implementations)
    fn should_exchange_with_peer(&self, _peer: &PeerInfo) -> bool {
        true
    }
    async fn prepare_streetpass_data(&self) -> StreetPassData {
        self.streetpass.exchange_data.clone()
    }
    fn encrypt_for_recipients(
        &self,
        content: &str,
        _recipients: &[String],
    ) -> Result<String, Box<dyn std::error::Error>> {
        Ok(content.to_string())
    }
    fn sign_message(&self, _content_hash: &str) -> Result<String, Box<dyn std::error::Error>> {
        Ok("SIGNATURE".to_string())
    }
    fn verify_message_signature(_message: &LoggedMessage, _crypto: &CryptoManager) -> bool {
        true
    }

    /// Share a media file over the mesh network
    pub async fn share_media_file(
        &mut self,
        file_path: std::path::PathBuf,
        filename: String,
        recipient_device_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Read the media file
        let file_data = std::fs::read(&file_path)?;

        // Determine content type
        let content_type = Self::get_media_content_type(&filename);

        // Create encrypted media message
        let media_message = self
            .create_encrypted_media_message(filename, content_type, file_data, recipient_device_id)
            .await?;

        // Add to message log
        {
            let mut log = self.message_log.write().await;
            log.add_message(media_message.clone()).await?;
        }

        // Replicate to peers if possible (stub implementation)
        // self.replicate_to_peers(vec![media_message]).await?;

        log::info!(
            "Shared media file {} to device {}",
            file_path.display(),
            recipient_device_id
        );
        Ok(())
    }

    /// Create an encrypted media message
    async fn create_encrypted_media_message(
        &mut self,
        filename: String,
        content_type: String,
        data: Vec<u8>,
        recipient_device_id: &str,
    ) -> Result<ScuttlebuttMessage, Box<dyn std::error::Error>> {
        // Encrypt the file data
        let encrypted_data = {
            let mut crypto = self.crypto.write().await;
            crypto.encrypt_media_data(&data, recipient_device_id)?
        };

        // Create message content with media info
        let message_content = format!("MEDIA_SHARE:{}:{}:{}", filename, content_type, data.len());
        let encrypted_content = {
            let mut crypto = self.crypto.write().await;
            crypto.encrypt_message(&message_content, recipient_device_id)?
        };

        // Generate message ID
        let mut hasher = sha2::Sha256::new();
        hasher.update(&self.identity.device_id);
        hasher.update(&chrono::Utc::now().timestamp().to_string());
        hasher.update(&filename);
        let message_id = hex::encode(hasher.finalize());

        Ok(ScuttlebuttMessage {
            id: message_id,
            author: self.identity.device_id.clone(),
            content: encrypted_content,
            message_type: MessageType::MediaShare,
            timestamp: chrono::Utc::now(),
            recipients: vec![recipient_device_id.to_string()],
            encrypted_media_data: Some(encrypted_data),
            media_filename: Some(filename),
            media_content_type: Some(content_type),
            signature: "demo_signature".to_string(),
        })
    }

    /// Get media file type from filename extension
    pub fn get_media_content_type(filename: &str) -> String {
        let extension = std::path::Path::new(filename)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("")
            .to_lowercase();

        match extension.as_str() {
            "mp3" => "audio/mpeg".to_string(),
            "flac" => "audio/flac".to_string(),
            "wav" => "audio/wav".to_string(),
            "ogg" => "audio/ogg".to_string(),
            "m4a" => "audio/mp4".to_string(),
            "aac" => "audio/aac".to_string(),
            "mp4" => "video/mp4".to_string(),
            "mkv" => "video/x-matroska".to_string(),
            "avi" => "video/x-msvideo".to_string(),
            "webm" => "video/webm".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }

    /// Send a text message to a specific device
    pub async fn send_message(
        &mut self,
        content: String,
        recipient_device_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create and encrypt message
        let encrypted_content = {
            let mut crypto = self.crypto.write().await;
            crypto.encrypt_message(&content, recipient_device_id)?
        };

        // Generate message ID
        let mut hasher = sha2::Sha256::new();
        hasher.update(&self.identity.device_id);
        hasher.update(&chrono::Utc::now().timestamp().to_string());
        hasher.update(&content);
        let message_id = hex::encode(hasher.finalize());

        let message = ScuttlebuttMessage {
            id: message_id,
            author: self.identity.device_id.clone(),
            content: encrypted_content,
            message_type: MessageType::Text,
            timestamp: chrono::Utc::now(),
            recipients: vec![recipient_device_id.to_string()],
            encrypted_media_data: None,
            media_filename: None,
            media_content_type: None,
            signature: "demo_signature".to_string(),
        };

        // Add to message log
        {
            let mut log = self.message_log.write().await;
            log.add_message(message.clone()).await?;
        }

        // Replicate to peers (stub implementation)
        // self.replicate_to_peers(vec![message]).await?;

        log::info!("Sent message to device {}", recipient_device_id);
        Ok(())
    }

    /// Get list of all received messages
    pub async fn get_messages(&self) -> Vec<LoggedMessage> {
        let log = self.message_log.read().await;
        log.messages.values().cloned().collect()
    }

    /// Enable peer discovery process
    pub async fn enable_peer_discovery(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.peer_discovery.discovery_active = true;
        log::info!("Enabled peer discovery on mesh network");
        Ok(())
    }

    /// Get list of discovered peers
    pub async fn get_discovered_peers(&self) -> Vec<String> {
        let peers = self.peer_discovery.known_peers.read().await;
        peers.keys().cloned().collect()
    }
}

impl CryptoManager {
    /// Encrypt a message for a specific device using per-relationship keys
    pub fn encrypt_message(
        &mut self,
        content: &str,
        device_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(content.to_string());
        }

        // Get or create relationship key for this device
        let (private_key, public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(device_id) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(device_id)?;
                self.relationship_keys
                    .insert(device_id.to_string(), new_keys.clone());
                new_keys
            };

        // Simplified encryption - in real implementation would use actual PGP
        let encrypted = format!("ENCRYPTED[{}]:{}", device_id, content);
        Ok(encrypted)
    }

    /// Decrypt a message, trying all available keys for the sender
    pub fn decrypt_message(
        &mut self,
        encrypted_content: &str,
        sender_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(encrypted_content.to_string());
        }

        // Try relationship key first
        if let Some((private_key, _)) = self.relationship_keys.get(sender_id) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, private_key, sender_id)
            {
                return Ok(decrypted);
            }
        }

        // Try main device key
        if let Ok(decrypted) =
            self.try_decrypt_with_key(encrypted_content, &self.private_key, sender_id)
        {
            return Ok(decrypted);
        }

        // If no key works, generate new relationship key for this sender
        let new_keys = self.generate_relationship_keys(sender_id)?;
        self.relationship_keys
            .insert(sender_id.to_string(), new_keys.clone());

        // Try with new key (this may still fail, but establishes the relationship)
        if let Ok(decrypted) = self.try_decrypt_with_key(encrypted_content, &new_keys.0, sender_id)
        {
            return Ok(decrypted);
        }

        Err("Failed to decrypt message with any available keys".into())
    }

    /// Generate a new key pair for a specific relationship
    fn generate_relationship_keys(
        &self,
        device_id: &str,
    ) -> Result<(String, String), Box<dyn std::error::Error>> {
        use rand::Rng;
        use sha2::{Digest, Sha256};

        // Generate a deterministic but unique key based on our device ID and their device ID
        let mut hasher = Sha256::new();
        hasher.update(self.public_key.as_bytes());
        hasher.update(device_id.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>()); // Add randomness
        let key_seed = hasher.finalize();

        let private_key = format!("PRIV_KEY_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("PUB_KEY_{}", hex::encode(&key_seed[16..]));

        Ok((private_key, public_key))
    }

    /// Try to decrypt with a specific key
    fn try_decrypt_with_key(
        &self,
        encrypted_content: &str,
        private_key: &str,
        expected_sender: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified decryption - check if message is in expected format
        if encrypted_content.starts_with(&format!("ENCRYPTED[{}]:", expected_sender)) {
            let content = encrypted_content
                .strip_prefix(&format!("ENCRYPTED[{}]:", expected_sender))
                .ok_or("Invalid encrypted format")?;
            Ok(content.to_string())
        } else {
            Err("Decryption failed".into())
        }
    }

    /// Get public key for a relationship (creates new relationship if needed)
    pub fn get_relationship_public_key(
        &mut self,
        device_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some((_, public_key)) = self.relationship_keys.get(device_id) {
            Ok(public_key.clone())
        } else {
            let new_keys = self.generate_relationship_keys(device_id)?;
            let public_key = new_keys.1.clone();
            self.relationship_keys
                .insert(device_id.to_string(), new_keys);
            Ok(public_key)
        }
    }

    /// Encrypt media data for a specific recipient device
    pub fn encrypt_media_data(
        &mut self,
        data: &[u8],
        recipient_device_id: &str,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        // Get or create relationship key for this device
        let (_private_key, _public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(recipient_device_id) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(recipient_device_id)?;
                self.relationship_keys
                    .insert(recipient_device_id.to_string(), new_keys.clone());
                new_keys
            };

        // For demo purposes, use simple XOR encryption with device ID hash
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        std::hash::Hash::hash(&recipient_device_id, &mut hasher);
        let key_bytes = hasher.finish().to_le_bytes();

        let mut encrypted_data = Vec::with_capacity(data.len());
        for (i, &byte) in data.iter().enumerate() {
            encrypted_data.push(byte ^ key_bytes[i % key_bytes.len()]);
        }

        // Prepend encryption header
        let mut result = format!("MESH_ENCRYPTED[{}]:", recipient_device_id)
            .as_bytes()
            .to_vec();
        result.extend_from_slice(&encrypted_data);

        Ok(result)
    }
}

// Supporting types for network communication
#[derive(Debug, Clone, Serialize, Deserialize)]
struct PeerAnnouncement {
    device_id: String,
    public_key: String,
    display_name: String,
    capabilities: Vec<String>,
    timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum SyncRequest {
    GetMessages { since_sequence: u64 },
    AddMessage { message: LoggedMessage },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum SyncResponse {
    Messages {
        messages: Vec<LoggedMessage>,
        current_sequence: u64,
    },
    Ack {
        success: bool,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LeashedHandshake {
    device_id: String,
    public_key: String,
    capabilities: Vec<String>,
    mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct StreetPassExchange {
    sender_id: String,
    data: StreetPassData,
    timestamp: DateTime<Utc>,
}
