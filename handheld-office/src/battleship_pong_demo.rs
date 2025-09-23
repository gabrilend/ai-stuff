use handheld_office::battleship_pong::*;
use std::io::{self, Write};
use std::time::{Duration, Instant};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 BATTLESHIP PONG 🎯");
    println!("======================");
    println!("Multiplayer Warfare for Anbernic Devices");
    println!("Limited visibility • Brick breaker • Roguelike progression");
    println!("");

    let mut game = BattleshipPong::new("AnbernicWarrior".to_string());
    let mut last_update = Instant::now();

    // Start in main menu
    loop {
        // Clear screen
        print!("\x1B[2J\x1B[1;1H");

        // Render current screen
        println!("{}", game.render_ascii());

        // Show controls based on current screen
        match game.ui_state.current_screen {
            PongScreen::MainMenu => {
                println!("🎮 Controls:");
                println!("A) Start Single Player");
                println!("B) Join WiFi Party Mode");
                println!("L) Open Map Painter");
                println!("R) View Skill Tree");
                println!("Q) Quit");
            }
            PongScreen::Playing => {
                println!("🎮 Game Controls:");
                println!("A) Move Paddle Left");
                println!("D) Move Paddle Right");
                println!("W) Scroll Visibility Up");
                println!("S) Scroll Visibility Down");
                println!("Space) Activate Power-up");
                println!("M) Map Painter");
                println!("T) Skill Tree");
                println!("Q) Quit to Menu");
            }
            PongScreen::MapPainter => {
                println!("🎨 Map Painter Controls:");
                println!("WASD) Move cursor");
                println!("1-7) Select brick type");
                println!("Space) Paint/Erase");
                println!("Enter) Save map");
                println!("Q) Back to menu");
            }
            PongScreen::SkillTree => {
                println!("🌟 Skill Tree Controls:");
                println!("WS) Navigate skills");
                println!("Enter) Unlock skill");
                println!("Q) Back to menu");
            }
            _ => {
                println!("Press Q to return to menu");
            }
        }

        print!("\n🎮 Input: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let input = input.trim().to_uppercase();

        // Calculate delta time
        let now = Instant::now();
        let delta_time = now.duration_since(last_update).as_secs_f32();
        last_update = now;

        // Handle input based on current screen
        match game.ui_state.current_screen {
            PongScreen::MainMenu => match input.as_str() {
                "A" => {
                    println!("🎯 Starting single player battleship pong...");
                    game.game_state = GameState::Playing;
                    game.ui_state.current_screen = PongScreen::Playing;
                    std::thread::sleep(Duration::from_millis(1000));
                }
                "B" => {
                    println!("🌐 Searching for WiFi party...");
                    game.network.wifi_party_mode = true;
                    std::thread::sleep(Duration::from_millis(1500));
                    println!("⚠️  No other Anbernic devices found in range.");
                    println!("💡 Tip: Start a WiFi hotspot on laptop and connect Anbernics!");
                    std::thread::sleep(Duration::from_millis(2000));
                }
                "L" => {
                    game.ui_state.current_screen = PongScreen::MapPainter;
                }
                "R" => {
                    game.ui_state.current_screen = PongScreen::SkillTree;
                }
                "Q" => {
                    println!("👋 Thanks for playing Battleship Pong!");
                    break;
                }
                _ => {
                    println!("❌ Invalid input. Use A/B/L/R or Q.");
                    std::thread::sleep(Duration::from_millis(1000));
                }
            },

            PongScreen::Playing => {
                match input.as_str() {
                    "A" => {
                        game.handle_input(PongInput::PaddleLeft);
                        // Auto-update for smooth movement
                        for _ in 0..5 {
                            game.update(0.016); // ~60 FPS
                            std::thread::sleep(Duration::from_millis(16));
                        }
                        game.handle_input(PongInput::PaddleStop);
                    }
                    "D" => {
                        game.handle_input(PongInput::PaddleRight);
                        // Auto-update for smooth movement
                        for _ in 0..5 {
                            game.update(0.016);
                            std::thread::sleep(Duration::from_millis(16));
                        }
                        game.handle_input(PongInput::PaddleStop);
                    }
                    "W" => {
                        game.handle_input(PongInput::ScrollVisibilityUp);
                        println!("👁️  Visibility scrolled up");
                        std::thread::sleep(Duration::from_millis(500));
                    }
                    "S" => {
                        game.handle_input(PongInput::ScrollVisibilityDown);
                        println!("👁️  Visibility scrolled down");
                        std::thread::sleep(Duration::from_millis(500));
                    }
                    " " | "SPACE" => {
                        game.handle_input(PongInput::ActivatePowerUp);
                        println!("⚡ Power-up activated!");
                        std::thread::sleep(Duration::from_millis(500));
                    }
                    "M" => {
                        game.handle_input(PongInput::OpenMapPainter);
                    }
                    "T" => {
                        game.handle_input(PongInput::OpenSkillTree);
                    }
                    "Q" => {
                        game.ui_state.current_screen = PongScreen::MainMenu;
                        game.game_state = GameState::WaitingForPlayers;
                    }
                    _ => {
                        println!("❌ Invalid input. Use A/D/W/S/Space/M/T or Q.");
                        std::thread::sleep(Duration::from_millis(500));
                    }
                }

                // Always update game physics when playing
                if matches!(game.game_state, GameState::Playing) {
                    game.update(delta_time);

                    // Check win/lose conditions
                    if game.bricks.is_empty() {
                        println!("🎉 LEVEL COMPLETE! All battleships destroyed!");
                        game.local_player.score += 1000;
                        game.roguelike_elements.experience_points += 50;

                        // Generate new level
                        game.bricks = BattleshipPong::generate_default_bricks();
                        game.roguelike_elements.current_level += 1;

                        std::thread::sleep(Duration::from_millis(2000));
                    }

                    if matches!(game.game_state, GameState::GameOver) {
                        println!("💀 GAME OVER! All lives lost!");
                        println!("Final Score: {}", game.local_player.score);
                        println!(
                            "Levels Completed: {}",
                            game.roguelike_elements.current_level - 1
                        );
                        std::thread::sleep(Duration::from_millis(3000));
                        game.ui_state.current_screen = PongScreen::MainMenu;

                        // Reset game
                        game = BattleshipPong::new("AnbernicWarrior".to_string());
                    }
                }
            }

            PongScreen::MapPainter => {
                match input.as_str() {
                    "1" => {
                        game.map_painter.brush.brush_type = BrickType::Normal;
                        println!("🎨 Selected: Normal Brick");
                    }
                    "2" => {
                        game.map_painter.brush.brush_type = BrickType::Armored;
                        println!("🎨 Selected: Armored Brick");
                    }
                    "3" => {
                        game.map_painter.brush.brush_type = BrickType::Explosive;
                        println!("🎨 Selected: Explosive Brick");
                    }
                    "4" => {
                        game.map_painter.brush.brush_type = BrickType::Regenerating;
                        println!("🎨 Selected: Regenerating Brick");
                    }
                    "5" => {
                        game.map_painter.brush.brush_type = BrickType::Invisible;
                        println!("🎨 Selected: Invisible Brick");
                    }
                    "6" => {
                        game.map_painter.brush.brush_type = BrickType::Teleporter;
                        println!("🎨 Selected: Teleporter Brick");
                    }
                    "7" => {
                        game.map_painter.brush.brush_type = BrickType::Spawner;
                        println!("🎨 Selected: Spawner Brick");
                    }
                    " " | "SPACE" => {
                        println!("🖌️  Painting with {:?}", game.map_painter.brush.brush_type);
                    }
                    "ENTER" => {
                        println!(
                            "💾 Map saved! (In real game, would save to files/build/custom_maps/)"
                        );
                        std::thread::sleep(Duration::from_millis(1000));
                    }
                    "Q" => {
                        game.ui_state.current_screen = PongScreen::MainMenu;
                    }
                    _ => {
                        println!("❌ Invalid input. Use 1-7 to select brush, Space to paint, Enter to save, Q to quit.");
                    }
                }
                std::thread::sleep(Duration::from_millis(500));
            }

            PongScreen::SkillTree => {
                match input.as_str() {
                    "ENTER" => {
                        if game.roguelike_elements.skill_tree.available_points > 0 {
                            // Find first unlockable skill
                            for skill in &mut game.roguelike_elements.skill_tree.nodes {
                                if !skill.unlocked
                                    && skill.cost
                                        <= game.roguelike_elements.skill_tree.available_points
                                {
                                    skill.unlocked = true;
                                    game.roguelike_elements.skill_tree.available_points -=
                                        skill.cost;
                                    println!("🌟 Unlocked: {}!", skill.name);

                                    // Apply skill effect
                                    match &skill.effect {
                                        SkillEffect::PaddleSpeedBoost(boost) => {
                                            game.local_player.paddle.max_speed *= 1.0 + boost;
                                        }
                                        SkillEffect::VisibilityRangeExtended(rows) => {
                                            game.visibility_window.visible_rows += rows;
                                        }
                                        _ => {}
                                    }

                                    std::thread::sleep(Duration::from_millis(1500));
                                    break;
                                }
                            }
                        } else {
                            println!("❌ Not enough skill points!");
                            std::thread::sleep(Duration::from_millis(1000));
                        }
                    }
                    "Q" => {
                        game.ui_state.current_screen = PongScreen::MainMenu;
                    }
                    _ => {
                        println!("❌ Invalid input. Use Enter to unlock skills, Q to quit.");
                        std::thread::sleep(Duration::from_millis(500));
                    }
                }
            }

            _ => {
                if input == "Q" {
                    game.ui_state.current_screen = PongScreen::MainMenu;
                }
            }
        }
    }

    Ok(())
}
