/// Migration adapter for transitioning existing P2P modules to secure crypto system
/// Provides backward compatibility while enabling crypto integration
use crate::crypto::{SecureP2PManager, SecureP2PMessage, RelationshipId, CryptoResult};
use crate::p2p_mesh::{P2PMessage, PeerDevice, SharedFile, P2PMeshManager};
use crate::wifi_direct_p2p::{WiFiDirectP2P, MessageContent, EncryptedPacket as OldEncryptedPacket};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Adapter that wraps existing P2P modules with crypto integration
pub struct P2PMigrationAdapter {
    /// Secure P2P manager (new system)
    secure_manager: SecureP2PManager,
    /// Legacy P2P mesh manager (for gradual migration)
    legacy_mesh: Option<P2PMeshManager>,
    /// Legacy WiFi Direct (for gradual migration) 
    legacy_wifi_direct: Option<WiFiDirectP2P>,
    /// Relationship mapping (legacy device ID -> new relationship ID)
    relationship_mapping: Arc<RwLock<HashMap<String, RelationshipId>>>,
    /// Migration configuration
    config: MigrationConfig,
}

/// Configuration for migration behavior
#[derive(Debug, Clone)]
pub struct MigrationConfig {
    /// Whether to enable legacy compatibility mode
    pub legacy_compatibility: bool,
    /// Whether to auto-migrate existing connections
    pub auto_migrate_connections: bool,
    /// Timeout for legacy operations (seconds)
    pub legacy_timeout: u64,
    /// Whether to log migration activities
    pub verbose_logging: bool,
}

/// Migration status for tracking progress
#[derive(Debug, Clone)]
pub struct MigrationStatus {
    /// Total legacy devices found
    pub total_legacy_devices: usize,
    /// Successfully migrated devices
    pub migrated_devices: usize,
    /// Failed migrations
    pub failed_migrations: usize,
    /// Active legacy connections
    pub active_legacy_connections: usize,
    /// Migration completion percentage
    pub completion_percentage: f32,
}

impl Default for MigrationConfig {
    fn default() -> Self {
        Self {
            legacy_compatibility: true,
            auto_migrate_connections: true,
            legacy_timeout: 300, // 5 minutes
            verbose_logging: true,
        }
    }
}

impl P2PMigrationAdapter {
    /// Create a new migration adapter
    pub fn new(
        device_name: String,
        device_type: crate::p2p_mesh::DeviceType,
    ) -> CryptoResult<Self> {
        let secure_manager = SecureP2PManager::new(device_name, device_type)?;
        
        Ok(Self {
            secure_manager,
            legacy_mesh: None,
            legacy_wifi_direct: None,
            relationship_mapping: Arc::new(RwLock::new(HashMap::new())),
            config: MigrationConfig::default(),
        })
    }

    /// Create adapter with existing legacy systems
    pub fn with_legacy_systems(
        device_name: String,
        device_type: crate::p2p_mesh::DeviceType,
        legacy_mesh: Option<P2PMeshManager>,
        legacy_wifi_direct: Option<WiFiDirectP2P>,
    ) -> CryptoResult<Self> {
        let secure_manager = SecureP2PManager::new(device_name, device_type)?;
        
        Ok(Self {
            secure_manager,
            legacy_mesh,
            legacy_wifi_direct,
            relationship_mapping: Arc::new(RwLock::new(HashMap::new())),
            config: MigrationConfig::default(),
        })
    }

    /// Start the migration adapter with both systems
    pub async fn start(&mut self) -> CryptoResult<()> {
        if self.config.verbose_logging {
            log::info!("Starting P2P migration adapter");
        }

        // Start secure system
        self.secure_manager.start().await?;

        // Start legacy systems if present
        if let Some(ref mut legacy_mesh) = self.legacy_mesh {
            if let Err(e) = legacy_mesh.start().await {
                log::warn!("Failed to start legacy mesh system: {}", e);
            }
        }

        // Begin migration process if enabled
        if self.config.auto_migrate_connections {
            self.start_migration_process().await?;
        }

        if self.config.verbose_logging {
            log::info!("P2P migration adapter started successfully");
        }

        Ok(())
    }

    /// Enter pairing mode (uses secure system)
    pub async fn enter_pairing_mode(&mut self) -> CryptoResult<crate::crypto::PairingEmoji> {
        self.secure_manager.enter_pairing_mode().await
    }

    /// Pair with a device (creates secure relationship)
    pub async fn pair_with_device(
        &mut self,
        target_emoji: &crate::crypto::PairingEmoji,
        nickname: String,
    ) -> CryptoResult<RelationshipId> {
        let relationship_id = self.secure_manager.pair_with_device(target_emoji, nickname).await?;

        // If we have legacy systems, attempt to establish compatibility
        if self.config.legacy_compatibility {
            self.establish_legacy_compatibility(&relationship_id, &target_emoji.session_id).await?;
        }

        Ok(relationship_id)
    }

