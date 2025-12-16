/// Portmaster Radial Keyboard Test Application
/// 
/// This application tests the ergonomics and functionality of the radial keyboard
/// system as specified in /todo/claude-next/claude-next-6. It can be deployed
/// manually to Portmaster without requiring online repositories.
///
/// Features:
/// - Blank screen with white circle in center
/// - Arc-shaped menus on D-pad press  
/// - 4 options per direction, arranged clockwise
/// - Complex angle positioning (UP+RIGHT = 45°, etc.)
/// - Letter selection with L1/L2/R1/R2 buttons
/// - Real-time menu switching between directions

use std::collections::HashMap;
use std::f32::consts::PI;

/// Main application state
pub struct RadialKeyboardTest {
    // Screen properties
    screen_width: f32,
    screen_height: f32,
    center_x: f32,
    center_y: f32,
    
    // Current input state
    active_direction: Option<Direction>,
    selected_letter: Option<char>,
    input_text: String,
    
    // Menu configuration
    alphabet_layout: AlphabetLayout,
    menu_radius: f32,
    option_spacing: f32,
}

/// 8-way directional input including diagonals
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

/// Button inputs for option selection
#[derive(Debug, Clone, Copy)]
pub enum SelectionButton {
    L1,  // First option (leftmost in arc)
    L2,  // Second option
    R1,  // Third option  
    R2,  // Fourth option (rightmost in arc)
    X,   // Alternative for L1
    B,   // Alternative for L2
    A,   // Alternative for R1
    Y,   // Alternative for R2
}

/// Alphabet distribution across all 8 directions
pub struct AlphabetLayout {
    sectors: HashMap<Direction, [char; 4]>,
}

/// Visual arc menu for a direction
#[derive(Debug, Clone)]
pub struct ArcMenu {
    direction: Direction,
    center_angle: f32,      // Angle in radians where arc is centered
    options: [Option<char>; 4],
    selected_index: Option<usize>,
}

impl RadialKeyboardTest {
    /// Create new test application
    pub fn new(screen_width: f32, screen_height: f32) -> Self {
        let center_x = screen_width / 2.0;
        let center_y = screen_height / 2.0;
        
        Self {
            screen_width,
            screen_height,
            center_x,
            center_y,
            active_direction: None,
            selected_letter: None,
            input_text: String::new(),
            alphabet_layout: AlphabetLayout::new(),
            menu_radius: 100.0,  // Distance from center to arc
            option_spacing: 0.3, // Radians between arc options
        }
    }
    
    /// Handle D-pad input to show/switch arc menus
    pub fn handle_dpad_input(&mut self, direction: Direction) {
        // Close current menu and open new one at specified direction
        self.active_direction = Some(direction);
        
        // Reset selection when switching directions
        self.selected_letter = None;
        
        println!("Opened arc menu for direction: {:?}", direction);
        self.debug_print_menu();
    }
    
    /// Handle selection button input (L1/L2/R1/R2, X/B/A/Y)
    pub fn handle_selection_button(&mut self, button: SelectionButton) {
        if let Some(direction) = self.active_direction {
            let option_index = match button {
                SelectionButton::L1 | SelectionButton::X => 0,
                SelectionButton::L2 | SelectionButton::B => 1,
                SelectionButton::R1 | SelectionButton::A => 2,
                SelectionButton::R2 | SelectionButton::Y => 3,
            };
            
            // Get the letter for this direction and option
            if let Some(letter) = self.alphabet_layout.get_letter(direction, option_index) {
                self.selected_letter = Some(letter);
                self.input_text.push(letter);
                
                println!("Selected letter: {} (option {})", letter, option_index + 1);
                println!("Current text: {}", self.input_text);
            }
        }
    }
    
    /// Handle D-pad release to close menus
    pub fn handle_dpad_release(&mut self) {
        self.active_direction = None;
        self.selected_letter = None;
        println!("Closed arc menu");
    }
    
