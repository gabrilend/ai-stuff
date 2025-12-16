use handheld_office::terminal::{AnbernicTerminal, RadialButton};
use std::io::{self, Write};
use std::time::{Duration, Instant};

struct AnbernicTerminalInterface {
    terminal: AnbernicTerminal,
    last_update: Instant,
    running: bool,
}

impl AnbernicTerminalInterface {
    fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let terminal = AnbernicTerminal::new()?;

        Ok(Self {
            terminal,
            last_update: Instant::now(),
            running: true,
        })
    }

    fn run(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("┌────────────────────────────────────────────────────────────────────────────┐");
        println!("│                      ANBERNIC TERMINAL EMULATOR                           │");
        println!("│                     Radial Menu Navigation Demo                           │");
        println!("├────────────────────────────────────────────────────────────────────────────┤");
        println!("│ Controls:                                                                  │");
        println!("│   W/↑ = A Button (Up/North)                                              │");
        println!("│   S/↓ = B Button (Down/South)                                            │");
        println!("│   A/← = L Button (Left/West)                                             │");
        println!("│   D/→ = R Button (Right/East)                                            │");
        println!("│   Q = Quit                                                                 │");
        println!("└────────────────────────────────────────────────────────────────────────────┘");
        println!();

        // Initial render
        self.render_terminal();

        while self.running {
            // Handle input (simulated - in real Anbernic would read hardware buttons)
            if let Ok(input) = self.get_simulated_input() {
                match input {
                    'q' | 'Q' => {
                        self.running = false;
                        break;
                    }
                    'w' | 'W' => {
                        self.terminal.handle_input(RadialButton::A)?;
                        self.render_terminal();
                    }
                    's' | 'S' => {
                        self.terminal.handle_input(RadialButton::B)?;
                        self.render_terminal();
                    }
                    'a' | 'A' => {
                        self.terminal.handle_input(RadialButton::L)?;
                        self.render_terminal();
                    }
                    'd' | 'D' => {
                        self.terminal.handle_input(RadialButton::R)?;
                        self.render_terminal();
                    }
                    '\n' | '\r' => {
                        // Execute command if in command builder and ready
                        if let Some(command) = self.get_built_command() {
                            println!("Executing: {}", command);
                            match self.terminal.execute_command(&command) {
                                Ok(result) => {
                                    println!("Command executed successfully!");
                                    println!("Exit code: {:?}", result.exit_code);
                                    if !result.output.is_empty() {
                                        println!("Output:\n{}", result.output);
                                    }
                                    if !result.error.is_empty() {
                                        println!("Error:\n{}", result.error);
                                    }
                                }
                                Err(e) => {
                                    println!("Error executing command: {}", e);
                                }
                            }
                            self.render_terminal();
                        }
                    }
                    _ => {}
                }
            }

            // Update at 30 FPS for smooth animation
            let now = Instant::now();
            let delta_time = now.duration_since(self.last_update).as_secs_f32();

            if delta_time >= 1.0 / 30.0 {
                self.update(delta_time);
                self.last_update = now;
            }

            std::thread::sleep(Duration::from_millis(16)); // ~60 FPS
        }

        println!("Terminal emulator closed. Thanks for using Anbernic Terminal!");
        Ok(())
    }

    fn get_simulated_input(&self) -> Result<char, Box<dyn std::error::Error>> {
        // This would normally read from Anbernic hardware buttons
        // For demo purposes, we'll simulate input

        // Non-blocking input simulation (would use proper input handling in real implementation)
        use std::sync::mpsc;
        use std::thread;
        use std::time::Duration;

        let (tx, rx) = mpsc::channel();

        thread::spawn(move || {
            // Simulate some input for demo
            thread::sleep(Duration::from_millis(100));
            // In real implementation, this would read hardware GPIO or input events
        });

        // For now, just return a demo character
        // In real implementation, this would be replaced with actual hardware input reading
        match rx.try_recv() {
            Ok(input) => Ok(input),
            Err(_) => {
                // Simulate no input most of the time
                std::thread::sleep(Duration::from_millis(50));
                Err("No input".into())
            }
        }
    }

    fn render_terminal(&self) {
        // Clear screen for fresh render (Game Boy style)
        print!("\x1B[2J\x1B[H"); // ANSI clear screen and move cursor to top

        // Render the terminal interface
        print!("{}", self.terminal.render());

        // Show current radial keyboard state if in text entry mode
        if matches!(
            self.terminal.input_state.input_mode,
            handheld_office::terminal::InputMode::TextEntry
        ) {
            self.render_radial_keyboard_state();
        }

        // Show command builder state if building a command
        if matches!(
            self.terminal.ui_state.current_view,
            handheld_office::terminal::TerminalView::CommandBuilder
        ) {
            self.render_command_builder_state();
        }

        io::stdout().flush().unwrap();
    }

    fn render_radial_keyboard_state(&self) {
        println!("┌────────────────────────────────────────────────────────────────────────────┐");
        println!("│                         RADIAL KEYBOARD                                   │");
        println!("├────────────────────────────────────────────────────────────────────────────┤");

        let current_sector = match self.terminal.radial_keyboard.current_sector {
            handheld_office::terminal::KeyboardSector::Letters => "Letters (a-z/A-Z)",
            handheld_office::terminal::KeyboardSector::Numbers => "Numbers (0-9)",
            handheld_office::terminal::KeyboardSector::Symbols => "Symbols (!@#$%...)",
            handheld_office::terminal::KeyboardSector::Navigation => {
                "Navigation (Space/Enter/Backspace...)"
            }
        };

        println!("│ Current Sector: {:<57} │", current_sector);
        println!(
            "│ Shift Mode: {:<63} │",
            if self.terminal.radial_keyboard.shift_mode {
                "ON"
            } else {
                "OFF"
            }
        );
        println!(
            "│ Text Buffer: {:<62} │",
            if self.terminal.input_state.text_buffer.len() > 62 {
                &self.terminal.input_state.text_buffer[..62]
            } else {
                &self.terminal.input_state.text_buffer
            }
        );
        println!("├────────────────────────────────────────────────────────────────────────────┤");
        println!("│ A/B: Change Sector  L/R: Select Character                                 │");
        println!("└────────────────────────────────────────────────────────────────────────────┘");
    }

    fn render_command_builder_state(&self) {
        let built_command = self.terminal.command_builder.build_command();
        if !built_command.is_empty() {
            println!(
                "┌────────────────────────────────────────────────────────────────────────────┐"
            );
            println!(
                "│                          BUILT COMMAND                                    │"
            );
            println!(
                "├────────────────────────────────────────────────────────────────────────────┤"
            );
            println!("│ {:<74} │", built_command);
            println!(
                "├────────────────────────────────────────────────────────────────────────────┤"
            );
            println!(
                "│ Press ENTER to execute command                                             │"
            );
            println!(
                "└────────────────────────────────────────────────────────────────────────────┘"
            );
        }
    }

    fn get_built_command(&self) -> Option<String> {
        let command = self.terminal.command_builder.build_command();
        if command.trim().is_empty() || command == self.terminal.command_builder.base_command {
            None
        } else {
            Some(command)
        }
    }

    fn update(&mut self, _delta_time: f32) {
        // Update any animations or time-based state
        self.terminal.ui_state.animation_frame =
            self.terminal.ui_state.animation_frame.wrapping_add(1);
    }
}