    /// Send message (routes through secure system)
    pub async fn send_message(
        &mut self,
        target: MessageTarget,
        message: UnifiedMessage,
    ) -> CryptoResult<String> {
        match target {
            MessageTarget::Relationship(relationship_id) => {
                let secure_message = self.convert_to_secure_message(message);
                self.secure_manager.send_message(&relationship_id, secure_message).await
            }
            MessageTarget::LegacyDevice(device_id) => {
                // Try to find mapped relationship first
                if let Some(relationship_id) = self.get_relationship_for_device(&device_id).await {
                    let secure_message = self.convert_to_secure_message(message);
                    self.secure_manager.send_message(&relationship_id, secure_message).await
                } else {
                    // Fall back to legacy system if available
                    self.send_legacy_message(&device_id, message).await
                }
            }
        }
    }

    /// Get list of all available peers (both secure and legacy)
    pub async fn get_all_peers(&self) -> Vec<UnifiedPeerInfo> {
        let mut peers = Vec::new();

        // Get secure peers
        for secure_peer in self.secure_manager.get_secure_peers().await {
            peers.push(UnifiedPeerInfo {
                relationship_id: Some(secure_peer.relationship_id.clone()),
                device_id: secure_peer.device_info.device_id,
                nickname: secure_peer.nickname,
                device_name: secure_peer.device_info.device_name,
                device_type: secure_peer.device_info.device_type,
                security_status: PeerSecurityStatus::Secure,
                last_contact: secure_peer.last_contact,
                capabilities: secure_peer.capabilities,
            });
        }

        // Get legacy peers (if compatibility mode enabled)
        if self.config.legacy_compatibility {
            if let Some(ref legacy_mesh) = self.legacy_mesh {
                for legacy_peer in legacy_mesh.get_peers().await {
                    // Check if already migrated
                    if !self.is_device_migrated(&legacy_peer.device_id).await {
                        peers.push(UnifiedPeerInfo {
                            relationship_id: None,
                            device_id: legacy_peer.device_id,
                            nickname: legacy_peer.device_name.clone(),
                            device_name: legacy_peer.device_name,
                            device_type: legacy_peer.device_type,
                            security_status: PeerSecurityStatus::Legacy,
                            last_contact: legacy_peer.last_seen,
                            capabilities: vec![], // Legacy peers have unknown capabilities
                        });
                    }
                }
            }
        }

        peers
    }

    /// Get migration status
    pub async fn get_migration_status(&self) -> MigrationStatus {
        let relationship_mapping = self.relationship_mapping.read().await;
        let total_legacy = self.count_legacy_devices().await;
        let migrated = relationship_mapping.len();
        
        MigrationStatus {
            total_legacy_devices: total_legacy,
            migrated_devices: migrated,
            failed_migrations: 0, // Would track this in real implementation
            active_legacy_connections: total_legacy - migrated,
            completion_percentage: if total_legacy > 0 {
                (migrated as f32 / total_legacy as f32) * 100.0
            } else {
                100.0
            },
        }
    }

    /// Manually migrate a specific device
    pub async fn migrate_device(&mut self, device_id: &str) -> CryptoResult<RelationshipId> {
        if self.config.verbose_logging {
            log::info!("Attempting to migrate device: {}", device_id);
        }

        // This would implement the actual migration logic
        // For now, return an error indicating manual migration is needed
        Err(crate::crypto::CryptoError::Pairing(
            "Manual migration requires re-pairing through secure system".to_string()
        ))
    }

    /// Force migration of all legacy devices
    pub async fn force_migrate_all(&mut self) -> CryptoResult<Vec<String>> {
        let mut failed_devices = Vec::new();

        // Get all legacy devices
        let legacy_devices = self.get_legacy_device_ids().await;

        for device_id in legacy_devices {
            if let Err(e) = self.migrate_device(&device_id).await {
                log::warn!("Failed to migrate device {}: {}", device_id, e);
                failed_devices.push(device_id);
            }
        }

        Ok(failed_devices)
    }

    // Private implementation methods

    async fn start_migration_process(&mut self) -> CryptoResult<()> {
        if self.config.verbose_logging {
            log::info!("Starting automatic migration process");
        }

        // This would implement background migration logic
        // For now, just log that migration is available
        log::info!("Automatic migration is available - legacy devices will be prompted to re-pair");

        Ok(())
    }

    async fn establish_legacy_compatibility(&self, _relationship_id: &RelationshipId, device_id: &str) -> CryptoResult<()> {
        // Map the new relationship to the legacy device ID for compatibility
        self.relationship_mapping.write().await.insert(device_id.to_string(), _relationship_id.clone());
        
        if self.config.verbose_logging {
            log::info!("Established legacy compatibility mapping for device: {}", device_id);
        }

        Ok(())
    }

    async fn get_relationship_for_device(&self, device_id: &str) -> Option<RelationshipId> {
        self.relationship_mapping.read().await.get(device_id).cloned()
    }

    async fn is_device_migrated(&self, device_id: &str) -> bool {
        self.relationship_mapping.read().await.contains_key(device_id)
    }

