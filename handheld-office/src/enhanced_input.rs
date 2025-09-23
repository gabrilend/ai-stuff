/// Enhanced input system with edit mode, configurable keyboards, and multi-controller support
/// Implements the proposed improvements from claude-next-2
use crate::input_config::*;
use crate::p2p_mesh::{P2PMeshManager, P2PIntegration, PeerDevice, DeviceType, SharedFile};
use crate::wifi_direct_p2p::{WiFiDirectP2P, MessageContent};
use crate::ai_image_service::{ImageGenerationRequest, ImageGenerationResponse, ImageStyle, ImageResolution};
use crate::crypto::{P2PMigrationAdapter, RelationshipId, PairingEmoji as CryptoPairingEmoji};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::time::{Duration, Instant};
use std::path::PathBuf;
use chrono;
use futures;
use base64::{Engine as _, engine::general_purpose};

// P2P integration is implemented directly in this file

/// Enhanced input manager that handles different input modes and controller types
pub struct EnhancedInputManager {
    pub config: InputConfig,
    pub current_mode: EnhancedInputMode,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub edit_mode_state: EditModeState,
    pub one_time_keyboard_state: Option<OneTimeKeyboardState>,
    pub button_states: HashMap<String, ButtonState>,
    pub last_input_time: Instant,
    
    // P2P mesh networking for document sharing (legacy)
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_documents: Vec<SharedDocument>,
    pub auto_save_enabled: bool,
    pub document_metadata: DocumentMetadata,
    pub collaboration_state: Option<CollaborationState>,
    
    // WiFi Direct P2P for AI image generation (legacy)
    pub wifi_direct: Option<WiFiDirectP2P>,
    pub wifi_direct_connected: bool,
    pub available_image_files: Vec<ImageFileEntry>,
    pub pending_image_requests: Vec<PendingImageRequest>,
    pub images_directory: PathBuf,
    
    // Secure P2P system with crypto integration
    pub secure_p2p: Option<P2PMigrationAdapter>,
    pub secure_p2p_enabled: bool,
    pub secure_relationships: Vec<RelationshipId>,
    pub pairing_mode_active: bool,
    pub discovered_secure_devices: Vec<CryptoPairingEmoji>,
}

#[derive(Debug, Clone)]
pub enum EnhancedInputMode {
    Navigation,
    EditMode,
    OneTimeKeyboard { target_mode: Box<EnhancedInputMode> },
    RadialMenu { state: RadialMenuState },
    SpecialCharacterMode,
    P2PBrowser,
    CollaborationMode,
    DocumentSaver,
    ImageMenu { submenu: ImageSubmenu },
    AIImagePrompt { prompt: String },
    SecurePairing { stage: SecurePairingStage },
    SecureDeviceSelection { devices: Vec<CryptoPairingEmoji> },
    RelationshipManager,
}

#[derive(Debug, Clone)]
pub enum ImageSubmenu {
    Main,
    FileSelection { files: Vec<ImageFileEntry> },
    AIGeneration,
}

#[derive(Debug, Clone)]
pub enum SecurePairingStage {
    /// Initiating pairing mode
    Initiating,
    /// Broadcasting our emoji and scanning
    Broadcasting { our_emoji: CryptoPairingEmoji },
    /// Showing discovered devices for selection
    DeviceSelection { devices: Vec<CryptoPairingEmoji> },
    /// Entering nickname for selected device
    NicknameEntry { target_device: CryptoPairingEmoji, partial_nickname: String },
    /// Completing pairing process
    Completing { target_device: CryptoPairingEmoji, nickname: String },
    /// Pairing completed successfully
    Completed { relationship_id: RelationshipId },
    /// Pairing failed
    Failed { error: String },
}

#[derive(Debug, Clone)]
pub struct ImageFileEntry {
    pub path: PathBuf,
    pub name: String,
    pub source: ImageSource,
    pub thumbnail_available: bool,
}

#[derive(Debug, Clone)]
pub enum ImageSource {
    Paint,
    AIGenerated,
    Shared,
    Downloaded,
}

