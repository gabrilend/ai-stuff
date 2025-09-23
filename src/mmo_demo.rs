use handheld_office::mmo_engine::{
    ActionInput, CameraMode, Direction, HandheldMMOEngine, InputState, MovementInput, ViewMode,
};
use std::io::{self, Write};
use std::net::SocketAddr;
use std::time::Instant;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🏰 Anbernic MMO Engine - AzerothCore Style");
    println!("   WotLK-inspired networking without Blizzard assets!");
    println!("   Perfect for handheld MMO gaming 🎮⚔️");
    println!("");

    let mut engine = HandheldMMOEngine::new();
    let start_time = Instant::now();

    println!("🌍 Initializing game world...");
    {
        let world = engine.world.read().await;
        println!(
            "   Generated map: {} ({}x{})",
            world
                .maps
                .get(&0)
                .map(|m| m.name.as_str())
                .unwrap_or("Unknown"),
            world.maps.get(&0).map(|m| m.size_x).unwrap_or(0),
            world.maps.get(&0).map(|m| m.size_y).unwrap_or(0)
        );
    }

    println!(
        "👤 Player created: {} (Level {})",
        engine.player.state.name, engine.player.state.level
    );
    println!("");

    // Connection options for different gaming scenarios
    println!("🔗 Connection Options:");
    println!("   1. Connect to desktop AzerothCore server");
    println!("   2. Join peer-to-peer swarm network");
    println!("   3. Play offline (single-player mode)");
    println!("   4. 🎮 Start WiFi Party (laptop hotspot mode)");
    println!("   5. 🎮 Join WiFi Party (connect to existing party)");
    println!("   Enter 1, 2, 3, 4, or 5:");

    let mut connection_choice = String::new();
    io::stdin().read_line(&mut connection_choice)?;

    match connection_choice.trim() {
        "1" => {
            println!("🖥️  Connecting to AzerothCore server...");
            // Simulate server connection
            let server_addr: SocketAddr = "127.0.0.1:8085".parse()?;
            if let Err(e) = engine.connect_to_server(server_addr).await {
                println!("⚠️  Server connection failed: {}. Continuing offline.", e);
            } else {
                println!("✅ Connected to AzerothCore server!");
            }
        }
        "2" => {
            println!("🌐 Joining P2P swarm network...");
            let bootstrap_peers = vec!["127.0.0.1:8086".parse()?, "127.0.0.1:8087".parse()?];
            if let Err(e) = engine.join_p2p_swarm(bootstrap_peers).await {
                println!("⚠️  P2P connection failed: {}. Continuing offline.", e);
            } else {
                println!("✅ Joined swarm network!");
            }
        }
        "4" => {
            println!("🎮 Starting WiFi Party (laptop hotspot mode)...");
            let party_mailbox = std::path::PathBuf::from("files/build/party_mailbox");
            let party_name = "Living Room MMO Party".to_string();

            if let Err(e) = engine.start_wifi_party(party_name, party_mailbox).await {
                println!("⚠️  Failed to start WiFi party: {}. Continuing offline.", e);
            } else {
                println!("✅ WiFi Party started! Other Anbernic devices can now join!");
                println!("   💡 On other devices: Choose option 5 to join this party");
            }
        }
        "5" => {
            println!("🎮 Joining existing WiFi Party...");
            let party_mailbox = std::path::PathBuf::from("files/build/party_mailbox");

            if let Err(e) = engine.join_wifi_party(party_mailbox).await {
                println!("⚠️  Failed to join WiFi party: {}. Continuing offline.", e);
            } else {
                println!("✅ Joined WiFi party!");

                // Show connected devices
                if let Ok(devices) = engine.list_party_devices().await {
                    println!("   🎮 Connected devices:");
                    for device in devices {
                        let battery_info = device
                            .battery_level
                            .map(|b| format!(" ({}%)", b))
                            .unwrap_or_default();
                        println!(
                            "     {} - {}{}",
                            device.device_name, device.player_name, battery_info
                        );
                    }
                }
            }
        }
        _ => {
            println!("🏠 Playing in offline mode");
        }
    }

    println!("");
    println!("🎮 Game Controls (Anbernic Style):");
    println!("   WASD: Movement  |  QE: Turn  |  Space: Jump");
    println!("   12345: Spells   |  I: Inventory  |  T: Chat");
    println!("   C: Camera mode  |  TAB: Target  |  ESC: Menu");
    println!("   Type 'help' for full commands | 'quit' to exit");
    println!("");

    let mut input_state = InputState::default();
    let mut command_history = Vec::new();

    loop {
        // Clear screen and render world
        print!("\x1B[2J\x1B[1;1H"); // ANSI clear screen

        // Render based on view mode
        let world_display = match engine.player.state.view_mode {
            ViewMode::Classic3D => engine.render_ascii().await,
            ViewMode::Retro2D => engine.render_2d_wow().await,
            ViewMode::Hybrid => {
                let display_3d = engine.render_ascii().await;
                let display_2d = engine.render_2d_wow().await;
                format!("{}\n{}", display_2d, display_3d)
            }
        };
        println!("{}", world_display);

        // Show session info
        let session_time = start_time.elapsed().as_secs();
        println!(
            "Session: {}m {}s | Commands: {}",
            session_time / 60,
            session_time % 60,
            command_history.len()
        );

        print!("\n> ");
        io::stdout().flush()?;

        let mut command = String::new();
        io::stdin().read_line(&mut command)?;
        let cmd = command.trim().to_lowercase();
        command_history.push(cmd.clone());

        // Reset input state
        input_state = InputState::default();

        match cmd.as_str() {
            // Movement commands
            "w" | "forward" | "up" => match engine.player.state.view_mode {
                ViewMode::Retro2D => {
                    if let Err(e) = engine.handle_2d_movement(Direction::North).await {
                        println!("❌ Movement failed: {}", e);
                    } else {
                        println!("📺 Moving background down (GBA style)");
                    }
                }
                _ => {
                    input_state.movement.forward = true;
                    println!("🏃 Moving forward...");
                }
            },
            "s" | "backward" | "down" => match engine.player.state.view_mode {
                ViewMode::Retro2D => {
                    if let Err(e) = engine.handle_2d_movement(Direction::South).await {
                        println!("❌ Movement failed: {}", e);
                    } else {
                        println!("📺 Moving background up (GBA style)");
                    }
                }
                _ => {
                    input_state.movement.backward = true;
                    println!("🚶 Moving backward...");
                }
            },
            "a" | "left" => match engine.player.state.view_mode {
                ViewMode::Retro2D => {
                    if let Err(e) = engine.handle_2d_movement(Direction::West).await {
                        println!("❌ Movement failed: {}", e);
                    } else {
                        println!("◄ Strafing left in 2D...");
                    }
                }
                _ => {
                    input_state.movement.strafe_left = true;
                    println!("↩️  Strafing left...");
                }
            },
            "d" | "right" => match engine.player.state.view_mode {
                ViewMode::Retro2D => {
                    if let Err(e) = engine.handle_2d_movement(Direction::East).await {
                        println!("❌ Movement failed: {}", e);
                    } else {
                        println!("► Strafing right in 2D...");
                    }
                }
                _ => {
                    input_state.movement.strafe_right = true;
                    println!("↪️  Strafing right...");
                }
            },
            "q" | "turnleft" => {
                input_state.movement.turn_left = true;
                println!("🔄 Turning left...");
            }
            "e" | "turnright" => {
                input_state.movement.turn_right = true;
                println!("🔃 Turning right...");
            }
            "space" | "jump" => {
                input_state.movement.jump = true;
                println!("🦘 Jumping!");
            }

            // Camera controls
            "c" | "camera" => {
                engine.player.camera.mode = match engine.player.camera.mode {
                    CameraMode::TopDown => CameraMode::ThirdPerson,
                    CameraMode::ThirdPerson => CameraMode::FirstPerson,
                    CameraMode::FirstPerson => CameraMode::Isometric,
                    CameraMode::Isometric => CameraMode::TopDown,
                };
                println!("📷 Camera mode: {:?}", engine.player.camera.mode);
            }

            // Action commands
            "attack" => {
                input_state.actions.auto_attack = true;
                println!("⚔️  Auto-attack enabled!");
            }
            "1" => {
                input_state.actions.cast_spell = Some(1);
                println!("✨ Casting spell 1!");
            }
            "2" => {
                input_state.actions.cast_spell = Some(2);
                println!("🔥 Casting spell 2!");
            }
            "3" => {
                input_state.actions.cast_spell = Some(3);
                println!("❄️  Casting spell 3!");
            }

            // UI commands
            "i" | "inventory" => {
                engine.player.ui_state.show_inventory = !engine.player.ui_state.show_inventory;
                println!(
                    "🎒 Inventory: {}",
                    if engine.player.ui_state.show_inventory {
                        "Open"
                    } else {
                        "Closed"
                    }
                );
            }
            "t" | "chat" => {
                input_state.actions.chat_mode = true;
                println!("💬 Chat mode activated");
            }
            "tab" | "target" => {
                println!("🎯 Looking for targets...");
                // In real implementation, would cycle through nearby objects
            }

            // MMO-specific commands
            "who" => {
                let world = engine.world.read().await;
                println!("👥 Players online: {}", world.players.len());
                for (_, player) in world.players.iter().take(5) {
                    println!(
                        "   {} (Level {}) at ({:.1}, {:.1})",
                        player.name, player.level, player.position.x, player.position.y
                    );
                }
            }
            "guild" => {
                println!("🏰 Guild system not implemented yet");
            }

            // Networking commands
            "ping" => {
                let peers = engine.networking.peers.read().await;
                println!("🏓 Network status: {} peers connected", peers.len());
                for (peer_id, peer) in peers.iter().take(3) {
                    println!(
                        "   Peer {}: {} (rep: {})",
                        peer_id, peer.address, peer.reputation
                    );
                }
            }
            "sync" => {
                println!("🔄 Synchronizing world state with peers...");
                // In real implementation, would sync with P2P network
            }

            // WiFi Party commands
            "party" | "devices" => {
                if let Ok(devices) = engine.list_party_devices().await {
                    println!("🎮 WiFi Party Devices ({}):", devices.len());
                    for device in devices {
                        let battery_info = device
                            .battery_level
                            .map(|b| format!(" (🔋{}%)", b))
                            .unwrap_or_default();
                        println!(
                            "   📱 {} - {}{}",
                            device.device_name, device.player_name, battery_info
                        );
                        println!("      Last seen: {}", device.last_seen.format("%H:%M:%S"));
                    }
                } else {
                    println!("❌ Not in WiFi party mode");
                }
            }
            "mailbox" | "messages" => {
                println!("📬 Checking party mailbox...");
                match engine.check_party_mailbox().await {
                    Ok(messages) => {
                        if messages.is_empty() {
                            println!("   📭 No new messages");
                        } else {
                            println!("   📨 {} new messages:", messages.len());
                            for msg in messages.iter().take(5) {
                                println!(
                                    "     From {}: {:?} at {}",
                                    msg.from_device,
                                    msg.message_type,
                                    msg.timestamp.format("%H:%M:%S")
                                );
                            }
                        }
                    }
                    Err(_) => println!("❌ Not in WiFi party mode"),
                }
            }
            "announce" => {
                println!("📢 Announcing presence to party...");
                use handheld_office::mmo_engine::PartyMessageType;
                let announcement = b"Hello from my Anbernic!".to_vec();
                if let Err(e) = engine
                    .send_party_message(PartyMessageType::ChatMessage, announcement, None)
                    .await
                {
                    println!("❌ Failed to send announcement: {}", e);
                } else {
                    println!("✅ Announcement sent!");
                }
            }
            "worldsync" => {
                println!("🌍 Syncing world state with party...");
                if let Err(e) = engine.sync_party_world().await {
                    println!("❌ Failed to sync world: {}", e);
                } else {
                    println!("✅ World state synchronized!");
                }
            }

            // Developer commands
            "teleport" => {
                engine.player.state.position.x = 25.0;
                engine.player.state.position.y = 25.0;
                println!("🌀 Teleported to (25.0, 25.0)");
            }
            "stats" => {
                let player = &engine.player.state;
                println!("📊 Player Stats:");
                println!(
                    "   STR: {} | AGI: {} | INT: {}",
                    player.stats.strength, player.stats.agility, player.stats.intellect
                );
                println!(
                    "   STA: {} | SPI: {}",
                    player.stats.stamina, player.stats.spirit
                );
                println!("   Health: {} | Mana: {}", player.health, player.mana);
            }
            "regen" => {
                engine.player.state.health = 1000;
                engine.player.state.mana = 500;
                println!("💚 Health and mana restored!");
            }

            // Test commands
            "demo" => {
                println!("🎬 Running demo sequence...");

                // Simulate movement pattern
                let movements = vec!["w", "w", "e", "w", "w", "q", "w"];
                for mv in movements {
                    match mv {
                        "w" => input_state.movement.forward = true,
                        "e" => input_state.movement.turn_right = true,
                        "q" => input_state.movement.turn_left = true,
                        _ => {}
                    }
                    engine.handle_input(input_state.clone()).await?;
                    tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
                }

                println!("✅ Demo complete! Player moved in a square pattern.");
            }
            "stress" => {
                println!("⚡ Stress testing P2P network...");
                for i in 0..10 {
                    input_state.movement.forward = true;
                    engine.handle_input(input_state.clone()).await?;
                    if i % 3 == 0 {
                        println!("   Packet burst {} sent", i + 1);
                    }
                }
                println!("✅ Network stress test complete");
            }

            // 2D WoW view mode commands
            "toggle2d" | "2d" => {
                engine.player.state.view_mode = match engine.player.state.view_mode {
                    ViewMode::Classic3D => ViewMode::Retro2D,
                    ViewMode::Retro2D => ViewMode::Classic3D,
                    ViewMode::Hybrid => ViewMode::Retro2D,
                };
                println!(
                    "📺 Switched to {:?} view mode",
                    engine.player.state.view_mode
                );
            }
            "hybrid" => {
                engine.player.state.view_mode = ViewMode::Hybrid;
                println!("📺 Hybrid view mode - both 2D and 3D!");
            }
            "loop" => {
                if matches!(engine.player.state.view_mode, ViewMode::Retro2D) {
                    let world = engine.world.read().await;
                    if let Some(map) = world.maps.get(&0) {
                        if let Some(tilemap) = &map.tilemap_2d {
                            let distance = engine.calculate_distance_to_loop_edge(tilemap);
                            if distance < tilemap.loop_boundaries.loop_warning_distance {
                                println!(
                                    "🌅 \"Oh she's looped around, better stop for the night\""
                                );
                                println!("   World edge detected {} tiles away", distance);
                            } else {
                                println!(
                                    "🗺️  Still safe from world loop ({} tiles to edge)",
                                    distance
                                );
                            }
                        }
                    }
                } else {
                    println!("❌ Loop detection only works in 2D view mode");
                }
            }

            // Help and exit
            "help" => {
                println!("🆘 Available Commands:");
                println!("Movement: w/s (forward/back), a/d (strafe), q/e (turn), space (jump)");
                println!("Combat: attack, 1-5 (spells)");
                println!("UI: i (inventory), t (chat), c (camera), tab (target)");
                println!("Social: who, guild, party, ping");
                println!("WiFi Party: devices, mailbox, announce, worldsync");
                println!("2D WoW: toggle2d, hybrid, loop (check world edge)");
                println!("Debug: teleport, stats, regen, demo, stress");
                println!("Other: help, quit");
            }
            "quit" | "exit" => {
                println!("👋 Leaving the MMO world...");
                break;
            }

            _ => {
                println!("❓ Unknown command: '{}'. Type 'help' for commands.", cmd);
            }
        }

        // Process the input if any movement occurred
        if input_state.movement.forward
            || input_state.movement.backward
            || input_state.movement.strafe_left
            || input_state.movement.strafe_right
            || input_state.movement.turn_left
            || input_state.movement.turn_right
        {
            engine.handle_input(input_state).await?;
        }

        // Small delay to prevent spam
        tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
    }

    println!("");
    println!("🏰 MMO Session Complete!");
    println!(
        "   Session duration: {}m {}s",
        start_time.elapsed().as_secs() / 60,
        start_time.elapsed().as_secs() % 60
    );
    println!("   Commands executed: {}", command_history.len());
    println!(
        "   Final position: ({:.1}, {:.1}, {:.1})",
        engine.player.state.position.x,
        engine.player.state.position.y,
        engine.player.state.position.z
    );

    println!("");
    println!("🎮 Perfect for AzerothCore + Anbernic MMO gaming!");
    println!("   ✅ WotLK-style networking protocols");
    println!("   ✅ Peer-to-peer swarm networking");
    println!("   ✅ Procedural world generation (no Blizzard assets)");
    println!("   ✅ Handheld-optimized ASCII rendering");
    println!("   ✅ Memory-efficient packet system");
    println!("   🌐 Ready for desktop AzerothCore server integration!");

    Ok(())
}
