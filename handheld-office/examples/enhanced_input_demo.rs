/// Demo of the enhanced input system with edit mode and configurable keyboards
/// Shows both Game Boy and SNES-style input configurations
use handheld_office::{
    ControllerType, EnhancedInputManager, InputConfig, InputResult, UniversalButton,
};
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 Enhanced Input System Demo");
    println!("=============================");
    println!();

    // Let user choose controller type
    println!("Select controller type:");
    println!("1. Game Boy style (A, B, SELECT, START, D-Pad)");
    println!("2. SNES style (A, B, X, Y, L, R, SELECT, START, D-Pad)");
    print!("Choice (1 or 2): ");
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    let mut input_manager = match input.trim() {
        "2" => {
            println!("🎮 Initializing SNES-style input system...");
            EnhancedInputManager::snes_style()
        }
        _ => {
            println!("🎮 Initializing Game Boy-style input system...");
            EnhancedInputManager::gameboy_style()
        }
    };

    println!();
    println!("Enhanced Input System Features:");
    println!("  ✅ Edit Mode: SELECT enters text editing mode");
    println!("  ✅ Cursor Navigation: D-pad moves cursor in edit mode");
    println!("  ✅ One-Time Keyboard: A button opens keyboard for single character");
    println!("  ✅ Backspace: B button deletes in edit mode");
    println!("  ✅ Auto-Exit: Edit mode times out after 30 seconds");

    if matches!(
        input_manager.config.controller_type,
        ControllerType::SNES { .. }
    ) {
        println!("  ✅ Radial Menus: D-pad opens 6-option character sets");
        println!("     - UP: Uppercase letters (A-F)");
        println!("     - DOWN: Lowercase letters (a-f)");
        println!("     - LEFT: Numbers (1-6)");
        println!("     - RIGHT: Symbols (!@#$%^)");
    }

    println!();
    println!("Current mode: {}", input_manager.get_mode_display());
    println!("Text buffer: '{}'", input_manager.text_buffer);

    // Interactive demo loop
    loop {
        println!();
        println!("Available commands:");
        println!(
            "  enter [button] - Simulate button press (a, b, select, start, up, down, left, right)"
        );
        if matches!(
            input_manager.config.controller_type,
            ControllerType::SNES { .. }
        ) {
            println!("                   (SNES: also x, y, l, r)");
        }
        println!("  status - Show current status");
        println!("  save [filename] - Save current configuration");
        println!("  load [filename] - Load configuration");
        println!("  quit - Exit demo");
        print!("> ");
        io::stdout().flush()?;

        let mut command = String::new();
        io::stdin().read_line(&mut command)?;
        let command = command.trim();

        if command == "quit" {
            break;
        } else if command == "status" {
            show_status(&input_manager);
        } else if command.starts_with("save ") {
            let filename = command.strip_prefix("save ").unwrap();
            save_config(&input_manager, filename)?;
        } else if command.starts_with("load ") {
            let filename = command.strip_prefix("load ").unwrap();
            input_manager = load_config(filename)?;
            println!("✅ Configuration loaded from {}", filename);
        } else if command.starts_with("enter ") {
            let button_name = command.strip_prefix("enter ").unwrap();
            if let Some(button) = parse_button(button_name) {
                handle_button_press(&mut input_manager, button);
            } else {
                println!("❌ Unknown button: {}", button_name);
            }
        } else if command.is_empty() {
            continue;
        } else {
            println!("❌ Unknown command: {}", command);
        }
    }

    println!("👋 Enhanced Input Demo completed!");
    Ok(())
}

fn show_status(input_manager: &EnhancedInputManager) {
    println!();
    println!("📊 Current Status:");
    println!("  Mode: {}", input_manager.get_mode_display());
    println!("  Controller: {:?}", input_manager.config.controller_type);
    println!("  Text Buffer: '{}'", input_manager.text_buffer);

    let cursor_info = input_manager.get_cursor_info();
    println!(
        "  Cursor: position {}, line {}, column {}",
        cursor_info.position, cursor_info.line, cursor_info.column
    );

    println!("  Text Length: {} characters", cursor_info.text_length);

    // Show available keyboard layouts
    println!("  Available Layouts:");
    for layout_name in input_manager.config.keyboard_layouts.keys() {
        println!("    - {}", layout_name);
    }
}

