use criterion::{criterion_group, criterion_main, Criterion, BenchmarkId};
use handheld_office::*;
use std::time::Duration;

fn paint_performance_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("paint_performance");
    
    // Canvas creation benchmarks
    group.bench_function("canvas_creation_16x16", |b| {
        b.iter(|| Canvas::new(16, 16))
    });
    
    group.bench_function("canvas_creation_64x64", |b| {
        b.iter(|| Canvas::new(64, 64))
    });
    
    group.bench_function("canvas_creation_256x256", |b| {
        b.iter(|| Canvas::new(256, 256))
    });
    
    // Drawing performance benchmarks
    group.bench_function("line_drawing_diagonal", |b| {
        let mut canvas = Canvas::new(64, 64);
        b.iter(|| {
            canvas.draw_line(0, 0, 63, 63, 1);
        });
    });
    
    group.bench_function("flood_fill_large_area", |b| {
        let mut canvas = Canvas::new(64, 64);
        b.iter(|| {
            canvas.flood_fill(32, 32, 5);
        });
    });
    
    // ASCII conversion benchmark
    group.bench_function("ascii_conversion_64x64", |b| {
        let mut canvas = Canvas::new(64, 64);
        // Fill with random pattern
        for y in 0..64 {
            for x in 0..64 {
                canvas.set_pixel(x, y, ((x + y) % 4) as u8);
            }
        }
        b.iter(|| canvas.to_ascii_art());
    });
    
    group.finish();
}

fn music_performance_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("music_performance");
    
    // Audio mixing benchmarks
    for buffer_size in [256, 512, 1024, 2048].iter() {
        group.bench_with_input(
            BenchmarkId::new("audio_mixing", buffer_size),
            buffer_size,
            |b, &size| {
                let mut mixer = MixingEngine::new(44100, 2);
                
                // Add 8 channels with different notes
                for i in 0..8 {
                    let mut channel = Channel::new();
                    channel.play_note(60 + i as u8, 1, 64);
                    mixer.add_channel(channel);
                }
                
                b.iter(|| mixer.mix_audio(size));
            },
        );
    }
    
    // Pattern processing benchmark
    group.bench_function("pattern_playback", |b| {
        let mut tracker = TrackerEngine::new();
        let mut pattern = Pattern::new(64, 8);
        
        // Fill pattern with notes
        for row in 0..64 {
            for channel in 0..8 {
                if row % 4 == 0 {
                    pattern.set_note(row, channel, Some(Note::new(60 + channel as u8, 4, 1, 64)));
                }
            }
        }
        
        tracker.load_pattern(pattern);
        
        b.iter(|| {
            for _ in 0..24 { // One row at 6 ticks per row
                tracker.advance_tick();
            }
        });
    });
    
    // Audio export benchmark
    group.bench_function("audio_export_1_second", |b| {
        let mut tracker = TrackerEngine::new();
        let mut pattern = Pattern::new(16, 4);
        
        // Add some notes
        pattern.set_note(0, 0, Some(Note::new(60, 4, 1, 80)));
        pattern.set_note(4, 1, Some(Note::new(64, 4, 1, 75)));
        pattern.set_note(8, 2, Some(Note::new(67, 4, 1, 70)));
        
        tracker.load_pattern(pattern);
        
        b.iter(|| tracker.export_to_audio(44100, 1.0));
    });
    
    group.finish();
}

fn terminal_performance_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("terminal_performance");
    
    // Directory scanning benchmarks
    group.bench_function("filesystem_cache_small_dir", |b| {
        let temp_dir = tempfile::TempDir::new().expect("Failed to create temp dir");
        
        // Create 10 files
        for i in 0..10 {
            std::fs::write(temp_dir.path().join(format!("file_{}.txt", i)), "content")
                .expect("Failed to create file");
        }
        
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        b.iter(|| {
            terminal.refresh_filesystem_cache().expect("Failed to refresh cache");
        });
    });
    
    group.bench_function("filesystem_cache_large_dir", |b| {
        let temp_dir = tempfile::TempDir::new().expect("Failed to create temp dir");
        
        // Create 1000 files
        for i in 0..1000 {
            std::fs::write(temp_dir.path().join(format!("file_{:04}.txt", i)), "content")
                .expect("Failed to create file");
        }
        
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        b.iter(|| {
            terminal.refresh_filesystem_cache().expect("Failed to refresh cache");
        });
    });
    
    // Rendering benchmarks
    group.bench_function("terminal_render_main_menu", |b| {
        let terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        b.iter(|| terminal.render());
    });
    
    group.bench_function("terminal_render_file_browser", |b| {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        terminal.ui_state.current_view = TerminalView::FilesystemBrowser;
        b.iter(|| terminal.render());
    });
    
    // Command history benchmark
    group.bench_function("command_history_large", |b| {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Add 1000 commands to history
        for i in 0..1000 {
            let cmd = CommandEntry {
                command: format!("command_{}", i),
                directory: terminal.current_directory.clone(),
                timestamp: chrono::Utc::now(),
                exit_code: 0,
                output: format!("Output for command {}", i),
            };
            terminal.command_history.push(cmd);
        }
        
        terminal.ui_state.current_view = TerminalView::History;
        
        b.iter(|| terminal.render());
    });
    
    group.finish();
}

