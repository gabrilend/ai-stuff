use crate::map::Position;
use crate::inventory::Item;
use crate::colors::Colors;
use serde::{Deserialize, Serialize};
use rand::Rng;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum UnitClass {
    Warrior,    // High HP, moderate attack, good defense
    Rogue,      // High speed, moderate attack, low defense
    Mage,       // High attack, low HP, moderate speed
    Tank,       // Very high HP, high defense, low speed, low attack
    Archer,     // High attack, moderate speed, low defense
    Cleric,     // Healing abilities, moderate stats overall
}

impl UnitClass {
    pub fn get_base_stats(&self, level: u32) -> UnitStats {
        let base = 8 + (level * 2);
        
        match self {
            UnitClass::Warrior => UnitStats {
                max_health: base * 6,
                health: base * 6,
                attack: base + 2,
                defense: base + 1,
                speed: base,
                level,
            },
            UnitClass::Rogue => UnitStats {
                max_health: base * 4,
                health: base * 4,
                attack: base + 1,
                defense: base - 1,
                speed: base + 3,
                level,
            },
            UnitClass::Mage => UnitStats {
                max_health: base * 3,
                health: base * 3,
                attack: base + 4,
                defense: base - 1,
                speed: base + 1,
                level,
            },
            UnitClass::Tank => UnitStats {
                max_health: base * 8,
                health: base * 8,
                attack: base - 2,
                defense: base + 3,
                speed: base - 2,
                level,
            },
            UnitClass::Archer => UnitStats {
                max_health: base * 4,
                health: base * 4,
                attack: base + 3,
                defense: base - 1,
                speed: base + 2,
                level,
            },
            UnitClass::Cleric => UnitStats {
                max_health: base * 5,
                health: base * 5,
                attack: base,
                defense: base,
                speed: base + 1,
                level,
            },
        }
    }

    pub fn get_symbol(&self) -> char {
        match self {
            UnitClass::Warrior => 'W',
            UnitClass::Rogue => 'R',
            UnitClass::Mage => 'M',
            UnitClass::Tank => 'T',
            UnitClass::Archer => 'A',
            UnitClass::Cleric => 'C',
        }
    }

