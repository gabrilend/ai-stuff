# P2P Mesh File Sharing System

## Overview

The handheld office suite includes a comprehensive peer-to-peer (P2P) mesh networking system that enables file sharing and real-time collaboration between handheld devices. This system is optimized for battery-efficient operation and works seamlessly across all major applications.

## Architecture

### Core Components

- **P2P Mesh Manager**: Central networking component handling device discovery, file transfers, and peer management
- **Device Discovery**: Automatic detection of nearby handheld devices using UDP broadcasts
- **File Transfer Protocol**: Battery-efficient chunked transfers (32KB chunks) over TCP
- **Collaborative Editing**: Real-time document synchronization with conflict resolution

### Supported Applications

1. **Media Player**: Share videos, music, and media files
2. **Paint Program**: Collaborative art sessions and artwork sharing
3. **Enhanced Input/Word Processor**: Document sharing and collaborative writing

## Getting Started

### Enabling P2P

P2P functionality is disabled by default. To enable it:

#### Media Player
```rust
let mut media_player = MediaPlayer::new()?;
media_player.enable_p2p("my_device_name".to_string())?;
```

#### Paint Program
```rust
let mut paint_app = AnbernicPaintApp::new()?;
paint_app.enable_p2p("my_device_name".to_string())?;
```

#### Enhanced Input/Word Processor
```rust
let mut input_manager = EnhancedInputManager::gameboy_style();
input_manager.enable_p2p("my_device_name".to_string())?;
```

### Controller Integration

The P2P system integrates with both Game Boy and SNES-style controllers:

#### Game Boy Controllers (4 buttons + D-pad)
- **START**: Open P2P browser (when P2P enabled)
- **SELECT**: Access edit/collaboration modes

#### SNES Controllers (6 buttons + D-pad)
- **START**: Open P2P browser
- **Y**: Toggle P2P on/off
- **X**: Open document/file saver
- **L + R**: Special P2P combinations (app-specific)

## Application-Specific Features

### Media Player P2P Features

#### File Sharing
- Share videos, music, and media collections
- Automatic metadata extraction and tagging
- Support for various media formats with ASCII video conversion

#### Controls
- **X Button**: Share current media file
- **Y Button**: Toggle P2P features
- **L/R Buttons**: Browse shared media from other devices

#### Example Usage
```rust
// Share a video file
media_player.share_current_media(vec!["video".to_string(), "entertainment".to_string()])?;

// Browse shared files
let shared_files = media_player.browse_shared_files(vec!["music".to_string()]);

// Download a shared file
media_player.download_file("file_hash_123", "/local/path/video.mp4")?;
```

### Paint Program P2P Features

#### Collaborative Art Sessions
- Real-time collaborative drawing
- Multiple artists can work on the same canvas
- Vector-based artwork sharing for memory efficiency

#### Controls
- **X Button**: Share current artwork
- **Y Button**: Start/join collaborative session
- **L + R**: Export artwork to P2P network

#### Collaborative Session Example
```rust
// Start a collaborative art session
paint_app.start_collaboration_session("art_session_123".to_string()).await;

// Share current artwork
paint_app.share_artwork(vec!["digital_art".to_string(), "collaborative".to_string()])?;

// Join an existing session
paint_app.join_collaboration_session("existing_session_id".to_string()).await;
```

### Enhanced Input/Word Processor P2P Features

#### Document Sharing & Collaboration
- Real-time collaborative document editing
- Document version tracking and history
- Multi-user writing sessions with conflict resolution

#### P2P Modes

##### P2P Browser Mode
Navigate and download shared documents:
- **A Button**: Download/open selected document
- **X Button**: Share current document
- **Y Button**: Enter collaboration mode
- **UP/DOWN**: Browse available documents

##### Collaboration Mode
Real-time collaborative editing:
- **A Button**: Sync current changes
- **X Button**: View participant list
- **B/SELECT**: Exit collaboration mode

##### Document Saver Mode
Save and export documents:
- **A Button**: Save document locally
- **X Button**: Export to P2P network
- **Y Button**: Toggle auto-save

#### Example Usage
```rust
// Enable P2P for word processor
input_manager.enable_p2p("writer_device".to_string())?;

// Share current document
let result = input_manager.share_current_document();

// Start collaborative editing
input_manager.start_collaboration_session("doc_session_456".to_string()).await;

// Add collaborative changes
input_manager.add_collaborative_change(
    ChangeType::Insert, 
    cursor_position, 
    "new text".to_string()
);

// Sync changes
input_manager.sync_collaborative_changes();
```

## Technical Features

### Battery Optimization

The P2P system is specifically designed for handheld devices with limited battery:

- **32KB Chunk Transfers**: Efficient file transfer sizes
- **Automatic Cleanup**: Removes stale connections and temporary files
- **Smart Discovery**: Periodic device discovery with exponential backoff
- **Connection Pooling**: Reuses TCP connections when possible

### File Transfer Protocol

#### Chunked Transfer System
```rust
pub struct FileChunk {
    pub file_id: String,
    pub chunk_index: u32,
    pub total_chunks: u32,
    pub data: Vec<u8>,        // 32KB max
    pub checksum: String,     // SHA-256 verification
}
```

#### Transfer Process
1. **Discovery**: Sender announces file availability
2. **Request**: Receiver requests specific chunks
3. **Transfer**: 32KB chunks sent over TCP
4. **Verification**: SHA-256 checksum validation
5. **Assembly**: Chunks reassembled into complete file

