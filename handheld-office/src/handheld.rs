use chrono::Utc;
use log::{debug, error, info, warn};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use handheld_office::wifi_direct_p2p::{WiFiDirectP2P, WiFiDirectIntegration, MessageContent, PairingEmoji};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputHierarchy {
    pub layers: Vec<InputLayer>,
    pub current_layer: usize,
    pub current_position: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputLayer {
    pub name: String,
    pub options: Vec<InputOption>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputOption {
    pub text: String,
    pub character: Option<char>,
    pub sub_layer: Option<InputLayer>,
    pub trigger: InputTrigger,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum InputTrigger {
    A,
    B,
    L,
    R,
    LA,
    LB,
    RA,
    RB,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextBuffer {
    pub content: String,
    pub cursor_position: usize,
    pub display_lines: VecDeque<String>,
    pub max_lines: usize,
}

pub struct HandheldDevice {
    pub input_hierarchy: InputHierarchy,
    pub text_buffer: TextBuffer,
    pub wifi_direct: WiFiDirectP2P,
    pub device_id: String,
    pub llm_responses: VecDeque<LlmResponse>,
    pub collaborative_sessions: Vec<CollaborativeSession>,
    pub file_operations: FileOperations,
    pub connected_laptop: Option<String>, // Laptop device ID for LLM services
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmResponse {
    pub id: String,
    pub request_id: String,
    pub response: String,
    pub timestamp: u64,
    pub model_used: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollaborativeSession {
    pub session_id: String,
    pub participants: Vec<String>,
    pub shared_content: String,
    pub version: u64,
    pub last_modified: u64,
}

#[derive(Debug, Clone)]
pub struct FileOperations {
    pub current_file: Option<String>,
    pub auto_save_enabled: bool,
    pub recent_files: VecDeque<String>,
    pub backup_interval: u64, // seconds
}

impl HandheldDevice {
    pub fn new(device_name: String) -> Result<Self, Box<dyn std::error::Error>> {
        let input_hierarchy = Self::create_default_hierarchy();
        let text_buffer = TextBuffer {
            content: String::new(),
            cursor_position: 0,
            display_lines: VecDeque::new(),
            max_lines: 20, // Gameboy screen constraint
        };

        let wifi_direct = WiFiDirectP2P::new(device_name)?;
        let device_id = wifi_direct.device_id.clone();

        Ok(Self {
            input_hierarchy,
            text_buffer,
            wifi_direct,
            device_id,
            llm_responses: VecDeque::new(),
            collaborative_sessions: Vec::new(),
            file_operations: FileOperations {
                current_file: None,
                auto_save_enabled: true,
                recent_files: VecDeque::new(),
                backup_interval: 30, // 30 seconds default
            },
            connected_laptop: None,
        })
    }

    fn create_default_hierarchy() -> InputHierarchy {
        let letters_layer = InputLayer {
            name: "Letters".to_string(),
            options: vec![
                InputOption {
                    text: "A-H".to_string(),
                    character: None,
                    sub_layer: Some(InputLayer {
                        name: "A-H".to_string(),
                        options: vec![
                            InputOption {
                                text: "A".to_string(),
                                character: Some('a'),
                                sub_layer: None,
                                trigger: InputTrigger::A,
                            },
                            InputOption {
                                text: "B".to_string(),
                                character: Some('b'),
                                sub_layer: None,
                                trigger: InputTrigger::B,
                            },
                            InputOption {
                                text: "C".to_string(),
                                character: Some('c'),
                                sub_layer: None,
                                trigger: InputTrigger::L,
                            },
                            InputOption {
                                text: "D".to_string(),
                                character: Some('d'),
                                sub_layer: None,
                                trigger: InputTrigger::R,
                            },
                        ],
                    }),
                    trigger: InputTrigger::A,
                },
                InputOption {
                    text: "I-P".to_string(),
                    character: None,
                    sub_layer: Some(InputLayer {
                        name: "I-P".to_string(),
                        options: vec![
                            InputOption {
                                text: "I".to_string(),
                                character: Some('i'),
                                sub_layer: None,
                                trigger: InputTrigger::A,
                            },
                            InputOption {
                                text: "O".to_string(),
                                character: Some('o'),
                                sub_layer: None,
                                trigger: InputTrigger::B,
                            },
                            InputOption {
                                text: "Space".to_string(),
                                character: Some(' '),
                                sub_layer: None,
                                trigger: InputTrigger::L,
                            },
                            InputOption {
                                text: "Enter".to_string(),
                                character: Some('\n'),
                                sub_layer: None,
                                trigger: InputTrigger::R,
                            },
                        ],
                    }),
                    trigger: InputTrigger::B,
                },
            ],
        };

        InputHierarchy {
            layers: vec![letters_layer],
            current_layer: 0,
            current_position: 0,
        }
    }

    pub async fn start_wifi_direct(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.wifi_direct.start_wifi_direct().await?;
        info!("Started WiFi Direct P2P networking");
        Ok(())
    }

    pub async fn enter_pairing_mode(&self) -> Result<PairingEmoji, Box<dyn std::error::Error>> {
        self.wifi_direct.enter_pairing_mode().await
    }

    pub async fn get_discovered_devices(&self) -> Vec<PairingEmoji> {
        self.wifi_direct.get_discovered_emojis().await
    }

    pub async fn pair_with_device(
        &self,
        emoji: &PairingEmoji,
        nickname: String,
    ) -> Result<String, Box<dyn std::error::Error>> {
        self.wifi_direct.pair_with_device(emoji, nickname).await
    }

    pub async fn connect_to_laptop(&mut self, laptop_device_id: String) -> Result<(), Box<dyn std::error::Error>> {
        self.wifi_direct.connect_to_laptop_daemon(&laptop_device_id).await?;
        self.connected_laptop = Some(laptop_device_id);
        info!("Connected to laptop for LLM services");
        Ok(())
    }

    pub async fn handle_input(
        &mut self,
        trigger: InputTrigger,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let current_layer = &self.input_hierarchy.layers[self.input_hierarchy.current_layer];

        for option in &current_layer.options {
            if option.trigger == trigger {
                if let Some(character) = option.character {
                    self.add_character(character).await?;
                } else if let Some(sub_layer) = &option.sub_layer {
                    // Navigate to sub-layer
                    self.navigate_to_sublayer(sub_layer.clone());
                }
                break;
            }
        }

        Ok(())
    }

    async fn add_character(&mut self, character: char) -> Result<(), Box<dyn std::error::Error>> {
        self.text_buffer
            .content
            .insert(self.text_buffer.cursor_position, character);
        self.text_buffer.cursor_position += 1;

        self.update_display();
        self.send_text_update().await?;

        Ok(())
    }

    fn navigate_to_sublayer(&mut self, sub_layer: InputLayer) {
        // For simplicity, we'll replace the current layer
        // In a real implementation, you'd maintain a navigation stack
        self.input_hierarchy.layers[0] = sub_layer;
        self.input_hierarchy.current_position = 0;
    }

    fn update_display(&mut self) {
        // Implement L-shaped text display as described in vision
        let words: Vec<&str> = self.text_buffer.content.split_whitespace().collect();
        self.text_buffer.display_lines.clear();

        if words.is_empty() {
            return;
        }

        // First line across the top (L shape)
        let mut current_line = words[0].to_string();
        for word in words.iter().skip(1) {
            if current_line.len() + word.len() + 1 <= 20 {
                // GBA screen width constraint
                current_line.push(' ');
                current_line.push_str(word);
            } else {
                break;
            }
        }
        self.text_buffer.display_lines.push_back(current_line);

        // Remaining words on right side (vertical part of L)
        // This is a simplified implementation of the L-shaped display
        for word in words.iter().skip(self.text_buffer.display_lines.len()) {
            if self.text_buffer.display_lines.len() < self.text_buffer.max_lines {
                let right_aligned = format!("{:>20}", word);
                self.text_buffer.display_lines.push_back(right_aligned);
            }
        }
    }

    async fn send_text_update(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Send text updates to all active peers via WiFi Direct
        let peers = self.wifi_direct.get_active_peers().await;
        for (peer_id, _nickname) in peers {
            let content = MessageContent::Text(self.text_buffer.content.clone());
            if let Err(e) = self.wifi_direct.send_message(&peer_id, content).await {
                warn!("Failed to send text update to peer {}: {}", peer_id, e);
            }
        }
        Ok(())
    }

    pub async fn send_llm_request(
        &mut self,
        request: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(ref laptop_id) = self.connected_laptop.clone() {
            let response = self.wifi_direct.send_llm_request(laptop_id, request.to_string()).await?;
            
            // Store the response
            let llm_response = LlmResponse {
                id: format!("{}_llm_{}", self.device_id, Utc::now().timestamp()),
                request_id: format!("req_{}", Utc::now().timestamp()),
                response: response.clone(),
                timestamp: Utc::now().timestamp() as u64,
                model_used: "laptop_llm".to_string(),
            };
            
            self.receive_llm_response(llm_response).await;
            Ok(response)
        } else {
            Err("No laptop connected for LLM services".into())
        }
    }

    pub async fn send_image_generation_request(
        &mut self,
        prompt: &str,
        style: &str,
        resolution: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(ref laptop_id) = self.connected_laptop.clone() {
            let response = self.wifi_direct.send_image_generation_request(
                laptop_id,
                prompt.to_string(),
                style.to_string(),
                resolution.to_string(),
                20, // default steps
                7.5, // default guidance scale
            ).await?;
            
            Ok(response)
        } else {
            Err("No laptop connected for image generation services".into())
        }
    }

    pub async fn receive_llm_response(&mut self, response: LlmResponse) {
        self.llm_responses.push_back(response);

        // Keep only last 10 responses to manage memory
        while self.llm_responses.len() > 10 {
            self.llm_responses.pop_front();
        }
    }

    pub async fn join_collaborative_session(
        &mut self,
        session_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let session = CollaborativeSession {
            session_id: session_id.to_string(),
            participants: vec![self.device_id.clone()],
            shared_content: self.text_buffer.content.clone(),
            version: 1,
            last_modified: Utc::now().timestamp() as u64,
        };

        self.collaborative_sessions.push(session);
        self.sync_collaborative_content().await?;
        Ok(())
    }

    pub async fn sync_collaborative_content(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let peers = self.wifi_direct.get_active_peers().await;
        
        for session in &mut self.collaborative_sessions {
            // Check if local content is newer
            if self.text_buffer.content != session.shared_content {
                session.shared_content = self.text_buffer.content.clone();
                session.version += 1;
                session.last_modified = Utc::now().timestamp() as u64;

                // Send document updates to all peers in this session
                let filename = format!("collaborative_doc_{}", session.session_id);
                let content = MessageContent::Document {
                    filename,
                    content: session.shared_content.clone(),
                };

                for (peer_id, _nickname) in &peers {
                    if let Err(e) = self.wifi_direct.send_message(peer_id, content.clone()).await {
                        warn!("Failed to sync with peer {}: {}", peer_id, e);
                    }
                }
            }
        }
        Ok(())
    }

    pub async fn receive_collaborative_update(
        &mut self,
        session_id: &str,
        content: &str,
        version: u64,
    ) -> Result<(), Box<dyn std::error::Error>> {
        for session in &mut self.collaborative_sessions {
            if session.session_id == session_id && version > session.version {
                session.shared_content = content.to_string();
                session.version = version;
                session.last_modified = Utc::now().timestamp() as u64;

                // Update local content with collaborative changes
                self.text_buffer.content = content.to_string();
                self.text_buffer.cursor_position =
                    self.text_buffer.cursor_position.min(content.len());
                self.update_display();
                break;
            }
        }
        Ok(())
    }

    pub async fn save_current_file(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref file_path) = self.file_operations.current_file {
            tokio::fs::write(file_path, &self.text_buffer.content).await?;
            info!("Saved file: {}", file_path);

            // Add to recent files if not already present
            if !self.file_operations.recent_files.contains(file_path) {
                self.file_operations
                    .recent_files
                    .push_front(file_path.clone());
                // Keep only last 10 recent files
                while self.file_operations.recent_files.len() > 10 {
                    self.file_operations.recent_files.pop_back();
                }
            }
        }
        Ok(())
    }

    pub async fn load_file(&mut self, file_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        let content = tokio::fs::read_to_string(file_path).await?;
        self.text_buffer.content = content;
        self.text_buffer.cursor_position = 0;
        self.file_operations.current_file = Some(file_path.to_string());
        self.update_display();

        info!("Loaded file: {}", file_path);
        Ok(())
    }

    pub async fn create_backup(&self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(ref file_path) = self.file_operations.current_file {
            let backup_path = format!("{}.backup_{}", file_path, Utc::now().timestamp());
            tokio::fs::write(&backup_path, &self.text_buffer.content).await?;
            info!("Created backup: {}", backup_path);
        }
        Ok(())
    }

    pub async fn start_auto_backup_task(&self) {
        if !self.file_operations.auto_save_enabled {
            return;
        }

        let backup_interval = self.file_operations.backup_interval;
        let device_id = self.device_id.clone();
        let current_file = self.file_operations.current_file.clone();
        let content = self.text_buffer.content.clone();

        tokio::spawn(async move {
            let mut interval =
                tokio::time::interval(std::time::Duration::from_secs(backup_interval));

            loop {
                interval.tick().await;
                if let Some(ref file_path) = current_file {
                    let backup_path = format!(
                        "files/build/auto_backup_{}_{}.txt",
                        device_id,
                        Utc::now().timestamp()
                    );
                    if let Err(e) = tokio::fs::write(&backup_path, &content).await {
                        error!("Auto-backup failed: {}", e);
                    } else {
                        debug!("Auto-backup created: {}", backup_path);
                    }
                }
            }
        });
    }

    pub fn get_recent_files(&self) -> &VecDeque<String> {
        &self.file_operations.recent_files
    }

    pub fn set_auto_save(&mut self, enabled: bool) {
        self.file_operations.auto_save_enabled = enabled;
    }

    pub fn set_backup_interval(&mut self, seconds: u64) {
        self.file_operations.backup_interval = seconds;
    }

    pub fn render_display(&self) -> String {
        let mut output = String::new();

        // Simple ASCII art frame for the "gameboy screen"
        output.push_str("┌────────────────────┐\n");

        for line in self.text_buffer.display_lines.iter() {
            output.push_str(&format!("│{:<20}│\n", line));
        }

        // Fill remaining lines
        for _ in self.text_buffer.display_lines.len()..self.text_buffer.max_lines.min(10) {
            output.push_str("│                    │\n");
        }

        output.push_str("└────────────────────┘\n");

        // Show current input hierarchy state
        let current_layer = &self.input_hierarchy.layers[self.input_hierarchy.current_layer];
        output.push_str(&format!("Layer: {} | Options: ", current_layer.name));
        for option in &current_layer.options {
            output.push_str(&format!("[{:?}]{} ", option.trigger, option.text));
        }
        output.push('\n');

        output
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let mut device = HandheldDevice::new("AnbernicWordProcessor".to_string())?;

    // Start WiFi Direct P2P networking
    if let Err(e) = device.start_wifi_direct().await {
        error!("Failed to start WiFi Direct: {}", e);
        return Ok(());
    }

    // Start auto-backup task
    device.start_auto_backup_task().await;

    // Simple interactive loop for testing
    println!("{}", device.render_display());
    println!("Commands:");
    println!("  A/B/L/R (input), 'quit'");
    println!("  'pair' (enter pairing mode)");
    println!("  'devices' (show discovered devices)");
    println!("  'connect:<laptop_id>' (connect to laptop)");
    println!("  'llm:<text>' (send LLM request)");
    println!("  'image:<prompt>' (generate image with default settings)");
    println!("  'image:<prompt>|<style>|<resolution>' (generate image with options)");
    println!("  'save:<file>', 'load:<file>', 'join:<session_id>'");

    // In a real implementation, this would handle actual gamepad input
    // For now, we'll use stdin simulation
    loop {
        let mut input = String::new();
        std::io::stdin().read_line(&mut input)?;

        match input.trim() {
            "quit" => break,
            "a" | "A" => device.handle_input(InputTrigger::A).await?,
            "b" | "B" => device.handle_input(InputTrigger::B).await?,
            "l" | "L" => device.handle_input(InputTrigger::L).await?,
            "r" | "R" => device.handle_input(InputTrigger::R).await?,
            "pair" => {
                match device.enter_pairing_mode().await {
                    Ok(emoji) => println!("Pairing mode active! Your emoji: {}", emoji.emoji),
                    Err(e) => println!("Failed to enter pairing mode: {}", e),
                }
            }
            "devices" => {
                let devices = device.get_discovered_devices().await;
                if devices.is_empty() {
                    println!("No devices discovered. Make sure other devices are in pairing mode.");
                } else {
                    println!("Discovered devices:");
                    for device in devices {
                        println!("  {} ({})", device.emoji, device.device_id);
                    }
                }
            }
            text if text.starts_with("connect:") => {
                let laptop_id = &text[8..];
                if let Err(e) = device.connect_to_laptop(laptop_id.to_string()).await {
                    println!("Failed to connect to laptop: {}", e);
                } else {
                    println!("Connected to laptop: {}", laptop_id);
                }
            }
            text if text.starts_with("llm:") => {
                let request = &text[4..];
                match device.send_llm_request(request).await {
                    Ok(response) => println!("LLM Response: {}", response),
                    Err(e) => println!("LLM request failed: {}", e),
                }
            }
            text if text.starts_with("image:") => {
                let params = &text[6..];
                let parts: Vec<&str> = params.split('|').collect();
                
                let prompt = parts[0];
                let style = parts.get(1).unwrap_or(&"realistic");
                let resolution = parts.get(2).unwrap_or(&"anbernic_screen");
                
                match device.send_image_generation_request(prompt, style, resolution).await {
                    Ok(response) => println!("Image Generation: {}", response),
                    Err(e) => println!("Image generation failed: {}", e),
                }
            }
            text if text.starts_with("save:") => {
                let file_path = &text[5..];
                device.file_operations.current_file = Some(file_path.to_string());
                device.save_current_file().await?;
                println!("Saved to: {}", file_path);
            }
            text if text.starts_with("load:") => {
                let file_path = &text[5..];
                if let Err(e) = device.load_file(file_path).await {
                    println!("Failed to load file: {}", e);
                } else {
                    println!("Loaded: {}", file_path);
                }
            }
            text if text.starts_with("join:") => {
                let session_id = &text[5..];
                if let Err(e) = device.join_collaborative_session(session_id).await {
                    println!("Failed to join session: {}", e);
                } else {
                    println!("Joined collaborative session: {}", session_id);
                }
            }
            "backup" => {
                device.create_backup().await?;
                println!("Backup created");
            }
            "recent" => {
                println!("Recent files:");
                for file in device.get_recent_files() {
                    println!("  {}", file);
                }
            }
            "peers" => {
                let peers = device.wifi_direct.get_active_peers().await;
                if peers.is_empty() {
                    println!("No active peers");
                } else {
                    println!("Active peers:");
                    for (id, nickname) in peers {
                        println!("  {} ({})", nickname, id);
                    }
                }
            }
            _ => continue,
        }

        println!("{}", device.render_display());
    }

    Ok(())
}