    async fn count_legacy_devices(&self) -> usize {
        let mut count = 0;

        if let Some(ref legacy_mesh) = self.legacy_mesh {
            count += legacy_mesh.get_peers().await.len();
        }

        // Could also count WiFi Direct peers if needed

        count
    }

    async fn get_legacy_device_ids(&self) -> Vec<String> {
        let mut device_ids = Vec::new();

        if let Some(ref legacy_mesh) = self.legacy_mesh {
            for peer in legacy_mesh.get_peers().await {
                device_ids.push(peer.device_id);
            }
        }

        device_ids
    }

    fn convert_to_secure_message(&self, message: UnifiedMessage) -> SecureP2PMessage {
        match message {
            UnifiedMessage::Text(text) => SecureP2PMessage::Application {
                app_name: "text_message".to_string(),
                payload: text.into_bytes(),
            },
            UnifiedMessage::FileShare { file_info, chunk_data } => SecureP2PMessage::FileShare {
                operation: if chunk_data.is_some() {
                    crate::crypto::FileOperation::Chunk {
                        file_id: file_info.id,
                        chunk_index: 0, // Would need proper chunk tracking
                        total_chunks: 1,
                    }
                } else {
                    crate::crypto::FileOperation::Request { file_id: file_info.id }
                },
                file_info: Some(file_info),
                chunk_data,
            },
            UnifiedMessage::DocumentSync { document_id, content } => SecureP2PMessage::DocumentSync {
                document_id,
                operation: crate::crypto::DocumentOperation::Sync,
                content,
            },
            UnifiedMessage::LLMRequest { prompt, request_id } => SecureP2PMessage::LLMProxy {
                request_id,
                operation: crate::crypto::LLMOperation::Request {
                    prompt,
                    parameters: HashMap::new(),
                },
            },
            UnifiedMessage::Heartbeat { battery_level } => SecureP2PMessage::Heartbeat {
                battery_level,
                capabilities: vec![], // Would enumerate actual capabilities
            },
        }
    }

    async fn send_legacy_message(&self, _device_id: &str, _message: UnifiedMessage) -> CryptoResult<String> {
        // Implementation would route to legacy systems
        // For now, return error encouraging migration
        Err(crate::crypto::CryptoError::Pairing(
            "Legacy messaging deprecated - please re-pair with secure system".to_string()
        ))
    }
}

/// Target for sending messages
#[derive(Debug, Clone)]
pub enum MessageTarget {
    /// Send to secure relationship
    Relationship(RelationshipId),
    /// Send to legacy device (will attempt migration)
    LegacyDevice(String),
}

/// Unified message type for both secure and legacy systems
#[derive(Debug, Clone)]
pub enum UnifiedMessage {
    /// Text message
    Text(String),
    /// File sharing
    FileShare {
        file_info: SharedFile,
        chunk_data: Option<Vec<u8>>,
    },
    /// Document synchronization
    DocumentSync {
        document_id: String,
        content: Option<String>,
    },
    /// LLM request
    LLMRequest {
        prompt: String,
        request_id: String,
    },
    /// Heartbeat
    Heartbeat {
        battery_level: Option<u8>,
    },
}

/// Unified peer information combining secure and legacy
#[derive(Debug, Clone)]
pub struct UnifiedPeerInfo {
    /// Secure relationship ID (if migrated)
    pub relationship_id: Option<RelationshipId>,
    /// Legacy device ID
    pub device_id: String,
    /// User-assigned nickname
    pub nickname: String,
    /// Device name
    pub device_name: String,
    /// Device type
    pub device_type: crate::p2p_mesh::DeviceType,
    /// Security status
    pub security_status: PeerSecurityStatus,
    /// Last contact timestamp
    pub last_contact: u64,
    /// Capabilities (if known)
    pub capabilities: Vec<crate::crypto::PeerCapability>,
}

/// Security status of a peer
#[derive(Debug, Clone, PartialEq)]
pub enum PeerSecurityStatus {
    /// Fully secure with crypto relationships
    Secure,
    /// Legacy connection (insecure)
    Legacy,
    /// Migration in progress
    Migrating,
    /// Migration failed
    MigrationFailed,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_migration_adapter_creation() {
        let adapter = P2PMigrationAdapter::new(
            "test_device".to_string(),
            crate::p2p_mesh::DeviceType::Anbernic("rg353v".to_string()),
        ).unwrap();

        let status = adapter.get_migration_status().await;
        assert_eq!(status.total_legacy_devices, 0);
        assert_eq!(status.completion_percentage, 100.0);
    }

    #[tokio::test]
    async fn test_peer_listing() {
        let adapter = P2PMigrationAdapter::new(
            "test_device".to_string(),
            crate::p2p_mesh::DeviceType::Anbernic("rg353v".to_string()),
        ).unwrap();

        let peers = adapter.get_all_peers().await;
        assert!(peers.is_empty()); // No peers initially
    }
}