### Device Types

The system supports different device types with automatic capability detection:

```rust
pub enum DeviceType {
    Anbernic(String),  // Model name (e.g., "RG353V", "word_processor")
    Desktop,           // Full computer
    Mobile,            // Phone/tablet
    Unknown,           // Unidentified device
}
```

### Message Types

P2P communication uses structured messages:

```rust
pub enum P2PMessage {
    Discovery { device_info: PeerDevice },
    FileShare { file_info: SharedFile, chunk_data: Option<Vec<u8>> },
    FileRequest { file_id: String, chunk_index: Option<u32> },
    FileList { files: Vec<SharedFile> },
    SearchRequest { query: String, file_types: Vec<String> },
    SearchResponse { results: Vec<SharedFile> },
    Heartbeat { device_id: String, battery_level: Option<u8> },
}
```

## Security & Privacy

### File Sharing Security
- **Hash Verification**: All files verified with SHA-256 checksums
- **Local Network Only**: P2P operates on local network segments
- **No Internet Transit**: Files never leave the local network
- **Device Authentication**: Basic device identification and filtering

### Privacy Features
- **Ephemeral Connections**: Connections close after transfers
- **No Persistent Storage**: Temporary files cleaned automatically
- **User Control**: Manual P2P enable/disable per application

## Troubleshooting

### Common Issues

#### P2P Not Connecting
1. Ensure devices are on the same network
2. Check firewall settings (ports 8080-8090)
3. Verify P2P is enabled on both devices
4. Try toggling P2P off and on

#### File Transfer Failures
1. Check available storage space
2. Verify file permissions
3. Ensure stable network connection
4. Check for file corruption (hash mismatch)

#### Collaboration Issues
1. Ensure all participants have P2P enabled
2. Check session ID matches across devices
3. Verify network stability
4. Try restarting collaboration session

### Debug Information

Get P2P status information:

```rust
// Media Player
let status = media_player.get_p2p_status().await;
println!("Peers: {}, Files: {}", status.peer_count, status.shared_files_count);

// Paint Program
let collab_info = paint_app.get_collaboration_info();
println!("Session: {}, Participants: {}", 
    collab_info.session_id, collab_info.participants.len());

// Word Processor
let p2p_status = input_manager.get_p2p_status().await;
println!("P2P Enabled: {}, Collaboration Active: {}", 
    p2p_status.enabled, p2p_status.collaboration_active);
```

## API Reference

### Core P2P Integration Trait

```rust
pub trait P2PIntegration {
    fn get_p2p_manager(&self) -> &P2PMeshManager;
    
    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>>;
    
    async fn search_shared_files(&self, query: String) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>>;
    
    async fn get_mesh_peers(&self) -> Vec<PeerDevice>;
}
```

### Shared File Structure

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFile {
    pub id: String,               // Unique file identifier
    pub filename: String,         // Original filename
    pub file_path: PathBuf,       // Local file path
    pub file_size: u64,          // Size in bytes
    pub file_hash: String,        // SHA-256 hash
    pub mime_type: String,        // MIME type
    pub shared_by: String,        // Creator device/user
    pub timestamp: u64,           // Unix timestamp
    pub description: Option<String>, // Optional description
    pub tags: Vec<String>,        // Searchable tags
}
```

### Device Information

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDevice {
    pub device_id: String,        // Unique device identifier
    pub device_name: String,      // Human-readable name
    pub ip_address: IpAddr,       // Network address (updated type)
    pub port: u16,               // TCP port
    pub last_seen: u64,          // Last contact timestamp
    pub battery_level: Option<u8>, // Battery percentage (handheld specific)
    pub device_type: DeviceType,  // Device category
    pub shared_files: Vec<SharedFile>, // Files shared by this device
}
```

### Device Type Classification

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Anbernic(String), // Model name (e.g., "RG353P", "Win600")
    Desktop,          // Desktop/laptop computers
    Mobile,          // Mobile phones and tablets
    Unknown,         // Unidentified device types
}
```

### Required Imports

```rust
use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use std::path::PathBuf;
```

## Performance Considerations

### Memory Usage
- **Chunk Size**: 32KB chunks minimize memory usage
- **Connection Limits**: Maximum 10 concurrent connections
- **File Caching**: LRU cache with 100MB limit
- **Metadata Storage**: Efficient in-memory indexing

### Network Efficiency
- **Discovery Interval**: 30-second device discovery broadcasts
- **Heartbeat**: 60-second keep-alive messages
- **Timeout Handling**: 30-second connection timeouts
- **Retry Logic**: Exponential backoff for failed transfers

### Battery Impact
- **Idle Power**: Minimal background power usage
- **Transfer Power**: Efficient chunk-based transfers
- **Sleep Mode**: P2P pauses during device sleep
- **Connection Pooling**: Reduces connection overhead

## Future Enhancements

### Planned Features
- **End-to-End Encryption**: Secure file transfers
- **Internet Relay**: P2P over internet through relay servers
- **Voice Chat**: Real-time voice communication during collaboration
- **Screen Sharing**: Share device screens with other participants
- **File Synchronization**: Automatic sync of document collections

### Performance Improvements
- **Compression**: File compression for faster transfers
- **Delta Sync**: Only transfer file changes for documents
- **Peer Caching**: Distributed file caching across peers
- **Bandwidth Adaptation**: Automatic speed adjustment based on network conditions

---

For more information about specific input configurations and controller mappings, see the [Enhanced Input System Documentation](enhanced-input-system.md).