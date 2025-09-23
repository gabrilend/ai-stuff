use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::RwLock;

/// AzerothCore-style MMO engine for Anbernic handhelds
/// Uses WotLK networking protocols without any Blizzard assets
/// Supports peer-to-peer swarm networking for massive scalability
#[derive(Debug, Clone)]
pub struct HandheldMMOEngine {
    pub world: Arc<RwLock<GameWorld>>,
    pub networking: NetworkManager,
    pub player: Player,
    pub session: Option<GameSession>,
}

/// Open-source game world with procedural generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameWorld {
    pub maps: HashMap<u32, GameMap>,
    pub players: HashMap<u64, PlayerState>,
    pub objects: HashMap<u64, GameObject>,
    pub version: u32,
    pub server_info: ServerInfo,
}

/// WotLK-style map structure (no Blizzard assets)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameMap {
    pub id: u32,
    pub name: String,
    pub size_x: u32,
    pub size_y: u32,
    pub height_map: Vec<Vec<f32>>, // Terrain elevation
    pub texture_map: Vec<Vec<u8>>, // Ground textures (0-15)
    pub objects: Vec<MapObject>,   // Trees, rocks, buildings
    pub spawn_points: Vec<Position3D>,
    pub safe_zones: Vec<SafeZone>,
    pub tilemap_2d: Option<TileMap2D>, // GBA-style 2D version
}

