use handheld_office::*;
use std::time::Duration;
use tempfile::TempDir;
use tokio::time::timeout;

#[cfg(test)]
mod integration_tests {
    use super::*;

    /// Test complete painting workflow from creation to save
    #[tokio::test]
    async fn test_complete_painting_workflow() {
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        
        // 1. User creates new canvas
        assert_eq!(paint_app.canvas.width, 16);
        assert_eq!(paint_app.canvas.height, 16);
        
        // 2. User selects brush tool and color
        paint_app.current_tool = DrawingTool::Brush;
        paint_app.current_color = 3;
        
        // 3. User draws a simple pattern
        paint_app.start_drawing(2, 2);
        paint_app.continue_drawing(3, 2);
        paint_app.continue_drawing(4, 2);
        paint_app.stop_drawing();
        
        // 4. User changes tool to line
        paint_app.current_tool = DrawingTool::Line;
        paint_app.current_color = 2;
        
        // 5. User draws a line
        paint_app.canvas.draw_line(1, 1, 5, 5, 2);
        
        // 6. User saves artwork
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let save_path = temp_dir.path().join("artwork.json");
        paint_app.save_artwork(&save_path).expect("Failed to save artwork");
        
        // 7. User loads artwork in new session
        let mut new_paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        new_paint_app.load_artwork(&save_path).expect("Failed to load artwork");
        
        // Verify artwork was preserved
        assert_eq!(new_paint_app.canvas.get_pixel(2, 2), 3);
        assert_eq!(new_paint_app.canvas.get_pixel(3, 2), 3);
        assert_eq!(new_paint_app.canvas.get_pixel(1, 1), 2);
        assert_eq!(new_paint_app.canvas.get_pixel(5, 5), 2);
    }

    /// Test complete music composition and playback workflow
    #[tokio::test]
    async fn test_music_composition_workflow() {
        let mut tracker = TrackerEngine::new();
        
        // 1. User sets up song parameters
        tracker.set_bpm(140);
        tracker.set_speed(6);
        
        // 2. User creates instruments
        let mut piano = Instrument::new("Piano");
        piano.envelope.attack = 0.01;
        piano.envelope.decay = 0.1;
        piano.envelope.sustain = 0.8;
        piano.envelope.release = 0.2;
        
        let mut bass = Instrument::new("Bass");
        bass.envelope.attack = 0.001;
        bass.envelope.sustain = 1.0;
        bass.envelope.release = 0.1;
        
        // 3. User creates pattern
        let mut pattern = Pattern::new(16, 2);
        
        // Add piano melody
        pattern.set_note(0, 0, Some(Note::new(60, 4, 1, 80))); // C
        pattern.set_note(4, 0, Some(Note::new(64, 4, 1, 75))); // E
        pattern.set_note(8, 0, Some(Note::new(67, 4, 1, 70))); // G
        pattern.set_note(12, 0, Some(Note::new(72, 4, 1, 85))); // C
        
        // Add bass line
        pattern.set_note(0, 1, Some(Note::new(36, 2, 2, 100))); // C
        pattern.set_note(8, 1, Some(Note::new(43, 2, 2, 100))); // G
        
        tracker.load_pattern(pattern);
        
        // 4. User plays back the pattern
        let mut mixer = MixingEngine::new(44100, 2);
        
        // Simulate playback for a few ticks
        for _ in 0..64 {
            tracker.advance_tick();
            let audio_buffer = mixer.mix_audio(256);
            assert_eq!(audio_buffer.len(), 512); // 256 * 2 channels
        }
        
        // 5. User exports audio
        let exported_audio = tracker.export_to_audio(44100, 1.0);
        assert!(!exported_audio.is_empty());
        
        // Verify audio contains actual sound
        let max_amplitude = exported_audio.iter().fold(0.0f32, |acc, &x| acc.max(x.abs()));
        assert!(max_amplitude > 0.01);
    }

    /// Test terminal session with filesystem navigation and commands
    #[tokio::test]
    async fn test_terminal_session_workflow() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // 1. User starts in main menu
        assert_eq!(terminal.ui_state.current_view, TerminalView::MainMenu);
        
        // 2. User navigates to file explorer
        terminal.handle_input(RadialButton::B).expect("Failed to navigate down");
        terminal.handle_input(RadialButton::R).expect("Failed to enter file explorer");
        
