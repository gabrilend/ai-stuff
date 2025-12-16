# P2P Mesh System - Developer Guide

## Overview

This guide shows developers how to integrate the P2P mesh file sharing system into new applications within the handheld office suite.

## Core Architecture

### P2P Integration Trait

All P2P-enabled applications must implement the `P2PIntegration` trait:

```rust
use crate::p2p_mesh::{P2PMeshManager, SharedFile, P2PIntegration, PeerDevice};

pub trait P2PIntegration {
    /// Get reference to the P2P manager
    fn get_p2p_manager(&self) -> &P2PMeshManager;
    
    /// Share a file with optional tags
    async fn share_file(&self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>>;
    
    /// Search for shared files by query
    async fn search_shared_files(&self, query: String) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>>;
    
    /// Get list of connected peers
    async fn get_mesh_peers(&self) -> Vec<PeerDevice>;
}
```

## Application Integration Steps

### 1. Add P2P Fields to Your Application Struct

```rust
use crate::p2p_mesh::{P2PMeshManager, SharedFile, DeviceType};

pub struct MyApplication {
    // Your existing fields
    pub data: String,
    pub state: AppState,
    
    // P2P fields
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_files: Vec<SharedFile>,
}
```

### 2. Implement P2P Enable/Disable Methods

```rust
impl MyApplication {
    /// Initialize P2P networking
    pub fn enable_p2p(&mut self, device_name: String) -> Result<(), Box<dyn std::error::Error>> {
        if !self.p2p_enabled {
            let manager = P2PMeshManager::new(device_name, DeviceType::Anbernic("my_app".to_string()))?;
            self.p2p_manager = Some(manager);
            self.p2p_enabled = true;
        }
        Ok(())
    }

    /// Disable P2P networking
    pub fn disable_p2p(&mut self) {
        self.p2p_manager = None;
        self.p2p_enabled = false;
    }

    /// Toggle P2P on/off
    pub fn toggle_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.disable_p2p();
            InputResult::SpecialAction {
                action: "P2P disabled".to_string(),
            }
        } else {
            if let Err(_) = self.enable_p2p("my_device".to_string()) {
                InputResult::SpecialAction {
                    action: "P2P enable failed".to_string(),
                }
            } else {
                InputResult::SpecialAction {
                    action: "P2P enabled".to_string(),
                }
            }
        }
    }
}
```

### 3. Implement the P2PIntegration Trait

```rust
impl P2PIntegration for MyApplication {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager.as_ref().expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec!["my_app".to_string(), "custom".to_string()])
            .await
    }

    async fn search_shared_files(&self, query: String) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec!["my_app".to_string()]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}
```

### 4. Add P2P-Specific Input Modes (Optional)

If your application needs specialized P2P modes:

```rust
#[derive(Debug, Clone)]
pub enum MyAppMode {
    Normal,
    P2PBrowser,
    CollaborationMode,
    FileSharingMode,
}

impl MyApplication {
    fn handle_p2p_browser_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Download selected file
                vec![InputResult::SpecialAction {
                    action: "download_file".to_string(),
                }]
            }
            UniversalButton::X => {
                // Share current file
                if self.p2p_enabled {
                    vec![self.share_current_file()]
                } else {
                    vec![InputResult::SpecialAction {
                        action: "p2p_not_enabled".to_string(),
                    }]
                }
            }
            UniversalButton::B | UniversalButton::Select => {
                // Exit P2P browser
                self.current_mode = MyAppMode::Normal;
                vec![InputResult::ModeChange {
                    new_mode: "Normal".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }
}
```

### 5. Integrate P2P Controls with Your Input System

```rust
impl MyApplication {
    pub fn handle_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        match self.current_mode {
            MyAppMode::Normal => self.handle_normal_input(button, pressed),
            MyAppMode::P2PBrowser => self.handle_p2p_browser_input(button, pressed),
            MyAppMode::CollaborationMode => self.handle_collaboration_input(button, pressed),
            MyAppMode::FileSharingMode => self.handle_file_sharing_input(button, pressed),
        }
    }

    fn handle_normal_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Start => {
                // Open P2P browser when P2P is enabled
                if self.p2p_enabled {
                    self.current_mode = MyAppMode::P2PBrowser;
                    vec![InputResult::ModeChange {
                        new_mode: "P2P Browser".to_string(),
                    }]
                } else {
                    vec![InputResult::Navigation {
                        direction: "menu".to_string(),
                    }]
                }
            }
            UniversalButton::Y => {
                // Toggle P2P (SNES controllers)
                vec![self.toggle_p2p()]
            }
            UniversalButton::X => {
                // Quick share current file (SNES controllers)
                vec![self.share_current_file()]
            }
            // Handle other buttons...
            _ => self.handle_app_specific_input(button, pressed),
        }
    }
}
```

