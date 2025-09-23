/// Standalone Laptop Daemon Binary
/// Provides AI services to Anbernic devices via WiFi Direct P2P

use handheld_office::{LaptopDaemon, LaptopDaemonConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let config = LaptopDaemonConfig::default();
    let mut daemon = LaptopDaemon::new(config)?;

    println!("🚀 Starting Laptop Daemon...");
    daemon.start().await?;

    // Keep the service running
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    }
}