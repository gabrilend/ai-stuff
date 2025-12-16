use std::time::{Duration, Instant};
use crate::unit::Unit;
use crate::map::Position;

pub struct GameEngine {
    pub tick_rate: Duration,
    pub last_update: Instant,
    pub total_time: f32,
    pub running: bool,
}

impl GameEngine {
    pub fn new() -> Self {
        GameEngine {
            tick_rate: Duration::from_millis(50), // 20 FPS
            last_update: Instant::now(),
            total_time: 0.0,
            running: false,
        }
    }
    
    pub fn start(&mut self) {
        self.running = true;
        self.last_update = Instant::now();
        self.total_time = 0.0;
    }
    
    pub fn stop(&mut self) {
        self.running = false;
    }
    
    pub fn tick(&mut self) -> Option<f32> {
        if !self.running {
            return None;
        }
        
        let now = Instant::now();
        let delta_time = now.duration_since(self.last_update).as_secs_f32();
        self.last_update = now;
        self.total_time += delta_time;
        
        Some(delta_time)
    }
    
    pub fn should_update(&self) -> bool {
        self.running && Instant::now().duration_since(self.last_update) >= self.tick_rate
    }
}

#[derive(Debug, Clone)]
pub struct UnitMovement {
    pub unit_id: usize,
    pub start_pos: Position,
    pub target_pos: Position,
    pub start_time: f32,
    pub move_duration: f32,
    pub is_moving: bool,
}

impl UnitMovement {
    pub fn new(unit_id: usize, start_pos: Position, target_pos: Position, current_time: f32, speed: u32) -> Self {
        // Movement duration based on speed (higher speed = faster movement)
        // Base time of 1.0 seconds, modified by speed
        let move_duration = 1.0 / (speed as f32 / 10.0).max(0.5);
        
        UnitMovement {
            unit_id,
            start_pos,
            target_pos,
            start_time: current_time,
            move_duration,
            is_moving: true,
        }
    }
    
    pub fn get_current_position(&self, current_time: f32) -> Position {
        if !self.is_moving {
            return self.target_pos;
        }
        
        let elapsed = current_time - self.start_time;
        if elapsed >= self.move_duration {
            return self.target_pos;
        }
        
        // Linear interpolation between start and target positions
        let progress = elapsed / self.move_duration;
        let dx = (self.target_pos.x - self.start_pos.x) as f32 * progress;
        let dy = (self.target_pos.y - self.start_pos.y) as f32 * progress;
        
        Position::new(
            self.start_pos.x + dx.round() as i32,
            self.start_pos.y + dy.round() as i32,
        )
    }
    
    pub fn is_complete(&self, current_time: f32) -> bool {
        current_time - self.start_time >= self.move_duration
    }
}

pub struct BattleEngine {
    pub movements: Vec<UnitMovement>,
    pub last_action_time: f32,
    pub action_cooldown: f32, // Time between actions for units
}

impl BattleEngine {
    pub fn new() -> Self {
        BattleEngine {
            movements: Vec::new(),
            last_action_time: 0.0,
            action_cooldown: 2.0, // 2 seconds between major actions
        }
    }
    
    pub fn add_movement(&mut self, movement: UnitMovement) {
        // Remove existing movement for this unit
        self.movements.retain(|m| m.unit_id != movement.unit_id);
        self.movements.push(movement);
    }
    
    pub fn update_movements(&mut self, current_time: f32) {
        // Remove completed movements
        self.movements.retain(|m| !m.is_complete(current_time));
    }
    
    pub fn get_unit_position(&self, unit_id: usize, current_time: f32, default_pos: Position) -> Position {
        for movement in &self.movements {
            if movement.unit_id == unit_id {
                return movement.get_current_position(current_time);
            }
        }
        default_pos
    }
    
    pub fn can_take_action(&self, current_time: f32) -> bool {
        current_time - self.last_action_time >= self.action_cooldown
    }
    
    pub fn mark_action_taken(&mut self, current_time: f32) {
        self.last_action_time = current_time;
    }
    
    pub fn has_active_movements(&self) -> bool {
        !self.movements.is_empty()
    }
}