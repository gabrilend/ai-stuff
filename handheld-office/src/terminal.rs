use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

/// Radial menu-based terminal emulator for Anbernic devices
/// Provides filesystem navigation and interactive bash command configuration
#[derive(Debug, Clone)]
pub struct AnbernicTerminal {
    pub current_directory: PathBuf,
    pub command_history: Vec<CommandEntry>,
    pub filesystem_cache: FilesystemCache,
    pub input_state: TerminalInputState,
    pub ui_state: TerminalUIState,
    pub command_builder: CommandBuilder,
    pub radial_keyboard: RadialKeyboard,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandEntry {
    pub command: String,
    pub working_directory: PathBuf,
    pub timestamp: DateTime<Utc>,
    pub exit_code: Option<i32>,
    pub output: String,
    pub error: String,
}

#[derive(Debug, Clone)]
pub struct FilesystemCache {
    pub current_entries: Vec<FilesystemEntry>,
    pub parent_directory: Option<PathBuf>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilesystemEntry {
    pub name: String,
    pub path: PathBuf,
    pub entry_type: EntryType,
    pub size: Option<u64>,
    pub permissions: String,
    pub modified: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EntryType {
    Directory,
    File,
    SymLink,
    Executable,
    Hidden,
}

/// Radial menu input system for terminal navigation
#[derive(Debug, Clone)]
pub struct TerminalInputState {
    pub current_group: InputGroup,
    pub selected_index: usize,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub input_mode: InputMode,
    pub command_cursor: usize,
}

#[derive(Debug, Clone)]
pub enum InputGroup {
    MainMenu,          // Navigate, Command, History, Settings
    FilesystemBrowser, // Directory navigation
    CommandBuilder,    // Build bash commands
    ParameterEntry,    // Enter command parameters
    FlagSelection,     // Select command flags
    History,           // Command history
    Settings,          // Terminal settings
}

#[derive(Debug, Clone)]
pub enum InputMode {
    Navigation,    // A/B navigate, L/R select
    TextEntry,     // Radial keyboard input
    TextEditMode,  // Enhanced edit mode with cursor navigation
    RadialMenu,    // Circular menu selection
    FileExplorer,  // Filesystem navigation
    CommandConfig, // Interactive command configuration
}

/// Game Boy style UI state for terminal
#[derive(Debug, Clone)]
pub struct TerminalUIState {
    pub current_view: TerminalView,
    pub selected_file_index: usize,
    pub scroll_offset: usize,
    pub show_help: bool,
    pub animation_frame: u32,
    pub show_hidden_files: bool,
    pub terminal_width: usize,
    pub terminal_height: usize,
}

#[derive(Debug, Clone)]
pub enum TerminalView {
    MainMenu,
    FilesystemBrowser,
    CommandBuilder,
    CommandOutput,
    History,
    Settings,
}

/// Interactive bash command builder with radial menu flag selection
#[derive(Debug, Clone)]
pub struct CommandBuilder {
    pub base_command: String,
    pub selected_flags: Vec<CommandFlag>,
    pub parameters: HashMap<String, String>,
    pub available_commands: HashMap<String, CommandTemplate>,
    pub build_state: BuildState,
}

#[derive(Debug, Clone)]
pub enum BuildState {
    SelectingCommand,
    SelectingFlags,
    EnteringParameters,
    ReviewingCommand,
    Ready,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandTemplate {
    pub name: String,
    pub description: String,
    pub common_flags: Vec<CommandFlag>,
    pub requires_path: bool,
    pub example_usage: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandFlag {
    pub short: Option<String>, // -l
    pub long: Option<String>,  // --list
    pub description: String,
    pub takes_value: bool,
    pub value_type: ValueType,
    pub conflicts_with: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValueType {
    None,
    String,
    Integer,
    Path,
    Boolean,
}

/// Radial keyboard for text input using directional buttons
#[derive(Debug, Clone)]
pub struct RadialKeyboard {
    pub current_sector: KeyboardSector,
    pub shift_mode: bool,
    pub caps_mode: bool,
    pub selected_char_index: usize,
}

#[derive(Debug, Clone)]
pub enum KeyboardSector {
    Letters,    // A-Z
    Numbers,    // 0-9
    Symbols,    // !@#$%^&*()
    Navigation, // Space, Enter, Backspace, Tab
}

/// Radial button mapping (consistent with email client)
#[derive(Debug, Clone)]
pub enum RadialButton {
    A, // Up/North
    B, // Down/South
    L, // Left/West
    R, // Right/East
}

impl AnbernicTerminal {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let current_directory = std::env::current_dir()?;
        let filesystem_cache = FilesystemCache::new(&current_directory)?;

        let command_templates = Self::load_command_templates();

        Ok(Self {
            current_directory,
            command_history: Vec::new(),
            filesystem_cache,
            input_state: TerminalInputState::default(),
            ui_state: TerminalUIState::default(),
            command_builder: CommandBuilder::new(command_templates),
            radial_keyboard: RadialKeyboard::default(),
        })
    }

    /// Load common bash command templates with their flags and options
    fn load_command_templates() -> HashMap<String, CommandTemplate> {
        let mut templates = HashMap::new();

        // ls command
        templates.insert(
            "ls".to_string(),
            CommandTemplate {
                name: "ls".to_string(),
                description: "List directory contents".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-l".to_string()),
                        long: Some("--long".to_string()),
                        description: "Long format listing".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-a".to_string()),
                        long: Some("--all".to_string()),
                        description: "Show hidden files".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-h".to_string()),
                        long: Some("--human-readable".to_string()),
                        description: "Human readable sizes".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "ls -la /home/user".to_string(),
            },
        );

        // cp command
        templates.insert(
            "cp".to_string(),
            CommandTemplate {
                name: "cp".to_string(),
                description: "Copy files or directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Copy directories recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-v".to_string()),
                        long: Some("--verbose".to_string()),
                        description: "Verbose output".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "cp -r source/ destination/".to_string(),
            },
        );

        // grep command
        templates.insert(
            "grep".to_string(),
            CommandTemplate {
                name: "grep".to_string(),
                description: "Search text patterns".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-i".to_string()),
                        long: Some("--ignore-case".to_string()),
                        description: "Case insensitive search".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-r".to_string()),
                        long: Some("--recursive".to_string()),
                        description: "Search recursively".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-n".to_string()),
                        long: Some("--line-number".to_string()),
                        description: "Show line numbers".to_string(),
                        takes_value: false,
                        value_type: ValueType::None,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: false,
                example_usage: "grep -in pattern file.txt".to_string(),
            },
        );

        // find command
        templates.insert(
            "find".to_string(),
            CommandTemplate {
                name: "find".to_string(),
                description: "Search for files and directories".to_string(),
                common_flags: vec![
                    CommandFlag {
                        short: Some("-name".to_string()),
                        long: None,
                        description: "Search by name pattern".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-type".to_string()),
                        long: None,
                        description: "File type (f=file, d=directory)".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                    CommandFlag {
                        short: Some("-size".to_string()),
                        long: None,
                        description: "File size criteria".to_string(),
                        takes_value: true,
                        value_type: ValueType::String,
                        conflicts_with: vec![],
                    },
                ],
                requires_path: true,
                example_usage: "find /path -name '*.txt' -type f".to_string(),
            },
        );

        templates
    }

    /// Navigate to a different directory and update filesystem cache
    pub fn change_directory(&mut self, path: &PathBuf) -> Result<(), Box<dyn std::error::Error>> {
        let new_path = if path.is_relative() {
            self.current_directory.join(path)
        } else {
            path.clone()
        };

        if new_path.exists() && new_path.is_dir() {
            self.current_directory = new_path.canonicalize()?;
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
            self.ui_state.selected_file_index = 0;
            self.ui_state.scroll_offset = 0;
            Ok(())
        } else {
            Err("Directory does not exist".into())
        }
    }

    /// Execute a bash command and capture output
    pub fn execute_command(
        &mut self,
        command: &str,
    ) -> Result<CommandEntry, Box<dyn std::error::Error>> {
        let start_time = Utc::now();

        let output = Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(&self.current_directory)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()?;

        let entry = CommandEntry {
            command: command.to_string(),
            working_directory: self.current_directory.clone(),
            timestamp: start_time,
            exit_code: output.status.code(),
            output: String::from_utf8_lossy(&output.stdout).to_string(),
            error: String::from_utf8_lossy(&output.stderr).to_string(),
        };

        self.command_history.push(entry.clone());

        // Update filesystem cache if command might have changed directory contents
        if command.starts_with("mkdir")
            || command.starts_with("rm")
            || command.starts_with("mv")
            || command.starts_with("cp")
        {
            self.filesystem_cache = FilesystemCache::new(&self.current_directory)?;
        }

        Ok(entry)
    }

    /// Handle radial button input based on current mode
    pub fn handle_input(&mut self, button: RadialButton) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.input_mode {
            InputMode::Navigation => self.handle_navigation_input(button),
            InputMode::TextEntry => self.handle_text_input(button),
            InputMode::RadialMenu => self.handle_radial_menu_input(button),
            InputMode::FileExplorer => self.handle_file_explorer_input(button),
            InputMode::CommandConfig => self.handle_command_config_input(button),
            InputMode::TextEditMode => self.handle_text_edit_input(button),
        }
    }

    fn handle_navigation_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_state.current_group {
            InputGroup::MainMenu => {
                match button {
                    RadialButton::A => {
                        if self.input_state.selected_index > 0 {
                            self.input_state.selected_index -= 1;
                        }
                    }
                    RadialButton::B => {
                        self.input_state.selected_index = (self.input_state.selected_index + 1) % 4;
                        // 4 main menu items
                    }
                    RadialButton::R => {
                        // Select current menu item
                        match self.input_state.selected_index {
                            0 => {
                                self.ui_state.current_view = TerminalView::FilesystemBrowser;
                                self.input_state.current_group = InputGroup::FilesystemBrowser;
                                self.input_state.input_mode = InputMode::FileExplorer;
                            }
                            1 => {
                                self.ui_state.current_view = TerminalView::CommandBuilder;
                                self.input_state.current_group = InputGroup::CommandBuilder;
                                self.input_state.input_mode = InputMode::CommandConfig;
                            }
                            2 => {
                                self.ui_state.current_view = TerminalView::History;
                                self.input_state.current_group = InputGroup::History;
                            }
                            3 => {
                                self.ui_state.current_view = TerminalView::Settings;
                                self.input_state.current_group = InputGroup::Settings;
                            }
                            _ => {}
                        }
                        self.input_state.selected_index = 0;
                    }
                    RadialButton::L => {
                        // Back to main menu
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                        self.input_state.selected_index = 0;
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.radial_keyboard
            .handle_input(button, &mut self.input_state.text_buffer)
    }

    fn handle_radial_menu_input(
        &mut self,
        _button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Implement radial menu navigation
        Ok(())
    }

    fn handle_file_explorer_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                if self.ui_state.selected_file_index > 0 {
                    self.ui_state.selected_file_index -= 1;
                }
            }
            RadialButton::B => {
                if self.ui_state.selected_file_index
                    < self
                        .filesystem_cache
                        .current_entries
                        .len()
                        .saturating_sub(1)
                {
                    self.ui_state.selected_file_index += 1;
                }
            }
            RadialButton::R => {
                // Enter directory or select file
                if let Some(entry) = self
                    .filesystem_cache
                    .current_entries
                    .get(self.ui_state.selected_file_index)
                {
                    match entry.entry_type {
                        EntryType::Directory => {
                            let path = entry.path.clone();
                            let _ = entry; // Release the borrow
                            self.change_directory(&path)?;
                        }
                        _ => {
                            // Add file path to command builder if in that mode
                            if let BuildState::EnteringParameters = self.command_builder.build_state
                            {
                                self.input_state.text_buffer =
                                    entry.path.to_string_lossy().to_string();
                            }
                        }
                    }
                }
            }
            RadialButton::L => {
                // Go up one directory
                let parent_path = self.filesystem_cache.parent_directory.clone();
                if let Some(parent_path) = parent_path {
                    self.change_directory(&parent_path)?;
                }
            }
        }
        Ok(())
    }

    fn handle_command_config_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                // Navigate through available commands
                match button {
                    RadialButton::A | RadialButton::B => {
                        // Cycle through commands
                        let commands: Vec<_> =
                            self.command_builder.available_commands.keys().collect();
                        if !commands.is_empty() {
                            let current_cmd = &self.command_builder.base_command;
                            if let Some(current_index) =
                                commands.iter().position(|&cmd| cmd == current_cmd)
                            {
                                let new_index = match button {
                                    RadialButton::A => {
                                        if current_index > 0 {
                                            current_index - 1
                                        } else {
                                            commands.len() - 1
                                        }
                                    }
                                    RadialButton::B => (current_index + 1) % commands.len(),
                                    _ => current_index,
                                };
                                self.command_builder.base_command = commands[new_index].clone();
                            }
                        }
                    }
                    RadialButton::R => {
                        self.command_builder.build_state = BuildState::SelectingFlags;
                    }
                    RadialButton::L => {
                        self.ui_state.current_view = TerminalView::MainMenu;
                        self.input_state.current_group = InputGroup::MainMenu;
                        self.input_state.input_mode = InputMode::Navigation;
                    }
                }
            }
            BuildState::SelectingFlags => {
                // Select flags for the current command
                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    match button {
                        RadialButton::A | RadialButton::B => {
                            // Navigate through flags
                        }
                        RadialButton::R => {
                            // Toggle flag selection
                        }
                        RadialButton::L => {
                            self.command_builder.build_state = BuildState::SelectingCommand;
                        }
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_text_edit_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Placeholder implementation for TextEditMode
        match button {
            RadialButton::L => {
                // Exit text edit mode
                self.input_state.input_mode = InputMode::Navigation;
            }
            _ => {
                // TODO: Implement actual text editing functionality
            }
        }
        Ok(())
    }

    /// Render the current terminal state as ASCII art (Game Boy style)
    pub fn render(&self) -> String {
        match self.ui_state.current_view {
            TerminalView::MainMenu => self.render_main_menu(),
            TerminalView::FilesystemBrowser => self.render_filesystem_browser(),
            TerminalView::CommandBuilder => self.render_command_builder(),
            TerminalView::CommandOutput => self.render_command_output(),
            TerminalView::History => self.render_history(),
            TerminalView::Settings => self.render_settings(),
        }
    }

    fn render_main_menu(&self) -> String {
        let menu_items = [
            "📁 File Explorer",
            "⚡ Command Builder",
            "📜 History",
            "⚙️ Settings",
        ];
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           ANBERNIC TERMINAL                                │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Directory: {}                                            │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, item) in menu_items.iter().enumerate() {
            let selected = if i == self.input_state.selected_index {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}{}                                                              │\n",
                selected, item
            ));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select  L: Back                                          │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_filesystem_browser(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                          FILE EXPLORER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ {:<74} │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        // Show parent directory option
        if self.filesystem_cache.parent_directory.is_some() {
            let selected = if self.ui_state.selected_file_index == 0 {
                "► "
            } else {
                "  "
            };
            output.push_str(&format!(
                "│ {}📁 ..                                                               │\n",
                selected
            ));
        }

        // Show directory contents
        for (i, entry) in self.filesystem_cache.current_entries.iter().enumerate() {
            let adjusted_index = if self.filesystem_cache.parent_directory.is_some() {
                i + 1
            } else {
                i
            };
            let selected = if adjusted_index == self.ui_state.selected_file_index {
                "► "
            } else {
                "  "
            };

            let icon = match entry.entry_type {
                EntryType::Directory => "📁",
                EntryType::Executable => "⚡",
                EntryType::SymLink => "🔗",
                EntryType::Hidden => "👻",
                EntryType::File => "📄",
            };

            output.push_str(&format!("│ {}{} {:<66} │\n", selected, icon, entry.name));
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Enter/Select  L: Up Directory                           │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_builder(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND BUILDER                                    │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        match self.command_builder.build_state {
            BuildState::SelectingCommand => {
                output.push_str("│ Select Command:                                                            │\n");
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");

                for (cmd, template) in &self.command_builder.available_commands {
                    let selected = if cmd == &self.command_builder.base_command {
                        "► "
                    } else {
                        "  "
                    };
                    output.push_str(&format!(
                        "│ {}{:<20} - {}                                   │\n",
                        selected, cmd, template.description
                    ));
                }
            }
            BuildState::SelectingFlags => {
                output.push_str(&format!(
                    "│ Command: {}                                                       │\n",
                    self.command_builder.base_command
                ));
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ Available Flags:                                                           │\n");

                if let Some(template) = self
                    .command_builder
                    .available_commands
                    .get(&self.command_builder.base_command)
                {
                    for flag in &template.common_flags {
                        let selected = self
                            .command_builder
                            .selected_flags
                            .iter()
                            .any(|f| f.short == flag.short || f.long == flag.long);
                        let indicator = if selected { "✓" } else { " " };

                        let flag_display = if let Some(short) = &flag.short {
                            short.clone()
                        } else if let Some(long) = &flag.long {
                            long.clone()
                        } else {
                            "".to_string()
                        };

                        output.push_str(&format!(
                            "│ [{}] {:<15} - {}                            │\n",
                            indicator, flag_display, flag.description
                        ));
                    }
                }
            }
            _ => {
                output.push_str("│ Building command...                                                        │\n");
            }
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ A/B: Navigate  R: Select/Toggle  L: Back                                  │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_command_output(&self) -> String {
        // Show output from last executed command
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                        COMMAND OUTPUT                                     │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        if let Some(last_command) = self.command_history.last() {
            output.push_str(&format!("│ Command: {:<66} │\n", last_command.command));
            output.push_str(&format!(
                "│ Exit Code: {:<64} │\n",
                last_command
                    .exit_code
                    .map_or("N/A".to_string(), |c| c.to_string())
            ));
            output.push_str(
                "├────────────────────────────────────────────────────────────────────────────┤\n",
            );

            // Show output (truncated to fit)
            for line in last_command.output.lines().take(10) {
                output.push_str(&format!(
                    "│ {:<74} │\n",
                    if line.len() > 74 { &line[..74] } else { line }
                ));
            }

            if !last_command.error.is_empty() {
                output.push_str("├────────────────────────────────────────────────────────────────────────────┤\n");
                output.push_str("│ STDERR:                                                                    │\n");
                for line in last_command.error.lines().take(5) {
                    output.push_str(&format!(
                        "│ {:<74} │\n",
                        if line.len() > 74 { &line[..74] } else { line }
                    ));
                }
            }
        } else {
            output.push_str(
                "│ No commands executed yet.                                                  │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_history(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                         COMMAND HISTORY                                   │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );

        for (i, entry) in self.command_history.iter().rev().enumerate().take(15) {
            let time = entry.timestamp.format("%H:%M:%S");
            let status = match entry.exit_code {
                Some(0) => "✓",
                Some(_) => "✗",
                None => "?",
            };

            output.push_str(&format!(
                "│ {} {} {:<60} │\n",
                status,
                time,
                if entry.command.len() > 60 {
                    &entry.command[..60]
                } else {
                    &entry.command
                }
            ));
        }

        if self.command_history.is_empty() {
            output.push_str(
                "│ No command history available.                                              │\n",
            );
        }

        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }

    fn render_settings(&self) -> String {
        let mut output = String::new();

        output.push_str(
            "┌────────────────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│                           SETTINGS                                        │\n",
        );
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(&format!(
            "│ Terminal Size: {}x{}                                               │\n",
            self.ui_state.terminal_width, self.ui_state.terminal_height
        ));
        output.push_str(&format!(
            "│ Show Hidden Files: {}                                                 │\n",
            if self.ui_state.show_hidden_files {
                "Yes"
            } else {
                "No"
            }
        ));
        output.push_str(&format!(
            "│ Current Directory: {}                                      │\n",
            self.current_directory.to_string_lossy()
        ));
        output.push_str(
            "├────────────────────────────────────────────────────────────────────────────┤\n",
        );
        output.push_str(
            "│ L: Back to Menu                                                            │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        output
    }
}

impl FilesystemCache {
    fn new(directory: &PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        let mut entries = Vec::new();

        if let Ok(read_dir) = std::fs::read_dir(directory) {
            for entry in read_dir {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    let metadata = entry.metadata()?;

                    let entry_type = if path.is_dir() {
                        EntryType::Directory
                    } else if path.is_symlink() {
                        EntryType::SymLink
                    } else if metadata.permissions().readonly() {
                        EntryType::File
                    } else {
                        EntryType::Executable
                    };

                    let name = entry.file_name().to_string_lossy().to_string();
                    if name.starts_with('.') {
                        continue; // Skip hidden files for now
                    }

                    entries.push(FilesystemEntry {
                        name,
                        path,
                        entry_type,
                        size: if metadata.is_file() {
                            Some(metadata.len())
                        } else {
                            None
                        },
                        permissions: format!("{:o}", metadata.permissions().mode() & 0o777),
                        modified: DateTime::from_timestamp(
                            metadata
                                .modified()?
                                .duration_since(std::time::UNIX_EPOCH)?
                                .as_secs() as i64,
                            0,
                        )
                        .unwrap_or_else(|| Utc::now()),
                    });
                }
            }
        }

        // Sort entries: directories first, then files
        entries.sort_by(|a, b| match (&a.entry_type, &b.entry_type) {
            (EntryType::Directory, EntryType::Directory) => a.name.cmp(&b.name),
            (EntryType::Directory, _) => std::cmp::Ordering::Less,
            (_, EntryType::Directory) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        });

        let parent_directory = directory.parent().map(|p| p.to_path_buf());

        Ok(Self {
            current_entries: entries,
            parent_directory,
            last_updated: Utc::now(),
        })
    }
}

impl CommandBuilder {
    fn new(templates: HashMap<String, CommandTemplate>) -> Self {
        let base_command = templates
            .keys()
            .next()
            .cloned()
            .unwrap_or_else(|| "ls".to_string());

        Self {
            base_command,
            selected_flags: Vec::new(),
            parameters: HashMap::new(),
            available_commands: templates,
            build_state: BuildState::SelectingCommand,
        }
    }

    /// Build the final command string with selected flags and parameters
    pub fn build_command(&self) -> String {
        let mut command = self.base_command.clone();

        for flag in &self.selected_flags {
            if let Some(short) = &flag.short {
                command.push(' ');
                command.push_str(short);
            }
        }

        for (param, value) in &self.parameters {
            command.push(' ');
            command.push_str(value);
        }

        command
    }
}

impl RadialKeyboard {
    fn handle_input(
        &mut self,
        button: RadialButton,
        text_buffer: &mut String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Navigation,
                    KeyboardSector::Numbers => KeyboardSector::Letters,
                    KeyboardSector::Symbols => KeyboardSector::Numbers,
                    KeyboardSector::Navigation => KeyboardSector::Symbols,
                }
            }
            RadialButton::B => {
                self.current_sector = match self.current_sector {
                    KeyboardSector::Letters => KeyboardSector::Numbers,
                    KeyboardSector::Numbers => KeyboardSector::Symbols,
                    KeyboardSector::Symbols => KeyboardSector::Navigation,
                    KeyboardSector::Navigation => KeyboardSector::Letters,
                }
            }
            RadialButton::L => {
                // Previous character in current sector
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = chars.len() - 1;
                        }
                    }
                    KeyboardSector::Navigation => {
                        let actions = ["SPACE", "ENTER", "BACKSPACE", "TAB", "SHIFT"];
                        if self.selected_char_index > 0 {
                            self.selected_char_index -= 1;
                        } else {
                            self.selected_char_index = actions.len() - 1;
                        }
                    }
                }
            }
            RadialButton::R => {
                // Select current character or action
                match self.current_sector {
                    KeyboardSector::Letters => {
                        let chars = if self.shift_mode {
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        } else {
                            "abcdefghijklmnopqrstuvwxyz"
                        };
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Numbers => {
                        let chars = "0123456789";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Symbols => {
                        let chars = "!@#$%^&*()_+-=[]{}|;:,.<>?";
                        if let Some(ch) = chars.chars().nth(self.selected_char_index) {
                            text_buffer.push(ch);
                        }
                    }
                    KeyboardSector::Navigation => {
                        match self.selected_char_index {
                            0 => text_buffer.push(' '),  // SPACE
                            1 => text_buffer.push('\n'), // ENTER
                            2 => {
                                text_buffer.pop();
                            } // BACKSPACE
                            3 => text_buffer.push('\t'), // TAB
                            4 => self.shift_mode = !self.shift_mode, // SHIFT
                            _ => {}
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

impl Default for TerminalInputState {
    fn default() -> Self {
        Self {
            current_group: InputGroup::MainMenu,
            selected_index: 0,
            text_buffer: String::new(),
            cursor_position: 0,
            input_mode: InputMode::Navigation,
            command_cursor: 0,
        }
    }
}

impl Default for TerminalUIState {
    fn default() -> Self {
        Self {
            current_view: TerminalView::MainMenu,
            selected_file_index: 0,
            scroll_offset: 0,
            show_help: false,
            animation_frame: 0,
            show_hidden_files: false,
            terminal_width: 80,
            terminal_height: 24,
        }
    }
}

impl Default for RadialKeyboard {
    fn default() -> Self {
        Self {
            current_sector: KeyboardSector::Letters,
            shift_mode: false,
            caps_mode: false,
            selected_char_index: 0,
        }
    }
}
