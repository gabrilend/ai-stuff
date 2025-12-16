use handheld_office::rocketship_bacterium::*;
use std::io::{self, Write};
use std::time::{Duration, Instant};

struct GameBoyInterface {
    simulation: RocketshipBacterium,
    last_update: Instant,
    paused: bool,
    selected_particle_type: ParticleType,
    cursor_x: u32,
    cursor_y: u32,
    zoom_level: f32,
    show_debug: bool,
    show_particle_count: bool,
    gravity_well_strength: f32,
}

impl GameBoyInterface {
    fn new() -> Self {
        let mut simulation = RocketshipBacterium::new();

        // Add some initial particles in the Game Boy vision
        for i in 0..20 {
            let position = Position3D {
                x: 80.0 + (i as f32 * 8.0) % 160.0,
                y: 72.0 + (i as f32 * 6.0) % 144.0,
                z: 50.0,
            };
            simulation.add_particle(ParticleType::Flame, position);
        }

        Self {
            simulation,
            last_update: Instant::now(),
            paused: false,
            selected_particle_type: ParticleType::Flame,
            cursor_x: 80,
            cursor_y: 72,
            zoom_level: 1.0,
            show_debug: false,
            show_particle_count: true,
            gravity_well_strength: 50.0,
        }
    }

    fn render_frame(&self) -> String {
        let mut output = String::new();

        // Clear screen with Game Boy-style header
        output.push_str("\x1b[2J\x1b[H");
        output.push_str(
            "╔══════════════════════════════════════════════════════════════════════════════╗\n",
        );
        output.push_str(
            "║                    ROCKETSHIP BACTERIUM - Particle Life                     ║\n",
        );
        output.push_str(
            "╚══════════════════════════════════════════════════════════════════════════════╝\n",
        );

        // Render the particle simulation
        let ascii_frame = self.simulation.render_ascii();
        for line in ascii_frame.lines() {
            output.push_str("│");
            output.push_str(line);
            output.push_str("│\n");
        }

        // Game Boy-style status bar
        output.push_str(
            "╔══════════════════════════════════════════════════════════════════════════════╗\n",
        );

        if self.show_particle_count {
            output.push_str(&format!(
                "║ Particles: {} | Active | Game Boy Simulation                           ║\n",
                20 // Placeholder count
            ));
        }

        output.push_str(&format!(
            "║ Type: {:?} | Cursor: ({},{}) | {} | Gravity: {:.1}            ║\n",
            self.selected_particle_type,
            self.cursor_x,
            self.cursor_y,
            if self.paused { "PAUSED" } else { "RUNNING" },
            self.gravity_well_strength
        ));

        output.push_str(
            "╚══════════════════════════════════════════════════════════════════════════════╝\n",
        );

        // Game Boy controls
        output.push_str(
            "┌─ CONTROLS ─────────────────────────────────────────────────────────────────┐\n",
        );
        output.push_str(
            "│ WASD: Move cursor  | SPACE: Add particle | P: Pause | Q: Quit             │\n",
        );
        output.push_str(
            "│ 1-6: Particle type | G: Add gravity well | R: Reset | T: Toggle debug     │\n",
        );
        output.push_str(
            "│ +/-: Adjust gravity | C: Toggle counts   | Z/X: Zoom                      │\n",
        );
        output.push_str(
            "└────────────────────────────────────────────────────────────────────────────┘\n",
        );

        if self.show_debug {
            output.push_str(
                "┌─ DEBUG INFO ───────────────────────────────────────────────────────────────┐\n",
            );
            output.push_str(
                "│ Particle Life Simulation - Game Boy Style Rendering                      │\n",
            );
            output.push_str(
                "│ 3D-to-2D Projection Active - Artificial Life Enabled                    │\n",
            );
            output.push_str(
                "└────────────────────────────────────────────────────────────────────────────┘\n",
            );
        }

        output
    }

    fn handle_input(&mut self, input: char) {
        match input.to_ascii_lowercase() {
            'w' => self.cursor_y = self.cursor_y.saturating_sub(2),
            's' => self.cursor_y = (self.cursor_y + 2).min(self.simulation.world.height - 1),
            'a' => self.cursor_x = self.cursor_x.saturating_sub(2),
            'd' => self.cursor_x = (self.cursor_x + 2).min(self.simulation.world.width - 1),

            ' ' => {
                // Add particle at cursor with Game Boy aesthetics
                let position = Position3D {
                    x: self.cursor_x as f32,
                    y: self.cursor_y as f32,
                    z: 50.0 + (rand::random::<f32>() - 0.5) * 20.0,
                };

                // Velocity is not needed for add_particle API

                self.simulation
                    .add_particle(self.selected_particle_type.clone(), position);
            }

            'g' => {
                // Add gravity well at cursor
                let position = Position3D {
                    x: self.cursor_x as f32,
                    y: self.cursor_y as f32,
                    z: 50.0,
                };
                self.simulation.add_gravity_well(
                    position,
                    self.gravity_well_strength,
                    GravityWellType::Attractive,
                );
            }

            'p' => self.paused = !self.paused,
            'r' => {
                self.simulation = RocketshipBacterium::new();
                for i in 0..20 {
                    let position = Position3D {
                        x: 80.0 + (i as f32 * 8.0) % 160.0,
                        y: 72.0 + (i as f32 * 6.0) % 144.0,
                        z: 50.0,
                    };
                    self.simulation.add_particle(ParticleType::Flame, position);
                }
            }
            't' => self.show_debug = !self.show_debug,
            'c' => self.show_particle_count = !self.show_particle_count,

            '1' => self.selected_particle_type = ParticleType::Flame,
            '2' => self.selected_particle_type = ParticleType::Bacterium,
            '3' => self.selected_particle_type = ParticleType::Virus,
            '4' => self.selected_particle_type = ParticleType::Crystal,
            '5' => self.selected_particle_type = ParticleType::Crystal,
            '6' => self.selected_particle_type = ParticleType::Plasma,

            '+' | '=' => {
                self.gravity_well_strength = (self.gravity_well_strength + 10.0).min(200.0)
            }
            '-' => self.gravity_well_strength = (self.gravity_well_strength - 10.0).max(10.0),

            'z' => self.zoom_level = (self.zoom_level * 1.2).min(3.0),
            'x' => self.zoom_level = (self.zoom_level / 1.2).max(0.5),

            _ => {}
        }
    }

