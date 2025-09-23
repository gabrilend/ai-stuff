use handheld_office::paint::{Direction, VectorPaintCanvas};
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎨 Game Boy Advance Vector Paint Tool Demo");
    println!("   Memory-efficient point storage, just like your vision!");
    println!("");

    // Create a Game Boy Advance sized canvas (240x160, but smaller for demo)
    let mut canvas = VectorPaintCanvas::new(40, 20);

    println!(
        "📱 Canvas: {}x{} pixels",
        canvas.canvas_width, canvas.canvas_height
    );
    println!("🎮 Controls:");
    println!("   WASD - Move cursor  |  Q - Start stroke  |  E - End stroke");
    println!("   1-4 - Change color  |  X - Exit");
    println!("");

    let mut color = 1;
    let mut thickness = 2;

    loop {
        // Clear screen and show canvas
        print!("\x1B[2J\x1B[1;1H"); // ANSI clear screen
        println!(
            "🎨 Vector Paint Demo - Memory: {} bytes",
            canvas.memory_usage()
        );
        println!(
            "Current: Color {} | Thickness {} | Strokes: {}",
            color,
            thickness,
            canvas.strokes.len()
        );
        println!("");

        println!("{}", canvas.render_ascii());

        print!("\nCommand: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let cmd = input.trim().to_lowercase();

        match cmd.as_str() {
            "w" => canvas.move_cursor(Direction::Up),
            "s" => canvas.move_cursor(Direction::Down),
            "a" => canvas.move_cursor(Direction::Left),
            "d" => canvas.move_cursor(Direction::Right),
            "q" => {
                if canvas.current_stroke.is_none() {
                    canvas.start_stroke(color, thickness);
                    println!("✏️  Started new stroke");
                }
            }
            "e" => {
                if canvas.current_stroke.is_some() {
                    canvas.finish_stroke();
                    println!("✅ Finished stroke");
                }
            }
            "1" => color = 0,
            "2" => color = 1,
            "3" => color = 2,
            "4" => color = 3,
            "x" => break,
            "demo" => {
                // Auto-draw a cool pattern
                println!("🚀 Drawing demo pattern...");

                // Draw a house
                canvas.start_stroke(1, 2);
                // Bottom line
                for _ in 0..10 {
                    canvas.add_point_to_stroke(Direction::Right);
                }
                // Right wall
                for _ in 0..6 {
                    canvas.add_point_to_stroke(Direction::Up);
                }
                // Roof right
                for _ in 0..5 {
                    canvas.add_point_to_stroke(Direction::UpLeft);
                }
                // Roof left
                for _ in 0..5 {
                    canvas.add_point_to_stroke(Direction::DownLeft);
                }
                // Left wall
                for _ in 0..6 {
                    canvas.add_point_to_stroke(Direction::Down);
                }
                canvas.finish_stroke();

                // Add a door
                canvas.move_cursor(Direction::Right);
                canvas.move_cursor(Direction::Right);
                canvas.move_cursor(Direction::Right);
                canvas.start_stroke(2, 1);
                for _ in 0..4 {
                    canvas.add_point_to_stroke(Direction::Up);
                }
                canvas.finish_stroke();

                println!("🏠 Demo house drawn!");
            }
            "save" => {
                let data = canvas.to_compact_format();
                println!(
                    "💾 Canvas saved: {} bytes (vs {}px bitmap = {} bytes)",
                    data.len(),
                    canvas.canvas_width * canvas.canvas_height,
                    (canvas.canvas_width * canvas.canvas_height) / 8
                ); // 1 bit per pixel
            }
            _ => {
                println!("❓ Unknown command: {}", cmd);
            }
        }
    }

    println!("");
    println!("🎯 Final Stats:");
    println!("   Strokes drawn: {}", canvas.strokes.len());
    println!("   Memory usage: {} bytes", canvas.memory_usage());
    println!(
        "   Compression ratio: {:.1}x vs bitmap",
        (canvas.canvas_width * canvas.canvas_height) as f32 / canvas.memory_usage() as f32
    );

    // Show the compact serialization
    let compact = canvas.to_compact_format();
    println!("   Serialized size: {} bytes", compact.len());

    // Demonstrate network transmission readiness
    println!("");
    println!("📡 Network Ready:");
    println!(
        "   This drawing can be sent over your LAN in {} bytes",
        compact.len()
    );
    println!("   Perfect for Anbernic-to-Anbernic art sharing! 🎮✨");

    Ok(())
}