## File Sharing Implementation

### Basic File Sharing

```rust
impl MyApplication {
    /// Share the currently active file
    pub fn share_current_file(&mut self) -> InputResult {
        if let Some(manager) = &mut self.p2p_manager {
            if let Some(current_file) = &self.current_file_path {
                // Create shared file metadata
                let shared_file = SharedFile {
                    file_hash: self.calculate_file_hash(current_file),
                    filename: current_file.file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("unknown")
                        .to_string(),
                    file_size: std::fs::metadata(current_file)
                        .map(|m| m.len() as usize)
                        .unwrap_or(0),
                    content_type: self.get_content_type(current_file),
                    tags: vec!["my_app".to_string(), "shared".to_string()],
                    author: "my_device".to_string(),
                    created_time: std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_secs(),
                    device_info: "my_handheld_device".to_string(),
                };

                // Add to shared files list
                self.shared_files.push(shared_file.clone());
                
                InputResult::SpecialAction {
                    action: format!("shared_file_{}", shared_file.filename),
                }
            } else {
                InputResult::SpecialAction {
                    action: "no_file_to_share".to_string(),
                }
            }
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Download a file from another peer
    pub async fn download_shared_file(&mut self, file_hash: &str, save_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(manager) = &mut self.p2p_manager {
            // Find peers that have this file
            let peers = manager.find_peers_with_file(file_hash).await?;
            
            if let Some(peer) = peers.first() {
                // Download from first available peer
                manager.download_file_from_peer(peer, file_hash, save_path).await?;
                
                // Add to local files
                self.add_downloaded_file(save_path);
            }
        }
        Ok(())
    }
}
```

### Advanced Collaboration Features

```rust
/// Collaboration state for real-time features
#[derive(Debug, Clone)]
pub struct CollaborationState {
    pub session_id: String,
    pub participants: Vec<String>,
    pub last_sync: u64,
    pub pending_changes: Vec<ChangeEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChangeEvent {
    pub event_id: String,
    pub author: String,
    pub timestamp: u64,
    pub change_type: String,
    pub data: serde_json::Value,
}

impl MyApplication {
    /// Start a collaborative session
    pub async fn start_collaboration_session(&mut self, session_id: String) {
        let participants = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.into_iter().map(|p| p.device_id).collect()
        } else {
            Vec::new()
        };
        
        self.collaboration_state = Some(CollaborationState {
            session_id,
            participants,
            last_sync: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            pending_changes: Vec::new(),
        });
        
        self.current_mode = MyAppMode::CollaborationMode;
    }

    /// Add a change event to be synchronized
    pub fn add_collaboration_change(&mut self, change_type: String, data: serde_json::Value) {
        if let Some(state) = &mut self.collaboration_state {
            let change = ChangeEvent {
                event_id: format!("{}-{}", 
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos(),
                    rand::random::<u32>()
                ),
                author: "my_device".to_string(),
                timestamp: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                change_type,
                data,
            };
            
            state.pending_changes.push(change);
        }
    }

    /// Synchronize pending changes with other participants
    pub async fn sync_collaboration_changes(&mut self) -> InputResult {
        if let Some(state) = &mut self.collaboration_state {
            let change_count = state.pending_changes.len();
            
            // Send changes to all participants (simplified)
            if let Some(manager) = &self.p2p_manager {
                for participant in &state.participants {
                    // In a real implementation, send changes via P2P
                    let _ = manager.send_collaboration_message(participant, &state.pending_changes).await;
                }
            }
            
            // Clear pending changes
            state.pending_changes.clear();
            state.last_sync = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
            
            InputResult::SpecialAction {
                action: format!("synced_{}_changes", change_count),
            }
        } else {
            InputResult::SpecialAction {
                action: "no_collaboration_session".to_string(),
            }
        }
    }
}
```