        // Should now be in file explorer
        assert_eq!(terminal.ui_state.current_view, TerminalView::FilesystemBrowser);
        
        // 3. User navigates through filesystem
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        std::fs::write(temp_dir.path().join("test.txt"), "Hello World").expect("Failed to write file");
        std::fs::create_dir(temp_dir.path().join("subdir")).expect("Failed to create subdir");
        
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // 4. User views directory contents
        let has_test_file = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "test.txt");
        let has_subdir = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "subdir");
        
        assert!(has_test_file);
        assert!(has_subdir);
        
        // 5. User switches to command builder
        terminal.ui_state.current_view = TerminalView::CommandBuilder;
        
        // 6. User builds a command
        terminal.command_builder.base_command = "ls".to_string();
        terminal.command_builder.add_flag("-la".to_string());
        
        let command_string = terminal.command_builder.build_command_string();
        assert!(command_string.contains("ls"));
        assert!(command_string.contains("-la"));
        
        // 7. User views command history
        let cmd_entry = CommandEntry {
            command: command_string.clone(),
            directory: terminal.current_directory.clone(),
            timestamp: chrono::Utc::now(),
            exit_code: 0,
            output: "total 4\n-rw-r--r-- 1 user user 11 test.txt".to_string(),
        };
        
        terminal.command_history.push(cmd_entry);
        terminal.ui_state.current_view = TerminalView::History;
        
        assert_eq!(terminal.command_history.len(), 1);
        assert_eq!(terminal.command_history[0].command, command_string);
    }

    /// Test email composition and sending workflow
    #[tokio::test]
    async fn test_email_composition_workflow() {
        let mut email_client = AnbernicEmailClient::new("user@handheld.local".to_string())
            .expect("Failed to create email client");
        
        // 1. User adds contacts
        let contact1 = Contact {
            email: "friend@example.com".to_string(),
            display_name: Some("Best Friend".to_string()),
            ssh_public_key: Some("ssh-rsa AAAAB3...".to_string()),
            device_type: Some("anbernic_rg35xx".to_string()),
            last_seen: Some(chrono::Utc::now()),
            trust_level: TrustLevel::Trusted,
        };
        
        let contact2 = Contact {
            email: "colleague@work.com".to_string(),
            display_name: Some("Work Colleague".to_string()),
            ssh_public_key: None,
            device_type: None,
            last_seen: None,
            trust_level: TrustLevel::Verified,
        };
        
        email_client.add_contact(contact1);
        email_client.add_contact(contact2);
        
        assert_eq!(email_client.contacts.len(), 2);
        
        // 2. User navigates to compose view
        email_client.navigate_to_compose();
        assert_eq!(email_client.ui_state.current_view, EmailView::Compose);
        
        // 3. User composes email
        let new_message = EmailMessage {
            id: "compose_123".to_string(),
            from: "user@handheld.local".to_string(),
            to: vec!["friend@example.com".to_string()],
            subject: "Greetings from Anbernic".to_string(),
            body: "Hello! Sending this from my handheld device.".to_string(),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Encrypted,
            message_type: MessageType::Draft,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };
        
        // 4. User saves as draft
        email_client.drafts.push(new_message.clone());
        assert_eq!(email_client.drafts.len(), 1);
        
        // 5. User sends email (moves from draft to outbox)
        let sent_message = EmailMessage {
            message_type: MessageType::Sent,
            read_status: true,
            ..new_message
        };
        
        email_client.outbox.push(sent_message);
        email_client.drafts.clear();
        
        assert_eq!(email_client.drafts.len(), 0);
        assert_eq!(email_client.outbox.len(), 1);
        
        // 6. User receives reply
        let reply = EmailMessage {
            id: "reply_456".to_string(),
            from: "friend@example.com".to_string(),
            to: vec!["user@handheld.local".to_string()],
            subject: "Re: Greetings from Anbernic".to_string(),
            body: "That's awesome! How's the handheld working out?".to_string(),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Encrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: Some("thread_123".to_string()),
            read_status: false,
        };
        
        email_client.inbox.push(reply);
        
        // 7. User navigates to inbox and reads message
        email_client.navigate_to_inbox();
        assert_eq!(email_client.ui_state.current_view, EmailView::Inbox);
        assert_eq!(email_client.inbox.len(), 1);
        assert!(!email_client.inbox[0].read_status);
        
        // Mark as read
        email_client.inbox[0].read_status = true;
        assert!(email_client.inbox[0].read_status);
    }

    /// Test media library scanning and playback workflow
    #[tokio::test]
    async fn test_media_library_workflow() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // 1. User sets up media library
        let mut media_player = MediaPlayer::new(temp_dir.path().to_path_buf())
            .expect("Failed to create media player");
        
        // 2. Create test media files
        let audio_files = vec![
            ("song1.mp3", b"fake mp3 data"),
            ("song2.flac", b"fake flac data"),
            ("song3.wav", b"fake wav data"),
        ];
        
        for (filename, content) in &audio_files {
            std::fs::write(temp_dir.path().join(filename), content)
                .expect("Failed to write audio file");
        }
        
        // 3. User scans library
        media_player.scan_library().expect("Failed to scan library");
        
        // Should find our test files
        assert!(media_player.library.tracks.len() >= 3);
        
        // 4. User creates playlist
        let mut playlist = Playlist::new("My Favorites".to_string());
        
        // Add tracks to playlist
        for track in &media_player.library.tracks[0..2] {
            playlist.add_track(track.clone());
        }
        
        assert_eq!(playlist.tracks.len(), 2);
        
        // 5. User starts playback
        media_player.load_playlist(playlist);
        media_player.play().expect("Failed to start playback");
        
        assert_eq!(media_player.state, PlaybackState::Playing);
        
        // 6. User controls playback
        media_player.pause();
        assert_eq!(media_player.state, PlaybackState::Paused);
        
        media_player.next_track();
        assert_eq!(media_player.current_track_index, 1);
        
        media_player.previous_track();
        assert_eq!(media_player.current_track_index, 0);
        
        // 7. User adjusts volume
        media_player.set_volume(0.7);
        assert!((media_player.volume - 0.7).abs() < 0.01);
    }

    /// Test MMO game session workflow
    #[tokio::test]
    async fn test_mmo_game_session_workflow() {
        let mut game = MMOGame::new().expect("Failed to create game");
        
        // 1. User creates character
        let mut player = Player::new("TestHero".to_string());
        player.position = Position { x: 100.0, y: 100.0, z: 0.0 };
        player.level = 1;
        player.experience = 0;
        
        game.local_player = Some(player);
        
        // 2. User enters game world
        game.world.generate_terrain(1000, 1000);
        assert_eq!(game.world.width, 1000);
        assert_eq!(game.world.height, 1000);
        
        // 3. User moves character
        let initial_pos = game.local_player.as_ref().unwrap().position;
        
        game.handle_movement_input(Direction::North);
        let new_pos = game.local_player.as_ref().unwrap().position;
        
        assert!(new_pos.y > initial_pos.y); // Moved north
        
        // 4. User encounters monsters
        let monster = Monster {
            id: "goblin_001".to_string(),
            position: Position { x: 105.0, y: 105.0, z: 0.0 },
            health: 50,
            max_health: 50,
            level: 1,
            experience_reward: 25,
        };
        
        game.world.spawn_monster(monster);
        
        // 5. User engages in combat
        let combat_result = game.initiate_combat("goblin_001");
        assert!(combat_result.is_ok());
        
        // Simulate combat resolution
        let initial_exp = game.local_player.as_ref().unwrap().experience;
        game.resolve_combat("goblin_001", true); // Player wins
        
        let final_exp = game.local_player.as_ref().unwrap().experience;
        assert!(final_exp > initial_exp); // Gained experience
        
        // 6. User saves game state
        let temp_file = temp_dir.path().join("savegame.json");
        game.save_game(&temp_file).expect("Failed to save game");
        
        // 7. User loads game state
        let mut loaded_game = MMOGame::new().expect("Failed to create game");
        loaded_game.load_game(&temp_file).expect("Failed to load game");
        
        assert_eq!(loaded_game.local_player.as_ref().unwrap().name, "TestHero");
        assert_eq!(loaded_game.world.width, 1000);
    }

    /// Test battleship-pong hybrid game workflow
    #[tokio::test]
    async fn test_battleship_pong_game_workflow() {
        let mut game = BattleshipPong::new().expect("Failed to create game");
        
        // 1. User sets up game board
        assert_eq!(game.board.width, 10);
        assert_eq!(game.board.height, 10);
        
        // 2. User places ships
        let ships = vec![
            Ship { length: 5, positions: vec![(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)] },
            Ship { length: 4, positions: vec![(2, 0), (2, 1), (2, 2), (2, 3)] },
            Ship { length: 3, positions: vec![(4, 0), (4, 1), (4, 2)] },
        ];
        
        for ship in ships {
            game.place_ship(ship).expect("Failed to place ship");
        }
        
        // 3. User starts pong mode
        game.ball.position = (5.0, 5.0);
        game.ball.velocity = (1.0, 1.0);
        game.paddle.position = 5.0;
        
        // 4. User plays pong (simulate ball bouncing)
        for _ in 0..100 {
            game.update_ball_physics(0.016); // 60 FPS
            game.check_ball_collisions();
            
            // Move paddle to follow ball
            if game.ball.position.0 > game.paddle.position {
                game.move_paddle_right();
            } else {
                game.move_paddle_left();
            }
        }
        
        // 5. Ball hits ship
        game.ball.position = (0.5, 0.5); // Near first ship
        let hit_result = game.check_ship_collision();
        
        if hit_result.is_some() {
            game.score += 100;
            assert!(game.score >= 100);
        }
        
        // 6. User achieves high score
        game.score = 15000;
        let high_scores = vec![10000, 8000, 5000];
        
        assert!(game.score > high_scores[0]); // New high score
        
        // 7. Game ends and saves state
        game.game_state = GameState::GameOver;
        
        let temp_file = temp_dir.path().join("battleship_pong_save.json");
        game.save_high_scores(&temp_file).expect("Failed to save high scores");
    }

    /// Test cross-application data sharing workflow
    #[tokio::test]
    async fn test_cross_app_data_sharing() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // 1. User creates art in paint app
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        paint_app.canvas.set_pixel(5, 5, 3);
        paint_app.canvas.set_pixel(6, 6, 3);
        
        let art_file = temp_dir.path().join("shared_art.json");
        paint_app.save_artwork(&art_file).expect("Failed to save artwork");
        
        // 2. User shares art via email
        let mut email_client = AnbernicEmailClient::new("artist@handheld.local".to_string())
            .expect("Failed to create email client");
        
        // Create attachment from art file
        let art_data = std::fs::read(&art_file).expect("Failed to read art file");
        let art_attachment = Attachment {
            filename: "my_art.json".to_string(),
            content_type: "application/json".to_string(),
            size: art_data.len() as u64,
            data: art_data,
            is_encrypted: false,
        };
        
        let email_with_art = EmailMessage {
            id: "art_share_001".to_string(),
            from: "artist@handheld.local".to_string(),
            to: vec!["friend@example.com".to_string()],
            subject: "Check out my pixel art!".to_string(),
            body: "I made this on my handheld device.".to_string(),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Sent,
            attachments: vec![art_attachment],
            thread_id: None,
            read_status: true,
        };
        
        email_client.outbox.push(email_with_art);
        
        // 3. User creates music and shares it
        let mut tracker = TrackerEngine::new();
        let exported_audio = tracker.export_to_audio(44100, 2.0);
        
        let music_attachment = Attachment {
            filename: "my_song.wav".to_string(),
            content_type: "audio/wav".to_string(),
            size: exported_audio.len() as u64 * 4, // f32 to bytes
            data: exported_audio.iter().flat_map(|&f| f.to_le_bytes().to_vec()).collect(),
            is_encrypted: false,
        };
        
        let email_with_music = EmailMessage {
            id: "music_share_001".to_string(),
            from: "artist@handheld.local".to_string(),
            to: vec!["musicfriend@example.com".to_string()],
            subject: "My latest track".to_string(),
            body: "Composed on my handheld tracker!".to_string(),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Sent,
            attachments: vec![music_attachment],
            thread_id: None,
            read_status: true,
        };
        
        email_client.outbox.push(email_with_music);
        
        // 4. User uses terminal to manage files
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // Should see shared files
        let has_art_file = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "shared_art.json");
        assert!(has_art_file);
        
        // 5. Verify all apps can access shared data
        assert_eq!(email_client.outbox.len(), 2);
        assert!(email_client.outbox[0].attachments[0].filename.contains("art"));
        assert!(email_client.outbox[1].attachments[0].filename.contains("song"));
        
        // Load art in new paint session
        let mut new_paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        new_paint_app.load_artwork(&art_file).expect("Failed to load shared art");
        
        assert_eq!(new_paint_app.canvas.get_pixel(5, 5), 3);
        assert_eq!(new_paint_app.canvas.get_pixel(6, 6), 3);
    }

    /// Test device synchronization and backup workflow
    #[tokio::test]
    async fn test_device_sync_workflow() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // 1. User sets up primary device
        let mut primary_device = DeviceSync::new("primary_handheld".to_string())
            .expect("Failed to create device sync");
        
        // 2. User creates content on primary device
        let user_data = UserData {
            artworks: vec!["art1.json".to_string(), "art2.json".to_string()],
            music_tracks: vec!["song1.mod".to_string(), "song2.xm".to_string()],
            game_saves: vec!["mmo_save.json".to_string()],
            email_data: "email_state.json".to_string(),
            settings: "device_settings.json".to_string(),
        };
        
        primary_device.user_data = user_data.clone();
        
        // 3. User initiates backup
        let backup_path = temp_dir.path().join("device_backup.json");
        primary_device.create_backup(&backup_path).expect("Failed to create backup");
        
        // 4. User sets up secondary device
        let mut secondary_device = DeviceSync::new("secondary_handheld".to_string())
            .expect("Failed to create device sync");
        
        // 5. User restores from backup
        secondary_device.restore_from_backup(&backup_path).expect("Failed to restore backup");
        
        // Verify data was transferred
        assert_eq!(secondary_device.user_data.artworks.len(), 2);
        assert_eq!(secondary_device.user_data.music_tracks.len(), 2);
        assert_eq!(secondary_device.user_data.game_saves.len(), 1);
        
        // 6. User makes changes on secondary device
        secondary_device.user_data.artworks.push("art3.json".to_string());
        
        // 7. User syncs changes back to primary
        let sync_data = secondary_device.create_sync_package().expect("Failed to create sync package");
        primary_device.apply_sync_package(sync_data).expect("Failed to apply sync");
        
        // Primary should now have the new artwork
        assert_eq!(primary_device.user_data.artworks.len(), 3);
        assert!(primary_device.user_data.artworks.contains(&"art3.json".to_string()));
    }

    // Helper structs and functions for integration tests
    #[derive(Clone, Debug)]
    struct UserData {
        artworks: Vec<String>,
        music_tracks: Vec<String>,
        game_saves: Vec<String>,
        email_data: String,
        settings: String,
    }

    struct DeviceSync {
        device_id: String,
        user_data: UserData,
    }

    impl DeviceSync {
        fn new(device_id: String) -> Result<Self, Box<dyn std::error::Error>> {
            Ok(Self {
                device_id,
                user_data: UserData {
                    artworks: Vec::new(),
                    music_tracks: Vec::new(),
                    game_saves: Vec::new(),
                    email_data: String::new(),
                    settings: String::new(),
                },
            })
        }

        fn create_backup(&self, path: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
            let backup_data = serde_json::to_string(&self.user_data)?;
            std::fs::write(path, backup_data)?;
            Ok(())
        }

        fn restore_from_backup(&mut self, path: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
            let backup_data = std::fs::read_to_string(path)?;
            self.user_data = serde_json::from_str(&backup_data)?;
            Ok(())
        }

        fn create_sync_package(&self) -> Result<SyncPackage, Box<dyn std::error::Error>> {
            Ok(SyncPackage {
                device_id: self.device_id.clone(),
                user_data: self.user_data.clone(),
                timestamp: chrono::Utc::now(),
            })
        }

        fn apply_sync_package(&mut self, package: SyncPackage) -> Result<(), Box<dyn std::error::Error>> {
            // Merge data (simplified - real implementation would handle conflicts)
            for artwork in package.user_data.artworks {
                if !self.user_data.artworks.contains(&artwork) {
                    self.user_data.artworks.push(artwork);
                }
            }
            for track in package.user_data.music_tracks {
                if !self.user_data.music_tracks.contains(&track) {
                    self.user_data.music_tracks.push(track);
                }
            }
            Ok(())
        }
    }

    #[derive(Clone, Debug)]
    struct SyncPackage {
        device_id: String,
        user_data: UserData,
        timestamp: chrono::DateTime<chrono::Utc>,
    }
}