fn save_config(
    input_manager: &EnhancedInputManager,
    filename: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let path = std::path::Path::new(filename);
    input_manager.config.save_to_file(path)?;
    println!("✅ Configuration saved to {}", filename);
    Ok(())
}

fn load_config(filename: &str) -> Result<EnhancedInputManager, Box<dyn std::error::Error>> {
    let path = std::path::Path::new(filename);
    let config = InputConfig::load_from_file(path)?;
    Ok(EnhancedInputManager::new(config))
}

fn parse_button(button_name: &str) -> Option<UniversalButton> {
    match button_name.to_lowercase().as_str() {
        "a" => Some(UniversalButton::A),
        "b" => Some(UniversalButton::B),
        "x" => Some(UniversalButton::X),
        "y" => Some(UniversalButton::Y),
        "l" => Some(UniversalButton::L),
        "r" => Some(UniversalButton::R),
        "select" => Some(UniversalButton::Select),
        "start" => Some(UniversalButton::Start),
        "up" => Some(UniversalButton::Up),
        "down" => Some(UniversalButton::Down),
        "left" => Some(UniversalButton::Left),
        "right" => Some(UniversalButton::Right),
        _ => None,
    }
}

fn handle_button_press(input_manager: &mut EnhancedInputManager, button: UniversalButton) {
    println!("🎮 Button pressed: {:?}", button);

    // Simulate press and release
    let results = input_manager.handle_button_input(button.clone(), true);
    process_input_results(&results);

    // Also check for any auto-update results
    let update_results = input_manager.update();
    if !update_results.is_empty() {
        println!("⏰ Auto-update triggered:");
        process_input_results(&update_results);
    }

    println!("📝 Current text: '{}'", input_manager.text_buffer);
    println!("🎯 Current mode: {}", input_manager.get_mode_display());

    let cursor_info = input_manager.get_cursor_info();
    if cursor_info.text_length > 0 {
        println!(
            "📍 Cursor at position {}/{}",
            cursor_info.position, cursor_info.text_length
        );
    }
}

fn process_input_results(results: &[InputResult]) {
    for result in results {
        match result {
            InputResult::TextInput { text } => {
                println!("  ✏️  Text updated: '{}'", text);
            }
            InputResult::ModeChange { new_mode } => {
                println!("  🔄 Mode changed to: {:?}", new_mode);
            }
            InputResult::CursorMove { new_position } => {
                println!("  📍 Cursor moved to position: {}", new_position);
            }
            InputResult::SpecialAction { action } => {
                println!("  ⭐ Special action: {}", action);
            }
            InputResult::Navigation { direction } => {
                println!("  🧭 Navigation: {}", direction);
            }
            InputResult::NoAction => {
                // println!("  ⭕ No action");
            }
        }
    }
}

/// Demonstrate the different input scenarios
fn demo_scenarios() {
    println!();
    println!("🎭 Demonstration Scenarios:");
    println!();

    println!("1. Basic Text Entry (Game Boy Style):");
    println!("   SELECT → Enter edit mode");
    println!("   A → Open one-time keyboard");
    println!("   UP/DOWN/LEFT/RIGHT → Navigate character sectors");
    println!("   A → Select character and return to edit mode");
    println!("   LEFT/RIGHT → Move cursor");
    println!("   B → Backspace");
    println!("   SELECT → Exit edit mode");
    println!();

    println!("2. SNES-Style 6-Option Radial:");
    println!("   UP → Open uppercase letters (A-F)");
    println!("   A/B/X/Y/L/R → Select option 1-6");
    println!("   Character inserted immediately");
    println!("   DOWN → Open lowercase letters (a-f)");
    println!("   LEFT → Open numbers (1-6)");
    println!("   RIGHT → Open symbols (!@#$%^)");
    println!();

    println!("3. Advanced Edit Mode:");
    println!("   SELECT → Enter edit mode");
    println!("   UP/DOWN → Move cursor between lines");
    println!("   LEFT/RIGHT → Move cursor within line");
    println!("   Hold A for 1 second → Special character mode");
    println!("   Auto-exit after 30 seconds of inactivity");
    println!();

    println!("4. Configuration Examples:");
    println!("   save gameboy.json → Save Game Boy config");
    println!("   save snes.json → Save SNES config");
    println!("   load custom.json → Load custom config");
}

