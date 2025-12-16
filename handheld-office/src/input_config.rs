/// Enhanced input configuration system for handheld devices
/// Supports multiple controller layouts and customizable input methods
/// 
/// ## Edit Mode Features
/// - SELECT button enters "edit mode" where D-pad moves cursor
/// - In edit mode: B = backspace, A = open one-time keyboard, SELECT = exit
/// - Compatibility mode: SELECT+START required for edit mode (optional)
/// - Visual feedback shows edit mode status
/// 
/// ## SNES Controller Features  
/// - 6-option arc-shaped radial menus using A/B/X/Y/L/R buttons
/// - D-pad directions open different character sets:
///   - UP: Uppercase letters (A-Z across multiple arcs)
///   - DOWN: Lowercase letters (a-z across multiple arcs)  
///   - LEFT: Numbers and punctuation (0-9, space, common symbols)
///   - RIGHT: Special symbols and functions (tree menu with special options)
/// - Button combinations: L+R (emoji), X+Y (special chars), A+B (language)
/// 
/// ## User-Definable Configuration
/// All layouts, button mappings, and character sets can be customized via config files
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Configuration for different controller types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputConfig {
    pub controller_type: ControllerType,
    pub keyboard_layouts: HashMap<String, KeyboardLayout>,
    pub edit_mode_settings: EditModeSettings,
    pub special_character_sets: HashMap<String, Vec<char>>,
    pub language_layouts: HashMap<String, LanguageLayout>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ControllerType {
    GameBoy {
        // A, B, SELECT, START, D-Pad
        buttons: GameBoyButtons,
    },
    SNES {
        // A, B, X, Y, L, R, SELECT, START, D-Pad
        buttons: SNESButtons,
    },
    Custom {
        // User-defined button mapping
        button_count: usize,
        layout_name: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameBoyButtons {
    pub a: ButtonConfig,
    pub b: ButtonConfig,
    pub select: ButtonConfig,
    pub start: ButtonConfig,
    pub dpad: DPadConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SNESButtons {
    pub a: ButtonConfig,
    pub b: ButtonConfig,
    pub x: ButtonConfig,
    pub y: ButtonConfig,
    pub l: ButtonConfig,
    pub r: ButtonConfig,
    pub select: ButtonConfig,
    pub start: ButtonConfig,
    pub dpad: DPadConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ButtonConfig {
    pub primary_action: ButtonAction,
    pub secondary_action: Option<ButtonAction>, // When held with modifier
    pub edit_mode_action: Option<ButtonAction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DPadConfig {
    pub up: DirectionalAction,
    pub down: DirectionalAction,
    pub left: DirectionalAction,
    pub right: DirectionalAction,
    pub edit_mode_actions: EditModeDirections,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ButtonAction {
    Navigate,
    Select,
    Back,
    OpenKeyboard,
    SpecialCharacter,
    EnterEditMode,
    ExitEditMode,
    Backspace,
    Delete,
    ToggleMode,
    HistoryNavigation,
    OpenOneTimeKeyboard, // A button in edit mode - opens keyboard for single character
    CompatibilityModeToggle, // SELECT+START combination
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DirectionalAction {
    Navigate,
    OpenRadialMenu { character_set: String },
    CycleThroughOptions,
    MoveCursor,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EditModeDirections {
    pub up: EditModeAction,
    pub down: EditModeAction,
    pub left: EditModeAction,
    pub right: EditModeAction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EditModeAction {
    MoveCursor,
    SelectWord,
    SelectLine,
    ScrollPage,
    HistoryNavigation,
}

/// Keyboard layout for radial input systems
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyboardLayout {
    pub name: String,
    pub sectors: Vec<RadialSector>,
    pub max_characters_per_sector: usize,
    pub special_actions: Vec<SpecialAction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RadialSector {
    pub direction: Direction,
    pub characters: Vec<char>,
    pub submenu: Option<Box<RadialSector>>, // For tree-style menus
    pub action_type: SectorAction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SectorAction {
    CharacterInput,
    OpenSubmenu,
    SpecialFunction { function: SpecialFunction },
    LanguageSwitch { language: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SpecialFunction {
    EmojiKeyboard,
    NumberPad,
    SymbolKeyboard,
    AccentedCharacters,
    LanguageSelector,
    InputMethodSelector,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpecialAction {
    pub trigger: ActionTrigger,
    pub result: ActionResult,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ActionTrigger {
    ButtonCombination { buttons: Vec<String> },
    LongPress { button: String, duration_ms: u64 },
    DoublePress { button: String, max_gap_ms: u64 },
    Sequence { sequence: Vec<String> },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ActionResult {
    OpenKeyboard { layout: String },
    InsertText { text: String },
    ExecuteCommand { command: String },
    SwitchMode { mode: String },
}

/// Language-specific keyboard layouts
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageLayout {
    pub language_code: String,
    pub display_name: String,
    pub character_sets: HashMap<String, Vec<char>>,
    pub special_combinations: HashMap<String, char>, // For accented characters
    pub number_format: NumberFormat,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NumberFormat {
    pub decimal_separator: char,
    pub thousands_separator: char,
    pub currency_symbol: char,
}

/// Edit mode settings for enhanced text editing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EditModeSettings {
    pub cursor_blink_rate_ms: u64,
    pub auto_exit_timeout_ms: u64,
    pub word_wrap: bool,
    pub show_line_numbers: bool,
    pub highlight_current_line: bool,
    pub tab_size: usize,
    pub vim_mode: bool, // For advanced users
    pub compatibility_mode: bool, // SELECT+START required for edit mode
    pub visual_feedback_enabled: bool, // Show edit mode indicator
    pub one_time_keyboard_timeout_ms: u64, // Timeout for single character input
}

impl Default for InputConfig {
    fn default() -> Self {
        Self::gameboy_default()
    }
}

impl InputConfig {
    /// Default configuration for Game Boy style controllers
    pub fn gameboy_default() -> Self {
        let mut keyboard_layouts = HashMap::new();
        keyboard_layouts.insert("english".to_string(), Self::english_gameboy_layout());

        let mut special_character_sets = HashMap::new();
        special_character_sets.insert(
            "symbols".to_string(),
            vec![
                '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '+', '=',
            ],
        );
        special_character_sets.insert(
            "emojis".to_string(),
            vec![
                '😀', '😎', '👍', '❤', '🎮', '🔥', '⭐', '🚀', '💯', '🎵', '📱', '💻',
            ],
        );

        let mut language_layouts = HashMap::new();
        language_layouts.insert("en".to_string(), Self::english_language_layout());

        Self {
            controller_type: ControllerType::GameBoy {
                buttons: GameBoyButtons {
                    a: ButtonConfig {
                        primary_action: ButtonAction::Select,
                        secondary_action: Some(ButtonAction::OpenKeyboard),
                        edit_mode_action: Some(ButtonAction::OpenOneTimeKeyboard), // Single character input
                    },
                    b: ButtonConfig {
                        primary_action: ButtonAction::Back,
                        secondary_action: None,
                        edit_mode_action: Some(ButtonAction::Backspace),
                    },
                    select: ButtonConfig {
                        primary_action: ButtonAction::EnterEditMode,
                        secondary_action: Some(ButtonAction::CompatibilityModeToggle), // SELECT+START
                        edit_mode_action: Some(ButtonAction::ExitEditMode),
                    },
                    start: ButtonConfig {
                        primary_action: ButtonAction::Navigate,
                        secondary_action: None,
                        edit_mode_action: None,
                    },
                    dpad: DPadConfig {
                        up: DirectionalAction::Navigate,
                        down: DirectionalAction::Navigate,
                        left: DirectionalAction::Navigate,
                        right: DirectionalAction::Navigate,
                        edit_mode_actions: EditModeDirections {
                            up: EditModeAction::MoveCursor,
                            down: EditModeAction::MoveCursor,
                            left: EditModeAction::MoveCursor,
                            right: EditModeAction::MoveCursor,
                        },
                    },
                },
            },
            keyboard_layouts,
            edit_mode_settings: EditModeSettings {
                cursor_blink_rate_ms: 500,
                auto_exit_timeout_ms: 30000,
                word_wrap: true,
                show_line_numbers: false,
                highlight_current_line: true,
                tab_size: 4,
                vim_mode: false,
                compatibility_mode: false, // SELECT alone enters edit mode
                visual_feedback_enabled: true,
                one_time_keyboard_timeout_ms: 5000, // 5 seconds for single character input
            },
            special_character_sets,
            language_layouts,
        }
    }

    /// SNES-style controller with 6-option radial menus
    pub fn snes_default() -> Self {
        let mut config = Self::gameboy_default();

        config.controller_type = ControllerType::SNES {
            buttons: SNESButtons {
                a: ButtonConfig {
                    primary_action: ButtonAction::Select,
                    secondary_action: Some(ButtonAction::OpenKeyboard),
                    edit_mode_action: Some(ButtonAction::OpenOneTimeKeyboard),
                },
                b: ButtonConfig {
                    primary_action: ButtonAction::Back,
                    secondary_action: None,
                    edit_mode_action: Some(ButtonAction::Backspace),
                },
                x: ButtonConfig {
                    primary_action: ButtonAction::SpecialCharacter,
                    secondary_action: None,
                    edit_mode_action: Some(ButtonAction::Delete),
                },
                y: ButtonConfig {
                    primary_action: ButtonAction::SpecialCharacter,
                    secondary_action: None,
                    edit_mode_action: Some(ButtonAction::SpecialCharacter),
                },
                l: ButtonConfig {
                    primary_action: ButtonAction::Navigate,
                    secondary_action: None,
                    edit_mode_action: Some(ButtonAction::HistoryNavigation),
                },
                r: ButtonConfig {
                    primary_action: ButtonAction::Navigate,
                    secondary_action: None,
                    edit_mode_action: Some(ButtonAction::HistoryNavigation),
                },
                select: ButtonConfig {
                    primary_action: ButtonAction::EnterEditMode,
                    secondary_action: Some(ButtonAction::CompatibilityModeToggle), // SELECT+START  
                    edit_mode_action: Some(ButtonAction::ExitEditMode),
                },
                start: ButtonConfig {
                    primary_action: ButtonAction::Navigate,
                    secondary_action: None,
                    edit_mode_action: None,
                },
                dpad: DPadConfig {
                    up: DirectionalAction::OpenRadialMenu {
                        character_set: "upper_alpha".to_string(),
                    },
                    down: DirectionalAction::OpenRadialMenu {
                        character_set: "lower_alpha".to_string(),
                    },
                    left: DirectionalAction::OpenRadialMenu {
                        character_set: "numbers".to_string(),
                    },
                    right: DirectionalAction::OpenRadialMenu {
                        character_set: "symbols_and_special".to_string(),
                    },
                    edit_mode_actions: EditModeDirections {
                        up: EditModeAction::MoveCursor,
                        down: EditModeAction::MoveCursor,
                        left: EditModeAction::MoveCursor,
                        right: EditModeAction::MoveCursor,
                    },
                },
            },
        };

        // Update keyboard layouts for SNES 6-option radials
        config
            .keyboard_layouts
            .insert("snes_english".to_string(), Self::snes_english_layout());

        config
    }

    fn english_gameboy_layout() -> KeyboardLayout {
        KeyboardLayout {
            name: "English (Game Boy)".to_string(),
            sectors: vec![
                RadialSector {
                    direction: Direction::Up,
                    characters: vec!['a', 'b', 'c', 'd'],
                    submenu: None,
                    action_type: SectorAction::CharacterInput,
                },
                RadialSector {
                    direction: Direction::Down,
                    characters: vec!['e', 'f', 'g', 'h'],
                    submenu: None,
                    action_type: SectorAction::CharacterInput,
                },
                RadialSector {
                    direction: Direction::Left,
                    characters: vec!['i', 'j', 'k', 'l'],
                    submenu: None,
                    action_type: SectorAction::CharacterInput,
                },
                RadialSector {
                    direction: Direction::Right,
                    characters: vec!['m', 'n', 'o', 'p'],
                    submenu: None,
                    action_type: SectorAction::CharacterInput,
                },
            ],
            max_characters_per_sector: 4,
            special_actions: vec![SpecialAction {
                trigger: ActionTrigger::LongPress {
                    button: "A".to_string(),
                    duration_ms: 1000,
                },
                result: ActionResult::OpenKeyboard {
                    layout: "symbols".to_string(),
                },
            }],
        }
    }

    fn snes_english_layout() -> KeyboardLayout {
        KeyboardLayout {
            name: "English (SNES 6-option arc menus)".to_string(),
            sectors: vec![
                // UP direction: Uppercase letters A-F through Z (6 characters per arc, 4 complete arcs + 2 remaining)
                RadialSector {
                    direction: Direction::Up,
                    characters: vec!['A', 'B', 'C', 'D', 'E', 'F'],
                    submenu: Some(Box::new(RadialSector {
                        direction: Direction::Up,
                        characters: vec!['G', 'H', 'I', 'J', 'K', 'L'],
                        submenu: Some(Box::new(RadialSector {
                            direction: Direction::Up,
                            characters: vec!['M', 'N', 'O', 'P', 'Q', 'R'],
                            submenu: Some(Box::new(RadialSector {
                                direction: Direction::Up,
                                characters: vec!['S', 'T', 'U', 'V', 'W', 'X'],
                                submenu: Some(Box::new(RadialSector {
                                    direction: Direction::Up,
                                    characters: vec!['Y', 'Z'],
                                    submenu: None,
                                    action_type: SectorAction::CharacterInput,
                                })),
                                action_type: SectorAction::CharacterInput,
                            })),
                            action_type: SectorAction::CharacterInput,
                        })),
                        action_type: SectorAction::CharacterInput,
                    })),
                    action_type: SectorAction::CharacterInput,
                },
                // DOWN direction: Lowercase letters a-f through z
                RadialSector {
                    direction: Direction::Down,
                    characters: vec!['a', 'b', 'c', 'd', 'e', 'f'],
                    submenu: Some(Box::new(RadialSector {
                        direction: Direction::Down,
                        characters: vec!['g', 'h', 'i', 'j', 'k', 'l'],
                        submenu: Some(Box::new(RadialSector {
                            direction: Direction::Down,
                            characters: vec!['m', 'n', 'o', 'p', 'q', 'r'],
                            submenu: Some(Box::new(RadialSector {
                                direction: Direction::Down,
                                characters: vec!['s', 't', 'u', 'v', 'w', 'x'],
                                submenu: Some(Box::new(RadialSector {
                                    direction: Direction::Down,
                                    characters: vec!['y', 'z'],
                                    submenu: None,
                                    action_type: SectorAction::CharacterInput,
                                })),
                                action_type: SectorAction::CharacterInput,
                            })),
                            action_type: SectorAction::CharacterInput,
                        })),
                        action_type: SectorAction::CharacterInput,
                    })),
                    action_type: SectorAction::CharacterInput,
                },
                // LEFT direction: Numbers 0-9 plus space and common punctuation (fits in 4 arcs of 6)
                RadialSector {
                    direction: Direction::Left,
                    characters: vec!['0', '1', '2', '3', '4', '5'],
                    submenu: Some(Box::new(RadialSector {
                        direction: Direction::Left,
                        characters: vec!['6', '7', '8', '9', ' ', '.'],
                        submenu: Some(Box::new(RadialSector {
                            direction: Direction::Left,
                            characters: vec![',', '?', '!', ';', ':', '"'],
                            submenu: Some(Box::new(RadialSector {
                                direction: Direction::Left,
                                characters: vec!['\'', '-', '_', '(', ')', '/'],
                                submenu: None,
                                action_type: SectorAction::CharacterInput,
                            })),
                            action_type: SectorAction::CharacterInput,
                        })),
                        action_type: SectorAction::CharacterInput,
                    })),
                    action_type: SectorAction::CharacterInput,
                },
                // RIGHT direction: Special functions and symbols - this gets the special tree menu
                RadialSector {
                    direction: Direction::Right,
                    characters: vec!['@', '#', '$', '%', '^', '&'],
                    submenu: Some(Box::new(RadialSector {
                        direction: Direction::Right,
                        characters: vec!['*', '+', '=', '<', '>', '|'],
                        submenu: Some(Box::new(RadialSector {
                            // Tree menu with special functions
                            direction: Direction::Right,
                            characters: vec!['[', ']'],
                            submenu: Some(Box::new(RadialSector {
                                direction: Direction::Right,
                                characters: vec![],
                                submenu: None,
                                action_type: SectorAction::SpecialFunction {
                                    function: SpecialFunction::EmojiKeyboard,
                                },
                            })),
                            action_type: SectorAction::CharacterInput,
                        })),
                        action_type: SectorAction::CharacterInput,
                    })),
                    action_type: SectorAction::CharacterInput,
                },
            ],
            max_characters_per_sector: 6,
            special_actions: vec![
                // L+R for emoji keyboard
                SpecialAction {
                    trigger: ActionTrigger::ButtonCombination {
                        buttons: vec!["L".to_string(), "R".to_string()],
                    },
                    result: ActionResult::OpenKeyboard {
                        layout: "emoji".to_string(),
                    },
                },
                // X+Y for special character input
                SpecialAction {
                    trigger: ActionTrigger::ButtonCombination {
                        buttons: vec!["X".to_string(), "Y".to_string()],
                    },
                    result: ActionResult::SwitchMode {
                        mode: "special_characters".to_string(),
                    },
                },
                // A+B for language selection
                SpecialAction {
                    trigger: ActionTrigger::ButtonCombination {
                        buttons: vec!["A".to_string(), "B".to_string()],
                    },
                    result: ActionResult::OpenKeyboard {
                        layout: "language_selector".to_string(),
                    },
                },
            ],
        }
    }

    fn english_language_layout() -> LanguageLayout {
        let mut character_sets = HashMap::new();
        character_sets.insert("lowercase".to_string(), ('a'..='z').collect::<Vec<_>>());
        character_sets.insert("uppercase".to_string(), ('A'..='Z').collect::<Vec<_>>());
        character_sets.insert("numbers".to_string(), ('0'..='9').collect::<Vec<_>>());

        LanguageLayout {
            language_code: "en".to_string(),
            display_name: "English".to_string(),
            character_sets,
            special_combinations: HashMap::new(), // English doesn't need many special combinations
            number_format: NumberFormat {
                decimal_separator: '.',
                thousands_separator: ',',
                currency_symbol: '$',
            },
        }
    }

    /// Load configuration from file
    pub fn load_from_file(path: &std::path::Path) -> Result<Self, Box<dyn std::error::Error>> {
        let content = std::fs::read_to_string(path)?;
        let config = serde_json::from_str(&content)?;
        Ok(config)
    }

    /// Save configuration to file
    pub fn save_to_file(&self, path: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(path, content)?;
        Ok(())
    }

    /// Generate default configuration file
    pub fn generate_default_config_file(
        controller: ControllerType,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let config = match controller {
            ControllerType::GameBoy { .. } => Self::gameboy_default(),
            ControllerType::SNES { .. } => Self::snes_default(),
            ControllerType::Custom { .. } => Self::gameboy_default(), // Fallback
        };

        Ok(serde_json::to_string_pretty(&config)?)
    }
}