## Testing Your P2P Integration

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_p2p_enable_disable() {
        let mut app = MyApplication::new();
        
        // Test enabling P2P
        assert!(!app.p2p_enabled);
        app.enable_p2p("test_device".to_string()).unwrap();
        assert!(app.p2p_enabled);
        assert!(app.p2p_manager.is_some());
        
        // Test disabling P2P
        app.disable_p2p();
        assert!(!app.p2p_enabled);
        assert!(app.p2p_manager.is_none());
    }

    #[tokio::test]
    async fn test_file_sharing() {
        let mut app = MyApplication::new();
        app.enable_p2p("test_device".to_string()).unwrap();
        
        // Test sharing a file
        let test_file = std::path::PathBuf::from("test_file.txt");
        let result = app.share_file(test_file).await;
        assert!(result.is_ok());
        
        // Check that file was added to shared files
        assert_eq!(app.shared_files.len(), 1);
    }

    #[test]
    fn test_p2p_input_handling() {
        let mut app = MyApplication::new();
        
        // Test P2P toggle
        let result = app.handle_input(UniversalButton::Y, true);
        assert!(!result.is_empty());
        
        // Test P2P browser access
        app.enable_p2p("test_device".to_string()).unwrap();
        let result = app.handle_input(UniversalButton::Start, true);
        assert!(matches!(app.current_mode, MyAppMode::P2PBrowser));
    }
}
```

### Integration Tests

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;

    #[tokio::test]
    async fn test_peer_discovery() {
        let mut app1 = MyApplication::new();
        let mut app2 = MyApplication::new();
        
        app1.enable_p2p("device1".to_string()).unwrap();
        app2.enable_p2p("device2".to_string()).unwrap();
        
        // Wait for discovery
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        
        // Check that peers discovered each other
        let peers1 = app1.get_mesh_peers().await;
        let peers2 = app2.get_mesh_peers().await;
        
        assert!(peers1.len() > 0);
        assert!(peers2.len() > 0);
    }

    #[tokio::test]
    async fn test_file_transfer() {
        let mut sender = MyApplication::new();
        let mut receiver = MyApplication::new();
        
        sender.enable_p2p("sender".to_string()).unwrap();
        receiver.enable_p2p("receiver".to_string()).unwrap();
        
        // Create test file
        let test_content = "Hello, P2P world!";
        let test_file = std::path::PathBuf::from("test_share.txt");
        std::fs::write(&test_file, test_content).unwrap();
        
        // Share file from sender
        let file_hash = sender.share_file(test_file).await.unwrap();
        
        // Search for file on receiver
        let search_results = receiver.search_shared_files("test_share".to_string()).await.unwrap();
        assert!(search_results.len() > 0);
        assert_eq!(search_results[0].file_hash, file_hash);
        
        // Download file
        let download_path = "downloaded_test.txt";
        receiver.download_shared_file(&file_hash, download_path).await.unwrap();
        
        // Verify downloaded content
        let downloaded_content = std::fs::read_to_string(download_path).unwrap();
        assert_eq!(downloaded_content, test_content);
        
        // Cleanup
        std::fs::remove_file("test_share.txt").ok();
        std::fs::remove_file(download_path).ok();
    }
}
```

## Best Practices

### Performance Optimization

1. **Lazy Initialization**: Only create P2P manager when needed
2. **Connection Pooling**: Reuse TCP connections between peers
3. **Chunked Transfers**: Use 32KB chunks for memory efficiency
4. **Background Processing**: Handle P2P operations asynchronously

### Error Handling

```rust
impl MyApplication {
    pub async fn robust_file_sharing(&mut self, file_path: std::path::PathBuf) -> Result<String, AppError> {
        // Validate file exists and is readable
        if !file_path.exists() {
            return Err(AppError::FileNotFound(file_path.to_string_lossy().to_string()));
        }
        
        // Check file size limits (e.g., 100MB)
        let metadata = std::fs::metadata(&file_path)
            .map_err(|e| AppError::FileSystem(e.to_string()))?;
        
        if metadata.len() > 100 * 1024 * 1024 {
            return Err(AppError::FileTooLarge(metadata.len()));
        }
        
        // Ensure P2P is enabled
        if !self.p2p_enabled {
            return Err(AppError::P2PNotEnabled);
        }
        
        // Attempt file sharing with retry logic
        let mut attempts = 0;
        let max_attempts = 3;
        
        while attempts < max_attempts {
            match self.share_file(file_path.clone()).await {
                Ok(hash) => return Ok(hash),
                Err(e) => {
                    attempts += 1;
                    if attempts >= max_attempts {
                        return Err(AppError::P2PTransfer(e.to_string()));
                    }
                    // Exponential backoff
                    tokio::time::sleep(tokio::time::Duration::from_millis(1000 * attempts)).await;
                }
            }
        }
        
        Err(AppError::P2PTransfer("Max attempts exceeded".to_string()))
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("File not found: {0}")]
    FileNotFound(String),
    
    #[error("File too large: {0} bytes")]
    FileTooLarge(u64),
    
    #[error("P2P not enabled")]
    P2PNotEnabled,
    
    #[error("P2P transfer failed: {0}")]
    P2PTransfer(String),
    
    #[error("File system error: {0}")]
    FileSystem(String),
}
```

### Security Considerations