    /// Convert direction to center angle for arc positioning
    fn direction_to_angle(direction: Direction) -> f32 {
        match direction {
            Direction::Right => 0.0,          // 0°
            Direction::UpRight => PI / 4.0,   // 45°
            Direction::Up => PI / 2.0,        // 90°
            Direction::UpLeft => 3.0 * PI / 4.0,   // 135°
            Direction::Left => PI,            // 180°
            Direction::DownLeft => 5.0 * PI / 4.0, // 225°
            Direction::Down => 3.0 * PI / 2.0,     // 270°
            Direction::DownRight => 7.0 * PI / 4.0, // 315°
        }
    }
    
    /// Get the arc menu for current direction
    pub fn get_current_arc_menu(&self) -> Option<ArcMenu> {
        self.active_direction.map(|direction| {
            let center_angle = Self::direction_to_angle(direction);
            let options = self.alphabet_layout.get_options(direction);
            
            ArcMenu {
                direction,
                center_angle,
                options,
                selected_index: None,
            }
        })
    }
    
    /// Debug print current menu state
    fn debug_print_menu(&self) {
        if let Some(direction) = self.active_direction {
            println!("=== Arc Menu for {:?} ===", direction);
            let options = self.alphabet_layout.get_options(direction);
            
            println!("Options (clockwise from left):");
            for (i, option) in options.iter().enumerate() {
                let button = match i {
                    0 => "L1/X",
                    1 => "L2/B", 
                    2 => "R1/A",
                    3 => "R2/Y",
                    _ => "??",
                };
                
                match option {
                    Some(letter) => println!("  {}: {}", button, letter),
                    None => println!("  {}: [empty]", button),
                }
            }
            
            let angle_deg = Self::direction_to_angle(direction) * 180.0 / PI;
            println!("Center angle: {:.1}°", angle_deg);
            println!("========================");
        }
    }
    
    /// Render the visual interface (would integrate with actual graphics)
    pub fn render(&self) -> String {
        let mut output = String::new();
        
        // ASCII art representation for testing
        output.push_str("╔════════════════════════════════════════╗\n");
        output.push_str("║          Radial Keyboard Test          ║\n");
        output.push_str("╠════════════════════════════════════════╣\n");
        
        // Show center circle
        output.push_str("║                  ●                     ║\n");
        output.push_str("║              (center)                  ║\n");
        output.push_str("║                                        ║\n");
        
        // Show current menu if active
        if let Some(direction) = self.active_direction {
            output.push_str(&format!("║ Active Direction: {:?:<15}    ║\n", direction));
            
            let options = self.alphabet_layout.get_options(direction);
            output.push_str("║ Arc Options:                           ║\n");
            
            for (i, option) in options.iter().enumerate() {
                let button = match i {
                    0 => "L1/X",
                    1 => "L2/B",
                    2 => "R1/A", 
                    3 => "R2/Y",
                    _ => "??",
                };
                
                let letter = option.map(|c| c.to_string()).unwrap_or_else(|| "[empty]".to_string());
                output.push_str(&format!("║   {}: {:<25}        ║\n", button, letter));
            }
        } else {
            output.push_str("║ Press D-pad to open arc menu           ║\n");
            output.push_str("║                                        ║\n");
            output.push_str("║                                        ║\n");
            output.push_str("║                                        ║\n");
            output.push_str("║                                        ║\n");
        }
        
        output.push_str("║                                        ║\n");
        output.push_str(&format!("║ Text: {:<30} ║\n", self.input_text));
        output.push_str("╚════════════════════════════════════════╝\n");
        
        output
    }
    
    /// Get current input text
    pub fn get_text(&self) -> &str {
        &self.input_text
    }
    
    /// Clear input text
    pub fn clear_text(&mut self) {
        self.input_text.clear();
    }
}

impl AlphabetLayout {
    /// Create new alphabet layout distributing A-Z across 8 directions
    pub fn new() -> Self {
        let mut sectors = HashMap::new();
        
        // Distribute alphabet across directions
        // Each direction gets 4 slots, some may be empty for 26 letters across 8*4=32 slots
        let letters: Vec<char> = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".chars().collect();
        let directions = [
            Direction::Up,
            Direction::UpRight,
            Direction::Right,
            Direction::DownRight,
            Direction::Down,
            Direction::DownLeft,
            Direction::Left,
            Direction::UpLeft,
        ];
        
        for (dir_idx, &direction) in directions.iter().enumerate() {
            let mut sector_letters = [None; 4];
            
            for slot in 0..4 {
                let letter_idx = dir_idx * 4 + slot;
                if letter_idx < letters.len() {
                    sector_letters[slot] = Some(letters[letter_idx]);
                }
            }
            
            let char_array = [
                sector_letters[0].unwrap_or(' '),
                sector_letters[1].unwrap_or(' '),
                sector_letters[2].unwrap_or(' '),
                sector_letters[3].unwrap_or(' '),
            ];
            
            sectors.insert(direction, char_array);
        }
        
        Self { sectors }
    }
    
