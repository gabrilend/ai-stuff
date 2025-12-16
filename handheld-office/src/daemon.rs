use log::{debug, error, info};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, RwLock};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub sender: String,
    pub content: String,
    pub timestamp: u64,
    pub message_type: MessageType,
    pub is_encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    Command,
    LlmRequest,
    LlmResponse,
    StateSync,
}

#[derive(Debug, Clone)]
pub struct ClientInfo {
    pub id: String,
    pub device_type: DeviceType,
    pub last_seen: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Handheld,
    Desktop,
    Cluster,
}

/// Per-relationship encryption manager for daemon communications
#[derive(Debug, Clone)]
pub struct DaemonCryptoManager {
    pub device_id: String,
    pub private_key: String,
    pub public_key: String,
    pub relationship_keys: HashMap<String, (String, String)>, // client_id -> (private_key, public_key)
    pub encryption_enabled: bool,
}

pub struct ProjectDaemon {
    clients: Arc<RwLock<HashMap<String, ClientInfo>>>,
    message_sender: broadcast::Sender<Message>,
    state: Arc<RwLock<HashMap<String, serde_json::Value>>>,
    crypto: Arc<RwLock<DaemonCryptoManager>>,
}

impl ProjectDaemon {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(1000);

        // Generate unique device ID for daemon
        let device_id = format!("daemon_{:016x}", rand::thread_rng().gen::<u64>());
        let (private_key, public_key) = Self::generate_keypair();

        let crypto = DaemonCryptoManager {
            device_id,
            private_key,
            public_key,
            relationship_keys: HashMap::new(),
            encryption_enabled: true,
        };

