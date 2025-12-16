use std::collections::HashMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

impl Position {
    pub fn new(x: i32, y: i32) -> Self {
        Position { x, y }
    }

    pub fn distance_to(&self, other: &Position) -> f32 {
        let dx = (self.x - other.x) as f32;
        let dy = (self.y - other.y) as f32;
        (dx * dx + dy * dy).sqrt()
    }

    pub fn manhattan_distance_to(&self, other: &Position) -> i32 {
        (self.x - other.x).abs() + (self.y - other.y).abs()
    }

    pub fn is_adjacent_to(&self, other: &Position) -> bool {
        self.manhattan_distance_to(other) == 1
    }

    pub fn move_toward(&self, target: &Position) -> Position {
        let mut new_pos = *self;
        
        let dx = target.x - self.x;
        let dy = target.y - self.y;
        
        // Move diagonally when possible for more natural movement
        if dx.abs() > dy.abs() {
            new_pos.x += dx.signum();
        } else if dy.abs() > dx.abs() {
            new_pos.y += dy.signum();
        } else if dx != 0 && dy != 0 {
            // Move diagonally
            new_pos.x += dx.signum();
            new_pos.y += dy.signum();
        } else if dx != 0 {
            new_pos.x += dx.signum();
        } else if dy != 0 {
            new_pos.y += dy.signum();
        }
        
        new_pos
    }

    pub fn move_around_target(&self, target: &Position, clockwise: bool) -> Position {
        let dx = target.x - self.x;
        let dy = target.y - self.y;
        
        // Calculate perpendicular movement for orbiting
        let (orbit_x, orbit_y) = if clockwise {
            (-dy.signum(), dx.signum())
        } else {
            (dy.signum(), -dx.signum())
        };
        
        Position::new(self.x + orbit_x, self.y + orbit_y)
    }

    pub fn retreat_from(&self, threat: &Position) -> Position {
        let dx = self.x - threat.x;
        let dy = self.y - threat.y;
        
        Position::new(
            self.x + dx.signum(),
            self.y + dy.signum()
        )
    }

    pub fn get_surrounding_positions(&self) -> Vec<Position> {
        vec![
            Position::new(self.x - 1, self.y - 1),
            Position::new(self.x, self.y - 1),
            Position::new(self.x + 1, self.y - 1),
            Position::new(self.x - 1, self.y),
            Position::new(self.x + 1, self.y),
            Position::new(self.x - 1, self.y + 1),
            Position::new(self.x, self.y + 1),
            Position::new(self.x + 1, self.y + 1),
        ]
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum Tile {
    Empty,
    Wall,
}

#[derive(Debug, Clone)]
pub struct Map {
    pub width: i32,
    pub height: i32,
    pub tiles: HashMap<Position, Tile>,
    pub player_position: Position,
    pub enemy_positions: Vec<Position>,
}

impl Map {
    pub fn new_arena(width: i32, height: i32) -> Self {
        let mut tiles = HashMap::new();
        
        // Fill the map with empty spaces and walls around the border
        for x in 0..width {
            for y in 0..height {
                let pos = Position::new(x, y);
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    tiles.insert(pos, Tile::Wall);
                } else {
                    tiles.insert(pos, Tile::Empty);
                }
            }
        }
        
        // Player starts at left side
        let player_position = Position::new(2, height / 2);
        
        // Single enemy starts at right side
        let enemy_positions = vec![Position::new(width - 3, height / 2)];
        
        Map {
            width,
            height,
            tiles,
            player_position,
            enemy_positions,
        }
    }

    pub fn is_valid_position(&self, pos: &Position) -> bool {
        if pos.x < 0 || pos.x >= self.width || pos.y < 0 || pos.y >= self.height {
            return false;
        }
        
        match self.tiles.get(pos) {
            Some(Tile::Empty) => true,
            _ => false,
        }
    }

    pub fn is_position_occupied(&self, pos: &Position) -> bool {
        if *pos == self.player_position {
            return true;
        }
        
        self.enemy_positions.contains(pos)
    }

    pub fn can_move_to(&self, pos: &Position) -> bool {
        self.is_valid_position(pos) && !self.is_position_occupied(pos)
    }

    pub fn move_player(&mut self, new_pos: Position) -> bool {
        if self.can_move_to(&new_pos) {
            self.player_position = new_pos;
            true
        } else {
            false
        }
    }

    pub fn move_enemy(&mut self, enemy_index: usize, new_pos: Position) -> bool {
        if enemy_index >= self.enemy_positions.len() {
            return false;
        }
        
        if self.can_move_to(&new_pos) {
            self.enemy_positions[enemy_index] = new_pos;
            true
        } else {
            false
        }
    }

    pub fn add_enemy(&mut self, pos: Position) {
        if self.can_move_to(&pos) {
            self.enemy_positions.push(pos);
        }
    }

    pub fn remove_enemy(&mut self, index: usize) {
        if index < self.enemy_positions.len() {
            self.enemy_positions.remove(index);
        }
    }

    pub fn render(&self, enemies: &[crate::combat::Enemy]) -> String {
        let mut output = String::new();
        
        for y in 0..self.height {
            for x in 0..self.width {
                let pos = Position::new(x, y);
                
                // Check if there's a player or enemy at this position
                if pos == self.player_position {
                    output.push('@');
                } else if let Some(enemy) = enemies.iter().find(|e| e.position == pos) {
                    output.push(enemy.symbol);
                } else {
                    // Render the tile
                    match self.tiles.get(&pos) {
                        Some(Tile::Wall) => output.push('.'),
                        Some(Tile::Empty) => output.push(' '),
                        None => output.push('?'), // Should never happen
                    }
                }
            }
            output.push('\n');
        }
        
        output
    }

    pub fn get_enemies_adjacent_to_player(&self) -> Vec<usize> {
        let mut adjacent_enemies = Vec::new();
        
        for (i, enemy_pos) in self.enemy_positions.iter().enumerate() {
            if self.player_position.is_adjacent_to(enemy_pos) {
                adjacent_enemies.push(i);
            }
        }
        
        adjacent_enemies
    }

    pub fn get_closest_enemy_to_player(&self) -> Option<usize> {
        if self.enemy_positions.is_empty() {
            return None;
        }

        let mut closest_index = 0;
        let mut closest_distance = self.player_position.distance_to(&self.enemy_positions[0]);

        for (i, enemy_pos) in self.enemy_positions.iter().enumerate().skip(1) {
            let distance = self.player_position.distance_to(enemy_pos);
            if distance < closest_distance {
                closest_distance = distance;
                closest_index = i;
            }
        }

        Some(closest_index)
    }
}