1. **File Validation**: Always validate file types and sizes
2. **Hash Verification**: Verify SHA-256 checksums for transfers
3. **Network Isolation**: Ensure P2P stays on local network
4. **User Consent**: Always ask before sharing personal files

### Battery Efficiency

1. **Adaptive Discovery**: Adjust discovery frequency based on battery level
2. **Connection Limits**: Limit concurrent connections (max 10)
3. **Smart Scheduling**: Batch operations during idle periods
4. **Power Monitoring**: Disable P2P during low battery conditions

## Debugging P2P Integration

### Logging

```rust
use log::{info, warn, error, debug};

impl MyApplication {
    pub fn enable_p2p_with_logging(&mut self, device_name: String) -> Result<(), Box<dyn std::error::Error>> {
        info!("Enabling P2P for device: {}", device_name);
        
        if self.p2p_enabled {
            warn!("P2P already enabled, skipping");
            return Ok(());
        }
        
        match P2PMeshManager::new(device_name.clone(), DeviceType::Anbernic("my_app".to_string())) {
            Ok(manager) => {
                self.p2p_manager = Some(manager);
                self.p2p_enabled = true;
                info!("P2P successfully enabled for {}", device_name);
                Ok(())
            }
            Err(e) => {
                error!("Failed to enable P2P: {}", e);
                Err(e)
            }
        }
    }
    
    pub async fn share_file_with_logging(&mut self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        debug!("Attempting to share file: {:?}", file_path);
        
        if !self.p2p_enabled {
            warn!("Attempted to share file without P2P enabled");
            return Err("P2P not enabled".into());
        }
        
        let start_time = std::time::Instant::now();
        let result = self.share_file(file_path.clone()).await;
        let duration = start_time.elapsed();
        
        match &result {
            Ok(hash) => {
                info!("Successfully shared file {:?} with hash {} in {:?}", 
                    file_path, hash, duration);
            }
            Err(e) => {
                error!("Failed to share file {:?}: {} (took {:?})", 
                    file_path, e, duration);
            }
        }
        
        result
    }
}
```

### Status Monitoring

```rust
impl MyApplication {
    /// Get detailed P2P status for debugging
    pub async fn get_debug_status(&self) -> DebugStatus {
        let p2p_info = if let Some(manager) = &self.p2p_manager {
            Some(P2PDebugInfo {
                peers: manager.get_peers().await,
                shared_files_count: self.shared_files.len(),
                active_transfers: manager.get_active_transfers().await,
                network_stats: manager.get_network_stats().await,
            })
        } else {
            None
        };
        
        DebugStatus {
            p2p_enabled: self.p2p_enabled,
            current_mode: format!("{:?}", self.current_mode),
            p2p_info,
            collaboration_active: self.collaboration_state.is_some(),
            uptime: self.start_time.elapsed(),
        }
    }
}

#[derive(Debug)]
pub struct DebugStatus {
    pub p2p_enabled: bool,
    pub current_mode: String,
    pub p2p_info: Option<P2PDebugInfo>,
    pub collaboration_active: bool,
    pub uptime: std::time::Duration,
}

#[derive(Debug)]
pub struct P2PDebugInfo {
    pub peers: Vec<PeerDevice>,
    pub shared_files_count: usize,
    pub active_transfers: Vec<String>,
    pub network_stats: NetworkStats,
}
```

## Common Integration Patterns

### File Browser Integration

```rust
impl MyApplication {
    /// Browse files with P2P integration
    pub async fn browse_files_with_p2p(&self) -> Vec<FileEntry> {
        let mut files = self.get_local_files();
        
        if self.p2p_enabled {
            // Add shared files from network
            if let Ok(shared) = self.search_shared_files("".to_string()).await {
                for shared_file in shared {
                    files.push(FileEntry::Shared(shared_file));
                }
            }
        }
        
        files
    }
}

#[derive(Debug)]
pub enum FileEntry {
    Local(std::path::PathBuf),
    Shared(SharedFile),
}
```

### Auto-Save with P2P Backup

```rust
impl MyApplication {
    /// Auto-save with optional P2P backup
    pub async fn auto_save_with_backup(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Save locally first
        let local_path = self.get_auto_save_path();
        self.save_to_file(&local_path)?;
        
        // If P2P enabled and configured for backup, share the file
        if self.p2p_enabled && self.settings.p2p_auto_backup {
            let _ = self.share_file(local_path).await; // Best effort, don't fail if P2P fails
        }
        
        Ok(())
    }
}
```

---

This developer guide provides everything needed to integrate P2P functionality into new applications. The pattern is consistent across all existing applications and provides a robust foundation for distributed handheld computing.