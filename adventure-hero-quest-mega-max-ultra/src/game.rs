use crate::player::Player;
use crate::inventory::{Inventory, Item};
use crate::map::{Map, Position};
use crate::unit::{Unit, UnitClass};
use crate::team::Team;
use crate::colors::Colors;
use crate::engine::{GameEngine, BattleEngine, UnitMovement};
use std::io::{self, Write};
use std::thread;
use std::time::Duration;
use rand::Rng;

enum PlayerAction {
    Attack(usize),
    Move(Position),
}

enum EnemyAction {
    Attack(usize),
    Move(Position),
}

pub struct Game {
    pub player: Player, // Keep for legacy gold tracking
    pub inventory: Inventory, // Shared team inventory
    pub player_team: Team,
    pub enemy_team: Option<Team>,
    pub map: Map,
    pub running: bool,
    pub in_battle: bool,
    pub gold: u32,
    pub battle_number: u32,
    pub engine: GameEngine,
    pub battle_engine: BattleEngine,
}

impl Game {
    pub fn new() -> Self {
        // Create a default player for now
        let player = Player::new("Hero".to_string());
        let mut inventory = Inventory::new();
        
        // Give the player some starting items
        inventory.add_item(Item::new_weapon("Rusty Sword", 5, 10)).unwrap();
        inventory.add_item(Item::new_armor("Leather Armor", 3, 15)).unwrap();
        inventory.add_item(Item::new_potion("Health Potion", 50, 25)).unwrap();
        
        let map = Map::new_arena(78, 20); // Use full terminal width
        let player_team = Team::create_default_player_team();
        
        Game {
            player,
            inventory,
            player_team,
            enemy_team: None,
            map,
            running: true,
            in_battle: false,
            gold: 500, // Starting gold for auto-battler
            battle_number: 1,
            engine: GameEngine::new(),
            battle_engine: BattleEngine::new(),
        }
    }

    pub fn run(&mut self) {
        while self.running {
            self.show_main_menu();
            self.handle_input();
        }
        println!("Thanks for playing Auto-Battler Arena!");
    }

    fn show_main_menu(&self) {
        print!("{}", Colors::CLEAR_SCREEN);
        println!("\n{}{}{}", Colors::SUCCESS, "=== AUTO-BATTLER ARENA ===", Colors::RESET);
        println!("Battle #{} | {}Gold: {}{}", 
                 self.battle_number, 
                 Colors::GOLD, self.gold, Colors::RESET);
        println!("Your Team: {} (Power: {})", 
                 self.player_team.get_team_composition_string(),
                 self.player_team.get_total_power());
        
        // Show team status
        println!("\nTeam Status:");
        for (i, unit) in self.player_team.units.iter().enumerate() {
            let health_bar = if unit.stats.health == unit.stats.max_health {
                "████"
            } else if unit.stats.health > unit.stats.max_health * 3 / 4 {
                "███░"
            } else if unit.stats.health > unit.stats.max_health / 2 {
                "██░░"
            } else if unit.stats.health > unit.stats.max_health / 4 {
                "█░░░"
            } else if unit.stats.health > 0 {
                "▓░░░"
            } else {
                "░░░░"
            };
            
            println!("  {}. {}{}{} ({}) {} {}/{}",
                     i + 1,
                     Colors::unit_color(&unit.class, unit.is_player_unit),
                     unit.name,
                     Colors::RESET,
                     unit.class.get_name(),
                     health_bar,
                     unit.stats.health,
                     unit.stats.max_health);
        }
        
        println!();
        println!("What would you like to do?");
        println!("1. Manage Team");
        println!("2. Start Battle");
        println!("3. Shop (Coming Soon)");
        println!("4. View Battle History");
        println!("5. Quit");
        print!("Choose an option (1-5): ");
        io::stdout().flush().unwrap();
    }

    fn handle_input(&mut self) {
        let mut input = String::new();
        io::stdin().read_line(&mut input).expect("Failed to read line");
        
        match input.trim() {
            "1" => self.manage_team(),
            "2" => self.start_battle(),
            "3" => println!("Shop coming soon!"),
            "4" => println!("Battle history coming soon!"),
            "5" => {
                self.running = false;
            },
            _ => println!("Invalid option! Please choose 1-5."),
        }
    }

