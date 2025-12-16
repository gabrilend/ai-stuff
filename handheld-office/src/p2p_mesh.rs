/// Peer-to-peer mesh file sharing system for Anbernic handhelds
/// Enables direct file sharing between devices on the same network
/// Optimized for low-bandwidth, battery-efficient operation
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::sync::{broadcast, RwLock};
use tokio::time;

/// File metadata for P2P sharing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFile {
    pub id: String,
    pub filename: String,
    pub file_path: PathBuf,
    pub file_size: u64,
    pub file_hash: String,
    pub mime_type: String,
    pub shared_by: String,
    pub timestamp: u64,
    pub description: Option<String>,
    pub tags: Vec<String>,
}

/// Peer device information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDevice {
    pub device_id: String,
    pub device_name: String,
    pub ip_address: IpAddr,
    pub port: u16,
    pub last_seen: u64,
    pub battery_level: Option<u8>,
    pub device_type: DeviceType,
    pub shared_files: Vec<SharedFile>,
}

/// Type of device in the mesh
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Anbernic(String), // Model name
    Desktop,
    Mobile,
    Unknown,
}

/// P2P message types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum P2PMessage {
    Discovery {
        device_info: PeerDevice,
    },
    FileShare {
        file_info: SharedFile,
        chunk_data: Option<Vec<u8>>,
        chunk_index: u32,
        total_chunks: u32,
    },
    FileRequest {
        file_id: String,
        chunk_index: Option<u32>,
    },
    FileList {
        files: Vec<SharedFile>,
    },
    Heartbeat {
        device_id: String,
        battery_level: Option<u8>,
    },
    SearchRequest {
        query: String,
        file_types: Vec<String>,
    },
    SearchResponse {
        results: Vec<SharedFile>,
        query: String,
    },
}

/// File transfer chunk for efficient streaming
#[derive(Debug, Clone)]
pub struct FileChunk {
    pub file_id: String,
    pub chunk_index: u32,
    pub total_chunks: u32,
    pub data: Vec<u8>,
    pub checksum: String,
}

/// P2P mesh network manager
pub struct P2PMeshManager {
    pub device_info: PeerDevice,
    pub peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
    pub shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
    pub active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,

    // Network components
    pub tcp_listener: Option<TcpListener>,
    pub udp_socket: Option<UdpSocket>,
    pub discovery_port: u16,
    pub transfer_port: u16,

    // Communication channels
    pub message_sender: broadcast::Sender<P2PMessage>,
    pub shutdown_signal: Arc<RwLock<bool>>,

    // Settings
    pub chunk_size: usize,
    pub discovery_interval: Duration,
    pub heartbeat_interval: Duration,
    pub max_concurrent_transfers: usize,
}

/// Active file transfer state
#[derive(Debug, Clone)]
pub struct FileTransfer {
    pub file_id: String,
    pub peer_id: String,
    pub filename: String,
    pub total_size: u64,
    pub transferred_bytes: u64,
    pub chunks_received: HashMap<u32, bool>,
    pub start_time: SystemTime,
    pub last_activity: SystemTime,
    pub transfer_type: TransferType,
}

#[derive(Debug, Clone)]
pub enum TransferType {
    Upload,
    Download,
}

impl P2PMeshManager {
    pub fn new(
        device_name: String,
        device_type: DeviceType,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let device_id = Self::generate_device_id();
        let (message_sender, _) = broadcast::channel(1000);

        let device_info = PeerDevice {
            device_id: device_id.clone(),
            device_name,
            ip_address: Self::get_local_ip()?,
            port: 8090, // Default P2P port
            last_seen: Self::current_timestamp(),
            battery_level: Self::get_battery_level(),
            device_type,
            shared_files: Vec::new(),
        };

        Ok(Self {
            device_info,
            peers: Arc::new(RwLock::new(HashMap::new())),
            shared_files: Arc::new(RwLock::new(HashMap::new())),
            active_transfers: Arc::new(RwLock::new(HashMap::new())),
            tcp_listener: None,
            udp_socket: None,
            discovery_port: 8091,
            transfer_port: 8090,
            message_sender,
            shutdown_signal: Arc::new(RwLock::new(false)),
            chunk_size: 32768, // 32KB chunks for efficient handheld transfer
            discovery_interval: Duration::from_secs(30),
            heartbeat_interval: Duration::from_secs(60),
            max_concurrent_transfers: 3,
        })
    }