        Self {
            clients: Arc::new(RwLock::new(HashMap::new())),
            message_sender: tx,
            state: Arc::new(RwLock::new(HashMap::new())),
            crypto: Arc::new(RwLock::new(crypto)),
        }
    }

    fn generate_keypair() -> (String, String) {
        let mut rng = rand::thread_rng();
        let private_key = format!("DAEMON_PRIV_{:032x}", rng.gen::<u128>());
        let public_key = format!("DAEMON_PUB_{:032x}", rng.gen::<u128>());
        (private_key, public_key)
    }

    pub async fn start(&self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", port)).await?; // Security: localhost only
        info!("Project daemon listening on localhost:{} (air-gapped compliance)", port);

        // Start state persistence task
        self.start_state_persistence().await;

        loop {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    // Security: Validate connection is from authorized localhost only
                    if !addr.ip().is_loopback() {
                        error!("Rejected non-localhost connection from: {}", addr);
                        continue;
                    }
                    
                    info!("New authorized client connected: {}", addr);
                    let daemon = self.clone();
                    tokio::spawn(async move {
                        if let Err(e) = daemon.handle_client(stream).await {
                            error!("Client handler error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }

    async fn handle_client(&self, mut stream: TcpStream) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0; 1024];
        let mut message_receiver = self.message_sender.subscribe();

        loop {
            tokio::select! {
                // Handle incoming messages from client
                result = stream.read(&mut buffer) => {
                    match result {
                        Ok(0) => break, // Connection closed
                        Ok(n) => {
                            let data = &buffer[..n];
                            if let Ok(message) = serde_json::from_slice::<Message>(data) {
                                self.process_message(message).await?;
                            }
                        }
                        Err(e) => {
                            error!("Read error: {}", e);
                            break;
                        }
                    }
                }

                // Forward messages to client
                message = message_receiver.recv() => {
                    match message {
                        Ok(msg) => {
                            let serialized = serde_json::to_vec(&msg)?;
                            if let Err(e) = stream.write_all(&serialized).await {
                                error!("Write error: {}", e);
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            }
        }

        Ok(())
    }

    async fn process_message(
        &self,
        mut message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        debug!("Processing message: {:?}", message);

        // Decrypt message if it's encrypted
        if message.is_encrypted {
            let mut crypto = self.crypto.write().await;
            match crypto.decrypt_from_client(&message.content, &message.sender) {
                Ok(decrypted_content) => {
                    message.content = decrypted_content;
                    message.is_encrypted = false;
                }
                Err(e) => {
                    error!("Failed to decrypt message from {}: {}", message.sender, e);
                    return Ok(()); // Skip processing encrypted messages we can't decrypt
                }
            }
        }

        match message.message_type {
            MessageType::LlmRequest => {
                // Forward to desktop LLM service
                self.forward_to_llm_service(message).await?;
            }
            MessageType::StateSync => {
                // Update daemon state
                self.update_state(&message).await?;
            }
            _ => {
                // Broadcast to all clients
                if let Err(e) = self.message_sender.send(message) {
                    error!("Failed to broadcast message: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn forward_to_llm_service(
        &self,
        message: Message,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Find desktop/cluster clients
        let clients = self.clients.read().await;
        for (_, client) in clients.iter() {
            match client.device_type {
                DeviceType::Desktop | DeviceType::Cluster => {
                    // Forward message to LLM service
                    if let Err(e) = self.message_sender.send(message.clone()) {
                        error!("Failed to forward to LLM service: {}", e);
                    }
                    break;
                }
                _ => continue,
            }
        }
        Ok(())
    }

    async fn update_state(&self, message: &Message) -> Result<(), Box<dyn std::error::Error>> {
        let mut state = self.state.write().await;
        if let Ok(value) = serde_json::from_str(&message.content) {
            state.insert(message.sender.clone(), value);
        }
        Ok(())
    }

    async fn start_state_persistence(&self) {
        let state = Arc::clone(&self.state);
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));

            loop {
                interval.tick().await;
                let state_snapshot = state.read().await;

                // Save state to files/build directory
                if let Ok(serialized) = serde_json::to_string_pretty(&*state_snapshot) {
                    if let Err(e) =
                        tokio::fs::write("files/build/daemon_state.json", serialized).await
                    {
                        error!("Failed to save state: {}", e);
                    }
                }
            }
        });
    }
}

impl Clone for ProjectDaemon {
    fn clone(&self) -> Self {
        Self {
            clients: Arc::clone(&self.clients),
            message_sender: self.message_sender.clone(),
            state: Arc::clone(&self.state),
            crypto: Arc::clone(&self.crypto),
        }
    }
}

impl DaemonCryptoManager {
    /// Encrypt a message for a specific client using per-relationship keys
    pub fn encrypt_for_client(
        &mut self,
        content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(content.to_string());
        }

        // Get or create relationship key for this client
        let (private_key, public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(client_id) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(client_id)?;
                self.relationship_keys
                    .insert(client_id.to_string(), new_keys.clone());
                new_keys
            };

        // Simplified encryption - in real implementation would use actual encryption
        let encrypted = format!("DAEMON_ENCRYPTED[{}]:{}", client_id, content);
        Ok(encrypted)
    }

    /// Decrypt a message, trying all available keys for the sender
    pub fn decrypt_from_client(
        &mut self,
        encrypted_content: &str,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if !self.encryption_enabled {
            return Ok(encrypted_content.to_string());
        }

        // Try relationship key first
        if let Some((private_key, _)) = self.relationship_keys.get(client_id) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, private_key, client_id)
            {
                return Ok(decrypted);
            }
        }

        // Try main daemon key
        if let Ok(decrypted) =
            self.try_decrypt_with_key(encrypted_content, &self.private_key, client_id)
        {
            return Ok(decrypted);
        }

        // If no key works, generate new relationship key for this client
        let new_keys = self.generate_relationship_keys(client_id)?;
        self.relationship_keys
            .insert(client_id.to_string(), new_keys.clone());

        // Try with new key (this may still fail, but establishes the relationship)
        if let Ok(decrypted) = self.try_decrypt_with_key(encrypted_content, &new_keys.0, client_id)
        {
            return Ok(decrypted);
        }

        Err("Failed to decrypt message with any available keys".into())
    }

    /// Generate a new key pair for a specific client relationship
    fn generate_relationship_keys(
        &self,
        client_id: &str,
    ) -> Result<(String, String), Box<dyn std::error::Error>> {
        use rand::Rng;
        use sha2::{Digest, Sha256};

        // Generate a deterministic but unique key based on our device ID and their client ID
        let mut hasher = Sha256::new();
        hasher.update(self.device_id.as_bytes());
        hasher.update(client_id.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>()); // Add randomness
        let key_seed = hasher.finalize();

        let private_key = format!("DAEMON_REL_PRIV_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("DAEMON_REL_PUB_{}", hex::encode(&key_seed[16..]));

        Ok((private_key, public_key))
    }

    /// Try to decrypt with a specific key
    fn try_decrypt_with_key(
        &self,
        encrypted_content: &str,
        private_key: &str,
        expected_client: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified decryption - check if message is in expected format
        if encrypted_content.starts_with(&format!("DAEMON_ENCRYPTED[{}]:", expected_client)) {
            let content = encrypted_content
                .strip_prefix(&format!("DAEMON_ENCRYPTED[{}]:", expected_client))
                .ok_or("Invalid encrypted format")?;
            Ok(content.to_string())
        } else {
            Err("Decryption failed".into())
        }
    }

    /// Get public key for a relationship (creates new relationship if needed)
    pub fn get_relationship_public_key(
        &mut self,
        client_id: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some((_, public_key)) = self.relationship_keys.get(client_id) {
            Ok(public_key.clone())
        } else {
            let new_keys = self.generate_relationship_keys(client_id)?;
            let public_key = new_keys.1.clone();
            self.relationship_keys
                .insert(client_id.to_string(), new_keys);
            Ok(public_key)
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let daemon = ProjectDaemon::new();
    daemon.start(8080).await?;

    Ok(())
}
