use crate::player::{Player, Stats};
use crate::map::Position;
use rand::Rng;

#[derive(Debug, Clone)]
pub struct Enemy {
    pub name: String,
    pub stats: Stats,
    pub gold_reward: u32,
    pub exp_reward: u32,
    pub position: Position,
    pub symbol: char,
}

impl Enemy {
    pub fn new(name: &str, level: u32, symbol: char) -> Self {
        let stats = Stats::new(level);
        Enemy {
            name: name.to_string(),
            stats,
            gold_reward: level * 10,
            exp_reward: level * 25,
            position: Position::new(0, 0), // Will be set by the map
            symbol,
        }
    }

    pub fn goblin(level: u32) -> Self {
        Enemy::new("Goblin", level, 'G')
    }

    pub fn orc(level: u32) -> Self {
        let mut enemy = Enemy::new("Orc", level, 'O');
        enemy.stats.attack += 2;
        enemy.stats.health += 10;
        enemy.stats.max_health += 10;
        enemy.gold_reward += 5;
        enemy
    }

    pub fn dragon(level: u32) -> Self {
        let mut enemy = Enemy::new("Dragon", level, 'D');
        enemy.stats.attack *= 2;
        enemy.stats.defense += 5;
        enemy.stats.health *= 3;
        enemy.stats.max_health *= 3;
        enemy.gold_reward *= 5;
        enemy.exp_reward *= 3;
        enemy
    }
}

pub struct CombatResult {
    pub player_won: bool,
    pub gold_gained: u32,
    pub exp_gained: u32,
}

pub fn battle(player: &mut Player, enemy: &mut Enemy, weapon_bonus: u32, armor_bonus: u32) -> CombatResult {
    println!("\n⚔️  Battle begins against {}! ⚔️", enemy.name);
    
    let mut rng = rand::thread_rng();
    
    while player.stats.is_alive() && enemy.stats.is_alive() {
        // Player attacks first if faster, otherwise enemy goes first
        if player.stats.speed >= enemy.stats.speed {
            player_attack(player, &mut enemy.stats, weapon_bonus, &mut rng);
            if enemy.stats.is_alive() {
                enemy_attack(player, enemy, armor_bonus, &mut rng);
            }
        } else {
            enemy_attack(player, enemy, armor_bonus, &mut rng);
            if player.stats.is_alive() {
                player_attack(player, &mut enemy.stats, weapon_bonus, &mut rng);
            }
        }
        
        println!("Player HP: {}/{}", player.stats.health, player.stats.max_health);
        println!("{} HP: {}/{}\n", enemy.name, enemy.stats.health, enemy.stats.max_health);
    }
    
    if player.stats.is_alive() {
        println!("🎉 Victory! You defeated the {}!", enemy.name);
        CombatResult {
            player_won: true,
            gold_gained: enemy.gold_reward,
            exp_gained: enemy.exp_reward,
        }
    } else {
        println!("💀 Defeat! You were slain by the {}...", enemy.name);
        CombatResult {
            player_won: false,
            gold_gained: 0,
            exp_gained: 0,
        }
    }
}

fn player_attack(player: &Player, enemy: &mut Stats, weapon_bonus: u32, rng: &mut impl Rng) {
    let base_damage = player.stats.attack + weapon_bonus;
    let damage_variance = rng.gen_range(0..=(base_damage / 4));
    let total_damage = base_damage + damage_variance;
    let final_damage = total_damage.saturating_sub(enemy.defense);
    
    enemy.take_damage(final_damage);
    println!("{} attacks for {} damage!", player.name, final_damage);
}

fn enemy_attack(player: &mut Player, enemy: &Enemy, armor_bonus: u32, rng: &mut impl Rng) {
    let base_damage = enemy.stats.attack;
    let damage_variance = rng.gen_range(0..=(base_damage / 4));
    let total_damage = base_damage + damage_variance;
    let player_defense = player.stats.defense + armor_bonus;
    let final_damage = total_damage.saturating_sub(player_defense);
    
    player.stats.take_damage(final_damage);
    println!("{} attacks {} for {} damage!", enemy.name, player.name, final_damage);
}