    fn manage_team(&mut self) {
        loop {
            print!("{}", Colors::CLEAR_SCREEN);
            println!("\n{}=== TEAM MANAGEMENT ==={}", Colors::INFO, Colors::RESET);
            println!("{}Gold: {}{}", Colors::GOLD, self.gold, Colors::RESET);
            println!("\nYour Team:");
            
            for (i, unit) in self.player_team.units.iter().enumerate() {
                println!("{}. {}{}{} ({}) - Level {} - Power: {}",
                         i + 1,
                         Colors::unit_color(&unit.class, unit.is_player_unit),
                         unit.name,
                         Colors::RESET,
                         unit.class.get_name(),
                         unit.stats.level,
                         unit.get_total_power());
                
                if let Some(weapon) = &unit.equipped_weapon {
                    println!("   {}Weapon: {} (+{} attack){}", Colors::WARNING, weapon.name, weapon.attack_bonus, Colors::RESET);
                }
                if let Some(armor) = &unit.equipped_armor {
                    println!("   {}Armor: {} (+{} defense){}", Colors::INFO, armor.name, armor.defense_bonus, Colors::RESET);
                }
            }
            
            println!("\nActions:");
            println!("1. View Unit Details");
            println!("2. Equip Items");
            println!("3. Recruit New Unit (50 gold)");
            println!("4. Heal All Units (20 gold)");
            println!("5. Back to Main Menu");
            print!("Choice: ");
            io::stdout().flush().unwrap();
            
            let mut input = String::new();
            io::stdin().read_line(&mut input).unwrap();
            
            match input.trim() {
                "1" => self.view_unit_details(),
                "2" => self.equip_items(),
                "3" => self.recruit_unit(),
                "4" => self.heal_team(),
                "5" => break,
                _ => println!("Invalid choice!"),
            }
        }
    }

    fn view_unit_details(&self) {
        print!("{}", Colors::CLEAR_SCREEN);
        println!("\n{}Which unit? (1-{}){}", Colors::INFO, self.player_team.units.len(), Colors::RESET);
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        
        if let Ok(choice) = input.trim().parse::<usize>() {
            if choice > 0 && choice <= self.player_team.units.len() {
                let unit = &self.player_team.units[choice - 1];
                print!("{}", Colors::CLEAR_SCREEN);
                println!("\n{}=== {} ==={}", 
                         Colors::unit_color(&unit.class, unit.is_player_unit),
                         unit.name,
                         Colors::RESET);
                println!("Class: {}", unit.class.get_name());
                println!("Level: {}", unit.stats.level);
                println!("Health: {}/{}", unit.stats.health, unit.stats.max_health);
                println!("Attack: {} (+{})", unit.stats.attack, unit.equipped_weapon.as_ref().map_or(0, |w| w.attack_bonus));
                println!("Defense: {} (+{})", unit.stats.defense, unit.equipped_armor.as_ref().map_or(0, |a| a.defense_bonus));
                println!("Speed: {}", unit.stats.speed);
                println!("Total Power: {}", unit.get_total_power());
                
                println!("\nPress Enter to continue...");
                let mut _input = String::new();
                io::stdin().read_line(&mut _input).unwrap();
            }
        }
    }

