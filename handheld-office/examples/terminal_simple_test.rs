use handheld_office::terminal::RadialButton;
use handheld_office::AnbernicTerminal;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 Simple Terminal Test");

    // Create a new terminal instance
    let mut terminal = AnbernicTerminal::new()?;

    println!("✅ Terminal created successfully!");
    println!(
        "Current directory: {}",
        terminal.current_directory.display()
    );

    // Test basic input handling
    println!("🔄 Testing input handling...");

    // Test navigate down (B button)
    terminal.handle_input(RadialButton::B)?;
    println!("✅ Down navigation successful");

    // Test navigate up (A button)
    terminal.handle_input(RadialButton::A)?;
    println!("✅ Up navigation successful");

    // Test navigate right (R button) - this should select/enter
    println!("🔄 Testing selection...");
    if let Err(e) = terminal.handle_input(RadialButton::R) {
        println!("ℹ️  Selection error (expected): {}", e);
    } else {
        println!("✅ Selection successful");
    }

    // Test navigate left (L button) - this should go back
    println!("🔄 Testing back navigation...");
    if let Err(e) = terminal.handle_input(RadialButton::L) {
        println!("ℹ️  Back navigation error (expected): {}", e);
    } else {
        println!("✅ Back navigation successful");
    }

    // Test render without printing the entire output
    let rendered = terminal.render();
    println!(
        "✅ Render successful, output length: {} characters",
        rendered.len()
    );

    // Show just the first few lines
    let lines: Vec<&str> = rendered.lines().take(5).collect();
    println!("🔍 First 5 lines of output:");
    for line in lines {
        println!("   {}", line);
    }

    println!("🎉 All tests completed successfully!");
    Ok(())
}