    pub fn get_name(&self) -> &'static str {
        match self {
            UnitClass::Warrior => "Warrior",
            UnitClass::Rogue => "Rogue",
            UnitClass::Mage => "Mage",
            UnitClass::Tank => "Tank",
            UnitClass::Archer => "Archer",
            UnitClass::Cleric => "Cleric",
        }
    }

    pub fn all_classes() -> Vec<UnitClass> {
        vec![
            UnitClass::Warrior,
            UnitClass::Rogue,
            UnitClass::Mage,
            UnitClass::Tank,
            UnitClass::Archer,
            UnitClass::Cleric,
        ]
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnitStats {
    pub health: u32,
    pub max_health: u32,
    pub attack: u32,
    pub defense: u32,
    pub speed: u32,
    pub level: u32,
}

impl UnitStats {
    pub fn is_alive(&self) -> bool {
        self.health > 0
    }

    pub fn take_damage(&mut self, damage: u32) {
        self.health = self.health.saturating_sub(damage);
    }

    pub fn heal(&mut self, amount: u32) {
        self.health = (self.health + amount).min(self.max_health);
    }

    pub fn get_total_power(&self) -> u32 {
        // Simple power calculation for balancing
        (self.max_health + self.attack * 2 + self.defense + self.speed) / 2
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Unit {
    pub name: String,
    pub class: UnitClass,
    pub stats: UnitStats,
    pub position: Position,
    pub equipped_weapon: Option<Item>,
    pub equipped_armor: Option<Item>,
    pub is_player_unit: bool, // true for player team, false for enemy team
    
    // Combat state tracking
    #[serde(skip)]
    pub last_dodge_turn: u32,
    #[serde(skip)]
    pub orbit_clockwise: bool,
    #[serde(skip)]
    pub current_target_pos: Option<Position>,
    #[serde(skip)]
    pub is_retreating: bool,
}

impl Unit {
    pub fn new(name: String, class: UnitClass, level: u32, is_player_unit: bool) -> Self {
        let stats = class.get_base_stats(level);
        
        Unit {
            name,
            class,
            stats,
            position: Position::new(0, 0),
            equipped_weapon: None,
            equipped_armor: None,
            is_player_unit,
            last_dodge_turn: 0,
            orbit_clockwise: rand::thread_rng().gen(),
            current_target_pos: None,
            is_retreating: false,
        }
    }

    pub fn get_symbol(&self) -> char {
        if self.is_player_unit {
            self.class.get_symbol()
        } else {
            // Enemy units use lowercase
            self.class.get_symbol().to_lowercase().next().unwrap_or('e')
        }
    }
    
    pub fn get_colored_symbol(&self) -> String {
        let symbol = self.get_symbol();
        Colors::colored_unit_symbol(&self.class, self.is_player_unit, symbol)
    }

    pub fn get_total_attack(&self) -> u32 {
        let weapon_bonus = self.equipped_weapon.as_ref().map_or(0, |w| w.attack_bonus);
        self.stats.attack + weapon_bonus
    }

    pub fn get_total_defense(&self) -> u32 {
        let armor_bonus = self.equipped_armor.as_ref().map_or(0, |a| a.defense_bonus);
        self.stats.defense + armor_bonus
    }

    pub fn get_total_power(&self) -> u32 {
        // Include equipment in power calculation
        let weapon_power = self.equipped_weapon.as_ref().map_or(0, |w| w.attack_bonus * 2);
        let armor_power = self.equipped_armor.as_ref().map_or(0, |a| a.defense_bonus);
        self.stats.get_total_power() + weapon_power + armor_power
    }

    pub fn equip_weapon(&mut self, weapon: Item) -> Result<Option<Item>, String> {
        if !matches!(weapon.item_type, crate::inventory::ItemType::Weapon) {
            return Err("Item is not a weapon".to_string());
        }
        
        let old_weapon = self.equipped_weapon.take();
        self.equipped_weapon = Some(weapon);
        Ok(old_weapon)
    }

    pub fn equip_armor(&mut self, armor: Item) -> Result<Option<Item>, String> {
        if !matches!(armor.item_type, crate::inventory::ItemType::Armor) {
            return Err("Item is not armor".to_string());
        }
        
        let old_armor = self.equipped_armor.take();
        self.equipped_armor = Some(armor);
        Ok(old_armor)
    }

    pub fn can_heal_allies(&self) -> bool {
        matches!(self.class, UnitClass::Cleric)
    }

    pub fn get_heal_amount(&self) -> u32 {
        if self.can_heal_allies() {
            self.stats.level * 5 + 10
        } else {
            0
        }
    }

    pub fn attack_target(&self, target: &mut Unit, rng: &mut impl Rng) -> u32 {
        let base_damage = self.get_total_attack();
        let damage_variance = rng.gen_range(0..=(base_damage / 4).max(1));
        let total_damage = base_damage + damage_variance;
        let final_damage = total_damage.saturating_sub(target.get_total_defense());
        
        target.stats.take_damage(final_damage);
        final_damage
    }

    pub fn heal_target(&self, target: &mut Unit) -> u32 {
        if !self.can_heal_allies() {
            return 0;
        }
        
        let heal_amount = self.get_heal_amount();
        let old_health = target.stats.health;
        target.stats.heal(heal_amount);
        target.stats.health - old_health
    }

    pub fn get_priority_target<'a>(&self, enemies: &'a mut [Unit]) -> Option<&'a mut Unit> {
        // Find the closest enemy based on unit class behavior
        let alive_enemies: Vec<&mut Unit> = enemies.iter_mut().filter(|e| e.stats.is_alive()).collect();
        
        if alive_enemies.is_empty() {
            return None;
        }

        match self.class {
            UnitClass::Warrior | UnitClass::Tank => {
                // Target closest enemy
                alive_enemies.into_iter()
                    .min_by_key(|enemy| self.position.manhattan_distance_to(&enemy.position))
            },
            UnitClass::Rogue | UnitClass::Archer => {
                // Target weakest enemy (lowest HP)
                alive_enemies.into_iter()
                    .min_by_key(|enemy| enemy.stats.health)
            },
            UnitClass::Mage => {
                // Target enemy with lowest defense
                alive_enemies.into_iter()
                    .min_by_key(|enemy| enemy.get_total_defense())
            },
            UnitClass::Cleric => {
                // Target closest enemy (clerics will prioritize healing allies first)
                alive_enemies.into_iter()
                    .min_by_key(|enemy| self.position.manhattan_distance_to(&enemy.position))
            },
        }
    }

    pub fn get_heal_target<'a>(&self, allies: &'a mut [Unit]) -> Option<&'a mut Unit> {
        if !self.can_heal_allies() {
            return None;
        }

        // Find the ally with lowest health percentage
        allies.iter_mut()
            .filter(|ally| ally.stats.is_alive() && ally.stats.health < ally.stats.max_health)
            .min_by_key(|ally| (ally.stats.health * 100) / ally.stats.max_health)
    }

    pub fn get_tactical_move(&mut self, enemies: &[Unit], allies: &[Unit], current_turn: u32, arena_width: i32, arena_height: i32) -> Position {
        let closest_enemy = self.find_closest_enemy(enemies);
        
        match self.class {
            UnitClass::Warrior | UnitClass::Tank => {
                // Melee units move toward closest enemy or orbit if already close
                if let Some(enemy_pos) = closest_enemy {
                    let distance = self.position.manhattan_distance_to(&enemy_pos);
                    
                    if distance <= 2 {
                        // Orbit the enemy for tactical positioning
                        let orbit_pos = self.position.move_around_target(&enemy_pos, self.orbit_clockwise);
                        if self.is_valid_move(&orbit_pos, arena_width, arena_height) {
                            return orbit_pos;
                        }
                    }
                    
                    // Move toward enemy
                    let move_pos = self.position.move_toward(&enemy_pos);
                    if self.is_valid_move(&move_pos, arena_width, arena_height) {
                        return move_pos;
                    }
                }
            },
            
            UnitClass::Rogue => {
                // Rogues are aggressive and try to flank
                if let Some(enemy_pos) = closest_enemy {
                    let distance = self.position.manhattan_distance_to(&enemy_pos);
                    
                    if distance <= 3 {
                        // Try to flank by moving around the enemy
                        let flank_pos = self.position.move_around_target(&enemy_pos, !self.orbit_clockwise);
                        if self.is_valid_move(&flank_pos, arena_width, arena_height) {
                            return flank_pos;
                        }
                    }
                    
                    let move_pos = self.position.move_toward(&enemy_pos);
                    if self.is_valid_move(&move_pos, arena_width, arena_height) {
                        return move_pos;
                    }
                }
            },
            
            UnitClass::Archer => {
                // Archers try to maintain distance and dodge every 3 turns
                if let Some(enemy_pos) = closest_enemy {
                    let distance = self.position.manhattan_distance_to(&enemy_pos);
                    
                    // Dodge every 3 turns (simulate dodging arrows)
                    if current_turn - self.last_dodge_turn >= 3 {
                        let dodge_pos = self.position.retreat_from(&enemy_pos);
                        if self.is_valid_move(&dodge_pos, arena_width, arena_height) {
                            self.last_dodge_turn = current_turn;
                            return dodge_pos;
                        }
                    }
                    
                    // Try to maintain optimal range (not too close, not too far)
                    if distance < 4 {
                        // Too close, retreat
                        let retreat_pos = self.position.retreat_from(&enemy_pos);
                        if self.is_valid_move(&retreat_pos, arena_width, arena_height) {
                            return retreat_pos;
                        }
                    } else if distance > 8 {
                        // Too far, move closer
                        let move_pos = self.position.move_toward(&enemy_pos);
                        if self.is_valid_move(&move_pos, arena_width, arena_height) {
                            return move_pos;
                        }
                    }
                }
            },
            
            UnitClass::Mage => {
                // Mages try to stay at medium range and avoid melee
                if let Some(enemy_pos) = closest_enemy {
                    let distance = self.position.manhattan_distance_to(&enemy_pos);
                    
                    if distance < 3 {
                        // Too close, retreat
                        let retreat_pos = self.position.retreat_from(&enemy_pos);
                        if self.is_valid_move(&retreat_pos, arena_width, arena_height) {
                            return retreat_pos;
                        }
                    } else if distance > 6 {
                        // Move to medium range
                        let move_pos = self.position.move_toward(&enemy_pos);
                        if self.is_valid_move(&move_pos, arena_width, arena_height) {
                            return move_pos;
                        }
                    }
                }
            },
            
            UnitClass::Cleric => {
                // Clerics position themselves to support allies
                let wounded_ally = allies.iter()
                    .filter(|ally| ally.stats.is_alive() && ally.stats.health < ally.stats.max_health)
                    .min_by_key(|ally| ally.stats.health);
                    
                if let Some(ally) = wounded_ally {
                    // Move toward wounded ally
                    let move_pos = self.position.move_toward(&ally.position);
                    if self.is_valid_move(&move_pos, arena_width, arena_height) {
                        return move_pos;
                    }
                } else if let Some(enemy_pos) = closest_enemy {
                    // Stay at medium range from enemies
                    let distance = self.position.manhattan_distance_to(&enemy_pos);
                    if distance < 4 {
                        let retreat_pos = self.position.retreat_from(&enemy_pos);
                        if self.is_valid_move(&retreat_pos, arena_width, arena_height) {
                            return retreat_pos;
                        }
                    }
                }
            },
        }
        
        // If no tactical move is possible, stay in place
        self.position
    }

    fn find_closest_enemy(&self, enemies: &[Unit]) -> Option<Position> {
        enemies.iter()
            .filter(|enemy| enemy.stats.is_alive())
            .min_by_key(|enemy| self.position.manhattan_distance_to(&enemy.position))
            .map(|enemy| enemy.position)
    }

    fn is_valid_move(&self, pos: &Position, arena_width: i32, arena_height: i32) -> bool {
        pos.x > 0 && pos.x < arena_width - 1 && pos.y > 0 && pos.y < arena_height - 1
    }

    pub fn should_attack(&self, enemies: &[Unit]) -> Option<usize> {
        // Check if there's an enemy in attack range
        for (i, enemy) in enemies.iter().enumerate() {
            if !enemy.stats.is_alive() {
                continue;
            }
            
            let distance = self.position.manhattan_distance_to(&enemy.position);
            let attack_range = match self.class {
                UnitClass::Archer => 8,  // Long range
                UnitClass::Mage => 6,    // Medium range
                _ => 2,                  // Melee range
            };
            
            if distance <= attack_range {
                return Some(i);
            }
        }
        
        None
    }
}