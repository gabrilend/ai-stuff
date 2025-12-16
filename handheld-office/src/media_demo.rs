use handheld_office::media::RadialButton;
use handheld_office::{AnbernicMediaPlayer, MediaUIState, PlaybackState};
use std::io::{self, Write};
use std::sync::mpsc;
use std::time::Duration;
use tokio::time;

/// Demo application for the Anbernic Media Player
pub struct MediaPlayerDemo {
    media_player: AnbernicMediaPlayer,
    running: bool,
    last_update: std::time::Instant,
}

impl MediaPlayerDemo {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            media_player: AnbernicMediaPlayer::new()?,
            running: true,
            last_update: std::time::Instant::now(),
        })
    }

    /// Main demo loop
    pub async fn run(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("🎮 Welcome to Anbernic Media Player! 🎮\n");

        println!("This media player features:");
        println!("• Support for MP3, FLAC, WAV, OGG audio formats");
        println!("• Radial menu navigation using A/B/L/R buttons");
        println!("• Media library scanning and management");
        println!("• Playlist creation and management");
        println!("• File sharing integration with communication apps");
        println!("• Game Boy-style interface optimized for handheld devices\n");

        println!("Initializing media player...");
        self.media_player.initialize().await?;

        println!("Starting in 3 seconds...");
        for i in (1..=3).rev() {
            println!("{}...", i);
            time::sleep(Duration::from_secs(1)).await;
        }

        // Set up input handling
        let (tx, rx) = mpsc::channel();

        // Spawn input handling task
        let input_tx = tx.clone();
        std::thread::spawn(move || loop {
            if let Some(button) = Self::get_simulated_input() {
                if input_tx.send(button).is_err() {
                    break;
                }
            }
            std::thread::sleep(Duration::from_millis(100));
        });

        // Main demo loop
        while self.running {
            // Clear screen and render current state
            self.render_interface();

            // Handle input
            if let Ok(button) = rx.try_recv() {
                if button == RadialButton::L
                    && self.media_player.ui_state == MediaUIState::MainMenu
                    && self.media_player.menu_stack.is_empty()
                {
                    println!("\nExiting media player demo...");
                    self.running = false;
                    break;
                }

                if let Err(e) = self.media_player.handle_input(button).await {
                    println!("Input error: {}", e);
                }
            }

            // Update playback position (simulate)
            self.update_playback_position();

            // Refresh rate limiting
            time::sleep(Duration::from_millis(100)).await;
        }

        Ok(())
    }

    fn render_interface(&self) {
        // Clear screen (ANSI escape sequence)
        print!("\x1B[2J\x1B[H");

        // Render the Game Boy-style border
        println!("┌────────────────────────────────────────────────────────────────────────────┐");
        println!("│                           ANBERNIC MEDIA PLAYER                            │");
        println!("├────────────────────────────────────────────────────────────────────────────┤");

        // Render current display
        let display_content = self.media_player.render_display();
        for line in display_content.lines() {
            println!("│ {:<74} │", line);
        }

        // Add battery and status info
        println!("├────────────────────────────────────────────────────────────────────────────┤");

        // Show current mode and battery
        let mode_info = format!(
            "Mode: {:?} | Battery: 85% | Volume: {}%",
            self.media_player.input_mode,
            (self.media_player.playback_info.volume * 100.0) as u8
        );
        println!("│ {:<74} │", mode_info);

        println!("└────────────────────────────────────────────────────────────────────────────┘");

        // Control instructions
        println!("\nControls:");
        println!("  W/↑ = A Button (Up/North)");
        println!("  S/↓ = B Button (Down/South)");
        println!("  A/← = L Button (Left/West)");
        println!("  D/→ = R Button (Right/East)");
        println!("  Q = Quit (from main menu)");

        // Show additional context based on current state
        match self.media_player.ui_state {
            MediaUIState::MainMenu => {
                println!("\nPress R to select menu items, L to exit");
            }
            MediaUIState::AudioLibrary => {
                println!(
                    "\nAudio files: {}",
                    self.media_player.media_library.audio_files.len()
                );
                println!(
                    "Video files: {}",
                    self.media_player.media_library.video_files.len()
                );
            }
            MediaUIState::NowPlaying => {
                println!("\nPress A/B for prev/next, R for play/pause");
                if let Some(sink) = &self.media_player.audio_sink {
                    if sink.is_paused() {
                        println!("Audio: PAUSED");
                    } else {
                        println!("Audio: PLAYING");
                    }
                }
            }
            _ => {}
        }

        println!("\n─────────────────────────────────────────────────────────────────────────────");

        // Flush output
        io::stdout().flush().unwrap();
    }

    fn update_playback_position(&mut self) {
        // Simulate playback position updates
        if self.media_player.playback_info.state == PlaybackState::Playing {
            let elapsed = self.last_update.elapsed();
            if elapsed >= Duration::from_secs(1) {
                self.media_player.playback_info.position += elapsed;
                self.last_update = std::time::Instant::now();
            }
        }
    }

    fn get_simulated_input() -> Option<RadialButton> {
        // In a real implementation, this would read from hardware buttons
        // For demo purposes, we simulate with keyboard input
        use std::io::Read;

        let mut stdin = io::stdin();
        let mut buffer = [0; 1];

        // Non-blocking read
        match stdin.read(&mut buffer) {
            Ok(0) => None, // No input
            Ok(_) => {
                match buffer[0] {
                    b'w' | b'W' => Some(RadialButton::A), // Up/North
                    b's' | b'S' => Some(RadialButton::B), // Down/South
                    b'a' | b'A' => Some(RadialButton::L), // Left/West
                    b'd' | b'D' => Some(RadialButton::R), // Right/East
                    b'q' | b'Q' => Some(RadialButton::L), // Quit
                    _ => None,
                }
            }
            Err(_) => None,
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    env_logger::init();

    println!("Initializing Anbernic Media Player Demo...\n");

    // Check for media directories
    let media_dirs = ["./music", "./videos", "./audio", "/media", "/mnt"];

    println!("Checking for media directories:");
    for dir in &media_dirs {
        let path = std::path::Path::new(dir);
        if path.exists() {
            println!("  ✓ {} (found)", dir);
        } else {
            println!("  ✗ {} (not found)", dir);
        }
    }

    // Create sample directory structure for demo
    tokio::fs::create_dir_all("./music").await?;
    tokio::fs::create_dir_all("./videos").await?;
    tokio::fs::create_dir_all("./received_media").await?;

    println!("\nCreated demo directories for media files.");
    println!("Place your .mp3, .flac, .wav, .ogg files in ./music/");
    println!("Place your .mp4, .mkv files in ./videos/\n");

    // Create and run the demo
    let mut demo = MediaPlayerDemo::new()?;
    demo.run().await?;

    println!("Media player demo completed!");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_media_player_creation() {
        let result = MediaPlayerDemo::new();
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_media_player_initialization() {
        let mut demo = MediaPlayerDemo::new().unwrap();
        let result = demo.media_player.initialize().await;
        assert!(result.is_ok());
    }
}