// Interactive demo for testing terminal functionality
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize the terminal interface
    let mut interface = AnbernicTerminalInterface::new()?;

    // Show welcome message
    println!("🎮 Welcome to Anbernic Terminal Emulator! 🎮");
    println!();
    println!("This terminal emulator features:");
    println!("• Radial menu navigation using A/B/L/R buttons");
    println!("• Interactive filesystem browser");
    println!("• Command builder with flag selection");
    println!("• Radial keyboard for text input");
    println!("• Command history and execution");
    println!();
    println!("Starting in 3 seconds...");

    for i in (1..=3).rev() {
        std::thread::sleep(Duration::from_secs(1));
        println!("{}...", i);
    }

    // Run the main interface loop
    interface.run()?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use handheld_office::terminal::*;

    #[test]
    fn test_terminal_creation() {
        let terminal = AnbernicTerminal::new();
        assert!(terminal.is_ok());
    }

    #[test]
    fn test_radial_keyboard_input() {
        let mut keyboard = RadialKeyboard::default();
        let mut buffer = String::new();

        // Test letter input
        keyboard.current_sector = KeyboardSector::Letters;
        keyboard.selected_char_index = 0; // 'a'
        keyboard.handle_input(RadialButton::R, &mut buffer).unwrap();

        assert_eq!(buffer, "a");
    }

    #[test]
    fn test_command_builder() {
        let mut terminal = AnbernicTerminal::new().unwrap();

        // Set up command
        terminal.command_builder.base_command = "ls".to_string();
        let command = terminal.command_builder.build_command();

        assert_eq!(command, "ls");
    }

    #[test]
    fn test_filesystem_navigation() {
        let terminal = AnbernicTerminal::new().unwrap();

        // Should start in some directory
        assert!(terminal.current_directory.exists());
        assert!(terminal.current_directory.is_dir());
    }

    #[test]
    fn test_input_handling() {
        let mut terminal = AnbernicTerminal::new().unwrap();

        // Test navigation input
        let result = terminal.handle_input(RadialButton::A);
        assert!(result.is_ok());
    }
}