fn email_performance_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("email_performance");
    
    // Email parsing benchmarks
    group.bench_function("email_serialization", |b| {
        let message = EmailMessage {
            id: "test_msg".to_string(),
            from: "sender@example.com".to_string(),
            to: vec!["recipient@example.com".to_string()],
            subject: "Performance Test Email".to_string(),
            body: "This is a test email for performance benchmarking. ".repeat(100),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };
        
        b.iter(|| {
            let serialized = serde_json::to_string(&message).expect("Serialization failed");
            let _: EmailMessage = serde_json::from_str(&serialized).expect("Deserialization failed");
        });
    });
    
    // Large inbox benchmarks
    for inbox_size in [100, 1000, 10000].iter() {
        group.bench_with_input(
            BenchmarkId::new("inbox_search", inbox_size),
            inbox_size,
            |b, &size| {
                let mut client = AnbernicEmailClient::new("test@example.com".to_string())
                    .expect("Failed to create client");
                
                // Fill inbox with test messages
                for i in 0..size {
                    let message = EmailMessage {
                        id: format!("msg_{}", i),
                        from: format!("sender{}@example.com", i),
                        to: vec!["test@example.com".to_string()],
                        subject: if i % 10 == 0 { "Important".to_string() } else { "Regular".to_string() },
                        body: format!("Message body {}", i),
                        timestamp: chrono::Utc::now(),
                        encryption_status: EncryptionStatus::Unencrypted,
                        message_type: MessageType::Received,
                        attachments: Vec::new(),
                        thread_id: None,
                        read_status: false,
                    };
                    client.inbox.push(message);
                }
                
                b.iter(|| {
                    client.search_messages("Important");
                });
            },
        );
    }
    
    // Attachment handling benchmark
    group.bench_function("large_attachment_handling", |b| {
        let attachment_data = vec![0u8; 1_000_000]; // 1MB attachment
        
        b.iter(|| {
            let attachment = Attachment {
                filename: "large_file.zip".to_string(),
                content_type: "application/zip".to_string(),
                size: attachment_data.len() as u64,
                data: attachment_data.clone(),
                is_encrypted: false,
            };
            
            // Serialize and deserialize
            let serialized = serde_json::to_string(&attachment).expect("Serialization failed");
            let _: Attachment = serde_json::from_str(&serialized).expect("Deserialization failed");
        });
    });
    
    group.finish();
}

fn mmo_performance_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("mmo_performance");
    
    // World generation benchmarks
    for world_size in [100, 500, 1000].iter() {
        group.bench_with_input(
            BenchmarkId::new("world_generation", world_size),
            world_size,
            |b, &size| {
                b.iter(|| {
                    let mut world = GameWorld::new();
                    world.generate_terrain(size, size);
                });
            },
        );
    }
    
    // Player movement and collision detection
    group.bench_function("collision_detection", |b| {
        let mut game = MMOGame::new().expect("Failed to create game");
        game.world.generate_terrain(500, 500);
        
        // Add many entities
        for i in 0..1000 {
            let entity = Entity {
                id: format!("entity_{}", i),
                position: Position {
                    x: (i % 500) as f32,
                    y: (i / 500) as f32,
                    z: 0.0,
                },
                entity_type: EntityType::NPC,
            };
            game.world.add_entity(entity);
        }
        
        b.iter(|| {
            game.update_collision_detection();
        });
    });
    
    // Network packet processing
    group.bench_function("packet_serialization", |b| {
        let packet = NetworkPacket {
            packet_type: PacketType::PlayerUpdate,
            sender_id: "player_123".to_string(),
            data: serde_json::json!({
                "position": {"x": 100.5, "y": 200.3, "z": 0.0},
                "health": 85,
                "level": 15
            }),
            timestamp: chrono::Utc::now(),
        };
        
        b.iter(|| {
            let serialized = serde_json::to_string(&packet).expect("Serialization failed");
            let _: NetworkPacket = serde_json::from_str(&serialized).expect("Deserialization failed");
        });
    });
    
    // Rendering performance
    group.bench_function("ascii_world_rendering", |b| {
        let mut game = MMOGame::new().expect("Failed to create game");
        game.world.generate_terrain(100, 100);
        
        // Add player
        let player = Player::new("TestPlayer".to_string());
        game.local_player = Some(player);
        
        b.iter(|| {
            game.render_world_ascii();
        });
    });
    
    group.finish();
}

