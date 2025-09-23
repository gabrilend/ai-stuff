use handheld_office::scuttlebutt::*;
use std::collections::HashMap;
use std::io::{self, Write};
use std::time::{Duration, Instant};

struct AnbernicScuttlebuttInterface {
    node: ScuttlebuttNode,
    current_view: ViewState,
    cursor_position: usize,
    last_update: Instant,
    streetpass_animation: StreetPassAnimation,
    show_debug: bool,
    message_buffer: String,
}

#[derive(Debug, Clone)]
enum ViewState {
    MainMenu,
    MessageFeed,
    Compose,
    StreetPass,
    PeerDiscovery,
    Settings,
    DebugInfo,
}

#[derive(Debug, Clone)]
struct StreetPassAnimation {
    active: bool,
    progress: f32,
    encounter_device: Option<String>,
    animation_start: Instant,
}

impl AnbernicScuttlebuttInterface {
    fn new() -> Self {
        let mut node =
            ScuttlebuttNode::new("AnbernicMesh".to_string(), "anbernic_rg35xx".to_string());

        // Set up some initial data for demo
        node.streetpass.exchange_data.profile.nickname = "ScuttlePlayer".to_string();
        node.streetpass.exchange_data.profile.favorite_game = "rocketship-bacterium".to_string();
        node.streetpass.exchange_data.profile.current_mood = "Exploring the mesh".to_string();

        Self {
            node,
            current_view: ViewState::MainMenu,
            cursor_position: 0,
            last_update: Instant::now(),
            streetpass_animation: StreetPassAnimation {
                active: false,
                progress: 0.0,
                encounter_device: None,
                animation_start: Instant::now(),
            },
            show_debug: false,
            message_buffer: String::new(),
        }
    }

