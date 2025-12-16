use serde::{Deserialize, Serialize};
use crate::map::Position;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Stats {
    pub health: u32,
    pub max_health: u32,
    pub attack: u32,
    pub defense: u32,
    pub speed: u32,
    pub level: u32,
    pub experience: u32,
}

impl Stats {
    pub fn new(level: u32) -> Self {
        let base_stats = 10 + (level * 2);
        Stats {
            health: base_stats * 5,
            max_health: base_stats * 5,
            attack: base_stats,
            defense: base_stats,
            speed: base_stats,
            level,
            experience: 0,
        }
    }

    pub fn is_alive(&self) -> bool {
        self.health > 0
    }

    pub fn take_damage(&mut self, damage: u32) {
        self.health = self.health.saturating_sub(damage);
    }

    pub fn heal(&mut self, amount: u32) {
        self.health = (self.health + amount).min(self.max_health);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Player {
    pub name: String,
    pub stats: Stats,
    pub gold: u32,
    pub position: Position,
}

impl Player {
    pub fn new(name: String) -> Self {
        Player {
            name,
            stats: Stats::new(1),
            gold: 100,
            position: Position::new(0, 0), // Will be set by the map
        }
    }

    pub fn gain_experience(&mut self, exp: u32) {
        self.stats.experience += exp;
        self.check_level_up();
    }

    fn check_level_up(&mut self) {
        let exp_needed = self.stats.level * 100;
        if self.stats.experience >= exp_needed {
            self.level_up();
        }
    }

    fn level_up(&mut self) {
        self.stats.level += 1;
        self.stats.experience = 0;
        
        // Increase stats on level up
        self.stats.max_health += 10;
        self.stats.health = self.stats.max_health; // Full heal on level up
        self.stats.attack += 2;
        self.stats.defense += 2;
        self.stats.speed += 1;
        
        println!("🎉 {} leveled up to level {}!", self.name, self.stats.level);
    }
}