fn memory_stress_tests(c: &mut Criterion) {
    let mut group = c.benchmark_group("memory_stress");
    group.sample_size(10); // Fewer samples for stress tests
    
    // Large canvas stress test
    group.bench_function("large_canvas_operations", |b| {
        b.iter(|| {
            let mut canvas = Canvas::new(512, 512);
            
            // Fill canvas with pattern
            for y in 0..512 {
                for x in 0..512 {
                    canvas.set_pixel(x, y, ((x + y) % 16) as u8);
                }
            }
            
            // Perform multiple operations
            canvas.draw_line(0, 0, 511, 511, 15);
            canvas.draw_circle(256, 256, 100, 14);
            canvas.flood_fill(50, 50, 13);
            
            // Convert to ASCII (memory intensive)
            let _ascii = canvas.to_ascii_art();
        });
    });
    
    // Audio buffer stress test
    group.bench_function("large_audio_buffers", |b| {
        b.iter(|| {
            let mut mixer = MixingEngine::new(44100, 2);
            
            // Add many channels
            for i in 0..32 {
                let mut channel = Channel::new();
                channel.play_note(60 + (i % 12) as u8, 1, 64);
                mixer.add_channel(channel);
            }
            
            // Generate large buffer
            let _buffer = mixer.mix_audio(44100); // 1 second of audio
        });
    });
    
    // Large file system stress test
    group.bench_function("large_directory_handling", |b| {
        let temp_dir = tempfile::TempDir::new().expect("Failed to create temp dir");
        
        // Create many files and directories
        for i in 0..1000 {
            std::fs::write(temp_dir.path().join(format!("file_{:04}.txt", i)), "content")
                .expect("Failed to create file");
            
            if i % 10 == 0 {
                std::fs::create_dir(temp_dir.path().join(format!("dir_{:03}", i / 10)))
                    .expect("Failed to create directory");
            }
        }
        
        b.iter(|| {
            let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
            terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
            let _output = terminal.render();
        });
    });
    
    // Email stress test
    group.bench_function("large_email_database", |b| {
        b.iter(|| {
            let mut client = AnbernicEmailClient::new("stress@test.com".to_string())
                .expect("Failed to create client");
            
            // Create large email database
            for i in 0..10000 {
                let message = EmailMessage {
                    id: format!("stress_msg_{}", i),
                    from: format!("sender{}@example.com", i % 100),
                    to: vec!["stress@test.com".to_string()],
                    subject: format!("Stress test message {}", i),
                    body: "This is a stress test email. ".repeat(50),
                    timestamp: chrono::Utc::now(),
                    encryption_status: EncryptionStatus::Unencrypted,
                    message_type: MessageType::Received,
                    attachments: Vec::new(),
                    thread_id: Some(format!("thread_{}", i % 100)),
                    read_status: i % 3 == 0,
                };
                client.inbox.push(message);
            }
            
            // Perform operations on large dataset
            client.sort_inbox_by_date();
            let _search_results = client.search_messages("stress");
            let _threads = client.get_thread_messages("thread_50");
        });
    });
    
    group.finish();
}

criterion_group!(
    benches,
    paint_performance_benchmarks,
    music_performance_benchmarks,
    terminal_performance_benchmarks,
    email_performance_benchmarks,
    mmo_performance_benchmarks,
    memory_stress_tests
);

criterion_main!(benches);