/// Game Boy Advance style 2D tilemap system
/// "Moving up/down moves the background behind you"
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TileMap2D {
    pub width: u32,
    pub height: u32,
    pub tiles: Vec<Vec<TileType>>,
    pub background_layers: Vec<BackgroundLayer>,
    pub scroll_offset_x: f32,
    pub scroll_offset_y: f32,
    pub zone_name: String,
    pub loop_boundaries: LoopBoundaries,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackgroundLayer {
    pub name: String,
    pub tiles: Vec<Vec<char>>, // ASCII representation
    pub scroll_speed: f32,     // Parallax scrolling speed
    pub repeats: bool,         // Does this layer loop?
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TileType {
    Grass,
    Stone,
    Water,
    Tree,
    Mountain,
    Path,
    Building,
    Bridge,
    Sand,
    Snow,
    Lava,
    Portal,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoopBoundaries {
    pub north_edge: u32,
    pub south_edge: u32,
    pub east_edge: u32,
    pub west_edge: u32,
    pub loop_warning_distance: u32, // "better stop for the night" distance
}

/// 2D position for retro RPG movement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position2D {
    pub x: f32,
    pub y: f32,
    pub facing: Direction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Direction {
    North,
    South,
    East,
    West,
    NorthEast,
    NorthWest,
    SouthEast,
    SouthWest,
}

/// Player state synchronized across network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerState {
    pub guid: u64,
    pub name: String,
    pub position: Position3D,
    pub position_2d: Position2D, // For 2D WoW mode
    pub rotation: f32,
    pub level: u8,
    pub health: u32,
    pub mana: u32,
    pub stats: PlayerStats,
    pub equipment: Vec<Item>,
    pub spells: Vec<Spell>,
    pub last_update: u64,
    pub view_mode: ViewMode, // 2D or 3D mode
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ViewMode {
    Classic3D, // Original 3D MMO view
    Retro2D,   // GBA-style 2D view
    Hybrid,    // Both views available
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub map_id: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerStats {
    pub strength: u16,
    pub agility: u16,
    pub intellect: u16,
    pub stamina: u16,
    pub spirit: u16,
}

/// Game objects (NPCs, items, etc.)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameObject {
    pub guid: u64,
    pub object_type: ObjectType,
    pub position: Position3D,
    pub properties: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ObjectType {
    Player,
    NPC,
    Item,
    Chest,
    Door,
    Teleporter,
    Custom(String),
}

/// AzerothCore-compatible networking
#[derive(Debug, Clone)]
pub struct NetworkManager {
    pub session_key: Option<[u8; 40]>,
    pub auth_server: Option<SocketAddr>,
    pub world_server: Option<SocketAddr>,
    pub peers: Arc<RwLock<HashMap<u64, PeerConnection>>>,
    pub packet_handlers: HashMap<OpCode, PacketHandler>,
    pub party_mode: Option<WiFiPartyManager>,
}

/// WiFi Party Mode - Local hotspot gaming without internet
/// Perfect for Anbernic devices connecting to a laptop hotspot
#[derive(Debug, Clone)]
pub struct WiFiPartyManager {
    pub host_device: String, // Device ID of the laptop host
    pub connected_devices: HashMap<String, PartyDevice>,
    pub shared_mailbox: PathBuf, // Shared folder for file-based sync
    pub party_name: String,      // "Living Room MMO Party"
    pub discovery_enabled: bool,
    pub auto_sync_interval: u64, // Seconds between mailbox checks
}

/// Device in the WiFi party
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PartyDevice {
    pub device_id: String,   // "anbernic_rg35xx_001"
    pub device_name: String, // "Player 1's Handheld"
    pub device_type: DeviceType,
    pub last_seen: DateTime<Utc>,
    pub mailbox_path: PathBuf, // device-specific folder
    pub battery_level: Option<u8>,
    pub player_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    AnbernicRG35XX,
    AnbernicRG405M,
    AnbernicRG503,
    LaptopHost,
    AndroidDevice,
    LinuxHandheld,
}

/// File-based message for device synchronization
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PartyMessage {
    pub from_device: String,
    pub to_device: Option<String>, // None = broadcast to all
    pub message_type: PartyMessageType,
    pub content: Vec<u8>,
    pub timestamp: DateTime<Utc>,
    pub message_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PartyMessageType {
    PlayerJoined,
    PlayerLeft,
    WorldUpdate,
    ChatMessage,
    GameInvite,
    BatteryUpdate,
    DiscoveryPing,
    FileTransfer,
}

/// WotLK-style packet system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GamePacket {
    pub opcode: OpCode,
    pub size: u16,
    pub data: Vec<u8>,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum OpCode {
    // Auth packets
    AUTH_LOGON_CHALLENGE = 0x00,
    AUTH_LOGON_PROOF = 0x01,

    // World packets
    CMSG_PLAYER_LOGIN = 0x3D,
    SMSG_LOGIN_VERIFY_WORLD = 0x236,
    MSG_MOVE_START_FORWARD = 0xB5,
    MSG_MOVE_STOP = 0xB7,
    SMSG_UPDATE_OBJECT = 0xA9,

    // Custom peer-to-peer packets
    P2P_WORLD_STATE_SYNC = 0x8000,
    P2P_PLAYER_UPDATE = 0x8001,
    P2P_OBJECT_SPAWN = 0x8002,
    P2P_SWARM_ANNOUNCE = 0x8003,
}

type PacketHandler = fn(&mut HandheldMMOEngine, &GamePacket) -> Result<(), MMOError>;

/// Peer-to-peer connection for swarm networking
#[derive(Debug, Clone)]
pub struct PeerConnection {
    pub peer_id: u64,
    pub address: SocketAddr,
    pub last_seen: u64,
    pub reputation: u8,     // Trust score (0-255)
    pub world_version: u32, // Version synchronization
}

/// Game session state
#[derive(Debug, Clone)]
pub struct GameSession {
    pub session_id: u64,
    pub account_id: u64,
    pub character_guid: u64,
    pub world_server: SocketAddr,
    pub connected_at: u64,
    pub last_ping: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Player {
    pub state: PlayerState,
    pub input: InputState,
    pub camera: Camera,
    pub ui_state: UIState,
}

/// Anbernic input mapping for MMO controls
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputState {
    pub movement: MovementInput,
    pub actions: ActionInput,
    pub camera_mode: CameraMode,
    pub target_guid: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MovementInput {
    pub forward: bool,
    pub backward: bool,
    pub strafe_left: bool,
    pub strafe_right: bool,
    pub turn_left: bool,
    pub turn_right: bool,
    pub jump: bool,
    pub run: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionInput {
    pub auto_attack: bool,
    pub cast_spell: Option<u32>, // Spell ID
    pub use_item: Option<u32>,   // Item slot
    pub interact: bool,
    pub chat_mode: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CameraMode {
    ThirdPerson,
    FirstPerson,
    TopDown,   // Good for small screens
    Isometric, // Classic RPG view
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Camera {
    pub position: Position3D,
    pub target: Position3D,
    pub distance: f32,
    pub angle_horizontal: f32,
    pub angle_vertical: f32,
    pub mode: CameraMode,
}

/// ASCII-based UI for Anbernic constraints
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UIState {
    pub show_health_bar: bool,
    pub show_minimap: bool,
    pub show_chat: bool,
    pub show_inventory: bool,
    pub chat_messages: Vec<ChatMessage>,
    pub target_info: Option<TargetFrame>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub sender: String,
    pub message: String,
    pub timestamp: u64,
    pub channel: ChatChannel,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ChatChannel {
    Say,
    Yell,
    Guild,
    Party,
    Whisper,
    System,
    P2P, // Peer-to-peer channel
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TargetFrame {
    pub name: String,
    pub level: u8,
    pub health_percent: u8,
    pub object_type: ObjectType,
}

#[derive(Debug, thiserror::Error)]
pub enum MMOError {
    #[error("Network error: {0}")]
    Network(String),
    #[error("Protocol error: {0}")]
    Protocol(String),
    #[error("Authentication failed")]
    AuthFailed,
    #[error("World server unavailable")]
    WorldUnavailable,
    #[error("Peer connection failed: {0}")]
    PeerFailed(String),
}

impl HandheldMMOEngine {
    pub fn new() -> Self {
        let world = Arc::new(RwLock::new(GameWorld::new()));
        let networking = NetworkManager::new();
        let player = Player::new();

        Self {
            world,
            networking,
            player,
            session: None,
        }
    }

    /// Connect to AzerothCore server (desktop)
    pub async fn connect_to_server(&mut self, auth_server: SocketAddr) -> Result<(), MMOError> {
        self.networking.auth_server = Some(auth_server);

        // Send authentication challenge
        let auth_packet = GamePacket {
            opcode: OpCode::AUTH_LOGON_CHALLENGE,
            size: 0,
            data: vec![],
            timestamp: chrono::Utc::now().timestamp() as u64,
        };

        // In real implementation, this would handle SRP6 authentication
        self.send_packet(&auth_packet).await?;

        Ok(())
    }

    /// Join peer-to-peer swarm network
    pub async fn join_p2p_swarm(
        &mut self,
        bootstrap_peers: Vec<SocketAddr>,
    ) -> Result<(), MMOError> {
        for peer_addr in bootstrap_peers {
            let peer_id = self.generate_peer_id(&peer_addr);
            let peer = PeerConnection {
                peer_id,
                address: peer_addr,
                last_seen: chrono::Utc::now().timestamp() as u64,
                reputation: 128, // Neutral reputation
                world_version: 0,
            };

            self.networking.peers.write().await.insert(peer_id, peer);

            // Announce ourselves to the swarm
            let announce_packet = GamePacket {
                opcode: OpCode::P2P_SWARM_ANNOUNCE,
                size: 0,
                data: serde_json::to_vec(&self.player.state).unwrap_or_default(),
                timestamp: chrono::Utc::now().timestamp() as u64,
            };

            self.broadcast_to_peers(&announce_packet).await?;
        }

        Ok(())
    }

    /// Process Anbernic input and generate movement
    pub async fn handle_input(&mut self, input: InputState) -> Result<(), MMOError> {
        let old_position = self.player.state.position.clone();

        // Update movement based on input
        if input.movement.forward {
            self.player.state.position.x += (self.player.state.rotation.cos() * 0.1);
            self.player.state.position.y += (self.player.state.rotation.sin() * 0.1);
        }

        if input.movement.backward {
            self.player.state.position.x -= (self.player.state.rotation.cos() * 0.1);
            self.player.state.position.y -= (self.player.state.rotation.sin() * 0.1);
        }

        if input.movement.turn_left {
            self.player.state.rotation -= 0.1;
        }

        if input.movement.turn_right {
            self.player.state.rotation += 0.1;
        }

        // Send movement update if position changed
        if old_position.x != self.player.state.position.x
            || old_position.y != self.player.state.position.y
        {
            let move_packet = GamePacket {
                opcode: OpCode::MSG_MOVE_START_FORWARD,
                size: 0,
                data: serde_json::to_vec(&self.player.state.position).unwrap_or_default(),
                timestamp: chrono::Utc::now().timestamp() as u64,
            };

            self.send_packet(&move_packet).await?;
            self.broadcast_to_peers(&move_packet).await?;
        }

        self.player.input = input;
        Ok(())
    }

    /// Render game world in ASCII for Anbernic display
    pub async fn render_ascii(&self) -> String {
        let mut output = String::new();
        let world = self.world.read().await;

        // Get current map
        let current_map = world.maps.get(&self.player.state.position.map_id);

        // ASCII mini-map view (perfect for Anbernic screens)
        output.push_str("┌─────────── WORLD ────────────┐\n");

        if let Some(map) = current_map {
            // Simple top-down view
            let player_x = (self.player.state.position.x / 10.0) as usize;
            let player_y = (self.player.state.position.y / 10.0) as usize;

            for y in player_y.saturating_sub(5)..=(player_y + 5).min(map.size_y as usize) {
                output.push('│');
                for x in player_x.saturating_sub(15)..=(player_x + 15).min(map.size_x as usize) {
                    if x == player_x && y == player_y {
                        output.push('@'); // Player character
                    } else {
                        // Terrain based on height
                        let height = map
                            .height_map
                            .get(y)
                            .and_then(|row| row.get(x))
                            .unwrap_or(&0.0);
                        let terrain_char = match *height {
                            h if h < 0.2 => '~', // Water
                            h if h < 0.4 => '.', // Plains
                            h if h < 0.6 => '^', // Hills
                            _ => '▲',            // Mountains
                        };
                        output.push(terrain_char);
                    }
                }
                output.push_str("│\n");
            }
        } else {
            output.push_str("│         No map loaded        │\n");
        }

        output.push_str("└──────────────────────────────┘\n");

        // Player info
        output.push_str(&format!(
            "Player: {} (Level {})\n",
            self.player.state.name, self.player.state.level
        ));
        output.push_str(&format!(
            "Position: ({:.1}, {:.1}, {:.1})\n",
            self.player.state.position.x,
            self.player.state.position.y,
            self.player.state.position.z
        ));
        output.push_str(&format!(
            "Health: {}/{} | Mana: {}/{}\n",
            self.player.state.health, 1000, self.player.state.mana, 500
        ));

        // Network status
        let peer_count = self.networking.peers.read().await.len();
        output.push_str(&format!("Network: {} peers connected\n", peer_count));

        // Controls help
        output.push_str("\n🎮 Controls:\n");
        output.push_str("  WASD: Move | QE: Turn | Space: Jump\n");
        output.push_str("  1-8: Spells | I: Inventory | T: Chat\n");

        output
    }

    /// Render 2D World of Warcraft - Game Boy Advance style!
    /// "Moving up/down moves the background behind you"
    pub async fn render_2d_wow(&self) -> String {
        let mut output = String::new();
        let world = self.world.read().await;

        // Get current map and its 2D tilemap
        if let Some(map) = world.maps.get(&0) {
            // Use map ID 0 for now
            if let Some(tilemap) = &map.tilemap_2d {
                output.push_str(&format!("╔══════════ {} ══════════╗\n", tilemap.zone_name));

                // Check for world loop warning
                let distance_to_edge = self.calculate_distance_to_loop_edge(tilemap);
                if distance_to_edge < tilemap.loop_boundaries.loop_warning_distance {
                    output.push_str("🌅 \"Oh she's looped around, better stop for the night\"\n");
                }

                // Render parallax background layers (far to near)
                for (layer_idx, layer) in tilemap.background_layers.iter().rev().enumerate() {
                    if layer_idx == 0 {
                        output.push_str("║"); // Border

                        // Far background layer with parallax
                        let bg_scroll_x =
                            (self.player.state.position_2d.x * layer.scroll_speed) as usize;
                        let bg_scroll_y =
                            (self.player.state.position_2d.y * layer.scroll_speed) as usize;

                        // Render one line of background
                        for x in 0..28 {
                            // Anbernic screen width
                            let tile_x = (bg_scroll_x + x) % layer.tiles[0].len();
                            let tile_y = bg_scroll_y % layer.tiles.len();
                            let bg_char = layer
                                .tiles
                                .get(tile_y)
                                .and_then(|row| row.get(tile_x))
                                .unwrap_or(&' ');
                            output.push(*bg_char);
                        }
                        output.push_str("║\n");
                    }
                }

                // Main gameplay area with character
                let player_x = self.player.state.position_2d.x as usize;
                let player_y = self.player.state.position_2d.y as usize;
                let view_height = 12; // GBA-style viewport

                for screen_y in 0..view_height {
                    output.push_str("║");

                    // Calculate world coordinates
                    let world_y = player_y + screen_y;

                    for screen_x in 0..28 {
                        let world_x = player_x.saturating_sub(14) + screen_x; // Center player

                        // Check if this is the player position
                        if screen_x == 14 && screen_y == 6 {
                            // Player in center
                            let player_char = match self.player.state.position_2d.facing {
                                Direction::North => '▲',
                                Direction::South => '▼',
                                Direction::East => '►',
                                Direction::West => '◄',
                                Direction::NorthEast => '◥',
                                Direction::NorthWest => '◤',
                                Direction::SouthEast => '◢',
                                Direction::SouthWest => '◣',
                            };
                            output.push(player_char);
                        } else {
                            // Render world tile
                            let tile = if world_y < tilemap.tiles.len()
                                && world_x < tilemap.tiles[0].len()
                            {
                                &tilemap.tiles[world_y][world_x]
                            } else {
                                &TileType::Grass // Default
                            };

                            let tile_char = match tile {
                                TileType::Grass => '.',
                                TileType::Stone => '▓',
                                TileType::Water => '~',
                                TileType::Tree => '🌲',
                                TileType::Mountain => '▲',
                                TileType::Path => '=',
                                TileType::Building => '⌂',
                                TileType::Bridge => '|',
                                TileType::Sand => '∴',
                                TileType::Snow => '*',
                                TileType::Lava => '≋',
                                TileType::Portal => '◯',
                            };
                            output.push(tile_char);
                        }
                    }
                    output.push_str("║\n");
                }

                output.push_str("╚══════════════════════════════╝\n");

                // 2D-specific status
                output.push_str(&format!(
                    "📍 Zone: {} | Pos: ({:.1}, {:.1})\n",
                    tilemap.zone_name,
                    self.player.state.position_2d.x,
                    self.player.state.position_2d.y
                ));

                output.push_str(&format!(
                    "👀 Facing: {:?} | Scroll: ({:.1}, {:.1})\n",
                    self.player.state.position_2d.facing,
                    tilemap.scroll_offset_x,
                    tilemap.scroll_offset_y
                ));

                if distance_to_edge < tilemap.loop_boundaries.loop_warning_distance {
                    output.push_str(&format!("⚠️  World edge in {} tiles\n", distance_to_edge));
                }
            } else {
                output.push_str("╔══════════ NO 2D MAP ══════════╗\n");
                output.push_str("║  This zone doesn't have a     ║\n");
                output.push_str("║  2D tilemap version yet!      ║\n");
                output.push_str("║  Try 'toggle3d' to switch     ║\n");
                output.push_str("╚══════════════════════════════╝\n");
            }
        }

        output.push_str("\n🎮 2D Controls:\n");
        output.push_str("  ↑↓: Move background | ←→: Strafe | Enter: Interact\n");
        output.push_str("  Space: Jump | F: Face direction | V: Toggle view\n");

        output
    }

    /// Calculate distance to nearest world loop edge
    pub fn calculate_distance_to_loop_edge(&self, tilemap: &TileMap2D) -> u32 {
        let player_x = self.player.state.position_2d.x as u32;
        let player_y = self.player.state.position_2d.y as u32;

        let distances = vec![
            player_y.saturating_sub(tilemap.loop_boundaries.north_edge),
            tilemap.loop_boundaries.south_edge.saturating_sub(player_y),
            player_x.saturating_sub(tilemap.loop_boundaries.west_edge),
            tilemap.loop_boundaries.east_edge.saturating_sub(player_x),
        ];

        *distances.iter().min().unwrap_or(&u32::MAX)
    }

    /// Handle 2D movement with background scrolling
    pub async fn handle_2d_movement(&mut self, direction: Direction) -> Result<(), MMOError> {
        let move_speed = 1.0;
        let old_pos = self.player.state.position_2d.clone();

        // Update position based on direction
        match direction {
            Direction::North => {
                self.player.state.position_2d.y -= move_speed;
                self.player.state.position_2d.facing = Direction::North;
            }
            Direction::South => {
                self.player.state.position_2d.y += move_speed;
                self.player.state.position_2d.facing = Direction::South;
            }
            Direction::East => {
                self.player.state.position_2d.x += move_speed;
                self.player.state.position_2d.facing = Direction::East;
            }
            Direction::West => {
                self.player.state.position_2d.x -= move_speed;
                self.player.state.position_2d.facing = Direction::West;
            }
            _ => {} // Diagonal movement
        }

        // Update world map if available
        let mut world = self.world.write().await;
        if let Some(map) = world.maps.get_mut(&0) {
            if let Some(tilemap) = &mut map.tilemap_2d {
                // Update scroll offsets for parallax background
                let delta_x = self.player.state.position_2d.x - old_pos.x;
                let delta_y = self.player.state.position_2d.y - old_pos.y;

                tilemap.scroll_offset_x += delta_x;
                tilemap.scroll_offset_y += delta_y;

                // Handle world looping
                if self.player.state.position_2d.x < 0.0 {
                    self.player.state.position_2d.x = tilemap.width as f32 - 1.0;
                    tilemap.scroll_offset_x = tilemap.width as f32 - 1.0;
                } else if self.player.state.position_2d.x >= tilemap.width as f32 {
                    self.player.state.position_2d.x = 0.0;
                    tilemap.scroll_offset_x = 0.0;
                }

                if self.player.state.position_2d.y < 0.0 {
                    self.player.state.position_2d.y = tilemap.height as f32 - 1.0;
                    tilemap.scroll_offset_y = tilemap.height as f32 - 1.0;
                } else if self.player.state.position_2d.y >= tilemap.height as f32 {
                    self.player.state.position_2d.y = 0.0;
                    tilemap.scroll_offset_y = 0.0;
                }
            }
        }

        Ok(())
    }

    async fn send_packet(&self, packet: &GamePacket) -> Result<(), MMOError> {
        // In real implementation, this would send to auth/world server
        println!("📤 Sending packet: {:?}", packet.opcode);
        Ok(())
    }

    async fn broadcast_to_peers(&self, packet: &GamePacket) -> Result<(), MMOError> {
        let peers = self.networking.peers.read().await;
        println!(
            "📡 Broadcasting to {} peers: {:?}",
            peers.len(),
            packet.opcode
        );
        Ok(())
    }

    fn generate_peer_id(&self, addr: &SocketAddr) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        addr.hash(&mut hasher);
        hasher.finish()
    }

    /// WiFi Party Mode - Create local hotspot gaming session
    /// Perfect for Anbernic devices connecting to laptop without router
    pub async fn start_wifi_party(
        &mut self,
        party_name: String,
        mailbox_path: PathBuf,
    ) -> Result<(), MMOError> {
        // Create shared mailbox directory structure
        let party_mailbox = mailbox_path.join("wifi_party");
        fs::create_dir_all(&party_mailbox)
            .map_err(|e| MMOError::Network(format!("Failed to create mailbox: {}", e)))?;

        // Create device-specific directories
        fs::create_dir_all(party_mailbox.join("devices"))
            .map_err(|e| MMOError::Network(format!("Failed to create devices dir: {}", e)))?;
        fs::create_dir_all(party_mailbox.join("messages"))
            .map_err(|e| MMOError::Network(format!("Failed to create messages dir: {}", e)))?;
        fs::create_dir_all(party_mailbox.join("world_sync"))
            .map_err(|e| MMOError::Network(format!("Failed to create world_sync dir: {}", e)))?;

        // Determine device type and ID
        let device_id = self.get_device_id();
        let device_type = self.detect_device_type();

        let party_manager = WiFiPartyManager {
            host_device: device_id.clone(),
            connected_devices: HashMap::new(),
            shared_mailbox: party_mailbox.clone(),
            party_name: party_name.clone(),
            discovery_enabled: true,
            auto_sync_interval: 2, // Check every 2 seconds
        };

        self.networking.party_mode = Some(party_manager);

        // Announce this device to the party
        self.announce_to_party(device_id, device_type).await?;

        println!("📡 WiFi Party '{}' started!", party_name);
        println!("   Mailbox: {}", party_mailbox.display());
        println!("   Other Anbernic devices can now join by connecting to the same WiFi!");

        Ok(())
    }

    /// Join existing WiFi party
    pub async fn join_wifi_party(&mut self, mailbox_path: PathBuf) -> Result<(), MMOError> {
        let party_mailbox = mailbox_path.join("wifi_party");

        if !party_mailbox.exists() {
            return Err(MMOError::Network(
                "No WiFi party found in this location".to_string(),
            ));
        }

        // Read party info to get party name
        let party_name = self
            .discover_party_name(&party_mailbox)
            .await
            .unwrap_or_else(|| "Unnamed Party".to_string());

        let device_id = self.get_device_id();
        let device_type = self.detect_device_type();

        let party_manager = WiFiPartyManager {
            host_device: "unknown".to_string(),
            connected_devices: HashMap::new(),
            shared_mailbox: party_mailbox.clone(),
            party_name: party_name.clone(),
            discovery_enabled: true,
            auto_sync_interval: 2,
        };

        self.networking.party_mode = Some(party_manager);

        // Announce joining
        self.announce_to_party(device_id, device_type).await?;

        println!("🎮 Joined WiFi party '{}'!", party_name);
        println!("   Looking for other players...");

        Ok(())
    }

    /// Send message through file-based mailbox system
    pub async fn send_party_message(
        &self,
        message_type: PartyMessageType,
        content: Vec<u8>,
        to_device: Option<String>,
    ) -> Result<(), MMOError> {
        if let Some(party) = &self.networking.party_mode {
            let device_id = self.get_device_id();
            let message = PartyMessage {
                from_device: device_id.clone(),
                to_device,
                message_type,
                content,
                timestamp: Utc::now(),
                message_id: format!("{}_{}", device_id, Utc::now().timestamp_millis()),
            };

            let message_json = serde_json::to_string(&message)
                .map_err(|e| MMOError::Network(format!("Failed to serialize message: {}", e)))?;

            let message_file = party
                .shared_mailbox
                .join("messages")
                .join(format!("{}.json", message.message_id));

            fs::write(&message_file, message_json)
                .map_err(|e| MMOError::Network(format!("Failed to write message: {}", e)))?;

            Ok(())
        } else {
            Err(MMOError::Network("Not in WiFi party mode".to_string()))
        }
    }

    /// Check mailbox for new messages (like checking Facebook Messenger, but simpler)
    pub async fn check_party_mailbox(&mut self) -> Result<Vec<PartyMessage>, MMOError> {
        if let Some(party) = &self.networking.party_mode.clone() {
            let messages_dir = party.shared_mailbox.join("messages");
            let mut new_messages = Vec::new();
            let device_id = self.get_device_id();

            if let Ok(entries) = fs::read_dir(&messages_dir) {
                for entry in entries.flatten() {
                    if let Ok(content) = fs::read_to_string(entry.path()) {
                        if let Ok(message) = serde_json::from_str::<PartyMessage>(&content) {
                            // Only process messages not from ourselves and newer than 30 seconds
                            if message.from_device != device_id
                                && (Utc::now() - message.timestamp).num_seconds() < 30
                            {
                                // Check if it's for us specifically or broadcast
                                if message.to_device.is_none()
                                    || message.to_device.as_ref() == Some(&device_id)
                                {
                                    new_messages.push(message);
                                }
                            }
                        }
                    }
                }
            }

            Ok(new_messages)
        } else {
            Err(MMOError::Network("Not in WiFi party mode".to_string()))
        }
    }

    /// Sync world state with other party devices
    pub async fn sync_party_world(&mut self) -> Result<(), MMOError> {
        if let Some(_party) = &self.networking.party_mode.clone() {
            let world_data = {
                let world = self.world.read().await;
                serde_json::to_vec(&*world)
                    .map_err(|e| MMOError::Network(format!("Failed to serialize world: {}", e)))?
            };

            self.send_party_message(PartyMessageType::WorldUpdate, world_data, None)
                .await?;

            Ok(())
        } else {
            Err(MMOError::Network("Not in WiFi party mode".to_string()))
        }
    }

    /// Auto-discovery and device listing for party
    pub async fn list_party_devices(&self) -> Result<Vec<PartyDevice>, MMOError> {
        if let Some(party) = &self.networking.party_mode {
            let devices_dir = party.shared_mailbox.join("devices");
            let mut devices = Vec::new();

            if let Ok(entries) = fs::read_dir(&devices_dir) {
                for entry in entries.flatten() {
                    if entry.path().extension().and_then(|s| s.to_str()) == Some("json") {
                        if let Ok(content) = fs::read_to_string(entry.path()) {
                            if let Ok(device) = serde_json::from_str::<PartyDevice>(&content) {
                                // Only include devices seen in last 60 seconds
                                if (Utc::now() - device.last_seen).num_seconds() < 60 {
                                    devices.push(device);
                                }
                            }
                        }
                    }
                }
            }

            Ok(devices)
        } else {
            Err(MMOError::Network("Not in WiFi party mode".to_string()))
        }
    }

    // Helper methods for WiFi party mode

    fn get_device_id(&self) -> String {
        // Generate unique device ID for each process/instance
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        // In real implementation, would use MAC address or hardware serial
        // For testing, use USER + process ID + timestamp to ensure uniqueness
        std::env::var("USER")
            .unwrap_or_else(|_| "anbernic_user".to_string())
            .hash(&mut hasher);
        std::process::id().hash(&mut hasher);
        chrono::Utc::now().timestamp_millis().hash(&mut hasher);
        let hash = hasher.finish();

        format!("anbernic_{:x}", hash & 0xFFFFFF)
    }

    fn detect_device_type(&self) -> DeviceType {
        // In real implementation, would detect actual Anbernic model
        if std::env::var("ANDROID_ROOT").is_ok() {
            DeviceType::AndroidDevice
        } else if std::path::Path::new("/sys/class/power_supply/battery").exists() {
            DeviceType::AnbernicRG35XX // Default handheld
        } else {
            DeviceType::LaptopHost
        }
    }

    async fn announce_to_party(
        &self,
        device_id: String,
        device_type: DeviceType,
    ) -> Result<(), MMOError> {
        if let Some(party) = &self.networking.party_mode {
            let device = PartyDevice {
                device_id: device_id.clone(),
                device_name: format!(
                    "Player {}",
                    device_id.chars().rev().take(3).collect::<String>()
                ),
                device_type,
                last_seen: Utc::now(),
                mailbox_path: party.shared_mailbox.join("devices").join(&device_id),
                battery_level: self.get_battery_level(),
                player_name: self.player.state.name.clone(),
            };

            let device_json = serde_json::to_string(&device)
                .map_err(|e| MMOError::Network(format!("Failed to serialize device: {}", e)))?;

            let device_file = party
                .shared_mailbox
                .join("devices")
                .join(format!("{}.json", device_id));

            fs::write(&device_file, device_json)
                .map_err(|e| MMOError::Network(format!("Failed to write device info: {}", e)))?;

            // Send join message
            let join_data = serde_json::to_vec(&device)
                .map_err(|e| MMOError::Network(format!("Failed to serialize join data: {}", e)))?;

            self.send_party_message(PartyMessageType::PlayerJoined, join_data, None)
                .await?;
        }

        Ok(())
    }

    async fn discover_party_name(&self, party_mailbox: &Path) -> Option<String> {
        // Look for party info file or derive from device names
        if let Ok(entries) = fs::read_dir(party_mailbox.join("devices")) {
            for entry in entries.flatten() {
                if let Ok(content) = fs::read_to_string(entry.path()) {
                    if let Ok(device) = serde_json::from_str::<PartyDevice>(&content) {
                        if matches!(device.device_type, DeviceType::LaptopHost) {
                            return Some(format!("{}'s Party", device.player_name));
                        }
                    }
                }
            }
        }
        None
    }

    fn get_battery_level(&self) -> Option<u8> {
        // Read battery level from system
        if let Ok(battery_path) = std::fs::read_to_string("/sys/class/power_supply/BAT0/capacity") {
            battery_path.trim().parse().ok()
        } else if let Ok(battery_path) =
            std::fs::read_to_string("/sys/class/power_supply/battery/capacity")
        {
            battery_path.trim().parse().ok()
        } else {
            None
        }
    }
}

impl GameWorld {
    pub fn new() -> Self {
        let mut world = Self {
            maps: HashMap::new(),
            players: HashMap::new(),
            objects: HashMap::new(),
            version: 1,
            server_info: ServerInfo::default(),
        };

        // Generate a starter map
        world.maps.insert(0, GameMap::generate_starter_map());
        world
    }
}

impl GameMap {
    /// Generate procedural map (no Blizzard assets needed)
    pub fn generate_starter_map() -> Self {
        let size = 100;
        let mut height_map = vec![vec![0.0; size]; size];
        let mut texture_map = vec![vec![0; size]; size];

        // Simple perlin-style noise for terrain
        for y in 0..size {
            for x in 0..size {
                let height = (((x as f32 * 0.1).sin() + (y as f32 * 0.1).cos()) * 0.3
                    + ((x as f32 * 0.05).sin() * (y as f32 * 0.05).cos()) * 0.5
                    + 0.5)
                    .clamp(0.0, 1.0);

                height_map[y][x] = height;

                // Texture based on height
                texture_map[y][x] = if height < 0.3 {
                    1 // Water texture
                } else if height < 0.6 {
                    2 // Grass texture
                } else {
                    3 // Rock texture
                };
            }
        }

        // Generate 2D tilemap version
        let tilemap_2d = Self::generate_2d_tilemap(&height_map, size);

        Self {
            id: 0,
            name: "Starter Valley".to_string(),
            size_x: size as u32,
            size_y: size as u32,
            height_map,
            texture_map,
            objects: vec![],
            spawn_points: vec![Position3D {
                x: 50.0,
                y: 50.0,
                z: 10.0,
                map_id: 0,
            }],
            safe_zones: vec![],
            tilemap_2d: Some(tilemap_2d),
        }
    }

    /// Generate Game Boy Advance style 2D tilemap from height data
    fn generate_2d_tilemap(height_map: &Vec<Vec<f32>>, size: usize) -> TileMap2D {
        let mut tiles = vec![vec![TileType::Grass; size]; size];

        // Convert 3D height map to 2D tiles
        for y in 0..size {
            for x in 0..size {
                let height = height_map[y][x];
                tiles[y][x] = match height {
                    h if h < 0.2 => TileType::Water,
                    h if h < 0.3 => TileType::Sand,
                    h if h < 0.5 => TileType::Grass,
                    h if h < 0.6 => TileType::Tree,
                    h if h < 0.8 => TileType::Stone,
                    _ => TileType::Mountain,
                };

                // Add some paths
                if (x + y) % 10 == 0 && height > 0.3 && height < 0.7 {
                    tiles[y][x] = TileType::Path;
                }

                // Add occasional buildings
                if x % 25 == 0 && y % 25 == 0 && height > 0.4 && height < 0.6 {
                    tiles[y][x] = TileType::Building;
                }
            }
        }

        // Create parallax background layers
        let mut background_layers = vec![];

        // Far mountains layer
        let mut mountain_layer = vec![vec![' '; 64]; 16];
        for y in 0..16 {
            for x in 0..64 {
                if (x + y * 3) % 8 == 0 {
                    mountain_layer[y][x] = '^';
                } else if (x + y * 2) % 12 == 0 {
                    mountain_layer[y][x] = '▲';
                }
            }
        }

        background_layers.push(BackgroundLayer {
            name: "Far Mountains".to_string(),
            tiles: mountain_layer,
            scroll_speed: 0.1, // Slow parallax
            repeats: true,
        });

        // Cloud layer
        let mut cloud_layer = vec![vec![' '; 32]; 8];
        for y in 0..8 {
            for x in 0..32 {
                if (x * 3 + y * 5) % 15 == 0 {
                    cloud_layer[y][x] = '☁';
                } else if (x * 2 + y * 3) % 20 == 0 {
                    cloud_layer[y][x] = '⛅';
                }
            }
        }

        background_layers.push(BackgroundLayer {
            name: "Clouds".to_string(),
            tiles: cloud_layer,
            scroll_speed: 0.05, // Very slow
            repeats: true,
        });

        TileMap2D {
            width: size as u32,
            height: size as u32,
            tiles,
            background_layers,
            scroll_offset_x: 0.0,
            scroll_offset_y: 0.0,
            zone_name: "Starter Valley - 2D".to_string(),
            loop_boundaries: LoopBoundaries {
                north_edge: 5,
                south_edge: size as u32 - 5,
                east_edge: size as u32 - 5,
                west_edge: 5,
                loop_warning_distance: 10, // "better stop for the night" warning
            },
        }
    }
}

impl Player {
    pub fn new() -> Self {
        Self {
            state: PlayerState {
                guid: chrono::Utc::now().timestamp() as u64,
                name: "Anbernic_Player".to_string(),
                position: Position3D {
                    x: 50.0,
                    y: 50.0,
                    z: 10.0,
                    map_id: 0,
                },
                position_2d: Position2D {
                    x: 15.0,
                    y: 10.0,
                    facing: Direction::South,
                },
                rotation: 0.0,
                level: 1,
                health: 100,
                mana: 50,
                stats: PlayerStats {
                    strength: 10,
                    agility: 10,
                    intellect: 10,
                    stamina: 10,
                    spirit: 10,
                },
                equipment: vec![],
                spells: vec![],
                last_update: chrono::Utc::now().timestamp() as u64,
                view_mode: ViewMode::Retro2D, // Default to 2D WoW mode
            },
            input: InputState::default(),
            camera: Camera {
                position: Position3D {
                    x: 50.0,
                    y: 50.0,
                    z: 15.0,
                    map_id: 0,
                },
                target: Position3D {
                    x: 50.0,
                    y: 50.0,
                    z: 10.0,
                    map_id: 0,
                },
                distance: 5.0,
                angle_horizontal: 0.0,
                angle_vertical: -0.5,
                mode: CameraMode::TopDown,
            },
            ui_state: UIState::default(),
        }
    }
}

impl NetworkManager {
    pub fn new() -> Self {
        Self {
            session_key: None,
            auth_server: None,
            world_server: None,
            peers: Arc::new(RwLock::new(HashMap::new())),
            packet_handlers: HashMap::new(),
            party_mode: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub version: String,
    pub max_players: u32,
    pub current_players: u32,
    pub uptime: u64,
}

impl Default for ServerInfo {
    fn default() -> Self {
        Self {
            name: "Anbernic MMO Server".to_string(),
            version: "1.0.0".to_string(),
            max_players: 1000,
            current_players: 0,
            uptime: 0,
        }
    }
}

impl Default for InputState {
    fn default() -> Self {
        Self {
            movement: MovementInput {
                forward: false,
                backward: false,
                strafe_left: false,
                strafe_right: false,
                turn_left: false,
                turn_right: false,
                jump: false,
                run: false,
            },
            actions: ActionInput {
                auto_attack: false,
                cast_spell: None,
                use_item: None,
                interact: false,
                chat_mode: false,
            },
            camera_mode: CameraMode::TopDown,
            target_guid: None,
        }
    }
}

impl Default for UIState {
    fn default() -> Self {
        Self {
            show_health_bar: true,
            show_minimap: true,
            show_chat: false,
            show_inventory: false,
            chat_messages: vec![],
            target_info: None,
        }
    }
}

// Placeholder types to complete the API
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Item {
    pub id: u32,
    pub name: String,
    pub slot: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Spell {
    pub id: u32,
    pub name: String,
    pub cooldown: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MapObject {
    pub id: u64,
    pub object_type: ObjectType,
    pub position: Position3D,
    pub model_id: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SafeZone {
    pub center: Position3D,
    pub radius: f32,
    pub name: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_mmo_engine_creation() {
        let engine = HandheldMMOEngine::new();
        assert_eq!(engine.player.state.level, 1);
        assert_eq!(engine.player.state.name, "Anbernic_Player");
    }

    #[tokio::test]
    async fn test_map_generation() {
        let map = GameMap::generate_starter_map();
        assert_eq!(map.size_x, 100);
        assert_eq!(map.size_y, 100);
        assert!(map.height_map.len() == 100);
        assert!(map.spawn_points.len() > 0);
    }

    #[tokio::test]
    async fn test_movement() {
        let mut engine = HandheldMMOEngine::new();
        let initial_x = engine.player.state.position.x;

        let mut input = InputState::default();
        input.movement.forward = true;

        engine.handle_input(input).await.unwrap();

        assert!(engine.player.state.position.x != initial_x);
    }
}