    fn render_frame(&self) -> String {
        let mut output = String::new();

        // Clear screen with Scuttlebutt header
        output.push_str("\x1b[2J\x1b[H");
        output.push_str(
            "╔══════════════════════════════════════════════════════════════════════════════╗\n",
        );
        output.push_str(
            "║                    ANBERNIC SCUTTLEBUTT MESH                                ║\n",
        );
        output.push_str(
            "╚══════════════════════════════════════════════════════════════════════════════╝\n",
        );

        // Show StreetPass animation if active
        if self.streetpass_animation.active {
            output.push_str(&self.render_streetpass_animation());
            return output;
        }

        match &self.current_view {
            ViewState::MainMenu => output.push_str(&self.render_main_menu()),
            ViewState::MessageFeed => output.push_str(&self.render_message_feed()),
            ViewState::Compose => output.push_str(&self.render_compose()),
            ViewState::StreetPass => output.push_str(&self.render_streetpass()),
            ViewState::PeerDiscovery => output.push_str(&self.render_peer_discovery()),
            ViewState::Settings => output.push_str(&self.render_settings()),
            ViewState::DebugInfo => output.push_str(&self.render_debug_info()),
        }

        // Status bar
        output.push_str(
            "╔══════════════════════════════════════════════════════════════════════════════╗\n",
        );
        output.push_str(&format!(
            "║ Mode: {} | Peers: {} | Messages: {} | ID: {}...    ║\n",
            match &self.node.mode {
                OperatingMode::Leashed { .. } => "LEASHED",
                OperatingMode::Unleashed { .. } => "UNLEASHED",
                OperatingMode::Hybrid { .. } => "HYBRID",
            },
            self.get_peer_count(),
            self.get_message_count(),
            &self.node.identity.device_id[..8]
        ));
        output.push_str(
            "╚══════════════════════════════════════════════════════════════════════════════╝\n",
        );

        // Controls
        output.push_str(
            "┌─ CONTROLS ─────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│ WASD: Navigate | A: Select | B: Back | L/R: Switch tabs | Start: Menu      │\n",
        );
        output.push_str(
            "│ Select: StreetPass | Y: Compose | X: Refresh | Debug: Toggle debug info   │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_main_menu(&self) -> String {
        let mut output = String::new();

        let menu_items = vec![
            "📨 Message Feed",
            "✍️  Compose Message",
            "🤝 StreetPass",
            "🌐 Peer Discovery",
            "⚙️  Settings",
            "🔧 Debug Info",
        ];

        output.push_str(
            "┌─ MAIN MENU ────────────────────────────────────────────────────────────────┐\n",
        );
        for (i, item) in menu_items.iter().enumerate() {
            if i == self.cursor_position {
                output.push_str(&format!("│ ► {}                                                                      │\n", item));
            } else {
                output.push_str(&format!("│   {}                                                                      │\n", item));
            }
        }
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        // Show recent activity
        output.push_str(
            "┌─ RECENT ACTIVITY ──────────────────────────────────────────────────────────┐\n",
        );
        if self.node.streetpass.encounter_history.is_empty() {
            output.push_str(
                "│ No recent StreetPass encounters                                           │\n",
            );
        } else {
            output.push_str(
                "│ Recent StreetPass encounters:                                             │\n",
            );
            for encounter in self.node.streetpass.encounter_history.iter().take(3) {
                output.push_str(&format!(
                    "│ • {} at {}                                    │\n",
                    &encounter.peer_device_id[..8],
                    encounter.encounter_time.format("%H:%M")
                ));
            }
        }
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_message_feed(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ MESSAGE FEED ─────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ 📡 Connecting to Scuttlebutt mesh...                                      │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Welcome to the Anbernic Scuttlebutt network!                              │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ This is a peer-to-peer messaging system inspired by Scuttlebutt and       │\n",
        );
        output.push_str(
            "│ Nintendo 3DS StreetPass. Messages are encrypted and shared directly       │\n",
        );
        output.push_str(
            "│ between Anbernic devices without requiring internet servers.              │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Features:                                                                  │\n",
        );
        output.push_str(
            "│ • Encrypted P2P messaging with PGP                                        │\n",
        );
        output.push_str(
            "│ • StreetPass-style automatic data exchange                                │\n",
        );
        output.push_str(
            "│ • Game save sharing and high score comparison                             │\n",
        );
        output.push_str(
            "│ • Art and music sharing between devices                                   │\n",
        );
        output.push_str(
            "│ • Works without WiFi routers (ad-hoc networking)                          │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Press Y to compose your first message!                                    │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_compose(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ COMPOSE MESSAGE ──────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ To: (empty = public broadcast)                                             │\n",
        );
        output.push_str(
            "│ ┌────────────────────────────────────────────────────────────────────┐   │\n",
        );
        output.push_str(
            "│ │                                                                    │   │\n",
        );
        output.push_str(
            "│ └────────────────────────────────────────────────────────────────────┘   │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Message:                                                                   │\n",
        );
        output.push_str(
            "│ ┌────────────────────────────────────────────────────────────────────┐   │\n",
        );
        output.push_str(
            "│ │ Hello from my Anbernic device!                                     │   │\n",
        );
        output.push_str(
            "│ │                                                                    │   │\n",
        );
        output.push_str(
            "│ │ This message will be shared via the Scuttlebutt mesh network.     │   │\n",
        );
        output.push_str(
            "│ │                                                                    │   │\n",
        );
        output.push_str(
            "│ │ [Cursor here]                                                      │   │\n",
        );
        output.push_str(
            "│ │                                                                    │   │\n",
        );
        output.push_str(
            "│ └────────────────────────────────────────────────────────────────────┘   │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ [A] Send  [B] Cancel  [L/R] Change message type                           │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_streetpass(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ STREETPASS STATUS ────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│    🤝 StreetPass Mode: ACTIVE                                              │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│    Your Profile:                                                           │\n",
        );
        output.push_str(&format!(
            "│    Name: {}                                                │\n",
            self.node.streetpass.exchange_data.profile.nickname
        ));
        output.push_str(&format!(
            "│    Favorite Game: {}                                      │\n",
            self.node.streetpass.exchange_data.profile.favorite_game
        ));
        output.push_str(&format!(
            "│    Mood: {}                                               │\n",
            self.node.streetpass.exchange_data.profile.current_mood
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│    Exchange Range: 10 meters                                              │\n",
        );
        output.push_str(
            "│    Auto-exchange: ON                                                      │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│    Recent Encounters:                                                      │\n",
        );

        if self.node.streetpass.encounter_history.is_empty() {
            output.push_str(
                "│    • No encounters yet - try walking around with your Anbernic!           │\n",
            );
        } else {
            for encounter in self.node.streetpass.encounter_history.iter().take(5) {
                output.push_str(&format!(
                    "│    • {} - {}                                         │\n",
                    &encounter.peer_device_id[..12],
                    encounter.encounter_time.format("%m/%d %H:%M")
                ));
            }
        }

        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│    [A] Manual Scan  [X] Clear History  [Y] Edit Profile                   │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_peer_discovery(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ PEER DISCOVERY ───────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ 📡 Scanning for nearby Anbernic devices...                                │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Discovery Method: WiFi Ad-Hoc (No router required)                        │\n",
        );
        output.push_str(
            "│ Network: AnbernicMesh                                                      │\n",
        );
        output.push_str(
            "│ Port: 7777                                                                 │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Discovered Peers:                                                          │\n",
        );
        output.push_str(
            "│ ┌────────────────────────────────────────────────────────────────────┐   │\n",
        );
        output.push_str(
            "│ │ Device ID       │ Name           │ Signal │ Last Seen │ Distance   │   │\n",
        );
        output.push_str(
            "│ ├────────────────────────────────────────────────────────────────────┤   │\n",
        );
        output.push_str(
            "│ │ abc123def456    │ GameBuddy      │ -45dBm │ 2s ago    │ ~5m        │   │\n",
        );
        output.push_str(
            "│ │ 789ghi012jkl    │ PixelArtist    │ -52dBm │ 8s ago    │ ~12m       │   │\n",
        );
        output.push_str(
            "│ │ mno345pqr678    │ RetroGamer     │ -38dBm │ 1s ago    │ ~3m        │   │\n",
        );
        output.push_str(
            "│ └────────────────────────────────────────────────────────────────────┘   │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ [A] Connect to Selected  [X] Refresh  [Y] Send StreetPass                 │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_settings(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ SETTINGS ─────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Operating Mode:                                                            │\n",
        );
        output.push_str(&format!(
            "│ ► {}                                                      │\n",
            match &self.node.mode {
                OperatingMode::Leashed { .. } => "🔗 LEASHED (Connected to laptop)",
                OperatingMode::Unleashed { .. } => "📡 UNLEASHED (Pure P2P mesh)",
                OperatingMode::Hybrid { .. } => "🔄 HYBRID (Adaptive)",
            }
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Security Settings:                                                         │\n",
        );
        output.push_str(&format!(
            "│   Encryption: {}                                                     │\n",
            "ENABLED" // For now, assume encryption is always enabled
        ));
        output.push_str(&format!(
            "│   Device ID: {}...                                          │\n",
            &self.node.identity.device_id[..16]
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ StreetPass Settings:                                                       │\n",
        );
        output.push_str(&format!(
            "│   Auto-exchange: {}                                                  │\n",
            if self.node.streetpass.auto_exchange {
                "ON"
            } else {
                "OFF"
            }
        ));
        output.push_str(&format!(
            "│   Exchange radius: {:.1}m                                            │\n",
            self.node.streetpass.exchange_radius
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Network Settings:                                                          │\n",
        );
        output.push_str(&format!(
            "│   Ad-hoc SSID: {}                                          │\n",
            match &self.node.mode {
                OperatingMode::Unleashed { ad_hoc_network, .. } => ad_hoc_network,
                _ => "N/A",
            }
        ));
        output.push_str(
            "│   Discovery port: 7777                                                     │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ [A] Toggle  [L/R] Change mode  [Y] Reset to defaults                      │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_debug_info(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌─ DEBUG INFO ───────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Node Identity:                                                             │\n",
        );
        output.push_str(&format!(
            "│   Device ID: {}                              │\n",
            self.node.identity.device_id
        ));
        output.push_str(&format!(
            "│   Display Name: {}                                          │\n",
            self.node.identity.display_name
        ));
        output.push_str(&format!(
            "│   Device Type: {}                                       │\n",
            self.node.identity.device_type
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Message Log:                                                               │\n",
        );
        output.push_str(
            "│   Current sequence: 0                                                      │\n",
        );
        output.push_str(
            "│   Total messages: 0                                                        │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Network Status:                                                            │\n",
        );
        output.push_str(&format!(
            "│   Discovery active: {}                                               │\n",
            if self.node.peer_discovery.discovery_active {
                "YES"
            } else {
                "NO"
            }
        ));
        output.push_str(
            "│   Known peers: 0                                                           │\n",
        );
        output.push_str(
            "│   TCP listener: Started on port 8080                                      │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│ Crypto Status:                                                             │\n",
        );
        output.push_str(&format!(
            "│   PGP keys: {}                                                     │\n",
            "Generated" // For now, assume keys are always generated
        ));
        output.push_str(
            "│   Trust web: Empty                                                         │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_streetpass_animation(&self) -> String {
        let mut output = String::new();

        let animation_chars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        let frame = (self.streetpass_animation.progress * 10.0) as usize % animation_chars.len();

        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│                          🤝 STREETPASS ACTIVE                              │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(&format!(
            "│                            {} Exchanging data...                        │\n",
            animation_chars[frame]
        ));
        output.push_str(
            "│                                                                            │\n",
        );
        if let Some(device) = &self.streetpass_animation.encounter_device {
            output.push_str(&format!(
                "│                        Connected to: {}...                      │\n",
                &device[..8]
            ));
        }
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│                     ╔══════════════════════════╗                          │\n",
        );
        output.push_str(&format!(
            "│                     ║{}║                          │\n",
            "█"
                .repeat((self.streetpass_animation.progress * 26.0) as usize)
                .chars()
                .chain(
                    " ".repeat(26 - (self.streetpass_animation.progress * 26.0) as usize)
                        .chars()
                )
                .collect::<String>()
        ));
        output.push_str(
            "│                     ╚══════════════════════════╝                          │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );
        output.push_str(
            "│                          Please wait...                                   │\n",
        );
        output.push_str(
            "│                                                                            │\n",
        );

        output
    }

    fn handle_input(&mut self, input: char) {
        match input.to_ascii_lowercase() {
            'w' => self.cursor_position = self.cursor_position.saturating_sub(1),
            's' => self.cursor_position = (self.cursor_position + 1).min(5),
            'a' => self.handle_select(),
            'b' => self.handle_back(),
            'l' => self.handle_tab_left(),
            'r' => self.handle_tab_right(),
            'y' => self.current_view = ViewState::Compose,
            'x' => self.handle_refresh(),
            't' => self.show_debug = !self.show_debug,
            ' ' => self.trigger_streetpass_animation(),
            _ => {}
        }
    }

    fn handle_select(&mut self) {
        match self.current_view {
            ViewState::MainMenu => {
                match self.cursor_position {
                    0 => self.current_view = ViewState::MessageFeed,
                    1 => self.current_view = ViewState::Compose,
                    2 => self.current_view = ViewState::StreetPass,
                    3 => self.current_view = ViewState::PeerDiscovery,
                    4 => self.current_view = ViewState::Settings,
                    5 => self.current_view = ViewState::DebugInfo,
                    _ => {}
                }
                self.cursor_position = 0;
            }
            _ => {}
        }
    }

    fn handle_back(&mut self) {
        match self.current_view {
            ViewState::MainMenu => {}
            _ => {
                self.current_view = ViewState::MainMenu;
                self.cursor_position = 0;
            }
        }
    }

    fn handle_tab_left(&mut self) {
        self.current_view = match self.current_view {
            ViewState::MainMenu => ViewState::DebugInfo,
            ViewState::MessageFeed => ViewState::MainMenu,
            ViewState::Compose => ViewState::MessageFeed,
            ViewState::StreetPass => ViewState::Compose,
            ViewState::PeerDiscovery => ViewState::StreetPass,
            ViewState::Settings => ViewState::PeerDiscovery,
            ViewState::DebugInfo => ViewState::Settings,
        };
    }

    fn handle_tab_right(&mut self) {
        self.current_view = match self.current_view {
            ViewState::MainMenu => ViewState::MessageFeed,
            ViewState::MessageFeed => ViewState::Compose,
            ViewState::Compose => ViewState::StreetPass,
            ViewState::StreetPass => ViewState::PeerDiscovery,
            ViewState::PeerDiscovery => ViewState::Settings,
            ViewState::Settings => ViewState::DebugInfo,
            ViewState::DebugInfo => ViewState::MainMenu,
        };
    }

    fn handle_refresh(&mut self) {
        // Simulate peer discovery refresh
        // In real implementation, would trigger actual network scan
    }

    fn trigger_streetpass_animation(&mut self) {
        self.streetpass_animation.active = true;
        self.streetpass_animation.progress = 0.0;
        self.streetpass_animation.encounter_device = Some("abc123def456".to_string());
        self.streetpass_animation.animation_start = Instant::now();
    }

    fn update(&mut self) {
        let now = Instant::now();
        let delta_time = now.duration_since(self.last_update).as_secs_f32();

        // Update StreetPass animation
        if self.streetpass_animation.active {
            let animation_duration = now
                .duration_since(self.streetpass_animation.animation_start)
                .as_secs_f32();
            self.streetpass_animation.progress = (animation_duration / 3.0).min(1.0);

            if self.streetpass_animation.progress >= 1.0 {
                self.streetpass_animation.active = false;
                // Simulate successful exchange
                // In real implementation, would actually perform data exchange
            }
        }

        self.last_update = now;
    }

    // Helper methods
    fn get_peer_count(&self) -> usize {
        // In real implementation, would return actual peer count
        3 // Simulated
    }

    fn get_message_count(&self) -> usize {
        // In real implementation, would return actual message count
        0
    }

    fn run(&mut self) -> io::Result<()> {
        println!("Starting Anbernic Scuttlebutt Mesh Interface...");
        println!("(This demo uses simplified input - press Enter after each command)");
        println!();

        loop {
            // Update state
            self.update();

            // Render frame
            print!("{}", self.render_frame());
            io::stdout().flush()?;

            // Handle input
            println!("Enter command (WASD/A/B/L/R/Y/X/Space or 'q' to quit): ");
            let mut input = String::new();
            io::stdin().read_line(&mut input)?;

            let command = input.trim().chars().next().unwrap_or('q');
            if command == 'q' {
                break;
            }

            self.handle_input(command);

            // Small delay for responsive feel
            std::thread::sleep(Duration::from_millis(50));
        }

        println!("Thanks for exploring the Scuttlebutt mesh network!");
        Ok(())
    }
}

fn main() -> io::Result<()> {
    println!("╔══════════════════════════════════════════════════════════════════════════════╗");
    println!("║                                                                              ║");
    println!("║  ████████▄   ▄█     ▄████████    ▄█    █▄       ▄████████  ▄█             ║");
    println!("║  ███   ▀███ ███    ███    ███   ███    ███     ███    ███ ███             ║");
    println!("║  ███    ███ ███▌   ███    ███   ███    ███     ███    ███ ███             ║");
    println!("║  ███    ███ ███▌   ███    ███  ▄███▄▄▄▄███▄▄  ▄███▄▄▄▄██▀ ███             ║");
    println!("║  ███    ███ ███▌ ▀███████████ ▀▀███▀▀▀▀███▀  ▀▀███▀▀▀▀▀   ███             ║");
    println!("║  ███    ███ ███    ███    ███   ███    ███   ▀███████████ ███             ║");
    println!("║  ███   ▄███ ███    ███    ███   ███    ███     ███    ███ ███▌    ▄       ║");
    println!("║  ████████▀  █▀     ███    █▀    ███    █▀      ███    ███ █████▄▄██       ║");
    println!("║                                                ███    ███ ▀              ║");
    println!("║                                                                              ║");
    println!("║                    SCUTTLEBUTT MESH NETWORK                                  ║");
    println!("║                                                                              ║");
    println!("║              \"Like StreetPass, but for everything\"                           ║");
    println!("║                                                                              ║");
    println!("╚══════════════════════════════════════════════════════════════════════════════╝");
    println!();
    println!("Welcome to the Anbernic Scuttlebutt mesh network!");
    println!("This system enables peer-to-peer communication between Anbernic devices");
    println!("without requiring internet connectivity or WiFi routers.");
    println!();

    let mut interface = AnbernicScuttlebuttInterface::new();
    interface.run()
}