    fn update(&mut self) {
        if !self.paused {
            let now = Instant::now();
            let delta_time = now.duration_since(self.last_update).as_secs_f32();

            // Target 30 FPS for Game Boy feel
            if delta_time >= 1.0 / 30.0 {
                self.simulation.update(delta_time as f64);
                self.last_update = now;
            }
        }
    }

    fn run(&mut self) -> io::Result<()> {
        // Enable raw mode for immediate input
        println!("Starting Rocketship Bacterium Particle Life Simulation...");
        println!("(This demo uses simplified input - press Enter after each command)");
        println!();

        loop {
            // Update simulation
            self.update();

            // Render frame
            print!("{}", self.render_frame());
            io::stdout().flush()?;

            // Simple input handling (in a real Game Boy emulator this would be different)
            println!("Enter command (or 'q' to quit): ");
            let mut input = String::new();
            io::stdin().read_line(&mut input)?;

            let command = input.trim().chars().next().unwrap_or('q');
            if command == 'q' {
                break;
            }

            self.handle_input(command);

            // Small delay to prevent overwhelming the terminal
            std::thread::sleep(Duration::from_millis(50));
        }

        println!("Thanks for exploring the particle life simulation!");
        Ok(())
    }
}

fn main() -> io::Result<()> {
    println!("╔══════════════════════════════════════════════════════════════════════════════╗");
    println!("║                                                                              ║");
    println!(
        "║    ██▀███   ▒█████   ▄████▄   ██ ▄█▀▓█████▄▄▄█████▓  ██████  ██░ ██ ██▓ ██▓███   ║"
    );
    println!(
        "║   ▓██ ▒ ██▒▒██▒  ██▒▒██▀ ▀█   ██▄█▒ ▓█   ▀▓  ██▒ ▓▒▒██    ▒ ▓██░ ██▒▓██▒▓██░  ██▒ ║"
    );
    println!(
        "║   ▓██ ░▄█ ▒▒██░  ██▒▒▓█    ▄ ▓███▄░ ▒███  ▒ ▓██░ ▒░░ ▓██▄   ▒██▀▀██░▒██▒▓██░ ██▓▒ ║"
    );
    println!(
        "║   ▒██▀▀█▄  ▒██   ██░▒▓▓▄ ▄██▒▓██ █▄ ▒▓█  ▄░ ▓██▓ ░   ▒   ██▒░▓█ ░██ ░██░▒██▄█▓▒ ▒ ║"
    );
    println!(
        "║   ░██▓ ▒██▒░ ████▓▒░▒ ▓███▀ ░▒██▒ █▄░▒████▒ ▒██▒ ░ ▒██████▒▒░▓█▒░██▓░██░▒██▒ ░  ░ ║"
    );
    println!(
        "║   ░ ▒▓ ░▒▓░░ ▒░▒░▒░ ░ ░▒ ▒  ░▒ ▒▒ ▓▒░░ ▒░ ░ ▒ ░░   ▒ ▒▓▒ ▒ ░ ▒ ░░▒░▒░▓  ▒▓▒░ ░  ░ ║"
    );
    println!(
        "║     ░▒ ░ ▒░  ░ ▒ ▒░   ░  ▒   ░ ░▒ ▒░ ░ ░  ░   ░    ░ ░▒  ░ ░ ▒ ░▒░ ░ ▒ ░░▒ ░      ║"
    );
    println!(
        "║     ░░   ░ ░ ░ ░ ▒  ░        ░ ░░ ░    ░    ░      ░  ░  ░   ░  ░░ ░ ▒ ░░░        ║"
    );
    println!(
        "║      ░         ░ ░  ░ ░      ░  ░      ░  ░              ░   ░  ░  ░ ░             ║"
    );
    println!(
        "║                     ░                                                             ║"
    );
    println!("║                                                                              ║");
    println!("║                           BACTERIUM - Particle Life                             ║");
    println!("║                                                                              ║");
    println!(
        "║          \"not like a worm, but rather like a particle simulation.\"              ║"
    );
    println!(
        "║                    \"artificial life, just... made more complicated\"             ║"
    );
    println!("║                                                                              ║");
    println!("╚══════════════════════════════════════════════════════════════════════════════╝");
    println!();
    println!("Remember those particle sim games on the early iPhone?");
    println!("Bright, bold colors like distant cyan flame in a cold, vast dark...");
    println!();

    let mut game = GameBoyInterface::new();
    game.run()
}
