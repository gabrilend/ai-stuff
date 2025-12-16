use crate::unit::{Unit, UnitClass};
use crate::inventory::Item;
use crate::map::Position;
use serde::{Deserialize, Serialize};
use rand::{Rng, seq::SliceRandom};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Team {
    pub name: String,
    pub units: Vec<Unit>,
    pub is_player_team: bool,
}

impl Team {
    pub fn new(name: String, is_player_team: bool) -> Self {
        Team {
            name,
            units: Vec::new(),
            is_player_team,
        }
    }

    pub fn add_unit(&mut self, unit: Unit) {
        if self.units.len() < 6 { // Max team size
            self.units.push(unit);
        }
    }

    pub fn remove_unit(&mut self, index: usize) -> Option<Unit> {
        if index < self.units.len() {
            Some(self.units.remove(index))
        } else {
            None
        }
    }

    pub fn get_total_power(&self) -> u32 {
        self.units.iter().map(|unit| unit.get_total_power()).sum()
    }

    pub fn get_alive_units(&self) -> Vec<&Unit> {
        self.units.iter().filter(|unit| unit.stats.is_alive()).collect()
    }

    pub fn get_alive_units_mut(&mut self) -> Vec<&mut Unit> {
        self.units.iter_mut().filter(|unit| unit.stats.is_alive()).collect()
    }

    pub fn is_defeated(&self) -> bool {
        self.units.iter().all(|unit| !unit.stats.is_alive())
    }

    pub fn position_units_for_battle(&mut self, arena_width: i32, arena_height: i32, is_player_team: bool) {
        let center_x = arena_width / 2;
        
        // Player team at bottom, enemy team at top
        let base_y = if is_player_team { 
            arena_height - 3 // Near bottom
        } else { 
            2 // Near top
        };
        
        // Spread units horizontally in formation
        let unit_count = self.units.len();
        for (i, unit) in self.units.iter_mut().enumerate() {
            let formation_positions = match unit_count {
                1 => vec![0],
                2 => vec![-3, 3],
                3 => vec![-6, 0, 6],
                4 => vec![-9, -3, 3, 9],
                5 => vec![-12, -6, 0, 6, 12],
                6 => vec![-15, -9, -3, 3, 9, 15],
                _ => vec![0], // fallback
            };
            
            let x_offset = if i < formation_positions.len() { 
                formation_positions[i] 
            } else { 
                0 
            };
            
            // Add some depth variation for tactical positioning
            let y_offset = match unit.class {
                crate::unit::UnitClass::Tank => 0,      // Front line
                crate::unit::UnitClass::Warrior => 0,   // Front line
                crate::unit::UnitClass::Rogue => if is_player_team { -1 } else { 1 }, // Slightly forward
                crate::unit::UnitClass::Archer => if is_player_team { -2 } else { 2 }, // Back line
                crate::unit::UnitClass::Mage => if is_player_team { -2 } else { 2 },   // Back line
                crate::unit::UnitClass::Cleric => if is_player_team { -1 } else { 1 }, // Mid line
            };
            
            unit.position = Position::new(
                (center_x + x_offset).max(1).min(arena_width - 2),
                (base_y + y_offset).max(1).min(arena_height - 2)
            );
        }
    }

    pub fn get_team_composition_string(&self) -> String {
        let mut comp = std::collections::HashMap::new();
        for unit in &self.units {
            *comp.entry(unit.class.get_name()).or_insert(0) += 1;
        }
        
        let mut result = Vec::new();
        for (class, count) in comp {
            if count == 1 {
                result.push(class.to_string());
            } else {
                result.push(format!("{}x{}", count, class));
            }
        }
        
        result.join(", ")
    }

    pub fn create_balanced_enemy_team(player_team_power: u32, level_range: (u32, u32)) -> Team {
        let mut rng = rand::thread_rng();
        let mut enemy_team = Team::new("Enemy Team".to_string(), false);
        
        let target_power = (player_team_power as f32 * rng.gen_range(0.8..1.2)) as u32;
        let mut current_power = 0;
        let mut unit_count = 0;
        
        let available_classes = UnitClass::all_classes();
        
        while current_power < target_power && unit_count < 6 {
            let class = available_classes.choose(&mut rng).unwrap().clone();
            let level = rng.gen_range(level_range.0..=level_range.1);
            
            let unit_name = format!("{} {}", 
                generate_enemy_name(&mut rng), 
                class.get_name());
            
            let unit = Unit::new(unit_name, class, level, false);
            let unit_power = unit.get_total_power();
            
            // Don't add unit if it would make team too overpowered
            if current_power + unit_power <= target_power + (target_power / 4) {
                current_power += unit_power;
                enemy_team.add_unit(unit);
                unit_count += 1;
            } else if unit_count == 0 {
                // Always add at least one unit, even if slightly overpowered
                current_power += unit_power;
                enemy_team.add_unit(unit);
                unit_count += 1;
            } else {
                break;
            }
        }
        
        // Give some enemy units basic equipment
        enemy_team.equip_random_items(&mut rng);
        
        enemy_team
    }

    pub fn equip_random_items(&mut self, rng: &mut impl Rng) {
        for unit in &mut self.units {
            // 60% chance for weapon
            if rng.gen_bool(0.6) {
                let weapon_power = unit.stats.level + rng.gen_range(1..=5);
                let weapon = Item::new_weapon(
                    &format!("{} {}", 
                        ["Iron", "Steel", "Magic", "Silver"].choose(rng).unwrap(),
                        ["Sword", "Blade", "Axe", "Spear"].choose(rng).unwrap()
                    ),
                    weapon_power,
                    weapon_power * 15
                );
                let _ = unit.equip_weapon(weapon);
            }
            
            // 50% chance for armor
            if rng.gen_bool(0.5) {
                let armor_power = unit.stats.level + rng.gen_range(1..=3);
                let armor = Item::new_armor(
                    &format!("{} {}", 
                        ["Leather", "Chain", "Plate", "Magic"].choose(rng).unwrap(),
                        ["Armor", "Mail", "Vest", "Robes"].choose(rng).unwrap()
                    ),
                    armor_power,
                    armor_power * 20
                );
                let _ = unit.equip_armor(armor);
            }
        }
    }

    pub fn create_default_player_team() -> Team {
        let mut team = Team::new("Player Team".to_string(), true);
        
        // Create a balanced starting team
        team.add_unit(Unit::new("Gareth".to_string(), UnitClass::Warrior, 1, true));
        team.add_unit(Unit::new("Lyra".to_string(), UnitClass::Archer, 1, true));
        team.add_unit(Unit::new("Finn".to_string(), UnitClass::Rogue, 1, true));
        
        team
    }

    pub fn get_average_level(&self) -> f32 {
        if self.units.is_empty() {
            return 0.0;
        }
        
        let total_level: u32 = self.units.iter().map(|u| u.stats.level).sum();
        total_level as f32 / self.units.len() as f32
    }

    pub fn heal_all_units(&mut self) {
        for unit in &mut self.units {
            unit.stats.health = unit.stats.max_health;
        }
    }
}

fn generate_enemy_name(rng: &mut impl Rng) -> String {
    let prefixes = ["Dark", "Shadow", "Blood", "Iron", "Stone", "Frost", "Fire", "Wild"];
    let names = ["Grunt", "Warrior", "Fighter", "Soldier", "Guard", "Brute", "Champion", "Destroyer"];
    
    format!("{} {}", 
        prefixes.choose(rng).unwrap(),
        names.choose(rng).unwrap()
    )
}