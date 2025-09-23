use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Battleship-Pong: A multiplayer pong/brick breaker hybrid for Anbernic devices
/// Players can only see 3 rows of opponent's screen, with roguelike and map painting elements
#[derive(Debug, Clone)]
pub struct BattleshipPong {
    pub game_state: GameState,
    pub local_player: Player,
    pub remote_players: HashMap<String, Player>,
    pub ball: Ball,
    pub bricks: Vec<Brick>,
    pub visibility_window: VisibilityWindow,
    pub map_painter: MapPainter,
    pub roguelike_elements: RoguelikeSystem,
    pub network: NetworkState,
    pub ui_state: PongUIState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GameState {
    WaitingForPlayers,
    Playing,
    Paused,
    GameOver,
    MapPainting,
    BrickBuilding,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Player {
    pub id: String,
    pub device_name: String,
    pub paddle: Paddle,
    pub score: u32,
    pub lives: u32,
    pub power_ups: Vec<PowerUp>,
    pub visible_area: VisibleArea,
    pub last_seen: DateTime<Utc>,
    pub anbernic_model: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Paddle {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub velocity: f32,
    pub max_speed: f32,
    pub color: PongColor,
    pub special_ability: Option<PaddleAbility>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PaddleAbility {
    Multiball,
    StickyPaddle,
    LaserShot,
    ShieldGenerator,
    GhostMode,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ball {
    pub x: f32,
    pub y: f32,
    pub velocity_x: f32,
    pub velocity_y: f32,
    pub radius: f32,
    pub trail: Vec<BallTrail>,
    pub power_level: u32,
    pub bounces: u32,
    pub last_paddle_hit: Option<String>, // Player ID
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BallTrail {
    pub x: f32,
    pub y: f32,
    pub timestamp: DateTime<Utc>,
    pub alpha: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Brick {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub health: u32,
    pub max_health: u32,
    pub brick_type: BrickType,
    pub color: PongColor,
    pub drops_powerup: Option<PowerUpType>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum BrickType {
    Normal,
    Armored,
    Explosive,
    Regenerating,
    Invisible,
    Teleporter,
    Spawner,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PowerUp {
    pub x: f32,
    pub y: f32,
    pub power_type: PowerUpType,
    pub duration: f32,
    pub active: bool,
    pub collected_by: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PowerUpType {
    BigPaddle,
    SmallPaddle,
    FastBall,
    SlowBall,
    Multiball,
    StickyPaddle,
    LaserPaddle,
    Shield,
    ExtraLife,
    ScoreMultiplier,
    TimeStop,
    BrickBreaker,
}

/// Limited visibility system - each player can only see 3 rows of opponent's area
#[derive(Debug, Clone)]
pub struct VisibilityWindow {
    pub visible_rows: u32,
    pub total_rows: u32,
    pub scroll_offset: f32,
    pub fog_of_war: Vec<Vec<bool>>,
    pub revealed_areas: Vec<RevealedArea>,
}

#[derive(Debug, Clone)]
pub struct RevealedArea {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub reveal_time: DateTime<Utc>,
    pub duration: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VisibleArea {
    pub start_row: u32,
    pub end_row: u32,
    pub known_bricks: Vec<Brick>,
    pub known_powerups: Vec<PowerUp>,
    pub last_update: DateTime<Utc>,
}

/// Map painting system for creating custom brick layouts
#[derive(Debug, Clone)]
pub struct MapPainter {
    pub canvas: Vec<Vec<BrickType>>,
    pub brush: BrushTool,
    pub current_layer: u32,
    pub canvas_width: u32,
    pub canvas_height: u32,
    pub saved_maps: Vec<CustomMap>,
}

#[derive(Debug, Clone)]
pub struct BrushTool {
    pub brush_type: BrickType,
    pub brush_size: u32,
    pub paint_mode: PaintMode,
}

#[derive(Debug, Clone)]
pub enum PaintMode {
    Paint,
    Erase,
    Fill,
    Line,
    Rectangle,
    Circle,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomMap {
    pub name: String,
    pub author: String,
    pub bricks: Vec<Brick>,
    pub difficulty: u32,
    pub created_at: DateTime<Utc>,
    pub anbernic_signature: String,
}

/// Roguelike progression system
#[derive(Debug, Clone)]
pub struct RoguelikeSystem {
    pub current_level: u32,
    pub experience_points: u32,
    pub skill_tree: SkillTree,
    pub unlocked_abilities: Vec<PaddleAbility>,
    pub artifacts: Vec<Artifact>,
    pub level_progression: LevelProgression,
}

#[derive(Debug, Clone)]
pub struct SkillTree {
    pub nodes: Vec<SkillNode>,
    pub available_points: u32,
}

#[derive(Debug, Clone)]
pub struct SkillNode {
    pub id: String,
    pub name: String,
    pub description: String,
    pub unlocked: bool,
    pub cost: u32,
    pub prerequisites: Vec<String>,
    pub effect: SkillEffect,
}

#[derive(Debug, Clone)]
pub enum SkillEffect {
    PaddleSpeedBoost(f32),
    BallControlImproved,
    PowerUpDurationExtended(f32),
    BrickDamageIncreased(u32),
    VisibilityRangeExtended(u32),
    MultiballMastery,
    ShieldCapacity(u32),
}

#[derive(Debug, Clone)]
pub struct Artifact {
    pub name: String,
    pub description: String,
    pub rarity: ArtifactRarity,
    pub effect: ArtifactEffect,
    pub found_at_level: u32,
}

#[derive(Debug, Clone)]
pub enum ArtifactRarity {
    Common,
    Rare,
    Epic,
    Legendary,
    Anbernic, // Special rarity for Anbernic-exclusive artifacts
}

#[derive(Debug, Clone)]
pub enum ArtifactEffect {
    PermanentStatBoost(StatType, f32),
    SpecialAbility(PaddleAbility),
    PassiveEffect(PassiveEffect),
}

#[derive(Debug, Clone)]
pub enum StatType {
    PaddleSpeed,
    BallAccuracy,
    PowerUpAttraction,
    BrickPenetration,
    VisibilityRange,
}

#[derive(Debug, Clone)]
pub enum PassiveEffect {
    BallMagnetism,
    AutoTargeting,
    HealthRegeneration,
    ScoreBonus(f32),
    LuckBoost,
}

#[derive(Debug, Clone)]
pub struct LevelProgression {
    pub levels_completed: Vec<CompletedLevel>,
    pub current_difficulty: f32,
    pub boss_battles_won: u32,
    pub secret_areas_found: u32,
}

#[derive(Debug, Clone)]
pub struct CompletedLevel {
    pub level_number: u32,
    pub completion_time: DateTime<Utc>,
    pub score: u32,
    pub perfect_clear: bool,
    pub secrets_found: u32,
}

#[derive(Debug, Clone)]
pub struct NetworkState {
    pub connected_players: Vec<String>,
    pub game_session_id: String,
    pub is_host: bool,
    pub wifi_party_mode: bool,
    pub sync_state: SyncState,
    pub latency_ms: u32,
}

#[derive(Debug, Clone)]
pub enum SyncState {
    Synchronized,
    Syncing,
    Desynchronized,
    Reconnecting,
}

#[derive(Debug, Clone)]
pub struct PongUIState {
    pub current_screen: PongScreen,
    pub hud_elements: HUDElements,
    pub game_camera: GameCamera,
    pub particle_effects: Vec<ParticleEffect>,
}

#[derive(Debug, Clone)]
pub enum PongScreen {
    MainMenu,
    LobbyWait,
    Playing,
    MapPainter,
    SkillTree,
    GameOver,
    NetworkSetup,
}

#[derive(Debug, Clone)]
pub struct HUDElements {
    pub score_display: ScoreDisplay,
    pub minimap: Minimap,
    pub visibility_indicator: VisibilityIndicator,
    pub power_up_bar: PowerUpBar,
    pub health_bar: HealthBar,
    pub level_progress: LevelProgressBar,
}

#[derive(Debug, Clone)]
pub struct ScoreDisplay {
    pub local_score: u32,
    pub remote_scores: HashMap<String, u32>,
    pub combo_multiplier: f32,
    pub score_animation: Option<ScoreAnimation>,
}

#[derive(Debug, Clone)]
pub struct ScoreAnimation {
    pub text: String,
    pub x: f32,
    pub y: f32,
    pub duration: f32,
    pub color: PongColor,
}

#[derive(Debug, Clone)]
pub struct Minimap {
    pub visible: bool,
    pub scale: f32,
    pub center_x: f32,
    pub center_y: f32,
    pub fog_overlay: bool,
}

#[derive(Debug, Clone)]
pub struct VisibilityIndicator {
    pub current_visible_rows: u32,
    pub max_rows: u32,
    pub scan_progress: f32,
    pub enemy_detection: Vec<EnemyBlip>,
}

#[derive(Debug, Clone)]
pub struct EnemyBlip {
    pub x: f32,
    pub y: f32,
    pub player_id: String,
    pub last_seen: DateTime<Utc>,
    pub confidence: f32,
}

#[derive(Debug, Clone)]
pub struct PowerUpBar {
    pub active_powerups: Vec<ActivePowerUp>,
    pub cooldowns: HashMap<PowerUpType, f32>,
}

#[derive(Debug, Clone)]
pub struct ActivePowerUp {
    pub power_type: PowerUpType,
    pub remaining_time: f32,
    pub intensity: f32,
}

#[derive(Debug, Clone)]
pub struct HealthBar {
    pub current_health: u32,
    pub max_health: u32,
    pub shield_health: u32,
    pub regeneration_rate: f32,
}

#[derive(Debug, Clone)]
pub struct LevelProgressBar {
    pub current_xp: u32,
    pub xp_to_next_level: u32,
    pub level: u32,
    pub progress_percentage: f32,
}

#[derive(Debug, Clone)]
pub struct GameCamera {
    pub x: f32,
    pub y: f32,
    pub zoom: f32,
    pub shake_intensity: f32,
    pub follow_ball: bool,
}

#[derive(Debug, Clone)]
pub struct ParticleEffect {
    pub x: f32,
    pub y: f32,
    pub velocity_x: f32,
    pub velocity_y: f32,
    pub life: f32,
    pub max_life: f32,
    pub color: PongColor,
    pub effect_type: EffectType,
}

#[derive(Debug, Clone)]
pub enum EffectType {
    BrickExplosion,
    PaddleHit,
    PowerUpCollection,
    BallTrail,
    LevelUp,
    ScorePoints,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PongColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl PongColor {
    pub fn new(r: u8, g: u8, b: u8, a: u8) -> Self {
        Self { r, g, b, a }
    }

    pub fn white() -> Self {
        Self::new(255, 255, 255, 255)
    }

    pub fn red() -> Self {
        Self::new(255, 0, 0, 255)
    }

    pub fn blue() -> Self {
        Self::new(0, 0, 255, 255)
    }

    pub fn green() -> Self {
        Self::new(0, 255, 0, 255)
    }

    pub fn anbernic_orange() -> Self {
        Self::new(255, 140, 0, 255)
    }
}

impl BattleshipPong {
    pub fn new(player_name: String) -> Self {
        let local_player = Player {
            id: format!("anbernic_{}", chrono::Utc::now().timestamp()),
            device_name: player_name,
            paddle: Paddle {
                x: 50.0,
                y: 400.0,
                width: 80.0,
                height: 12.0,
                velocity: 0.0,
                max_speed: 5.0,
                color: PongColor::anbernic_orange(),
                special_ability: None,
            },
            score: 0,
            lives: 3,
            power_ups: vec![],
            visible_area: VisibleArea {
                start_row: 0,
                end_row: 3,
                known_bricks: vec![],
                known_powerups: vec![],
                last_update: chrono::Utc::now(),
            },
            last_seen: chrono::Utc::now(),
            anbernic_model: "RG35XX".to_string(),
        };

        let ball = Ball {
            x: 300.0,
            y: 300.0,
            velocity_x: 3.0,
            velocity_y: -3.0,
            radius: 6.0,
            trail: vec![],
            power_level: 1,
            bounces: 0,
            last_paddle_hit: None,
        };

        Self {
            game_state: GameState::WaitingForPlayers,
            local_player,
            remote_players: HashMap::new(),
            ball,
            bricks: Self::generate_default_bricks(),
            visibility_window: VisibilityWindow {
                visible_rows: 3,
                total_rows: 20,
                scroll_offset: 0.0,
                fog_of_war: vec![vec![false; 30]; 20],
                revealed_areas: vec![],
            },
            map_painter: MapPainter {
                canvas: vec![vec![BrickType::Normal; 30]; 20],
                brush: BrushTool {
                    brush_type: BrickType::Normal,
                    brush_size: 1,
                    paint_mode: PaintMode::Paint,
                },
                current_layer: 0,
                canvas_width: 30,
                canvas_height: 20,
                saved_maps: vec![],
            },
            roguelike_elements: RoguelikeSystem {
                current_level: 1,
                experience_points: 0,
                skill_tree: SkillTree {
                    nodes: Self::generate_skill_tree(),
                    available_points: 0,
                },
                unlocked_abilities: vec![],
                artifacts: vec![],
                level_progression: LevelProgression {
                    levels_completed: vec![],
                    current_difficulty: 1.0,
                    boss_battles_won: 0,
                    secret_areas_found: 0,
                },
            },
            network: NetworkState {
                connected_players: vec![],
                game_session_id: format!("pong_session_{}", chrono::Utc::now().timestamp()),
                is_host: true,
                wifi_party_mode: false,
                sync_state: SyncState::Synchronized,
                latency_ms: 0,
            },
            ui_state: PongUIState {
                current_screen: PongScreen::MainMenu,
                hud_elements: HUDElements {
                    score_display: ScoreDisplay {
                        local_score: 0,
                        remote_scores: HashMap::new(),
                        combo_multiplier: 1.0,
                        score_animation: None,
                    },
                    minimap: Minimap {
                        visible: true,
                        scale: 0.2,
                        center_x: 300.0,
                        center_y: 400.0,
                        fog_overlay: true,
                    },
                    visibility_indicator: VisibilityIndicator {
                        current_visible_rows: 3,
                        max_rows: 20,
                        scan_progress: 0.0,
                        enemy_detection: vec![],
                    },
                    power_up_bar: PowerUpBar {
                        active_powerups: vec![],
                        cooldowns: HashMap::new(),
                    },
                    health_bar: HealthBar {
                        current_health: 100,
                        max_health: 100,
                        shield_health: 0,
                        regeneration_rate: 1.0,
                    },
                    level_progress: LevelProgressBar {
                        current_xp: 0,
                        xp_to_next_level: 100,
                        level: 1,
                        progress_percentage: 0.0,
                    },
                },
                game_camera: GameCamera {
                    x: 0.0,
                    y: 0.0,
                    zoom: 1.0,
                    shake_intensity: 0.0,
                    follow_ball: false,
                },
                particle_effects: vec![],
            },
        }
    }

    /// Generate default brick layout for battleship-pong
    pub fn generate_default_bricks() -> Vec<Brick> {
        let mut bricks = vec![];

        // Create a battleship formation
        for row in 0..8 {
            for col in 0..12 {
                let brick_type = match row {
                    0..=1 => BrickType::Armored,   // Front line armor
                    2..=4 => BrickType::Normal,    // Main body
                    5..=6 => BrickType::Explosive, // Weapon bays
                    _ => BrickType::Regenerating,  // Shield generators
                };

                let health = match brick_type {
                    BrickType::Armored => 3,
                    BrickType::Explosive => 1,
                    BrickType::Regenerating => 2,
                    _ => 1,
                };

                bricks.push(Brick {
                    x: col as f32 * 50.0 + 50.0,
                    y: row as f32 * 25.0 + 50.0,
                    width: 45.0,
                    height: 20.0,
                    health,
                    max_health: health,
                    brick_type,
                    color: Self::brick_color(&brick_type),
                    drops_powerup: if row % 3 == 0 {
                        Some(PowerUpType::ExtraLife)
                    } else {
                        None
                    },
                });
            }
        }

        bricks
    }

    fn brick_color(brick_type: &BrickType) -> PongColor {
        match brick_type {
            BrickType::Normal => PongColor::blue(),
            BrickType::Armored => PongColor::new(128, 128, 128, 255), // Gray
            BrickType::Explosive => PongColor::red(),
            BrickType::Regenerating => PongColor::green(),
            BrickType::Invisible => PongColor::new(255, 255, 255, 64), // Semi-transparent
            BrickType::Teleporter => PongColor::new(255, 0, 255, 255), // Magenta
            BrickType::Spawner => PongColor::anbernic_orange(),
        }
    }

    /// Generate skill tree for roguelike progression
    fn generate_skill_tree() -> Vec<SkillNode> {
        vec![
            SkillNode {
                id: "paddle_speed_1".to_string(),
                name: "Swift Paddle".to_string(),
                description: "Increases paddle movement speed by 25%".to_string(),
                unlocked: false,
                cost: 1,
                prerequisites: vec![],
                effect: SkillEffect::PaddleSpeedBoost(0.25),
            },
            SkillNode {
                id: "ball_control_1".to_string(),
                name: "Ball Whisperer".to_string(),
                description: "Improved ball control and deflection accuracy".to_string(),
                unlocked: false,
                cost: 2,
                prerequisites: vec!["paddle_speed_1".to_string()],
                effect: SkillEffect::BallControlImproved,
            },
            SkillNode {
                id: "visibility_1".to_string(),
                name: "Eagle Eye".to_string(),
                description: "Extends visibility range by 1 row".to_string(),
                unlocked: false,
                cost: 3,
                prerequisites: vec![],
                effect: SkillEffect::VisibilityRangeExtended(1),
            },
            SkillNode {
                id: "multiball_mastery".to_string(),
                name: "Multiball Master".to_string(),
                description: "Unlocks advanced multiball techniques".to_string(),
                unlocked: false,
                cost: 5,
                prerequisites: vec!["ball_control_1".to_string()],
                effect: SkillEffect::MultiballMastery,
            },
        ]
    }

    /// Update game physics and state
    pub fn update(&mut self, delta_time: f32) {
        match self.game_state {
            GameState::Playing => {
                self.update_ball(delta_time);
                self.update_paddles(delta_time);
                self.update_bricks(delta_time);
                self.update_powerups(delta_time);
                self.update_particles(delta_time);
                self.update_visibility();
                self.check_collisions();
                self.update_roguelike_progression();
            }
            GameState::MapPainting => {
                self.update_map_painter();
            }
            _ => {}
        }
    }

    fn update_ball(&mut self, delta_time: f32) {
        // Update ball position
        self.ball.x += self.ball.velocity_x * delta_time * 60.0;
        self.ball.y += self.ball.velocity_y * delta_time * 60.0;

        // Add to trail
        self.ball.trail.push(BallTrail {
            x: self.ball.x,
            y: self.ball.y,
            timestamp: chrono::Utc::now(),
            alpha: 1.0,
        });

        // Keep trail length manageable
        if self.ball.trail.len() > 20 {
            self.ball.trail.remove(0);
        }

        // Update trail alpha
        for trail_point in &mut self.ball.trail {
            let age = chrono::Utc::now()
                .signed_duration_since(trail_point.timestamp)
                .num_milliseconds() as f32;
            trail_point.alpha = (1.0 - age / 1000.0).max(0.0);
        }

        // Boundary collisions
        if self.ball.x <= self.ball.radius || self.ball.x >= 600.0 - self.ball.radius {
            self.ball.velocity_x *= -1.0;
            self.add_particle_effect(EffectType::PaddleHit, self.ball.x, self.ball.y);
        }

        if self.ball.y <= self.ball.radius {
            self.ball.velocity_y *= -1.0;
            self.add_particle_effect(EffectType::PaddleHit, self.ball.x, self.ball.y);
        }

        // Check if ball is out of bounds (player loses)
        if self.ball.y >= 800.0 {
            self.handle_ball_out_of_bounds();
        }
    }

    fn update_paddles(&mut self, delta_time: f32) {
        // Update local paddle (will be controlled by input)
        let paddle = &mut self.local_player.paddle;

        // Apply velocity
        paddle.x += paddle.velocity * delta_time * 60.0;

        // Keep paddle in bounds
        paddle.x = paddle.x.max(0.0).min(600.0 - paddle.width);

        // Apply friction
        paddle.velocity *= 0.95;
    }

    fn update_bricks(&mut self, _delta_time: f32) {
        // Update regenerating bricks
        for brick in &mut self.bricks {
            if matches!(brick.brick_type, BrickType::Regenerating)
                && brick.health < brick.max_health
            {
                // Regenerate health slowly
                if chrono::Utc::now().timestamp() % 5 == 0 {
                    brick.health = (brick.health + 1).min(brick.max_health);
                }
            }
        }
    }

    fn update_powerups(&mut self, _delta_time: f32) {
        // Update active power-ups for local player
        for powerup in &mut self.local_player.power_ups {
            if powerup.active && powerup.duration > 0.0 {
                powerup.duration -= 1.0 / 60.0; // Assume 60 FPS
                if powerup.duration <= 0.0 {
                    powerup.active = false;
                }
            }
        }
    }

    fn update_particles(&mut self, delta_time: f32) {
        // Update particle effects
        for particle in &mut self.ui_state.particle_effects {
            particle.x += particle.velocity_x * delta_time;
            particle.y += particle.velocity_y * delta_time;
            particle.life -= delta_time;
        }

        // Remove expired particles
        self.ui_state.particle_effects.retain(|p| p.life > 0.0);
    }

    fn update_visibility(&mut self) {
        // Update fog of war based on limited visibility
        let visible_start = self.visibility_window.scroll_offset as u32;
        let visible_end = (visible_start + self.visibility_window.visible_rows)
            .min(self.visibility_window.total_rows);

        // Clear current visibility
        for row in &mut self.visibility_window.fog_of_war {
            for cell in row {
                *cell = false;
            }
        }

        // Set visible rows
        for row_idx in visible_start..visible_end {
            if let Some(row) = self.visibility_window.fog_of_war.get_mut(row_idx as usize) {
                for cell in row {
                    *cell = true;
                }
            }
        }
    }

    fn check_collisions(&mut self) {
        // Ball-paddle collision
        let paddle = &self.local_player.paddle;
        if self.ball.x >= paddle.x
            && self.ball.x <= paddle.x + paddle.width
            && self.ball.y + self.ball.radius >= paddle.y
            && self.ball.y - self.ball.radius <= paddle.y + paddle.height
        {
            // Calculate deflection angle based on hit position
            let hit_pos = (self.ball.x - paddle.x) / paddle.width;
            let deflection_angle = (hit_pos - 0.5) * std::f32::consts::PI / 3.0; // Max 60 degrees

            let speed = (self.ball.velocity_x.powi(2) + self.ball.velocity_y.powi(2)).sqrt();
            self.ball.velocity_x = speed * deflection_angle.sin();
            self.ball.velocity_y = -speed * deflection_angle.cos().abs();

            self.ball.bounces += 1;
            self.ball.last_paddle_hit = Some(self.local_player.id.clone());

            self.add_particle_effect(EffectType::PaddleHit, self.ball.x, self.ball.y);
        }

        // Ball-brick collisions
        let mut hit_bricks = vec![];
        for (i, brick) in self.bricks.iter().enumerate() {
            if self.ball.x + self.ball.radius >= brick.x
                && self.ball.x - self.ball.radius <= brick.x + brick.width
                && self.ball.y + self.ball.radius >= brick.y
                && self.ball.y - self.ball.radius <= brick.y + brick.height
            {
                hit_bricks.push(i);
            }
        }

        for brick_idx in hit_bricks.iter().rev() {
            // Store brick info before borrowing
            let brick_x = self.bricks[*brick_idx].x;
            let brick_y = self.bricks[*brick_idx].y;
            let brick_width = self.bricks[*brick_idx].width;
            let brick_height = self.bricks[*brick_idx].height;
            let brick_type = self.bricks[*brick_idx].brick_type;

            let brick = &mut self.bricks[*brick_idx];
            brick.health = brick.health.saturating_sub(self.ball.power_level);

            // Reverse ball direction
            self.ball.velocity_y *= -1.0;

            // Handle special brick types before mutations
            let should_explode = matches!(brick_type, BrickType::Explosive);
            let should_teleport = matches!(brick_type, BrickType::Teleporter);

            // Award points
            self.local_player.score += 10 * self.ball.power_level;

            // Drop power-up if specified
            if let Some(_powerup_type) = &brick.drops_powerup {
                // Create power-up at brick location
                // (Implementation depends on power-up system)
            }

            let brick_destroyed = brick.health == 0;

            // Now handle special effects after releasing the brick reference
            if brick_destroyed {
                self.roguelike_elements.experience_points += 5;
            }

            // Add particles
            self.add_particle_effect(
                EffectType::BrickExplosion,
                brick_x + brick_width / 2.0,
                brick_y + brick_height / 2.0,
            );

            if should_explode {
                // Explode nearby bricks
                self.explode_nearby_bricks(brick_x, brick_y, 100.0);
            }

            if should_teleport {
                // Teleport ball to random location
                self.ball.x = 100.0 + (rand::random::<f32>() * 400.0);
                self.ball.y = 100.0 + (rand::random::<f32>() * 200.0);
            }

            // Remove destroyed brick
            if brick_destroyed {
                self.bricks.remove(*brick_idx);
            }
        }
    }

    fn explode_nearby_bricks(&mut self, x: f32, y: f32, radius: f32) {
        let mut to_damage = vec![];

        for (i, brick) in self.bricks.iter().enumerate() {
            let dist_x = (brick.x + brick.width / 2.0) - x;
            let dist_y = (brick.y + brick.height / 2.0) - y;
            let distance = (dist_x * dist_x + dist_y * dist_y).sqrt();

            if distance <= radius {
                to_damage.push(i);
            }
        }

        for &idx in to_damage.iter().rev() {
            self.bricks[idx].health = self.bricks[idx].health.saturating_sub(2);
            if self.bricks[idx].health == 0 {
                self.add_particle_effect(
                    EffectType::BrickExplosion,
                    self.bricks[idx].x + self.bricks[idx].width / 2.0,
                    self.bricks[idx].y + self.bricks[idx].height / 2.0,
                );
                self.bricks.remove(idx);
            }
        }
    }

    fn handle_ball_out_of_bounds(&mut self) {
        self.local_player.lives = self.local_player.lives.saturating_sub(1);

        if self.local_player.lives == 0 {
            self.game_state = GameState::GameOver;
        } else {
            // Reset ball position
            self.ball.x = 300.0;
            self.ball.y = 300.0;
            self.ball.velocity_x = 3.0;
            self.ball.velocity_y = -3.0;
            self.ball.bounces = 0;
        }
    }

    fn update_roguelike_progression(&mut self) {
        // Check for level up
        let xp_needed = self.roguelike_elements.current_level * 100;
        if self.roguelike_elements.experience_points >= xp_needed {
            self.level_up();
        }
    }

    fn level_up(&mut self) {
        self.roguelike_elements.current_level += 1;
        self.roguelike_elements.skill_tree.available_points += 1;

        // Add level up particle effect
        self.add_particle_effect(EffectType::LevelUp, 300.0, 400.0);

        // Increase difficulty
        self.roguelike_elements.level_progression.current_difficulty += 0.1;
        self.ball.velocity_x *= 1.05;
        self.ball.velocity_y *= 1.05;
    }

    fn update_map_painter(&mut self) {
        // Map painter logic would go here
        // For now, just a placeholder
    }

    fn add_particle_effect(&mut self, effect_type: EffectType, x: f32, y: f32) {
        let color = match effect_type {
            EffectType::BrickExplosion => PongColor::red(),
            EffectType::PaddleHit => PongColor::anbernic_orange(),
            EffectType::PowerUpCollection => PongColor::green(),
            EffectType::LevelUp => PongColor::new(255, 215, 0, 255), // Gold
            _ => PongColor::white(),
        };

        // Add multiple particles for better effect
        for _ in 0..10 {
            self.ui_state.particle_effects.push(ParticleEffect {
                x: x + (rand::random::<f32>() - 0.5) * 20.0,
                y: y + (rand::random::<f32>() - 0.5) * 20.0,
                velocity_x: (rand::random::<f32>() - 0.5) * 100.0,
                velocity_y: (rand::random::<f32>() - 0.5) * 100.0,
                life: 1.0 + rand::random::<f32>(),
                max_life: 2.0,
                color: color.clone(),
                effect_type: effect_type.clone(),
            });
        }
    }

    /// Handle radial input for Anbernic devices
    pub fn handle_input(&mut self, input: PongInput) {
        match input {
            PongInput::PaddleLeft => {
                self.local_player.paddle.velocity = -self.local_player.paddle.max_speed;
            }
            PongInput::PaddleRight => {
                self.local_player.paddle.velocity = self.local_player.paddle.max_speed;
            }
            PongInput::PaddleStop => {
                self.local_player.paddle.velocity = 0.0;
            }
            PongInput::ActivatePowerUp => {
                self.activate_next_powerup();
            }
            PongInput::ScrollVisibilityUp => {
                if self.visibility_window.scroll_offset > 0.0 {
                    self.visibility_window.scroll_offset -= 1.0;
                }
            }
            PongInput::ScrollVisibilityDown => {
                let max_scroll = self.visibility_window.total_rows as f32
                    - self.visibility_window.visible_rows as f32;
                if self.visibility_window.scroll_offset < max_scroll {
                    self.visibility_window.scroll_offset += 1.0;
                }
            }
            PongInput::OpenMapPainter => {
                self.game_state = GameState::MapPainting;
            }
            PongInput::OpenSkillTree => {
                self.ui_state.current_screen = PongScreen::SkillTree;
            }
        }
    }

    fn activate_next_powerup(&mut self) {
        for powerup in &mut self.local_player.power_ups {
            if !powerup.active && powerup.duration > 0.0 {
                powerup.active = true;
                break;
            }
        }
    }

    /// Render ASCII representation for Anbernic display
    pub fn render_ascii(&self) -> String {
        let mut output = String::new();

        match self.ui_state.current_screen {
            PongScreen::Playing => {
                output.push_str(&self.render_game_field());
                output.push_str(&self.render_hud());
            }
            PongScreen::MapPainter => {
                output.push_str(&self.render_map_painter());
            }
            PongScreen::SkillTree => {
                output.push_str(&self.render_skill_tree());
            }
            _ => {
                output.push_str(&self.render_main_menu());
            }
        }

        output
    }

    fn render_game_field(&self) -> String {
        let mut field = vec![vec![' '; 60]; 25];

        // Draw visible bricks based on fog of war
        for brick in &self.bricks {
            let row = (brick.y / 25.0) as usize;
            let col = (brick.x / 10.0) as usize;

            if row < self.visibility_window.fog_of_war.len()
                && col < 60
                && self
                    .visibility_window
                    .fog_of_war
                    .get(row)
                    .map_or(false, |r| r.get(col).copied().unwrap_or(false))
            {
                let brick_char = match brick.brick_type {
                    BrickType::Normal => '█',
                    BrickType::Armored => '▓',
                    BrickType::Explosive => '※',
                    BrickType::Regenerating => '♦',
                    BrickType::Invisible => '░',
                    BrickType::Teleporter => '◊',
                    BrickType::Spawner => '⚡',
                };

                if row < field.len() && col < field[0].len() {
                    field[row][col] = brick_char;
                }
            }
        }

        // Draw ball
        let ball_row = (self.ball.y / 25.0) as usize;
        let ball_col = (self.ball.x / 10.0) as usize;
        if ball_row < field.len() && ball_col < field[0].len() {
            field[ball_row][ball_col] = '●';
        }

        // Draw ball trail
        for trail_point in &self.ball.trail {
            let trail_row = (trail_point.y / 25.0) as usize;
            let trail_col = (trail_point.x / 10.0) as usize;
            if trail_row < field.len()
                && trail_col < field[0].len()
                && field[trail_row][trail_col] == ' '
            {
                field[trail_row][trail_col] = '·';
            }
        }

        // Draw local paddle
        let paddle = &self.local_player.paddle;
        let paddle_row = (paddle.y / 25.0) as usize;
        let paddle_start_col = (paddle.x / 10.0) as usize;
        let paddle_end_col = ((paddle.x + paddle.width) / 10.0) as usize;

        if paddle_row < field.len() {
            for col in paddle_start_col..=paddle_end_col.min(field[0].len() - 1) {
                field[paddle_row][col] = '━';
            }
        }

        // Draw fog of war overlay
        for (row_idx, row) in field.iter_mut().enumerate() {
            for (col_idx, cell) in row.iter_mut().enumerate() {
                if row_idx < self.visibility_window.fog_of_war.len() {
                    if let Some(fog_row) = self.visibility_window.fog_of_war.get(row_idx) {
                        if col_idx < fog_row.len() && !fog_row[col_idx] {
                            *cell = '░'; // Fog of war
                        }
                    }
                }
            }
        }

        // Convert to string
        let mut output = String::new();
        output.push_str("┌────────── BATTLESHIP PONG ──────────┐\n");
        for row in &field {
            output.push('│');
            for &cell in row {
                output.push(cell);
            }
            output.push_str("│\n");
        }
        output.push_str("└──────────────────────────────────────┘\n");

        output
    }

    fn render_hud(&self) -> String {
        let mut output = String::new();

        output.push_str(&format!(
            "┌─ SCORE: {} │ LIVES: {} │ LVL: {} │ XP: {}/{} ─┐\n",
            self.local_player.score,
            self.local_player.lives,
            self.roguelike_elements.current_level,
            self.roguelike_elements.experience_points,
            self.roguelike_elements.current_level * 100
        ));

        output.push_str(&format!(
            "│ Visibility: {}/{} rows │ Ball: {:.0},{:.0} │ Bounces: {} │\n",
            self.visibility_window.visible_rows,
            self.visibility_window.total_rows,
            self.ball.x,
            self.ball.y,
            self.ball.bounces
        ));

        // Active power-ups
        output.push_str("│ PowerUps: ");
        for powerup in &self.local_player.power_ups {
            if powerup.active {
                let powerup_icon = match powerup.power_type {
                    PowerUpType::BigPaddle => "▬",
                    PowerUpType::Multiball => "●●",
                    PowerUpType::Shield => "🛡",
                    PowerUpType::LaserPaddle => "⚡",
                    _ => "?",
                };
                output.push_str(&format!("{} ", powerup_icon));
            }
        }
        output.push_str("                    │\n");

        output.push_str("└─────────────────────────────────────────────┘\n");

        // Visibility indicator
        output.push_str("Visibility Window: ");
        for i in 0..self.visibility_window.total_rows {
            if i >= self.visibility_window.scroll_offset as u32
                && i < self.visibility_window.scroll_offset as u32
                    + self.visibility_window.visible_rows
            {
                output.push('█');
            } else {
                output.push('░');
            }
        }
        output.push('\n');

        output
    }

    fn render_map_painter(&self) -> String {
        let mut output = String::new();

        output.push_str("┌─────────── MAP PAINTER ───────────┐\n");
        output.push_str("│ 🎨 Create custom battleship maps  │\n");
        output.push_str("├───────────────────────────────────┤\n");

        // Render canvas
        for row in 0..10 {
            output.push_str("│ ");
            for col in 0..30 {
                if let Some(canvas_row) = self.map_painter.canvas.get(row) {
                    if let Some(brick_type) = canvas_row.get(col) {
                        let char = match brick_type {
                            BrickType::Normal => '█',
                            BrickType::Armored => '▓',
                            BrickType::Explosive => '※',
                            BrickType::Regenerating => '♦',
                            BrickType::Invisible => '░',
                            BrickType::Teleporter => '◊',
                            BrickType::Spawner => '⚡',
                        };
                        output.push(char);
                    } else {
                        output.push(' ');
                    }
                } else {
                    output.push(' ');
                }
            }
            output.push_str(" │\n");
        }

        output.push_str("├───────────────────────────────────┤\n");
        output.push_str(&format!(
            "│ Brush: {:?} Size: {} │\n",
            self.map_painter.brush.brush_type, self.map_painter.brush.brush_size
        ));
        output.push_str("│ A/B: Select brush | L/R: Paint    │\n");
        output.push_str("└───────────────────────────────────┘\n");

        output
    }

    fn render_skill_tree(&self) -> String {
        let mut output = String::new();

        output.push_str("┌─────────── SKILL TREE ────────────┐\n");
        output.push_str(&format!(
            "│ Available Points: {} │\n",
            self.roguelike_elements.skill_tree.available_points
        ));
        output.push_str("├───────────────────────────────────┤\n");

        for skill in &self.roguelike_elements.skill_tree.nodes {
            let status = if skill.unlocked { "✓" } else { "○" };
            output.push_str(&format!(
                "│ {} {} ({}pts) │\n",
                status, skill.name, skill.cost
            ));
            output.push_str(&format!("│   {} │\n", skill.description));
        }

        output.push_str("├───────────────────────────────────┤\n");
        output.push_str("│ A/B: Navigate | SELECT: Unlock    │\n");
        output.push_str("└───────────────────────────────────┘\n");

        output
    }

    fn render_main_menu(&self) -> String {
        let mut output = String::new();

        output.push_str("┌─────── BATTLESHIP PONG ──────────┐\n");
        output.push_str("│ 🎮 Anbernic Multiplayer Warfare  │\n");
        output.push_str("├───────────────────────────────────┤\n");
        output.push_str("│ A) 🎯 Start Game                  │\n");
        output.push_str("│ B) 🌐 Join WiFi Party             │\n");
        output.push_str("│ L) 🎨 Map Painter                 │\n");
        output.push_str("│ R) 🌟 Skill Tree                  │\n");
        output.push_str("├───────────────────────────────────┤\n");
        output.push_str(&format!("│ Player: {} │\n", self.local_player.device_name));
        output.push_str(&format!(
            "│ Level: {} XP: {} │\n",
            self.roguelike_elements.current_level, self.roguelike_elements.experience_points
        ));
        output.push_str("└───────────────────────────────────┘\n");

        output
    }
}

#[derive(Debug, Clone)]
pub enum PongInput {
    PaddleLeft,
    PaddleRight,
    PaddleStop,
    ActivatePowerUp,
    ScrollVisibilityUp,
    ScrollVisibilityDown,
    OpenMapPainter,
    OpenSkillTree,
}

// For simplified random number generation in demo
mod rand {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    pub fn random<T>() -> f32
    where
        T: Default,
    {
        let mut hasher = DefaultHasher::new();
        chrono::Utc::now()
            .timestamp_nanos_opt()
            .unwrap_or(0)
            .hash(&mut hasher);
        let hash = hasher.finish();
        (hash % 1000) as f32 / 1000.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_battleship_pong_creation() {
        let game = BattleshipPong::new("TestPlayer".to_string());
        assert_eq!(game.local_player.device_name, "TestPlayer");
        assert_eq!(game.local_player.lives, 3);
        assert!(!game.bricks.is_empty());
    }

    #[test]
    fn test_visibility_system() {
        let game = BattleshipPong::new("TestPlayer".to_string());
        assert_eq!(game.visibility_window.visible_rows, 3);
        assert_eq!(game.visibility_window.total_rows, 20);
    }

    #[test]
    fn test_skill_tree_initialization() {
        let game = BattleshipPong::new("TestPlayer".to_string());
        assert!(!game.roguelike_elements.skill_tree.nodes.is_empty());
        assert_eq!(game.roguelike_elements.skill_tree.available_points, 0);
    }
}