    /// Start the P2P mesh networking
    pub async fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        log::info!(
            "Starting P2P mesh network for device: {}",
            self.device_info.device_name
        );

        // Start TCP listener for file transfers
        self.start_tcp_listener().await?;

        // Start UDP socket for discovery
        self.start_udp_discovery().await?;

        // Start background tasks
        self.start_discovery_task().await;
        self.start_heartbeat_task().await;
        self.start_cleanup_task().await;

        log::info!("P2P mesh network started successfully");
        Ok(())
    }

    async fn start_tcp_listener(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.transfer_port);
        let listener = TcpListener::bind(addr).await?;

        log::info!("TCP listener started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shared_files = Arc::clone(&self.shared_files);
        let chunk_size = self.chunk_size;

        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, peer_addr)) => {
                        log::debug!("New TCP connection from {}", peer_addr);

                        let peers_clone = Arc::clone(&peers);
                        let transfers_clone = Arc::clone(&active_transfers);
                        let files_clone = Arc::clone(&shared_files);

                        tokio::spawn(async move {
                            if let Err(e) = Self::handle_tcp_connection(
                                stream,
                                peers_clone,
                                transfers_clone,
                                files_clone,
                                chunk_size,
                            )
                            .await
                            {
                                log::error!("TCP connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        log::error!("Failed to accept TCP connection: {}", e);
                    }
                }
            }
        });

        Ok(())
    }

    async fn start_udp_discovery(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = SocketAddr::new(self.device_info.ip_address, self.discovery_port);
        let socket = Arc::new(UdpSocket::bind(addr).await?);

        log::info!("UDP discovery started on {}", addr);

        let peers = Arc::clone(&self.peers);
        let device_info = self.device_info.clone();
        let message_sender = self.message_sender.clone();
        let socket_clone = Arc::clone(&socket);

        tokio::spawn(async move {
            let mut buffer = [0; 4096];

            loop {
                match socket_clone.recv_from(&mut buffer).await {
                    Ok((len, peer_addr)) => {
                        let data = &buffer[..len];

                        if let Ok(message) = serde_json::from_slice::<P2PMessage>(data) {
                            if let Err(e) = Self::handle_discovery_message(
                                message,
                                peer_addr,
                                Arc::clone(&peers),
                                &device_info,
                                &socket_clone,
                                &message_sender,
                            )
                            .await
                            {
                                log::error!("Discovery message error: {}", e);
                            }
                        }
                    }
                    Err(e) => {
                        log::error!("UDP receive error: {}", e);
                    }
                }
            }
        });

        // We can't move the Arc<UdpSocket> directly into Option<UdpSocket>
        // For now, we'll set it to None and handle discovery differently
        self.udp_socket = None;
        Ok(())
    }

    async fn start_discovery_task(&self) {
        let device_info = self.device_info.clone();
        let discovery_interval = self.discovery_interval;
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(discovery_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Broadcast discovery message
                if let Err(e) = Self::broadcast_discovery(&device_info).await {
                    log::error!("Discovery broadcast error: {}", e);
                }
            }
        });
    }

    async fn start_heartbeat_task(&self) {
        let device_id = self.device_info.device_id.clone();
        let heartbeat_interval = self.heartbeat_interval;
        let peers = Arc::clone(&self.peers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(heartbeat_interval);

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                // Send heartbeat to all known peers
                let peers_read = peers.read().await;
                for peer in peers_read.values() {
                    if let Err(e) = Self::send_heartbeat(&device_id, peer).await {
                        log::debug!("Heartbeat failed to {}: {}", peer.device_name, e);
                    }
                }
            }
        });
    }

    async fn start_cleanup_task(&self) {
        let peers = Arc::clone(&self.peers);
        let active_transfers = Arc::clone(&self.active_transfers);
        let shutdown_signal = Arc::clone(&self.shutdown_signal);

        tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_secs(300)); // 5 minutes

            loop {
                interval.tick().await;

                if *shutdown_signal.read().await {
                    break;
                }

                let now = Self::current_timestamp();

                // Clean up stale peers (not seen in 10 minutes)
                {
                    let mut peers_write = peers.write().await;
                    peers_write.retain(|_, peer| now - peer.last_seen < 600);
                }

                // Clean up failed transfers (inactive for 5 minutes)
                {
                    let mut transfers_write = active_transfers.write().await;
                    transfers_write.retain(|_, transfer| {
                        match transfer.last_activity.duration_since(UNIX_EPOCH) {
                            Ok(duration) => now - duration.as_secs() < 300,
                            Err(_) => false,
                        }
                    });
                }
            }
        });
    }

    /// Share a file with the mesh network
    pub async fn share_file(
        &self,
        file_path: PathBuf,
        description: Option<String>,
        tags: Vec<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let metadata = tokio::fs::metadata(&file_path).await?;
        let file_size = metadata.len();

        // Calculate file hash
        let file_hash = self.calculate_file_hash(&file_path).await?;

        // Generate unique file ID
        let file_id = format!("{}_{}", self.device_info.device_id, file_hash);

        let filename = file_path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("unknown")
            .to_string();

        let mime_type = Self::detect_mime_type(&file_path);

        let shared_file = SharedFile {
            id: file_id.clone(),
            filename,
            file_path: file_path.clone(),
            file_size,
            file_hash,
            mime_type,
            shared_by: self.device_info.device_id.clone(),
            timestamp: Self::current_timestamp(),
            description,
            tags,
        };

        // Add to local shared files
        self.shared_files
            .write()
            .await
            .insert(file_id.clone(), shared_file.clone());

        // Broadcast to peers
        self.broadcast_file_list().await?;

        log::info!("File shared: {} ({})", shared_file.filename, file_id);
        Ok(file_id)
    }

    /// Request a file from a peer
    pub async fn request_file(
        &self,
        file_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let peers_read = self.peers.read().await;
        let peer = peers_read.get(&peer_id).ok_or("Peer not found")?;

        let file_info = peer
            .shared_files
            .iter()
            .find(|f| f.id == file_id)
            .ok_or("File not found on peer")?;

        // Create transfer record
        let transfer = FileTransfer {
            file_id: file_id.clone(),
            peer_id: peer_id.clone(),
            filename: file_info.filename.clone(),
            total_size: file_info.file_size,
            transferred_bytes: 0,
            chunks_received: HashMap::new(),
            start_time: SystemTime::now(),
            last_activity: SystemTime::now(),
            transfer_type: TransferType::Download,
        };

        self.active_transfers
            .write()
            .await
            .insert(file_id.clone(), transfer);

        // Send request to peer
        let request = P2PMessage::FileRequest {
            file_id: file_id.clone(),
            chunk_index: None, // Request entire file
        };

        self.send_message_to_peer(&request, peer).await?;

        log::info!(
            "Requested file: {} from {}",
            file_info.filename,
            peer.device_name
        );
        Ok(())
    }

    /// Search for files across the mesh
    pub async fn search_files(
        &self,
        query: String,
        file_types: Vec<String>,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        let search_request = P2PMessage::SearchRequest {
            query: query.clone(),
            file_types,
        };

        // Send search to all peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&search_request, peer).await {
                log::debug!("Search request failed to {}: {}", peer.device_name, e);
            }
        }

        // Return local matches immediately
        let shared_files_read = self.shared_files.read().await;
        let local_results: Vec<SharedFile> = shared_files_read
            .values()
            .filter(|file| {
                file.filename.to_lowercase().contains(&query.to_lowercase())
                    || file.description.as_ref().map_or(false, |desc| {
                        desc.to_lowercase().contains(&query.to_lowercase())
                    })
                    || file
                        .tags
                        .iter()
                        .any(|tag| tag.to_lowercase().contains(&query.to_lowercase()))
            })
            .cloned()
            .collect();

        Ok(local_results)
    }

    /// Get list of all available files in the mesh
    pub async fn get_available_files(&self) -> Vec<SharedFile> {
        let mut all_files = Vec::new();

        // Add local files
        let shared_files_read = self.shared_files.read().await;
        all_files.extend(shared_files_read.values().cloned());

        // Add files from peers
        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            all_files.extend(peer.shared_files.iter().cloned());
        }

        all_files
    }

    /// Get list of connected peers
    pub async fn get_peers(&self) -> Vec<PeerDevice> {
        let peers_read = self.peers.read().await;
        peers_read.values().cloned().collect()
    }

    /// Get active file transfers
    pub async fn get_active_transfers(&self) -> Vec<FileTransfer> {
        let transfers_read = self.active_transfers.read().await;
        transfers_read.values().cloned().collect()
    }

    /// Utility functions

    fn generate_device_id() -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", SystemTime::now()));
        hasher.update(std::process::id().to_string());
        format!(
            "anbernic_{}",
            hex::encode(hasher.finalize())[..16].to_string()
        )
    }

    fn get_local_ip() -> Result<IpAddr, Box<dyn std::error::Error>> {
        // P2P-only compliance: Use WiFi Direct local interface discovery
        // This gets the local WiFi Direct interface IP for P2P communication
        // No router dependency - direct device-to-device networking
        
        // Get WiFi Direct interface IP (typically 192.168.49.x range for WiFi Direct)
        // This is the standard WiFi Direct GO (Group Owner) IP range
        let wifi_direct_ip = std::env::var("WIFI_DIRECT_LOCAL_IP")
            .unwrap_or_else(|_| "192.168.49.1".to_string()); // WiFi Direct standard range
            
        Ok(wifi_direct_ip.parse()?)
    }

    fn get_battery_level() -> Option<u8> {
        // Battery level detection for handheld devices
        // Placeholder - would integrate with actual battery APIs
        Some(85)
    }

    fn current_timestamp() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }

    async fn calculate_file_hash(
        &self,
        file_path: &Path,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let data = tokio::fs::read(file_path).await?;
        let mut hasher = Sha256::new();
        hasher.update(&data);
        Ok(hex::encode(hasher.finalize()))
    }

    fn detect_mime_type(file_path: &Path) -> String {
        match file_path.extension().and_then(|ext| ext.to_str()) {
            Some("mp3") => "audio/mpeg".to_string(),
            Some("mp4") => "video/mp4".to_string(),
            Some("jpg") | Some("jpeg") => "image/jpeg".to_string(),
            Some("png") => "image/png".to_string(),
            Some("txt") => "text/plain".to_string(),
            Some("pdf") => "application/pdf".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }

    async fn broadcast_discovery(
        device_info: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Discovery {
            device_info: device_info.clone(),
        };

        let data = serde_json::to_vec(&message)?;

        // Broadcast to local network
        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.set_broadcast(true)?;

        let broadcast_addr = SocketAddr::new("255.255.255.255".parse()?, 8091);
        socket.send_to(&data, broadcast_addr).await?;

        Ok(())
    }

    async fn broadcast_file_list(&self) -> Result<(), Box<dyn std::error::Error>> {
        let shared_files_read = self.shared_files.read().await;
        let files: Vec<SharedFile> = shared_files_read.values().cloned().collect();

        let message = P2PMessage::FileList { files };

        let peers_read = self.peers.read().await;
        for peer in peers_read.values() {
            if let Err(e) = self.send_message_to_peer(&message, peer).await {
                log::debug!("Failed to send file list to {}: {}", peer.device_name, e);
            }
        }

        Ok(())
    }

    async fn send_message_to_peer(
        &self,
        message: &P2PMessage,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let data = serde_json::to_vec(message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn send_heartbeat(
        device_id: &str,
        peer: &PeerDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let message = P2PMessage::Heartbeat {
            device_id: device_id.to_string(),
            battery_level: Self::get_battery_level(),
        };

        let data = serde_json::to_vec(&message)?;
        let addr = SocketAddr::new(peer.ip_address, peer.port);

        let mut stream = TcpStream::connect(addr).await?;
        stream.write_all(&data).await?;

        Ok(())
    }

    async fn handle_tcp_connection(
        mut stream: TcpStream,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        active_transfers: Arc<RwLock<HashMap<String, FileTransfer>>>,
        shared_files: Arc<RwLock<HashMap<String, SharedFile>>>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; chunk_size];
        let len = stream.read(&mut buffer).await?;
        buffer.truncate(len);

        if let Ok(message) = serde_json::from_slice::<P2PMessage>(&buffer) {
            match message {
                P2PMessage::FileRequest {
                    file_id,
                    chunk_index,
                } => {
                    // Handle file request
                    let shared_files_read = shared_files.read().await;
                    if let Some(file_info) = shared_files_read.get(&file_id) {
                        Self::send_file_chunk(&mut stream, file_info, chunk_index, chunk_size)
                            .await?;
                    }
                }
                _ => {
                    log::debug!("Received TCP message: {:?}", message);
                }
            }
        }

        Ok(())
    }

    async fn send_file_chunk(
        stream: &mut TcpStream,
        file_info: &SharedFile,
        chunk_index: Option<u32>,
        chunk_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let file_data = tokio::fs::read(&file_info.file_path).await?;
        let total_chunks = (file_data.len() + chunk_size - 1) / chunk_size;

        match chunk_index {
            Some(index) => {
                // Send specific chunk
                let start = (index as usize) * chunk_size;
                let end = std::cmp::min(start + chunk_size, file_data.len());
                let chunk_data = file_data[start..end].to_vec();

                let message = P2PMessage::FileShare {
                    file_info: file_info.clone(),
                    chunk_data: Some(chunk_data),
                    chunk_index: index,
                    total_chunks: total_chunks as u32,
                };

                let data = serde_json::to_vec(&message)?;
                stream.write_all(&data).await?;
            }
            None => {
                // Send entire file in chunks
                for i in 0..total_chunks {
                    let start = i * chunk_size;
                    let end = std::cmp::min(start + chunk_size, file_data.len());
                    let chunk_data = file_data[start..end].to_vec();

                    let message = P2PMessage::FileShare {
                        file_info: file_info.clone(),
                        chunk_data: Some(chunk_data),
                        chunk_index: i as u32,
                        total_chunks: total_chunks as u32,
                    };

                    let data = serde_json::to_vec(&message)?;
                    stream.write_all(&data).await?;

                    // Small delay between chunks for battery efficiency
                    tokio::time::sleep(Duration::from_millis(10)).await;
                }
            }
        }

        Ok(())
    }

    async fn handle_discovery_message(
        message: P2PMessage,
        peer_addr: SocketAddr,
        peers: Arc<RwLock<HashMap<String, PeerDevice>>>,
        device_info: &PeerDevice,
        socket: &Arc<UdpSocket>,
        message_sender: &broadcast::Sender<P2PMessage>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match message {
            P2PMessage::Discovery {
                device_info: peer_info,
            } => {
                let mut peer_info = peer_info;
                // Update peer info
                peer_info.ip_address = peer_addr.ip();
                peer_info.last_seen = Self::current_timestamp();

                let mut peers_write = peers.write().await;
                peers_write.insert(peer_info.device_id.clone(), peer_info.clone());

                // Send our discovery response
                let response = P2PMessage::Discovery {
                    device_info: device_info.clone(),
                };
                let data = serde_json::to_vec(&response)?;
                socket.send_to(&data, peer_addr).await?;

                // Notify application
                let discovery_message = P2PMessage::Discovery {
                    device_info: peer_info.clone(),
                };
                let _ = message_sender.send(discovery_message);
            }
            _ => {
                log::debug!("Received UDP message: {:?}", message);
            }
        }

        Ok(())
    }

    /// Shutdown the P2P mesh
    pub async fn shutdown(&self) -> Result<(), Box<dyn std::error::Error>> {
        *self.shutdown_signal.write().await = true;
        log::info!("P2P mesh shutting down");
        Ok(())
    }
}

/// Helper trait for applications to integrate P2P file sharing
pub trait P2PIntegration {
    fn get_p2p_manager(&self) -> &P2PMeshManager;

    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec![])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec![]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}