#[derive(Debug, Clone)]
pub struct PendingImageRequest {
    pub request_id: String,
    pub prompt: String,
    pub placeholder_position: usize,
    pub target_application: String,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct EditModeState {
    pub cursor_line: usize,
    pub cursor_column: usize,
    pub selection_start: Option<CursorPosition>,
    pub selection_end: Option<CursorPosition>,
    pub word_wrap_enabled: bool,
    pub auto_exit_timer: Option<Instant>,
    pub last_cursor_move: Instant,
}

#[derive(Debug, Clone)]
pub struct CursorPosition {
    pub line: usize,
    pub column: usize,
    pub absolute_position: usize,
}

#[derive(Debug, Clone)]
pub struct OneTimeKeyboardState {
    pub layout: String,
    pub sector_index: usize,
    pub character_index: usize,
    pub return_mode: EnhancedInputMode,
    pub partial_input: String,
}

#[derive(Debug, Clone)]
pub struct ButtonState {
    pub pressed: bool,
    pub press_time: Option<Instant>,
    pub release_time: Option<Instant>,
    pub press_count: usize,
    pub last_press_time: Option<Instant>,
}

/// P2P-specific structures for word processor
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedDocument {
    pub file_hash: String,
    pub filename: String,
    pub content: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub tags: Vec<String>,
    pub file_size: usize,
    pub device_info: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentMetadata {
    pub filename: String,
    pub author: String,
    pub created_time: u64,
    pub last_modified: u64,
    pub word_count: usize,
    pub character_count: usize,
    pub tags: Vec<String>,
    pub version: u32,
}

#[derive(Debug, Clone)]
pub struct CollaborationState {
    pub session_id: String,
    pub participants: Vec<String>,
    pub document_hash: String,
    pub last_sync: u64,
    pub pending_changes: Vec<DocumentChange>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentChange {
    pub change_id: String,
    pub author: String,
    pub timestamp: u64,
    pub change_type: ChangeType,
    pub position: usize,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ChangeType {
    Insert,
    Delete,
    Replace,
    CursorMove,
}

/// Radial menu system for enhanced input
#[derive(Debug, Clone)]
pub struct RadialMenuState {
    pub center_x: f32,
    pub center_y: f32,
    pub active_direction: Direction,
    pub active_angle: f32,
    pub menu_options: [Option<char>; 4],
    pub selected_option: Option<usize>,
    pub alphabet_layout: AlphabetLayout,
    pub is_visible: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

#[derive(Debug, Clone)]
pub struct AlphabetLayout {
    pub sectors: HashMap<Direction, [char; 4]>,
}

impl Default for AlphabetLayout {
    fn default() -> Self {
        let mut sectors = HashMap::new();
        
        // Distribute A-Z across 8 directions (32 total slots, using 26)
        sectors.insert(Direction::Up, ['A', 'B', 'C', 'D']);
        sectors.insert(Direction::UpRight, ['E', 'F', 'G', 'H']);
        sectors.insert(Direction::Right, ['I', 'J', 'K', 'L']);
        sectors.insert(Direction::DownRight, ['M', 'N', 'O', 'P']);
        sectors.insert(Direction::Down, ['Q', 'R', 'S', 'T']);
        sectors.insert(Direction::DownLeft, ['U', 'V', 'W', 'X']);
        sectors.insert(Direction::Left, ['Y', 'Z', ' ', '.']);
        sectors.insert(Direction::UpLeft, ['!', '?', ',', ';']);
        
        Self { sectors }
    }
}

impl RadialMenuState {
    pub fn new(center_x: f32, center_y: f32) -> Self {
        Self {
            center_x,
            center_y,
            active_direction: Direction::Up,
            active_angle: 0.0,
            menu_options: [None; 4],
            selected_option: None,
            alphabet_layout: AlphabetLayout::default(),
            is_visible: false,
        }
    }
    
    pub fn update_direction(&mut self, direction: Direction) {
        self.active_direction = direction;
        self.active_angle = self.direction_to_angle(direction);
        self.update_menu_options();
        self.is_visible = true;
    }
    
    fn direction_to_angle(&self, direction: Direction) -> f32 {
        match direction {
            Direction::Up => 270.0,
            Direction::UpRight => 315.0,
            Direction::Right => 0.0,
            Direction::DownRight => 45.0,
            Direction::Down => 90.0,
            Direction::DownLeft => 135.0,
            Direction::Left => 180.0,
            Direction::UpLeft => 225.0,
        }
    }
    
    fn update_menu_options(&mut self) {
        if let Some(chars) = self.alphabet_layout.sectors.get(&self.active_direction) {
            for (i, &ch) in chars.iter().enumerate() {
                self.menu_options[i] = Some(ch);
            }
        } else {
            self.menu_options = [None; 4];
        }
    }
    
    pub fn get_option_positions(&self) -> [(f32, f32); 4] {
        let radius = 50.0; // Distance from center
        let base_angle_rad = self.active_angle * PI / 180.0;
        
        // Position options in an arc around the direction
        let mut positions = [(0.0, 0.0); 4];
        
        match self.active_direction {
            Direction::Left => {
                // LEFT: First two options below X-axis, next two above X-axis
                let angles = [-30.0, -60.0, 30.0, 60.0]; // Relative to left (180°)
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (180.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            Direction::UpRight => {
                // UP+RIGHT: Menu at 45° angle
                let angles = [-30.0, -15.0, 15.0, 30.0]; // Relative to 45°
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (315.0 + angle_offset) * PI / 180.0;
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            },
            _ => {
                // Default arc positioning
                let angles = [-30.0, -10.0, 10.0, 30.0]; // Spread around direction
                for (i, &angle_offset) in angles.iter().enumerate() {
                    let angle_rad = (base_angle_rad + angle_offset * PI / 180.0);
                    positions[i] = (
                        self.center_x + radius * angle_rad.cos(),
                        self.center_y + radius * angle_rad.sin(),
                    );
                }
            }
        }
        
        positions
    }
    
    pub fn select_option(&mut self, button_index: usize) -> Option<char> {
        if button_index < 4 {
            self.selected_option = Some(button_index);
            self.menu_options[button_index]
        } else {
            None
        }
    }
    
    pub fn hide(&mut self) {
        self.is_visible = false;
        self.selected_option = None;
    }
    
    /// Get visual rendering data for the radial menu
    pub fn get_render_data(&self) -> RadialMenuRenderData {
        let positions = self.get_option_positions();
        let mut options = Vec::new();
        
        for (i, pos) in positions.iter().enumerate() {
            if let Some(character) = self.menu_options[i] {
                options.push(RadialMenuOption {
                    character,
                    position: *pos,
                    selected: self.selected_option == Some(i),
                    button_hint: match i {
                        0 => "L1".to_string(),
                        1 => "B".to_string(), 
                        2 => "A".to_string(),
                        3 => "Y".to_string(),
                        _ => "".to_string(),
                    },
                });
            }
        }
        
        RadialMenuRenderData {
            center: (self.center_x, self.center_y),
            options,
            direction: self.active_direction.clone(),
            angle: self.active_angle,
            visible: self.is_visible,
        }
    }
}

/// Data structure for rendering the radial menu
#[derive(Debug, Clone)]
pub struct RadialMenuRenderData {
    pub center: (f32, f32),
    pub options: Vec<RadialMenuOption>,
    pub direction: Direction,
    pub angle: f32,
    pub visible: bool,
}

#[derive(Debug, Clone)]
pub struct RadialMenuOption {
    pub character: char,
    pub position: (f32, f32),
    pub selected: bool,
    pub button_hint: String,
}

/// Radial button inputs for universal controller support
#[derive(Debug, Clone, PartialEq)]
pub enum UniversalButton {
    // Basic buttons (Game Boy compatible)
    A,
    B,
    Select,
    Start,

    // Extended buttons (SNES compatible)
    X,
    Y,
    L,
    R,

    // D-Pad directions
    Up,
    Down,
    Left,
    Right,

    // Custom/mapped buttons
    Custom(String),
}

#[derive(Debug, Clone)]
pub enum InputResult {
    TextInput { text: String },
    InsertText { text: String },
    ReplaceText { find: String, replace: String },
    ModeChange { new_mode: EnhancedInputMode },
    CursorMove { new_position: usize },
    SpecialAction { action: String },
    Navigation { direction: String },
    StatusMessage { message: String },
    NoAction,
}

impl EnhancedInputManager {
    pub fn new(config: InputConfig) -> Self {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        Self {
            config,
            current_mode: EnhancedInputMode::Navigation,
            text_buffer: String::new(),
            cursor_position: 0,
            edit_mode_state: EditModeState {
                cursor_line: 0,
                cursor_column: 0,
                selection_start: None,
                selection_end: None,
                word_wrap_enabled: true,
                auto_exit_timer: None,
                last_cursor_move: Instant::now(),
            },
            one_time_keyboard_state: None,
            button_states: HashMap::new(),
            last_input_time: Instant::now(),
            
            // P2P fields
            p2p_manager: None,
            p2p_enabled: false,
            shared_documents: Vec::new(),
            auto_save_enabled: true,
            document_metadata: DocumentMetadata {
                filename: "untitled.txt".to_string(),
                author: "anonymous".to_string(),
                created_time: now,
                last_modified: now,
                word_count: 0,
                character_count: 0,
                tags: vec!["handheld".to_string(), "draft".to_string()],
                version: 1,
            },
            collaboration_state: None,
            
            // WiFi Direct P2P for AI image generation
            wifi_direct: None,
            wifi_direct_connected: false,
            available_image_files: Vec::new(),
            pending_image_requests: Vec::new(),
            images_directory: PathBuf::from("./images"),
            
            // Secure P2P system with crypto integration
            secure_p2p: None,
            secure_p2p_enabled: false,
            secure_relationships: Vec::new(),
            pairing_mode_active: false,
            discovered_secure_devices: Vec::new(),
        }
    }

    /// Handle button input with enhanced features
    pub fn handle_button_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        self.last_input_time = Instant::now();
        self.update_button_state(button.clone(), pressed);

        match self.current_mode.clone() {
            EnhancedInputMode::Navigation => self.handle_navigation_input(button, pressed),
            EnhancedInputMode::EditMode => self.handle_edit_mode_input(button, pressed),
            EnhancedInputMode::OneTimeKeyboard { target_mode } => {
                self.handle_one_time_keyboard_input(button, pressed, *target_mode)
            }
            EnhancedInputMode::RadialMenu { state } => {
                self.handle_radial_menu_input(button, pressed, state)
            }
            EnhancedInputMode::SpecialCharacterMode => {
                self.handle_special_character_input(button, pressed)
            }
            EnhancedInputMode::P2PBrowser => {
                self.handle_p2p_browser_input(button, pressed)
            }
            EnhancedInputMode::CollaborationMode => {
                self.handle_collaboration_mode_input(button, pressed)
            }
            EnhancedInputMode::DocumentSaver => {
                self.handle_document_saver_input(button, pressed)
            }
            EnhancedInputMode::ImageMenu { submenu } => {
                self.handle_image_menu_input(button, pressed, submenu)
            }
            EnhancedInputMode::AIImagePrompt { prompt } => {
                self.handle_ai_image_prompt_input(button, pressed, prompt)
            }
            EnhancedInputMode::SecurePairing { stage } => {
                self.handle_secure_pairing_input(button, pressed, stage)
            }
            EnhancedInputMode::SecureDeviceSelection { devices } => {
                self.handle_secure_device_selection_input(button, pressed, devices)
            }
            EnhancedInputMode::RelationshipManager => {
                self.handle_relationship_manager_input(button, pressed)
            }
        }
    }

    fn update_button_state(&mut self, button: UniversalButton, pressed: bool) {
        let button_name = format!("{:?}", button);
        let state = self
            .button_states
            .entry(button_name)
            .or_insert(ButtonState {
                pressed: false,
                press_time: None,
                release_time: None,
                press_count: 0,
                last_press_time: None,
            });

        if pressed && !state.pressed {
            // Button press detected
            state.pressed = true;
            state.press_time = Some(Instant::now());

            // Count rapid presses for double-tap detection
            if let Some(last_press) = state.last_press_time {
                if Instant::now().duration_since(last_press) < Duration::from_millis(500) {
                    state.press_count += 1;
                } else {
                    state.press_count = 1;
                }
            } else {
                state.press_count = 1;
            }
            state.last_press_time = Some(Instant::now());
        } else if !pressed && state.pressed {
            // Button release detected
            state.pressed = false;
            state.release_time = Some(Instant::now());
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT enters edit mode (as proposed)
                vec![self.enter_edit_mode()]
            }
            UniversalButton::A => {
                vec![InputResult::Navigation {
                    direction: "select".to_string(),
                }]
            }
            UniversalButton::B => {
                vec![InputResult::Navigation {
                    direction: "back".to_string(),
                }]
            }
            UniversalButton::Start => {
                // START opens P2P browser when P2P is enabled
                if self.p2p_enabled {
                    self.current_mode = EnhancedInputMode::P2PBrowser;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::Navigation {
                        direction: "menu".to_string(),
                    }]
                }
            }
            UniversalButton::X => {
                // X opens document saver (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::DocumentSaver;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Y toggles P2P features (SNES controllers)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.toggle_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => self.handle_directional_navigation(button),
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_edit_mode_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select => {
                // SELECT exits edit mode
                vec![self.exit_edit_mode()]
            }
            UniversalButton::A => {
                // A opens one-time keyboard for character input
                vec![self.enter_one_time_keyboard()]
            }
            UniversalButton::B => {
                // B acts as backspace in edit mode
                vec![self.handle_backspace()]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // D-pad moves cursor in edit mode
                vec![self.handle_cursor_movement(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_one_time_keyboard_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        return_mode: EnhancedInputMode,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Select current character and return to edit mode
                if let Some(character) = self.get_current_keyboard_character() {
                    self.current_mode = return_mode;
                    self.one_time_keyboard_state = None;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                // Cancel and return to edit mode
                self.current_mode = return_mode;
                self.one_time_keyboard_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                // Navigate through keyboard characters
                vec![self.navigate_keyboard_character(button)]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_directional_navigation(&mut self, button: UniversalButton) -> Vec<InputResult> {
        match &self.config.controller_type {
            ControllerType::SNES { .. } => {
                // Check if L or R is pressed for media functions
                let l_pressed = self.button_states.get("L").map_or(false, |s| s.pressed);
                let r_pressed = self.button_states.get("R").map_or(false, |s| s.pressed);
                
                // SNES-style: D-pad opens radial menus with proper direction mapping
                let direction = self.button_to_direction(button);
                let mut radial_state = RadialMenuState::new(400.0, 300.0); // Default screen center
                radial_state.update_direction(direction);
                
                self.current_mode = EnhancedInputMode::RadialMenu {
                    state: radial_state,
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Game Boy style: simple navigation
                let direction = match button {
                    UniversalButton::Up => "up",
                    UniversalButton::Down => "down",
                    UniversalButton::Left => "left",
                    UniversalButton::Right => "right",
                    _ => "unknown",
                };
                vec![InputResult::Navigation {
                    direction: direction.to_string(),
                }]
            }
        }
    }

    fn enter_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::EditMode;
        self.edit_mode_state.auto_exit_timer = Some(
            Instant::now()
                + Duration::from_millis(self.config.edit_mode_settings.auto_exit_timeout_ms),
        );
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn exit_edit_mode(&mut self) -> InputResult {
        self.current_mode = EnhancedInputMode::Navigation;
        self.edit_mode_state.auto_exit_timer = None;
        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn enter_one_time_keyboard(&mut self) -> InputResult {
        let layout = self
            .config
            .keyboard_layouts
            .keys()
            .next()
            .unwrap_or(&"default".to_string())
            .clone();

        self.one_time_keyboard_state = Some(OneTimeKeyboardState {
            layout: layout.clone(),
            sector_index: 0,
            character_index: 0,
            return_mode: EnhancedInputMode::EditMode,
            partial_input: String::new(),
        });

        let old_mode = self.current_mode.clone();
        self.current_mode = EnhancedInputMode::OneTimeKeyboard {
            target_mode: Box::new(old_mode),
        };

        InputResult::ModeChange {
            new_mode: self.current_mode.clone(),
        }
    }

    fn handle_backspace(&mut self) -> InputResult {
        if self.cursor_position > 0 && !self.text_buffer.is_empty() {
            self.cursor_position -= 1;
            self.text_buffer.remove(self.cursor_position);
            InputResult::TextInput {
                text: self.text_buffer.clone(),
            }
        } else {
            InputResult::NoAction
        }
    }

    fn handle_cursor_movement(&mut self, direction: UniversalButton) -> InputResult {
        self.edit_mode_state.last_cursor_move = Instant::now();

        match direction {
            UniversalButton::Left => {
                if self.cursor_position > 0 {
                    self.cursor_position -= 1;
                }
            }
            UniversalButton::Right => {
                if self.cursor_position < self.text_buffer.len() {
                    self.cursor_position += 1;
                }
            }
            UniversalButton::Up => {
                // Move up one line (if multiline)
                self.move_cursor_up();
            }
            UniversalButton::Down => {
                // Move down one line (if multiline)
                self.move_cursor_down();
            }
            _ => {}
        }

        InputResult::CursorMove {
            new_position: self.cursor_position,
        }
    }

    fn move_cursor_up(&mut self) {
        if self.edit_mode_state.cursor_line > 0 {
            self.edit_mode_state.cursor_line -= 1;
            self.update_absolute_cursor_position();
        }
    }

    fn move_cursor_down(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        if self.edit_mode_state.cursor_line < lines.len().saturating_sub(1) {
            self.edit_mode_state.cursor_line += 1;
            self.update_absolute_cursor_position();
        }
    }

    fn update_absolute_cursor_position(&mut self) {
        let lines: Vec<&str> = self.text_buffer.lines().collect();
        let mut position = 0;

        for (i, line) in lines.iter().enumerate() {
            if i == self.edit_mode_state.cursor_line {
                position += self.edit_mode_state.cursor_column.min(line.len());
                break;
            }
            position += line.len() + 1; // +1 for newline
        }

        self.cursor_position = position.min(self.text_buffer.len());
    }

    fn get_current_keyboard_character(&self) -> Option<char> {
        if let Some(state) = &self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                if let Some(sector) = layout.sectors.get(state.sector_index) {
                    return sector.characters.get(state.character_index).copied();
                }
            }
        }
        None
    }

    fn navigate_keyboard_character(&mut self, direction: UniversalButton) -> InputResult {
        if let Some(state) = &mut self.one_time_keyboard_state {
            if let Some(layout) = self.config.keyboard_layouts.get(&state.layout) {
                match direction {
                    UniversalButton::Up | UniversalButton::Down => {
                        // Move between sectors
                        match direction {
                            UniversalButton::Up => {
                                if state.sector_index > 0 {
                                    state.sector_index -= 1;
                                }
                            }
                            UniversalButton::Down => {
                                if state.sector_index < layout.sectors.len() - 1 {
                                    state.sector_index += 1;
                                }
                            }
                            _ => {}
                        }
                        state.character_index = 0; // Reset character index when changing sectors
                    }
                    UniversalButton::Left | UniversalButton::Right => {
                        // Move within sector
                        if let Some(sector) = layout.sectors.get(state.sector_index) {
                            match direction {
                                UniversalButton::Left => {
                                    if state.character_index > 0 {
                                        state.character_index -= 1;
                                    }
                                }
                                UniversalButton::Right => {
                                    if state.character_index < sector.characters.len() - 1 {
                                        state.character_index += 1;
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        InputResult::Navigation {
            direction: format!("{:?}", direction),
        }
    }

    fn insert_character_at_cursor(&mut self, character: char) -> InputResult {
        self.text_buffer.insert(self.cursor_position, character);
        self.cursor_position += character.len_utf8();

        // Update line/column tracking
        if character == '\n' {
            self.edit_mode_state.cursor_line += 1;
            self.edit_mode_state.cursor_column = 0;
        } else {
            self.edit_mode_state.cursor_column += 1;
        }

        InputResult::TextInput {
            text: self.text_buffer.clone(),
        }
    }

    fn handle_radial_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut state: RadialMenuState,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            // D-pad changes active direction and switches to new menu
            UniversalButton::Up
            | UniversalButton::Down
            | UniversalButton::Left
            | UniversalButton::Right => {
                let direction = self.button_to_direction(button);
                state.update_direction(direction);
                self.current_mode = EnhancedInputMode::RadialMenu { state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            // Face buttons (L1/X=1st, L2/B=2nd, R1/A=3rd, R2/Y=4th option)
            UniversalButton::L => {
                if let Some(character) = state.select_option(0) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::B => {
                if let Some(character) = state.select_option(1) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::A => {
                if let Some(character) = state.select_option(2) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                if let Some(character) = state.select_option(3) {
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        self.insert_character_at_cursor(character),
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Select => {
                // Exit radial menu
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }
    
    fn button_to_direction(&self, button: UniversalButton) -> Direction {
        match button {
            UniversalButton::Up => Direction::Up,
            UniversalButton::Down => Direction::Down,
            UniversalButton::Left => Direction::Left,
            UniversalButton::Right => Direction::Right,
            _ => Direction::Up, // Default
        }
    }
    
    // Support for complex directional input (UP+RIGHT, etc.)
    pub fn handle_complex_directional_input(&mut self, buttons: &[UniversalButton]) -> Direction {
        let up_pressed = buttons.contains(&UniversalButton::Up);
        let down_pressed = buttons.contains(&UniversalButton::Down);
        let left_pressed = buttons.contains(&UniversalButton::Left);
        let right_pressed = buttons.contains(&UniversalButton::Right);
        
        match (up_pressed, down_pressed, left_pressed, right_pressed) {
            (true, false, false, true) => Direction::UpRight,
            (true, false, true, false) => Direction::UpLeft,
            (false, true, false, true) => Direction::DownRight,
            (false, true, true, false) => Direction::DownLeft,
            (true, false, false, false) => Direction::Up,
            (false, true, false, false) => Direction::Down,
            (false, false, true, false) => Direction::Left,
            (false, false, false, true) => Direction::Right,
            _ => Direction::Up, // Default for ambiguous input
        }
    }

    fn handle_special_character_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        // Implementation for special character mode (emojis, symbols, etc.)
        match button {
            UniversalButton::Select => {
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Handle special character selection
                vec![InputResult::SpecialAction {
                    action: "special_char".to_string(),
                }]
            }
        }
    }


    fn handle_radial_action(&mut self, action: String) -> Vec<InputResult> {
        match action.as_str() {
            "image_menu" => {
                // Scan for available image files
                self.scan_for_image_files();
                self.current_mode = EnhancedInputMode::ImageMenu { 
                    submenu: ImageSubmenu::Main 
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "emoji_keyboard" => {
                let mut emoji_state = RadialMenuState::new(400.0, 300.0);
                // Create emoji layout
                let mut emoji_layout = AlphabetLayout::default();
                emoji_layout.sectors.insert(Direction::Up, ['😀', '😎', '👍', '❤']);
                emoji_layout.sectors.insert(Direction::Right, ['🎮', '🔥', '⭐', '✨']);
                emoji_layout.sectors.insert(Direction::Down, ['🎯', '🚀', '💯', '🎪']);
                emoji_layout.sectors.insert(Direction::Left, ['🌟', '🎨', '🎭', '🎪']);
                emoji_state.alphabet_layout = emoji_layout;
                emoji_state.update_direction(Direction::Up);
                
                self.current_mode = EnhancedInputMode::RadialMenu { state: emoji_state };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "special_chars" => {
                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            "settings" => {
                vec![InputResult::SpecialAction {
                    action: "open_settings".to_string(),
                }]
            }
            "shift_toggle" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_shift".to_string(),
                }]
            }
            "caps_lock" => {
                vec![InputResult::SpecialAction {
                    action: "toggle_caps_lock".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn handle_image_menu_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        submenu: ImageSubmenu,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match submenu {
            ImageSubmenu::Main => {
                match button {
                    UniversalButton::A => {
                        // Insert existing image
                        self.current_mode = EnhancedInputMode::ImageMenu {
                            submenu: ImageSubmenu::FileSelection {
                                files: self.available_image_files.clone(),
                            },
                        };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    UniversalButton::B => {
                        // Create new AI image (if connected)
                        if self.wifi_direct_connected {
                            self.current_mode = EnhancedInputMode::AIImagePrompt {
                                prompt: String::new(),
                            };
                            vec![InputResult::ModeChange {
                                new_mode: self.current_mode.clone(),
                            }]
                        } else {
                            vec![InputResult::StatusMessage {
                                message: "AI image generation requires laptop connection".to_string(),
                            }]
                        }
                    }
                    UniversalButton::Select => {
                        // Exit image menu
                        self.current_mode = EnhancedInputMode::Navigation;
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            ImageSubmenu::FileSelection { files } => {
                self.handle_image_file_selection(button, files)
            }
            ImageSubmenu::AIGeneration => {
                // Handle AI generation options
                vec![InputResult::NoAction]
            }
        }
    }

    fn handle_ai_image_prompt_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        mut prompt: String,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::A => {
                // Submit prompt for AI generation
                if !prompt.is_empty() {
                    self.submit_ai_image_request(prompt.clone())
                } else {
                    vec![InputResult::StatusMessage {
                        message: "Please enter a prompt".to_string(),
                    }]
                }
            }
            UniversalButton::B => {
                // Backspace
                prompt.pop();
                self.current_mode = EnhancedInputMode::AIImagePrompt { prompt };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::Select => {
                // Cancel AI image generation
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => {
                // Open character keyboard for typing prompt
                self.current_mode = EnhancedInputMode::OneTimeKeyboard {
                    target_mode: Box::new(EnhancedInputMode::AIImagePrompt { prompt }),
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
        }
    }

    fn handle_image_file_selection(
        &mut self,
        button: UniversalButton,
        files: Vec<ImageFileEntry>,
    ) -> Vec<InputResult> {
        // Navigate through available image files and select one to insert
        match button {
            UniversalButton::A => {
                // Insert selected image placeholder
                if let Some(file) = files.first() {
                    let placeholder = format!("[IMAGE:{}]", file.name);
                    self.current_mode = EnhancedInputMode::Navigation;
                    vec![
                        InputResult::InsertText { text: placeholder },
                        InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        },
                    ]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No images available".to_string(),
                    }]
                }
            }
            UniversalButton::Select => {
                // Exit file selection
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    fn scan_for_image_files(&mut self) {
        // Scan paint directory, AI generated images directory, and shared files
        self.available_image_files.clear();

        // Add paint files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("paint")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::Paint,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add AI generated files
        if let Ok(entries) = std::fs::read_dir(&self.images_directory.join("ai_generated")) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.ends_with(".png") || name.ends_with(".jpg") {
                        self.available_image_files.push(ImageFileEntry {
                            path: entry.path(),
                            name: name.to_string(),
                            source: ImageSource::AIGenerated,
                            thumbnail_available: false,
                        });
                    }
                }
            }
        }

        // Add shared files from P2P
        for shared_file in &self.shared_documents {
            if shared_file.filename.ends_with(".png") || shared_file.filename.ends_with(".jpg") {
                self.available_image_files.push(ImageFileEntry {
                    path: PathBuf::from(&shared_file.filename),
                    name: shared_file.filename.clone(),
                    source: ImageSource::Shared,
                    thumbnail_available: false,
                });
            }
        }
    }

    fn submit_ai_image_request(&mut self, prompt: String) -> Vec<InputResult> {
        let request_id = format!("img_{}", chrono::Utc::now().timestamp());
        let placeholder = format!("[AI_IMAGE_GENERATING:{}]", request_id);
        
        // Create pending request
        let pending_request = PendingImageRequest {
            request_id: request_id.clone(),
            prompt: prompt.clone(),
            placeholder_position: self.cursor_position,
            target_application: "document".to_string(),
            timestamp: Instant::now(),
        };
        
        self.pending_image_requests.push(pending_request);
        
        // Send WiFi Direct request if connected
        if let Some(ref wifi_direct) = self.wifi_direct {
            // This will be handled asynchronously
            let paired_devices = futures::executor::block_on(wifi_direct.get_active_peers());
            if let Some((device_id, _)) = paired_devices.into_iter().next() {
                let image_request = ImageGenerationRequest {
                    request_id: request_id.clone(),
                    sender_device_id: wifi_direct.device_id.clone(),
                    prompt: prompt.clone(),
                    negative_prompt: None,
                    style: ImageStyle::Realistic,
                    resolution: ImageResolution::Square512,
                    steps: 20,
                    guidance_scale: 7.5,
                    seed: None,
                    timestamp: chrono::Utc::now().timestamp() as u64,
                };
                
                // Send request (this would be async in real implementation)
                let _ = futures::executor::block_on(
                    wifi_direct.send_message(&device_id, MessageContent::ImageGenerationRequest {
                        request_id: image_request.request_id,
                        prompt: image_request.prompt,
                        style: "realistic".to_string(),
                        resolution: "512x512".to_string(),
                        steps: 20,
                        guidance_scale: 7.5,
                    })
                );
            }
        }
        
        // Return to navigation mode and insert placeholder
        self.current_mode = EnhancedInputMode::Navigation;
        vec![
            InputResult::InsertText { text: placeholder },
            InputResult::ModeChange {
                new_mode: self.current_mode.clone(),
            },
            InputResult::StatusMessage {
                message: format!("AI image generation started: {}", prompt),
            },
        ]
    }

    /// Initialize WiFi Direct connection
    pub fn set_wifi_direct(&mut self, wifi_direct: Option<WiFiDirectP2P>) {
        self.wifi_direct = wifi_direct;
        self.update_wifi_direct_status();
    }
    
    /// Update WiFi Direct connection status
    pub fn update_wifi_direct_status(&mut self) {
        if let Some(ref wifi_direct) = self.wifi_direct {
            // Check if any devices are connected
            let peers = futures::executor::block_on(wifi_direct.get_active_peers());
            self.wifi_direct_connected = !peers.is_empty();
        } else {
            self.wifi_direct_connected = false;
        }
    }
    
    /// Handle received AI image generation response
    pub fn handle_ai_image_response(&mut self, response: ImageGenerationResponse) -> Vec<InputResult> {
        // Find pending request
        if let Some(pos) = self.pending_image_requests.iter().position(|r| r.request_id == response.request_id) {
            let pending_request = self.pending_image_requests.remove(pos);
            
            if response.success {
                // Replace placeholder with actual image reference
                let replacement_text = if let Some(image_path) = response.image_path {
                    format!("[IMAGE:{}]", image_path)
                } else {
                    format!("[AI_IMAGE:{}]", response.request_id)
                };
                
                // Save the image if data is provided
                if let Some(image_data) = response.image_data {
                    let image_filename = format!("ai_generated_{}.png", response.request_id);
                    let image_path = self.images_directory.join("ai_generated").join(&image_filename);
                    
                    // Create directory if it doesn't exist
                    if let Some(parent) = image_path.parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    
                    // Decode and save image
                    if let Ok(decoded_data) = general_purpose::STANDARD.decode(&image_data) {
                        if std::fs::write(&image_path, decoded_data).is_ok() {
                            // Add to available images
                            self.available_image_files.push(ImageFileEntry {
                                path: image_path,
                                name: image_filename.clone(),
                                source: ImageSource::AIGenerated,
                                thumbnail_available: false,
                            });
                        }
                    }
                }
                
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: replacement_text,
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation completed: {}", pending_request.prompt),
                    },
                ]
            } else {
                let error_msg = response.error_message.unwrap_or_else(|| "Unknown error".to_string());
                vec![
                    InputResult::ReplaceText {
                        find: format!("[AI_IMAGE_GENERATING:{}]", response.request_id),
                        replace: format!("[AI_IMAGE_FAILED:{}]", error_msg),
                    },
                    InputResult::StatusMessage {
                        message: format!("AI image generation failed: {}", error_msg),
                    },
                ]
            }
        } else {
            vec![InputResult::StatusMessage {
                message: "Received unknown AI image response".to_string(),
            }]
        }
    }

    /// Check for auto-exit conditions and timeouts
    pub fn update(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        // Check for edit mode auto-exit
        if let EnhancedInputMode::EditMode = self.current_mode {
            if let Some(exit_time) = self.edit_mode_state.auto_exit_timer {
                if Instant::now() > exit_time {
                    results.push(self.exit_edit_mode());
                }
            }
        }

        // Check for long press actions
        results.extend(self.check_long_press_actions());

        results
    }

    fn check_long_press_actions(&mut self) -> Vec<InputResult> {
        let mut results = Vec::new();

        for (button_name, state) in &self.button_states {
            if state.pressed {
                if let Some(press_time) = state.press_time {
                    let duration = Instant::now().duration_since(press_time);

                    // Check for 1-second long press for special actions
                    if duration >= Duration::from_millis(1000) {
                        match button_name.as_str() {
                            "A" => {
                                // Long press A for special character mode
                                self.current_mode = EnhancedInputMode::SpecialCharacterMode;
                                results.push(InputResult::ModeChange {
                                    new_mode: self.current_mode.clone(),
                                });
                            }
                            _ => {}
                        }
                    }
                }
            }
        }

        results
    }
    
    /// Get radial menu rendering data for UI display
    pub fn get_radial_menu_render_data(&self) -> Option<RadialMenuRenderData> {
        if let EnhancedInputMode::RadialMenu { state } = &self.current_mode {
            if state.is_visible {
                return Some(state.get_render_data());
            }
        }
        None
    }

    /// Get current input mode status for UI display
    pub fn get_mode_display(&self) -> String {
        match &self.current_mode {
            EnhancedInputMode::Navigation => "Navigation".to_string(),
            EnhancedInputMode::EditMode => "Edit Mode".to_string(),
            EnhancedInputMode::OneTimeKeyboard { .. } => "Keyboard".to_string(),
            EnhancedInputMode::RadialMenu { state } => format!("Radial: {:?}", state.active_direction),
            EnhancedInputMode::SpecialCharacterMode => "Special Characters".to_string(),
            EnhancedInputMode::P2PBrowser => "P2P Browser".to_string(),
            EnhancedInputMode::CollaborationMode => "Collaboration".to_string(),
            EnhancedInputMode::DocumentSaver => "Document Saver".to_string(),
            EnhancedInputMode::ImageMenu { submenu } => {
                match submenu {
                    ImageSubmenu::Main => "Image Menu".to_string(),
                    ImageSubmenu::FileSelection { .. } => "Select Image File".to_string(),
                    ImageSubmenu::AIGeneration => "AI Image Generation".to_string(),
                }
            }
            EnhancedInputMode::AIImagePrompt { .. } => "AI Image Prompt".to_string(),
            EnhancedInputMode::SecurePairing { .. } => "Secure Pairing".to_string(),
            EnhancedInputMode::SecureDeviceSelection { .. } => "Select Device".to_string(),
            EnhancedInputMode::RelationshipManager => "Relationship Manager".to_string(),
        }
    }

    /// Draw a simple ASCII representation of the radial menu (for terminal display)
    pub fn draw_radial_menu_ascii(&self) -> String {
        if let Some(render_data) = self.get_radial_menu_render_data() {
            let mut output = String::new();
            output.push_str(&format!("\n=== Radial Menu ({:?}) ===\n", render_data.direction));
            output.push_str("       ○ (center)\n");
            output.push_str("\n");
            
            for (i, option) in render_data.options.iter().enumerate() {
                let marker = if option.selected { "►" } else { " " };
                output.push_str(&format!(
                    "{} [{}] {} - '{}'\n", 
                    marker, 
                    option.button_hint, 
                    if option.selected { "<<" } else { "  " },
                    option.character
                ));
            }
            
            output.push_str("\nPress D-pad to change direction\n");
            output.push_str("Press L1/B/A/Y to select option\n");
            output.push_str("Press SELECT to exit\n");
            output
        } else {
            String::from("Radial menu not active")
        }
    }

    /// Get cursor information for UI display
    pub fn get_cursor_info(&self) -> CursorInfo {
        CursorInfo {
            position: self.cursor_position,
            line: self.edit_mode_state.cursor_line,
            column: self.edit_mode_state.cursor_column,
            text_length: self.text_buffer.len(),
        }
    }

    /// Load a different controller configuration
    pub fn switch_controller_config(&mut self, new_config: InputConfig) {
        self.config = new_config;
        // Reset state to ensure compatibility
        self.current_mode = EnhancedInputMode::Navigation;
        self.button_states.clear();
    }
    
    /// Set radial menu center position (for different screen sizes)
    pub fn set_radial_menu_center(&mut self, x: f32, y: f32) {
        if let EnhancedInputMode::RadialMenu { state } = &mut self.current_mode {
            state.center_x = x;
            state.center_y = y;
        }
    }
    /// Handle P2P browser input
    fn handle_p2p_browser_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit P2P browser
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Download/open selected document
                vec![InputResult::SpecialAction {
                    action: "download_document".to_string(),
                }]
            }
            UniversalButton::X => {
                // Share current document
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![self.share_current_document()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Enter collaboration mode
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::CollaborationMode;
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Up => {
                vec![InputResult::Navigation {
                    direction: "browse_up".to_string(),
                }]
            }
            UniversalButton::Down => {
                vec![InputResult::Navigation {
                    direction: "browse_down".to_string(),
                }]
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle collaboration mode input
    fn handle_collaboration_mode_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit collaboration mode
                self.current_mode = EnhancedInputMode::Navigation;
                self.collaboration_state = None;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Sync current changes
                vec![self.sync_collaborative_changes()]
            }
            UniversalButton::X => {
                // View participant list
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    vec![InputResult::SpecialAction {
                        action: "view_participants".to_string(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle document saver input
    fn handle_document_saver_input(&mut self, button: UniversalButton, pressed: bool) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit document saver
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Save document locally
                vec![self.save_document_locally()]
            }
            UniversalButton::X => {
                // Export to P2P network
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) && self.p2p_enabled {
                    vec![self.export_to_p2p()]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            UniversalButton::Y => {
                // Quick auto-save toggle
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.auto_save_enabled = !self.auto_save_enabled;
                    let status = if self.auto_save_enabled { "enabled" } else { "disabled" };
                    vec![InputResult::SpecialAction {
                        action: format!("auto_save_{}", status),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

#[derive(Debug, Clone)]
pub struct CursorInfo {
    pub position: usize,
    pub line: usize,
    pub column: usize,
    pub text_length: usize,
}

impl Default for EnhancedInputManager {
    fn default() -> Self {
        Self::new(InputConfig::default())
    }
}

/// Convenience functions for creating input managers with different configurations
impl EnhancedInputManager {
    pub fn gameboy_style() -> Self {
        Self::new(InputConfig::gameboy_default())
    }

    pub fn snes_style() -> Self {
        Self::new(InputConfig::snes_default())
    }

    pub fn from_config_file(path: &std::path::Path) -> Result<Self, Box<dyn std::error::Error>> {
        let config = InputConfig::load_from_file(path)?;
        Ok(Self::new(config))
    }

    /// Initialize P2P networking for document sharing
    pub fn enable_p2p(&mut self, device_name: String) -> Result<(), Box<dyn std::error::Error>> {
        if !self.p2p_enabled {
            let manager = P2PMeshManager::new(device_name, DeviceType::Anbernic("word_processor".to_string()))?;
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

    /// Toggle P2P functionality
    pub fn toggle_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.disable_p2p();
            InputResult::SpecialAction {
                action: "P2P disabled".to_string(),
            }
        } else {
            if let Err(_) = self.enable_p2p("handheld_device".to_string()) {
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

    /// Share current document via P2P
    pub fn share_current_document(&mut self) -> InputResult {
        if let Some(_manager) = &mut self.p2p_manager {
            let shared_doc = SharedDocument {
                file_hash: self.calculate_document_hash(),
                filename: self.document_metadata.filename.clone(),
                content: self.text_buffer.clone(),
                author: self.document_metadata.author.clone(),
                created_time: self.document_metadata.created_time,
                last_modified: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                tags: self.document_metadata.tags.clone(),
                file_size: self.text_buffer.len(),
                device_info: "handheld_word_processor".to_string(),
            };

            self.shared_documents.push(shared_doc.clone());
            
            InputResult::SpecialAction {
                action: format!("shared_document_{}", shared_doc.filename),
            }
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Sync collaborative changes
    pub fn sync_collaborative_changes(&mut self) -> InputResult {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
            
            collaboration_state.last_sync = now;
            
            let change_count = collaboration_state.pending_changes.len();
            collaboration_state.pending_changes.clear();
            
            InputResult::SpecialAction {
                action: format!("synced_{}_changes", change_count),
            }
        } else {
            InputResult::SpecialAction {
                action: "no_collaboration_session".to_string(),
            }
        }
    }

    /// Save document locally
    pub fn save_document_locally(&mut self) -> InputResult {
        self.update_document_metadata();
        
        InputResult::SpecialAction {
            action: format!("saved_{}", self.document_metadata.filename),
        }
    }

    /// Export document to P2P network
    pub fn export_to_p2p(&mut self) -> InputResult {
        if self.p2p_enabled {
            self.share_current_document()
        } else {
            InputResult::SpecialAction {
                action: "p2p_not_enabled".to_string(),
            }
        }
    }

    /// Calculate hash for current document
    pub fn calculate_document_hash(&self) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        self.text_buffer.hash(&mut hasher);
        self.document_metadata.filename.hash(&mut hasher);
        format!("{:x}", hasher.finish())
    }

    /// Update document metadata
    pub fn update_document_metadata(&mut self) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        self.document_metadata.last_modified = now;
        self.document_metadata.character_count = self.text_buffer.len();
        self.document_metadata.word_count = self.text_buffer.split_whitespace().count();
        self.document_metadata.version += 1;
    }

    /// Get P2P status information
    pub async fn get_p2p_status(&self) -> P2PStatus {
        let peer_count = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.len()
        } else {
            0
        };
        
        P2PStatus {
            enabled: self.p2p_enabled,
            peer_count,
            shared_documents_count: self.shared_documents.len(),
            collaboration_active: self.collaboration_state.is_some(),
        }
    }

    /// Start a collaborative editing session
    pub async fn start_collaboration_session(&mut self, session_id: String) {
        let participants = if let Some(manager) = &self.p2p_manager {
            manager.get_peers().await.into_iter().map(|p| p.device_id).collect()
        } else {
            Vec::new()
        };
        
        self.collaboration_state = Some(CollaborationState {
            session_id,
            participants,
            document_hash: self.calculate_document_hash(),
            last_sync: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            pending_changes: Vec::new(),
        });
    }

    /// Add a collaborative change to the pending queue
    pub fn add_collaborative_change(&mut self, change_type: ChangeType, position: usize, content: String) {
        if let Some(collaboration_state) = &mut self.collaboration_state {
            let change = DocumentChange {
                change_id: format!("{}-{}", 
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos(),
                    position
                ),
                author: self.document_metadata.author.clone(),
                timestamp: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
                change_type,
                position,
                content,
            };
            
            collaboration_state.pending_changes.push(change);
        }
    }

    /// Handle secure pairing input
    fn handle_secure_pairing_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        stage: SecurePairingStage,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit secure pairing
                self.current_mode = EnhancedInputMode::Navigation;
                self.pairing_mode_active = false;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Progress through pairing stages
                match stage {
                    SecurePairingStage::Initiating => {
                        // Start pairing process
                        vec![InputResult::SpecialAction {
                            action: "start_secure_pairing".to_string(),
                        }]
                    }
                    SecurePairingStage::DeviceSelection { devices } => {
                        // Move to device selection mode
                        self.current_mode = EnhancedInputMode::SecureDeviceSelection { devices };
                        vec![InputResult::ModeChange {
                            new_mode: self.current_mode.clone(),
                        }]
                    }
                    _ => vec![InputResult::NoAction],
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle secure device selection input
    fn handle_secure_device_selection_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
        devices: Vec<CryptoPairingEmoji>,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Go back to pairing mode
                self.current_mode = EnhancedInputMode::SecurePairing {
                    stage: SecurePairingStage::DeviceSelection { devices },
                };
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // Select current device (simplified - would need navigation)
                if let Some(device) = devices.first() {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::NicknameEntry {
                            target_device: device.clone(),
                            partial_nickname: String::new(),
                        },
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::StatusMessage {
                        message: "No devices available".to_string(),
                    }]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }

    /// Handle relationship manager input
    fn handle_relationship_manager_input(
        &mut self,
        button: UniversalButton,
        pressed: bool,
    ) -> Vec<InputResult> {
        if !pressed {
            return vec![InputResult::NoAction];
        }

        match button {
            UniversalButton::Select | UniversalButton::B => {
                // Exit relationship manager
                self.current_mode = EnhancedInputMode::Navigation;
                vec![InputResult::ModeChange {
                    new_mode: self.current_mode.clone(),
                }]
            }
            UniversalButton::A => {
                // View relationship details
                vec![InputResult::SpecialAction {
                    action: "view_relationship_details".to_string(),
                }]
            }
            UniversalButton::X => {
                // Start new pairing (if SNES controller)
                if matches!(self.config.controller_type, ControllerType::SNES { .. }) {
                    self.current_mode = EnhancedInputMode::SecurePairing {
                        stage: SecurePairingStage::Initiating,
                    };
                    vec![InputResult::ModeChange {
                        new_mode: self.current_mode.clone(),
                    }]
                } else {
                    vec![InputResult::NoAction]
                }
            }
            _ => vec![InputResult::NoAction],
        }
    }
}

impl std::fmt::Debug for EnhancedInputManager {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EnhancedInputManager")
            .field("config", &self.config)
            .field("current_mode", &self.current_mode)
            .field("text_buffer", &self.text_buffer)
            .field("cursor_position", &self.cursor_position)
            .field("edit_mode_state", &self.edit_mode_state)
            .field("one_time_keyboard_state", &self.one_time_keyboard_state)
            .field("button_states", &self.button_states)
            .field("last_input_time", &self.last_input_time)
            .field("p2p_enabled", &self.p2p_enabled)
            .field("shared_documents", &self.shared_documents)
            .field("auto_save_enabled", &self.auto_save_enabled)
            .field("document_metadata", &self.document_metadata)
            .field("collaboration_state", &self.collaboration_state)
            .field("p2p_manager", &"<P2PMeshManager>")
            .finish()
    }
}

/// P2P status information for UI display
#[derive(Debug, Clone)]
pub struct P2PStatus {
    pub enabled: bool,
    pub peer_count: usize,
    pub shared_documents_count: usize,
    pub collaboration_active: bool,
}

/// Implement P2P integration trait for enhanced input manager
impl P2PIntegration for EnhancedInputManager {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager.as_ref().expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: std::path::PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        self.get_p2p_manager()
            .share_file(file_path, None, vec!["document".to_string(), "handheld".to_string()])
            .await
    }

    async fn search_shared_files(
        &self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        self.get_p2p_manager().search_files(query, vec!["document".to_string()]).await
    }

    async fn get_mesh_peers(&self) -> Vec<PeerDevice> {
        self.get_p2p_manager().get_peers().await
    }
}