    fn equip_items(&mut self) {
        print!("{}", Colors::CLEAR_SCREEN);
        println!("\n{}Available Items in Inventory:{}", Colors::INFO, Colors::RESET);
        for (i, item) in self.inventory.items.iter().enumerate() {
            println!("{}. {} ({})", i + 1, item.name, item.description);
        }
        
        if self.inventory.items.is_empty() {
            println!("{}No items available!{}", Colors::WARNING, Colors::RESET);
            return;
        }
        
        println!("\nWhich item to equip? (0 to cancel)");
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        
        if let Ok(item_choice) = input.trim().parse::<usize>() {
            if item_choice == 0 {
                return;
            }
            if item_choice > 0 && item_choice <= self.inventory.items.len() {
                println!("\nEquip to which unit? (1-{})", self.player_team.units.len());
                let mut input2 = String::new();
                io::stdin().read_line(&mut input2).unwrap();
                
                if let Ok(unit_choice) = input2.trim().parse::<usize>() {
                    if unit_choice > 0 && unit_choice <= self.player_team.units.len() {
                        if let Some(item) = self.inventory.remove_item(item_choice - 1) {
                            let unit = &mut self.player_team.units[unit_choice - 1];
                            
                            match item.item_type {
                                crate::inventory::ItemType::Weapon => {
                                    if let Ok(old_item) = unit.equip_weapon(item.clone()) {
                                        if let Some(old) = old_item {
                                            self.inventory.add_item(old).ok();
                                        }
                                        println!("Equipped {} to {}!", item.name, unit.name);
                                    }
                                },
                                crate::inventory::ItemType::Armor => {
                                    if let Ok(old_item) = unit.equip_armor(item.clone()) {
                                        if let Some(old) = old_item {
                                            self.inventory.add_item(old).ok();
                                        }
                                        println!("Equipped {} to {}!", item.name, unit.name);
                                    }
                                },
                                _ => {
                                    println!("Cannot equip this item type!");
                                    self.inventory.add_item(item).ok();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fn recruit_unit(&mut self) {
        print!("{}", Colors::CLEAR_SCREEN);
        if self.gold < 50 {
            println!("{}Not enough gold! Need 50 gold to recruit.{}", Colors::ERROR, Colors::RESET);
            return;
        }
        
        if self.player_team.units.len() >= 6 {
            println!("{}Team is full! Maximum 6 units.{}", Colors::WARNING, Colors::RESET);
            return;
        }
        
        println!("\nAvailable Classes:");
        let classes = UnitClass::all_classes();
        for (i, class) in classes.iter().enumerate() {
            println!("{}. {} - {}", i + 1, class.get_name(), class.get_name());
        }
        
        println!("Choose class:");
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        
        if let Ok(choice) = input.trim().parse::<usize>() {
            if choice > 0 && choice <= classes.len() {
                println!("Enter unit name:");
                let mut name_input = String::new();
                io::stdin().read_line(&mut name_input).unwrap();
                let name = name_input.trim().to_string();
                
                let level = (self.player_team.get_average_level() as u32).max(1);
                let unit = Unit::new(name, classes[choice - 1].clone(), level, true);
                
                self.player_team.add_unit(unit);
                self.gold -= 50;
                println!("Unit recruited!");
            }
        }
    }

    fn heal_team(&mut self) {
        if self.gold < 20 {
            println!("Not enough gold! Need 20 gold to heal team.");
            return;
        }
        
        self.player_team.heal_all_units();
        self.gold -= 20;
        println!("Team fully healed!");
    }

    fn start_battle(&mut self) {
        // Generate enemy team
        let player_power = self.player_team.get_total_power();
        let level_range = {
            let avg_level = self.player_team.get_average_level() as u32;
            (avg_level.saturating_sub(1).max(1), avg_level + 2)
        };
        
        let enemy_team = Team::create_balanced_enemy_team(player_power, level_range);
        let enemy_power = enemy_team.get_total_power();
        
        // Calculate betting odds
        let odds = if enemy_power > player_power {
            let ratio = enemy_power as f32 / player_power as f32;
            format!("{:.1}:1", ratio)
        } else {
            let ratio = player_power as f32 / enemy_power as f32;
            format!("1:{:.1}", ratio)
        };
        
        println!("\n=== BATTLE {} PREVIEW ===", self.battle_number);
        println!("Your Team: {} (Power: {})", 
                 self.player_team.get_team_composition_string(),
                 player_power);
        println!("Enemy Team: {} (Power: {})", 
                 enemy_team.get_team_composition_string(),
                 enemy_power);
        println!("Odds: {}", odds);
        
        println!("\nPlace your bet (0 to skip betting): ");
        print!("Gold to wager: ");
        io::stdout().flush().unwrap();
        
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        
        let bet_amount = if let Ok(amount) = input.trim().parse::<u32>() {
            if amount > 0 && amount <= self.gold {
                amount
            } else {
                0
            }
        } else {
            0
        };
        
        if bet_amount > 0 {
            println!("Bet placed: {} gold", bet_amount);
            self.gold -= bet_amount; // Deduct bet amount
        } else {
            println!("No bet placed.");
        }
        
        self.enemy_team = Some(enemy_team);
        
        println!("\nPress Enter to start the battle...");
        let mut _input = String::new();
        io::stdin().read_line(&mut _input).unwrap();
        
        self.run_team_battle(bet_amount);
    }

    fn run_team_battle(&mut self, bet_amount: u32) {
        println!("\n🏟️  BATTLE {} BEGINS! 🏟️", self.battle_number);
        
        // Position teams - players at bottom, enemies at top
        self.player_team.position_units_for_battle(self.map.width, self.map.height, true);
        if let Some(ref mut enemy_team) = self.enemy_team {
            enemy_team.position_units_for_battle(self.map.width, self.map.height, false);
        }
        
        self.in_battle = true;
        self.engine.start();
        self.battle_engine = BattleEngine::new();
        
        // Main game loop
        while self.in_battle {
            if let Some(delta_time) = self.engine.tick() {
                // Update battle state
                self.update_battle(delta_time);
                
                // Render if enough time has passed
                if self.engine.should_update() {
                    self.render_battle_frame();
                }
                
                // Check for battle end
                if self.player_team.is_defeated() || self.enemy_team.as_ref().map_or(true, |e| e.is_defeated()) {
                    self.end_battle(bet_amount);
                    break;
                }
            }
            
            // Small sleep to prevent CPU spinning
            thread::sleep(Duration::from_millis(16)); // ~60 FPS cap
        }
        
        self.engine.stop();
    }
    
    fn update_battle(&mut self, delta_time: f32) {
        // Update movement animations
        self.battle_engine.update_movements(self.engine.total_time);
        
        // Check if it's time for units to take actions (move or attack)
        if self.battle_engine.can_take_action(self.engine.total_time) {
            self.process_unit_actions();
            self.battle_engine.mark_action_taken(self.engine.total_time);
        }
    }
    
    fn render_battle_frame(&self) {
        // Clear screen
        print!("{}", Colors::CLEAR_SCREEN);
        
        println!("=== {}BATTLE {}{} - {:.1}s ===", 
                 Colors::SUCCESS, self.battle_number, Colors::RESET, self.engine.total_time);
        
        // Show team status
        self.display_battle_status();
        
        // Show the battlefield with real-time positions
        self.render_battlefield_realtime();
        
        // Show movement status
        if self.battle_engine.has_active_movements() {
            println!("{}🏃 Units moving...{}", Colors::INFO, Colors::RESET);
        }
    }
    
    fn process_unit_actions(&mut self) {
        // Collect actions to perform first, then execute them
        let mut player_actions = Vec::new();
        let mut enemy_actions = Vec::new();
        
        // Determine player actions
        {
            let enemy_units = self.enemy_team.as_ref().map(|t| t.units.clone()).unwrap_or_default();
            let ally_units = self.player_team.units.clone();
            
            for (i, unit) in self.player_team.units.iter().enumerate() {
                if !unit.stats.is_alive() {
                    continue;
                }
                
                // Check if unit should attack
                if let Some(target_idx) = unit.should_attack(&enemy_units) {
                    player_actions.push((i, PlayerAction::Attack(target_idx)));
                } else {
                    // Determine movement
                    let mut unit_copy = unit.clone();
                    let new_pos = unit_copy.get_tactical_move(&enemy_units, &ally_units, 
                                                           self.engine.total_time as u32, 
                                                           self.map.width, self.map.height);
                    
                    if new_pos != unit.position {
                        player_actions.push((i, PlayerAction::Move(new_pos)));
                    }
                }
            }
        }
        
        // Determine enemy actions
        if let Some(ref enemy_team) = self.enemy_team {
            let player_units = self.player_team.units.clone();
            let ally_units = enemy_team.units.clone();
            
            for (i, unit) in enemy_team.units.iter().enumerate() {
                if !unit.stats.is_alive() {
                    continue;
                }
                
                // Check if unit should attack
                if let Some(target_idx) = unit.should_attack(&player_units) {
                    enemy_actions.push((i, EnemyAction::Attack(target_idx)));
                } else {
                    // Determine movement
                    let mut unit_copy = unit.clone();
                    let new_pos = unit_copy.get_tactical_move(&player_units, &ally_units, 
                                                           self.engine.total_time as u32, 
                                                           self.map.width, self.map.height);
                    
                    if new_pos != unit.position {
                        enemy_actions.push((i, EnemyAction::Move(new_pos)));
                    }
                }
            }
        }
        
        // Execute player actions
        for (unit_idx, action) in player_actions {
            match action {
                PlayerAction::Attack(target_idx) => {
                    self.execute_attack(unit_idx, target_idx, true);
                },
                PlayerAction::Move(new_pos) => {
                    if !self.is_position_occupied(&new_pos, unit_idx, true) {
                        let unit = &mut self.player_team.units[unit_idx];
                        let movement = UnitMovement::new(unit_idx, unit.position, new_pos, 
                                                       self.engine.total_time, unit.stats.speed);
                        self.battle_engine.add_movement(movement);
                        
                        println!("{}{}{} {} moves to ({}, {})", 
                                 Colors::unit_color(&unit.class, unit.is_player_unit),
                                 unit.get_symbol(),
                                 Colors::RESET,
                                 unit.name, new_pos.x, new_pos.y);
                        
                        unit.position = new_pos;
                    }
                }
            }
        }
        
        // Execute enemy actions
        for (unit_idx, action) in enemy_actions {
            match action {
                EnemyAction::Attack(target_idx) => {
                    self.execute_attack(unit_idx, target_idx, false);
                },
                EnemyAction::Move(new_pos) => {
                    if !self.is_position_occupied(&new_pos, unit_idx, false) {
                        if let Some(ref mut enemy_team) = self.enemy_team {
                            let unit = &mut enemy_team.units[unit_idx];
                            let enemy_unit_id = 1000 + unit_idx;
                            let movement = UnitMovement::new(enemy_unit_id, unit.position, new_pos, 
                                                           self.engine.total_time, unit.stats.speed);
                            self.battle_engine.add_movement(movement);
                            
                            println!("{}{}{} {} moves to ({}, {})", 
                                     Colors::unit_color(&unit.class, unit.is_player_unit),
                                     unit.get_symbol(),
                                     Colors::RESET,
                                     unit.name, new_pos.x, new_pos.y);
                            
                            unit.position = new_pos;
                        }
                    }
                }
            }
        }
    }

    fn display_battle_status(&self) {
        println!("{}Player Team:{}", Colors::PLAYER_WARRIOR, Colors::RESET);
        for unit in &self.player_team.units {
            if unit.stats.is_alive() {
                println!("  {}{}{} ({}) HP: {}/{}", 
                         Colors::unit_color(&unit.class, unit.is_player_unit),
                         unit.name,
                         Colors::RESET,
                         unit.get_colored_symbol(),
                         unit.stats.health, unit.stats.max_health);
            }
        }
        
        if let Some(ref enemy_team) = self.enemy_team {
            println!("\n{}Enemy Team:{}", Colors::ENEMY_WARRIOR, Colors::RESET);
            for unit in &enemy_team.units {
                if unit.stats.is_alive() {
                    println!("  {}{}{} ({}) HP: {}/{}", 
                             Colors::unit_color(&unit.class, unit.is_player_unit),
                             unit.name,
                             Colors::RESET,
                             unit.get_colored_symbol(),
                             unit.stats.health, unit.stats.max_health);
                }
            }
        }
        println!();
    }
    
    fn render_battlefield_realtime(&self) {
        // Create a field for positions that contain units
        let mut unit_positions = std::collections::HashMap::new();
        
        // Map player units to their current animated positions
        for (i, unit) in self.player_team.units.iter().enumerate() {
            if unit.stats.is_alive() {
                let current_pos = self.battle_engine.get_unit_position(i, self.engine.total_time, unit.position);
                let x = current_pos.x;
                let y = current_pos.y;
                if x >= 0 && x < self.map.width && y >= 0 && y < self.map.height {
                    unit_positions.insert((x, y), unit.get_colored_symbol());
                }
            }
        }
        
        // Map enemy units to their current animated positions
        if let Some(ref enemy_team) = self.enemy_team {
            for (i, unit) in enemy_team.units.iter().enumerate() {
                if unit.stats.is_alive() {
                    let enemy_unit_id = 1000 + i;
                    let current_pos = self.battle_engine.get_unit_position(enemy_unit_id, self.engine.total_time, unit.position);
                    let x = current_pos.x;
                    let y = current_pos.y;
                    if x >= 0 && x < self.map.width && y >= 0 && y < self.map.height {
                        unit_positions.insert((x, y), unit.get_colored_symbol());
                    }
                }
            }
        }
        
        // Render the field
        for y in 0..self.map.height {
            for x in 0..self.map.width {
                if x == 0 || x == self.map.width - 1 || y == 0 || y == self.map.height - 1 {
                    print!("{}·{}", Colors::INFO, Colors::RESET);
                } else if let Some(colored_symbol) = unit_positions.get(&(x, y)) {
                    print!("{}", colored_symbol);
                } else {
                    print!(" ");
                }
            }
            println!();
        }
        println!();
    }
    
    fn execute_attack(&mut self, attacker_idx: usize, target_idx: usize, is_player_attacking: bool) {
        if is_player_attacking {
            // Player attacking enemy
            if let Some(ref mut enemy_team) = self.enemy_team {
                if target_idx < enemy_team.units.len() && enemy_team.units[target_idx].stats.is_alive() {
                    let attacker = &self.player_team.units[attacker_idx];
                    let mut rng = rand::thread_rng();
                    
                    let base_damage = attacker.get_total_attack();
                    let damage_variance = rng.gen_range(0..=(base_damage / 4).max(1));
                    let total_damage = base_damage + damage_variance;
                    let final_damage = total_damage.saturating_sub(enemy_team.units[target_idx].get_total_defense());
                    
                    enemy_team.units[target_idx].stats.take_damage(final_damage);
                    
                    let attack_verb = match attacker.class {
                        crate::unit::UnitClass::Archer => "shoots",
                        crate::unit::UnitClass::Mage => "casts at",
                        _ => "attacks",
                    };
                    
                    println!("{}{}{} {} {} {}{}{} for {}{}{}  damage!", 
                             Colors::unit_color(&attacker.class, attacker.is_player_unit),
                             attacker.get_symbol(),
                             Colors::RESET,
                             attacker.name, attack_verb,
                             Colors::unit_color(&enemy_team.units[target_idx].class, enemy_team.units[target_idx].is_player_unit),
                             enemy_team.units[target_idx].name,
                             Colors::RESET,
                             Colors::WARNING, final_damage, Colors::RESET);
                    
                    if !enemy_team.units[target_idx].stats.is_alive() {
                        println!("{}💀 {} is defeated!{}", 
                                 Colors::ERROR,
                                 enemy_team.units[target_idx].name,
                                 Colors::RESET);
                    }
                }
            }
        } else {
            // Enemy attacking player
            if target_idx < self.player_team.units.len() && self.player_team.units[target_idx].stats.is_alive() {
                if let Some(ref enemy_team) = self.enemy_team {
                    let attacker = &enemy_team.units[attacker_idx];
                    let mut rng = rand::thread_rng();
                    
                    let base_damage = attacker.get_total_attack();
                    let damage_variance = rng.gen_range(0..=(base_damage / 4).max(1));
                    let total_damage = base_damage + damage_variance;
                    let final_damage = total_damage.saturating_sub(self.player_team.units[target_idx].get_total_defense());
                    
                    self.player_team.units[target_idx].stats.take_damage(final_damage);
                    
                    let attack_verb = match attacker.class {
                        crate::unit::UnitClass::Archer => "shoots",
                        crate::unit::UnitClass::Mage => "casts at",
                        _ => "attacks",
                    };
                    
                    println!("{}{}{} {} {} {}{}{} for {}{}{}  damage!", 
                             Colors::unit_color(&attacker.class, attacker.is_player_unit),
                             attacker.get_symbol(),
                             Colors::RESET,
                             attacker.name, attack_verb,
                             Colors::unit_color(&self.player_team.units[target_idx].class, self.player_team.units[target_idx].is_player_unit),
                             self.player_team.units[target_idx].name,
                             Colors::RESET,
                             Colors::WARNING, final_damage, Colors::RESET);
                    
                    if !self.player_team.units[target_idx].stats.is_alive() {
                        println!("{}💀 {} is defeated!{}", 
                                 Colors::ERROR,
                                 self.player_team.units[target_idx].name,
                                 Colors::RESET);
                    }
                }
            }
        }
    }

    fn render_battlefield(&self) {
        // Create a field for positions that contain units
        let mut unit_positions = std::collections::HashMap::new();
        
        // Map player units to their positions
        for unit in &self.player_team.units {
            if unit.stats.is_alive() {
                let x = unit.position.x;
                let y = unit.position.y;
                if x >= 0 && x < self.map.width && y >= 0 && y < self.map.height {
                    unit_positions.insert((x, y), unit.get_colored_symbol());
                }
            }
        }
        
        // Map enemy units to their positions
        if let Some(ref enemy_team) = self.enemy_team {
            for unit in &enemy_team.units {
                if unit.stats.is_alive() {
                    let x = unit.position.x;
                    let y = unit.position.y;
                    if x >= 0 && x < self.map.width && y >= 0 && y < self.map.height {
                        unit_positions.insert((x, y), unit.get_colored_symbol());
                    }
                }
            }
        }
        
        // Render the field
        for y in 0..self.map.height {
            for x in 0..self.map.width {
                if (x == 0 || x == self.map.width - 1 || y == 0 || y == self.map.height - 1) {
                    print!("{}·{}", Colors::INFO, Colors::RESET);
                } else if let Some(colored_symbol) = unit_positions.get(&(x, y)) {
                    print!("{}", colored_symbol);
                } else {
                    print!(" ");
                }
            }
            println!();
        }
        println!();
    }


    fn is_position_occupied(&self, pos: &Position, unit_index: usize, is_player_unit: bool) -> bool {
        // Check player units
        for (i, unit) in self.player_team.units.iter().enumerate() {
            if unit.stats.is_alive() && unit.position == *pos {
                // Skip checking the unit that's trying to move
                if is_player_unit && i == unit_index {
                    continue;
                }
                return true;
            }
        }
        
        // Check enemy units
        if let Some(ref enemy_team) = self.enemy_team {
            for (i, unit) in enemy_team.units.iter().enumerate() {
                if unit.stats.is_alive() && unit.position == *pos {
                    // Skip checking the unit that's trying to move
                    if !is_player_unit && i == unit_index {
                        continue;
                    }
                    return true;
                }
            }
        }
        
        false
    }

    fn end_battle(&mut self, bet_amount: u32) {
        self.in_battle = false;
        
        let player_won = !self.player_team.is_defeated();
        
        if player_won {
            println!("\n{}🎉 VICTORY! Your team wins!{}", Colors::SUCCESS, Colors::RESET);
            let base_reward = 50 + (self.battle_number * 10);
            self.gold += base_reward;
            
            if bet_amount > 0 {
                // Calculate winnings based on odds
                let enemy_power = self.enemy_team.as_ref().map_or(0, |e| e.get_total_power());
                let player_power = self.player_team.get_total_power();
                
                let winnings = if enemy_power > player_power {
                    // Player was underdog, better payout
                    let multiplier = (enemy_power as f32 / player_power as f32).max(1.1);
                    (bet_amount as f32 * multiplier) as u32
                } else {
                    // Player was favorite, standard payout
                    bet_amount / 2
                };
                
                self.gold += winnings;
                println!("{}Bet winnings: {} gold!{}", Colors::GOLD, winnings, Colors::RESET);
            }
            
            println!("{}Battle reward: {} gold{}", Colors::GOLD, base_reward, Colors::RESET);
        } else {
            println!("\n{}💀 DEFEAT! Your team has fallen...{}", Colors::ERROR, Colors::RESET);
            if bet_amount > 0 {
                println!("{}Lost bet: {} gold{}", Colors::ERROR, bet_amount, Colors::RESET);
            }
        }
        
        self.battle_number += 1;
        self.enemy_team = None;
        
        println!("\nPress Enter to continue...");
        let mut _input = String::new();
        io::stdin().read_line(&mut _input).unwrap();
    }
}