use handheld_office::terminal::RadialButton;
use handheld_office::AnbernicTerminal;
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 Anbernic Terminal Test");

    // Create a new terminal instance
    let mut terminal = AnbernicTerminal::new()?;

    // Display the initial interface
    println!("{}", terminal.render());

    println!("Controls: W/A/S/D for navigation, Q to quit");
    println!(
        "Current directory: {}",
        terminal.current_directory.display()
    );

    // Simple input loop for testing
    loop {
        print!("Enter command (w/a/s/d/q): ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;

        match input.trim().to_lowercase().as_str() {
            "q" => break,
            "w" => {
                // Simulate Up button
                if let Err(e) = terminal.handle_input(RadialButton::A) {
                    println!("Error: {}", e);
                }
            }
            "s" => {
                // Simulate Down button
                if let Err(e) = terminal.handle_input(RadialButton::B) {
                    println!("Error: {}", e);
                }
            }
            "a" => {
                // Simulate Left button
                if let Err(e) = terminal.handle_input(RadialButton::L) {
                    println!("Error: {}", e);
                }
            }
            "d" => {
                // Simulate Right button
                if let Err(e) = terminal.handle_input(RadialButton::R) {
                    println!("Error: {}", e);
                }
            }
            _ => continue,
        }

        // Display updated interface
        println!("{}", terminal.render());
    }

    println!("Terminal test complete!");
    Ok(())
}
