use handheld_office::music::{GamepadButton, GamepadKeymap, MusicalInstrument};
use std::collections::HashMap;
use std::io::{self, Write};
use std::time::Instant;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎵 Handheld Office Music Studio");
    println!("   Turn your Anbernic into a pocket instrument! 🎮🎹");
    println!("");

    // Create default instrument
    let mut current_instrument =
        MusicalInstrument::new("Piano".to_string(), GamepadKeymap::piano());

    let mut button_sequence = Vec::new();
    let mut recording_combo_held = false;
    let start_time = Instant::now();

    println!("🎼 Available Instruments:");
    println!("   1 - Piano (default)");
    println!("   2 - Drum Kit");
    println!("   3 - Load custom keymap");
    println!("");

    loop {
        // Clear screen and show current state
        print!("\x1B[2J\x1B[1;1H"); // ANSI clear screen
        println!("{}", current_instrument.render_display());

        if recording_combo_held {
            println!("🔴 HOLD L+R+SELECT for recording...");
        }

        // Show recent notes played
        if let Some(ref recording) = current_instrument.current_recording {
            println!("\n📝 Recording Events: {}", recording.events.len());
            for event in recording.events.iter().rev().take(5) {
                println!(
                    "  {:.1}s: {} ({:?})",
                    event.timestamp_ms as f32 / 1000.0,
                    event.note.name,
                    event.button
                );
            }
        }

        println!("\n🎮 Press buttons to play, or:");
        println!("   i1-i3: Switch instrument  |  q: Quit");
        println!("   save: Save config  |  load: Load config");

        print!("\nInput: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let cmd = input.trim().to_lowercase();

        let timestamp = start_time.elapsed().as_millis() as u64;

        match cmd.as_str() {
            // Instrument switching
            "i1" => {
                current_instrument =
                    MusicalInstrument::new("Piano".to_string(), GamepadKeymap::piano());
                println!("🎹 Switched to Piano");
            }
            "i2" => {
                current_instrument =
                    MusicalInstrument::new("Drums".to_string(), GamepadKeymap::drums());
                println!("🥁 Switched to Drums");
            }
            "i3" => {
                if let Ok(custom) = MusicalInstrument::load_from_config("keymap-custom-1.json") {
                    current_instrument = custom;
                    println!("🔧 Loaded custom instrument");
                } else {
                    println!("⚠️  No custom keymap found");
                }
            }

            // Config management
            "save" => {
                let filename = format!(
                    "keymap-{}-{}.json",
                    current_instrument.name.to_lowercase(),
                    chrono::Utc::now().format("%Y%m%d")
                );
                current_instrument.save_to_config(&filename)?;
                println!("💾 Saved to {}", filename);
            }
            "load" => {
                // List available configs
                println!("📁 Available configs:");
                if let Ok(entries) = std::fs::read_dir("files/build/") {
                    for entry in entries {
                        if let Ok(entry) = entry {
                            let filename = entry.file_name();
                            if let Some(name) = filename.to_str() {
                                if name.starts_with("keymap-") && name.ends_with(".json") {
                                    println!("   {}", name);
                                }
                            }
                        }
                    }
                }
            }

            // Recording controls
            "rec" => {
                if current_instrument.current_recording.is_none() {
                    current_instrument.start_recording("Manual Recording".to_string())?;
                    println!("🔴 Recording started");
                } else {
                    let recording = current_instrument.stop_recording()?;
                    println!(
                        "⏹️  Recording stopped: {} events, {:.1}s",
                        recording.events.len(),
                        recording.duration_ms as f32 / 1000.0
                    );
                }
            }

            // Simulate L+R+SELECT combo
            "lrs" => {
                recording_combo_held = !recording_combo_held;
                if recording_combo_held {
                    if current_instrument.current_recording.is_none() {
                        // Start recording with metronome countdown
                        println!("🎵 Metronome countdown...");
                        for i in (1..=current_instrument.metronome.countdown_beats).rev() {
                            println!("  {} ♪", i);
                            std::thread::sleep(std::time::Duration::from_millis(
                                60000 / current_instrument.metronome.bpm as u64,
                            ));
                        }
                        current_instrument.start_recording("Live Recording".to_string())?;
                        println!("🔴 Recording!");
                    } else {
                        let recording = current_instrument.stop_recording()?;
                        println!("✅ Recording saved: {}", recording.name);
                        recording_combo_held = false;
                    }
                }
            }

            // Password combo simulation
            "password" => {
                println!("🔐 Testing password combo...");
                let combo = &current_instrument.keymap.password_combo;
                for button in combo {
                    println!("  Press {:?}", button);
                    button_sequence.push(*button);
                }

                if current_instrument.is_password_combo(&button_sequence) {
                    println!("✅ Password accepted! Returning to main menu...");
                    break;
                } else {
                    println!("❌ Password incorrect");
                }
                button_sequence.clear();
            }

            // Senescence simulation
            "sleep" => {
                println!("😴 Forcing senescence...");
                println!("   Clearing recordings (conversation context)");
                println!("   Keeping instrument settings (persistent)");
                current_instrument.force_senescence();
                println!("🌅 Awakened with fresh memory");
            }

            // Gamepad button simulation
            "a" => play_note(&mut current_instrument, GamepadButton::A, timestamp),
            "b" => play_note(&mut current_instrument, GamepadButton::B, timestamp),
            "x" => play_note(&mut current_instrument, GamepadButton::X, timestamp),
            "y" => play_note(&mut current_instrument, GamepadButton::Y, timestamp),
            "up" => play_note(&mut current_instrument, GamepadButton::DPadUp, timestamp),
            "down" => play_note(&mut current_instrument, GamepadButton::DPadDown, timestamp),
            "left" => play_note(&mut current_instrument, GamepadButton::DPadLeft, timestamp),
            "right" => play_note(&mut current_instrument, GamepadButton::DPadRight, timestamp),
            "l1" => play_note(&mut current_instrument, GamepadButton::L1, timestamp),
            "r1" => play_note(&mut current_instrument, GamepadButton::R1, timestamp),
            "l2" => play_note(&mut current_instrument, GamepadButton::L2, timestamp),
            "r2" => play_note(&mut current_instrument, GamepadButton::R2, timestamp),

            // Demo song
            "demo" => {
                println!("🎼 Playing demo song...");
                current_instrument.start_recording("Demo Song".to_string())?;

                // Simple melody: C-D-E-F-G
                let melody = vec![
                    GamepadButton::A,  // C4
                    GamepadButton::B,  // D4
                    GamepadButton::X,  // E4
                    GamepadButton::Y,  // F4
                    GamepadButton::L1, // G4
                ];

                for (i, button) in melody.iter().enumerate() {
                    let note_time = i as u64 * 500; // 500ms per note
                    play_note(&mut current_instrument, *button, note_time);
                    std::thread::sleep(std::time::Duration::from_millis(500));
                }

                let recording = current_instrument.stop_recording()?;
                println!("🎵 Demo complete: {} notes", recording.events.len());
            }

            "q" => break,

            _ => {
                println!("❓ Unknown command: {}", cmd);
                println!("   Try: a,b,x,y (notes) | rec (record) | lrs (L+R+SELECT) | password");
            }
        }

        button_sequence.push(parse_button(&cmd));

        // Keep only recent buttons for password detection
        if button_sequence.len() > 10 {
            button_sequence.drain(0..5);
        }

        std::thread::sleep(std::time::Duration::from_millis(100));
    }

    println!("");
    println!("🎵 Music Session Complete!");
    println!(
        "   Total recordings: {}",
        current_instrument.recordings.len()
    );

    // Show session summary
    let session_duration = start_time.elapsed().as_secs();
    println!(
        "   Session duration: {}m {}s",
        session_duration / 60,
        session_duration % 60
    );

    if !current_instrument.recordings.is_empty() {
        println!("   Recordings saved as living config files in files/build/");
        println!("   Ready for sharing between programs or over LAN!");
    }

    println!("");
    println!("🎮 Perfect for your Anbernic music sessions! 🎹✨");

    Ok(())
}

fn play_note(instrument: &mut MusicalInstrument, button: GamepadButton, timestamp: u64) {
    if let Some(note) = instrument.press_button(button, timestamp) {
        println!(
            "🎵 {} ({:.1}Hz) - {:?}",
            note.name, note.frequency, note.timbre
        );

        // Simulate note duration
        std::thread::sleep(std::time::Duration::from_millis(50));
        instrument.release_button(button, timestamp + 50);
    } else {
        println!("🔇 No note mapped to {:?}", button);
    }
}

fn parse_button(cmd: &str) -> GamepadButton {
    match cmd {
        "a" => GamepadButton::A,
        "b" => GamepadButton::B,
        "x" => GamepadButton::X,
        "y" => GamepadButton::Y,
        "up" => GamepadButton::DPadUp,
        "down" => GamepadButton::DPadDown,
        "left" => GamepadButton::DPadLeft,
        "right" => GamepadButton::DPadRight,
        "l1" => GamepadButton::L1,
        "r1" => GamepadButton::R1,
        "l2" => GamepadButton::L2,
        "r2" => GamepadButton::R2,
        "select" => GamepadButton::Select,
        "start" => GamepadButton::Start,
        _ => GamepadButton::A, // Default
    }
}
