use crate::unit::UnitClass;

pub struct Colors;

impl Colors {
    pub const RESET: &'static str = "\x1b[0m";
    pub const CLEAR_SCREEN: &'static str = "\x1b[2J\x1b[1;1H";
    
    // Player team colors (blues)
    pub const PLAYER_WARRIOR: &'static str = "\x1b[34m"; // Blue
    pub const PLAYER_ROGUE: &'static str = "\x1b[36m";   // Cyan
    pub const PLAYER_MAGE: &'static str = "\x1b[94m";    // Bright blue
    pub const PLAYER_TANK: &'static str = "\x1b[44m";    // Blue background
    pub const PLAYER_ARCHER: &'static str = "\x1b[96m";  // Bright cyan
    pub const PLAYER_CLERIC: &'static str = "\x1b[104m"; // Bright blue background
    
    // Enemy team colors (reds)
    pub const ENEMY_WARRIOR: &'static str = "\x1b[31m"; // Red
    pub const ENEMY_ROGUE: &'static str = "\x1b[35m";   // Magenta
    pub const ENEMY_MAGE: &'static str = "\x1b[91m";    // Bright red
    pub const ENEMY_TANK: &'static str = "\x1b[41m";    // Red background
    pub const ENEMY_ARCHER: &'static str = "\x1b[95m";  // Bright magenta
    pub const ENEMY_CLERIC: &'static str = "\x1b[101m"; // Bright red background
    
    // UI colors
    pub const GOLD: &'static str = "\x1b[33m";    // Yellow
    pub const SUCCESS: &'static str = "\x1b[32m"; // Green
    pub const WARNING: &'static str = "\x1b[93m"; // Bright yellow
    pub const ERROR: &'static str = "\x1b[91m";   // Bright red
    pub const INFO: &'static str = "\x1b[37m";    // White
}

impl Colors {
    pub fn unit_color(class: &UnitClass, is_player: bool) -> &'static str {
        match (class, is_player) {
            (UnitClass::Warrior, true) => Self::PLAYER_WARRIOR,
            (UnitClass::Rogue, true) => Self::PLAYER_ROGUE,
            (UnitClass::Mage, true) => Self::PLAYER_MAGE,
            (UnitClass::Tank, true) => Self::PLAYER_TANK,
            (UnitClass::Archer, true) => Self::PLAYER_ARCHER,
            (UnitClass::Cleric, true) => Self::PLAYER_CLERIC,
            
            (UnitClass::Warrior, false) => Self::ENEMY_WARRIOR,
            (UnitClass::Rogue, false) => Self::ENEMY_ROGUE,
            (UnitClass::Mage, false) => Self::ENEMY_MAGE,
            (UnitClass::Tank, false) => Self::ENEMY_TANK,
            (UnitClass::Archer, false) => Self::ENEMY_ARCHER,
            (UnitClass::Cleric, false) => Self::ENEMY_CLERIC,
        }
    }
    
    pub fn colored_unit_symbol(class: &UnitClass, is_player: bool, symbol: char) -> String {
        format!("{}{}{}", 
                Self::unit_color(class, is_player), 
                symbol, 
                Self::RESET)
    }
    
    pub fn colored_text(text: &str, color: &str) -> String {
        format!("{}{}{}", color, text, Self::RESET)
    }
}