    /// Get the 4 options for a specific direction
    pub fn get_options(&self, direction: Direction) -> [Option<char>; 4] {
        if let Some(chars) = self.sectors.get(&direction) {
            [
                if chars[0] != ' ' { Some(chars[0]) } else { None },
                if chars[1] != ' ' { Some(chars[1]) } else { None },
                if chars[2] != ' ' { Some(chars[2]) } else { None },
                if chars[3] != ' ' { Some(chars[3]) } else { None },
            ]
        } else {
            [None, None, None, None]
        }
    }
    
    /// Get specific letter by direction and option index
    pub fn get_letter(&self, direction: Direction, option_index: usize) -> Option<char> {
        if option_index >= 4 {
            return None;
        }
        
        self.get_options(direction)[option_index]
    }
}

fn main() {
    run_keyboard_test();
}

/// Simple test runner for demonstration  
pub fn run_keyboard_test() {
    println!("Starting Radial Keyboard Test");
    println!("============================");
    
    let mut app = RadialKeyboardTest::new(800.0, 600.0);
    
    // Show initial state
    println!("{}", app.render());
    
    // Test sequence: UP direction
    println!("\n🎮 Testing UP direction:");
    app.handle_dpad_input(Direction::Up);
    println!("{}", app.render());
    
    // Select first option (L1/X)
    println!("\n🎮 Pressing L1 to select first option:");
    app.handle_selection_button(SelectionButton::L1);
    
    // Test sequence: UP+RIGHT (45 degree)
    println!("\n🎮 Testing UP+RIGHT direction (45°):");
    app.handle_dpad_input(Direction::UpRight);
    println!("{}", app.render());
    
    // Select third option (R1/A)
    println!("\n🎮 Pressing R1/A to select third option:");
    app.handle_selection_button(SelectionButton::R1);
    
    // Test LEFT direction
    println!("\n🎮 Testing LEFT direction:");
    app.handle_dpad_input(Direction::Left);
    println!("{}", app.render());
    
    // Select second option (L2/B)
    println!("\n🎮 Pressing L2/B to select second option:");
    app.handle_selection_button(SelectionButton::L2);
    
    // Close menu
    println!("\n🎮 Releasing D-pad:");
    app.handle_dpad_release();
    println!("{}", app.render());
    
    println!("\nFinal text entered: \"{}\"", app.get_text());
    println!("\n✅ Radial keyboard test completed!");
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_alphabet_layout() {
        let layout = AlphabetLayout::new();
        
        // Test that we can get letters from different directions
        assert_eq!(layout.get_letter(Direction::Up, 0), Some('A'));
        assert_eq!(layout.get_letter(Direction::Up, 1), Some('B'));
        assert_eq!(layout.get_letter(Direction::UpRight, 0), Some('E'));
    }
    
    #[test]
    fn test_direction_angles() {
        assert_eq!(RadialKeyboardTest::direction_to_angle(Direction::Right), 0.0);
        assert_eq!(RadialKeyboardTest::direction_to_angle(Direction::Up), PI / 2.0);
        assert_eq!(RadialKeyboardTest::direction_to_angle(Direction::UpRight), PI / 4.0);
    }
    
    #[test]
    fn test_keyboard_input_flow() {
        let mut app = RadialKeyboardTest::new(800.0, 600.0);
        
        // No active menu initially
        assert_eq!(app.active_direction, None);
        
        // Open menu
        app.handle_dpad_input(Direction::Up);
        assert_eq!(app.active_direction, Some(Direction::Up));
        
        // Select letter
        app.handle_selection_button(SelectionButton::L1);
        assert_eq!(app.get_text(), "A");
        
        // Close menu
        app.handle_dpad_release();
        assert_eq!(app.active_direction, None);
    }
}