#[cfg(test)]
mod enhanced_input_tests {
    use super::*;

    #[test]
    fn test_gameboy_input_flow() {
        let mut input_manager = EnhancedInputManager::gameboy_style();

        // Start in navigation mode
        assert!(matches!(
            input_manager.current_mode,
            handheld_office::EnhancedInputMode::Navigation
        ));

        // Press SELECT to enter edit mode
        let results = input_manager.handle_button_input(UniversalButton::Select, true);
        assert!(!results.is_empty());
        assert!(matches!(
            input_manager.current_mode,
            handheld_office::EnhancedInputMode::EditMode
        ));

        // Press A to open one-time keyboard
        let results = input_manager.handle_button_input(UniversalButton::A, true);
        assert!(!results.is_empty());
        assert!(matches!(
            input_manager.current_mode,
            handheld_office::EnhancedInputMode::OneTimeKeyboard { .. }
        ));

        // Navigate and select a character
        input_manager.handle_button_input(UniversalButton::Up, true);
        let results = input_manager.handle_button_input(UniversalButton::A, true);

        // Should return to edit mode with character inserted
        assert!(matches!(
            input_manager.current_mode,
            handheld_office::EnhancedInputMode::EditMode
        ));
        assert!(!input_manager.text_buffer.is_empty());
    }

    #[test]
    fn test_snes_radial_menu() {
        let mut input_manager = EnhancedInputManager::snes_style();

        // Press UP to open uppercase radial menu
        let results = input_manager.handle_button_input(UniversalButton::Up, true);
        assert!(matches!(
            input_manager.current_mode,
            handheld_office::EnhancedInputMode::RadialMenu { .. }
        ));

        // Press A to select first option
        let results = input_manager.handle_button_input(UniversalButton::A, true);
        assert!(!input_manager.text_buffer.is_empty());
    }

    #[test]
    fn test_edit_mode_cursor_movement() {
        let mut input_manager = EnhancedInputManager::gameboy_style();
        input_manager.text_buffer = "Hello World".to_string();
        input_manager.cursor_position = 5; // After "Hello"

        // Enter edit mode
        input_manager.handle_button_input(UniversalButton::Select, true);

        // Move cursor right
        let results = input_manager.handle_button_input(UniversalButton::Right, true);
        assert_eq!(input_manager.cursor_position, 6);

        // Move cursor left
        let results = input_manager.handle_button_input(UniversalButton::Left, true);
        assert_eq!(input_manager.cursor_position, 5);
    }

    #[test]
    fn test_backspace_functionality() {
        let mut input_manager = EnhancedInputManager::gameboy_style();
        input_manager.text_buffer = "Test".to_string();
        input_manager.cursor_position = 4;

        // Enter edit mode
        input_manager.handle_button_input(UniversalButton::Select, true);

        // Press B for backspace
        let results = input_manager.handle_button_input(UniversalButton::B, true);
        assert_eq!(input_manager.text_buffer, "Tes");
        assert_eq!(input_manager.cursor_position, 3);
    }

    #[test]
    fn test_config_serialization() {
        let config = InputConfig::gameboy_default();
        let json = serde_json::to_string(&config).expect("Serialization failed");
        let deserialized: InputConfig =
            serde_json::from_str(&json).expect("Deserialization failed");

        // Verify key properties are preserved
        assert!(matches!(
            deserialized.controller_type,
            ControllerType::GameBoy { .. }
        ));
        assert!(!deserialized.keyboard_layouts.is_empty());
    }
}
