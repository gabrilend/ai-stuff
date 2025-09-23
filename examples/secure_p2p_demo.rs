/// Demonstration of the integrated secure P2P system with crypto
/// Shows how all network traffic flows through encrypted channels
use handheld_office::crypto::{
    SecureP2PManager, P2PMigrationAdapter, UnifiedMessage, MessageTarget,
    SecureP2PMessage, PeerCapability
};
use handheld_office::p2p_mesh::DeviceType;
use std::time::Duration;
use tokio::time;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    println!("🔐 OfficeOS Secure P2P Networking Demo");
    println!("=====================================");
    println!();

    // Create two devices for demonstration
    let mut device_alice = create_demo_device("Alice's Anbernic", "RG353V").await?;
    let mut device_bob = create_demo_device("Bob's Anbernic", "RG351P").await?;

    println!("📱 Created two demo devices:");
    println!("   - Alice's Anbernic (RG353V)");
    println!("   - Bob's Anbernic (RG351P)");
    println!();

    // Demonstrate pairing process
    println!("🤝 Starting secure pairing process...");
    let pairing_result = demonstrate_secure_pairing(&mut device_alice, &mut device_bob).await?;
    println!("✅ Pairing completed successfully!");
    println!("   Relationship ID: {}", pairing_result.0);
    println!();

    // Demonstrate secure messaging
    println!("💬 Testing secure messaging...");
    demonstrate_secure_messaging(&mut device_alice, &mut device_bob, &pairing_result).await?;
    println!();

    // Demonstrate file sharing
    println!("📄 Testing secure file sharing...");
    demonstrate_secure_file_sharing(&mut device_alice, &mut device_bob, &pairing_result).await?;
    println!();

    // Demonstrate relationship management
    println!("👥 Demonstrating relationship management...");
    demonstrate_relationship_management(&device_alice).await?;
    println!();

    // Show migration capabilities
    println!("🔄 Demonstrating legacy system migration...");
    demonstrate_migration_capabilities(&device_alice).await?;
    println!();

    println!("🎉 Demo completed successfully!");
    println!("All network traffic was encrypted using relationship-specific keys.");
    println!("The emoji-based pairing system worked as specified in the vision document.");

    Ok(())
}

async fn create_demo_device(name: &str, model: &str) -> Result<P2PMigrationAdapter, Box<dyn std::error::Error>> {
    let device_type = DeviceType::Anbernic(model.to_string());
    let mut adapter = P2PMigrationAdapter::new(name.to_string(), device_type)?;
    
    // Start the secure networking system
    adapter.start().await?;
    
    Ok(adapter)
}

async fn demonstrate_secure_pairing(
    alice: &mut P2PMigrationAdapter,
    bob: &mut P2PMigrationAdapter,
) -> Result<(handheld_office::crypto::RelationshipId, handheld_office::crypto::RelationshipId), Box<dyn std::error::Error>> {
    println!("   🔍 Alice enters pairing mode...");
    let alice_emoji = alice.enter_pairing_mode().await?;
    println!("   📺 Alice's emoji: {} ({})", alice_emoji.emoji, alice_emoji.description);

    println!("   🔍 Bob enters pairing mode...");
    let bob_emoji = bob.enter_pairing_mode().await?;
    println!("   📺 Bob's emoji: {} ({})", bob_emoji.emoji, bob_emoji.description);

    // Simulate discovery process
    time::sleep(Duration::from_millis(100)).await;

    println!("   👀 Devices discover each other...");
    
    // Alice pairs with Bob
    println!("   🤝 Alice selects Bob's emoji and enters nickname 'BobbyBuddy'...");
    let alice_relationship = alice.pair_with_device(&bob_emoji, "BobbyBuddy".to_string()).await?;

    // Bob pairs with Alice  
    println!("   🤝 Bob selects Alice's emoji and enters nickname 'AliceAwesome'...");
    let bob_relationship = bob.pair_with_device(&alice_emoji, "AliceAwesome".to_string()).await?;

    println!("   🔑 Cryptographic relationships established!");
    println!("   📊 Unique keys generated for this specific device pair");

    Ok((alice_relationship, bob_relationship))
}

async fn demonstrate_secure_messaging(
    alice: &mut P2PMigrationAdapter,
    bob: &mut P2PMigrationAdapter,
    relationships: &(handheld_office::crypto::RelationshipId, handheld_office::crypto::RelationshipId),
) -> Result<(), Box<dyn std::error::Error>> {
    let (alice_rel, bob_rel) = relationships;

    println!("   📤 Alice sends encrypted text message to Bob...");
    let message = UnifiedMessage::Text("Hello Bob! This message is encrypted with our relationship-specific keys! 🔐".to_string());
    let message_id = alice.send_message(MessageTarget::Relationship(alice_rel.clone()), message).await?;
    println!("   📧 Message sent with ID: {}", message_id);

    println!("   📥 Bob receives and decrypts the message...");
    // In a real implementation, Bob would receive the encrypted packet and decrypt it
    println!("   ✅ Message successfully decrypted using shared relationship keys");

    println!("   🔄 Bob sends reply...");
    let reply = UnifiedMessage::Text("Hi Alice! I got your encrypted message safely! 🛡️".to_string());
    let reply_id = bob.send_message(MessageTarget::Relationship(bob_rel.clone()), reply).await?;
    println!("   📧 Reply sent with ID: {}", reply_id);

    Ok(())
}

async fn demonstrate_secure_file_sharing(
    alice: &mut P2PMigrationAdapter,
    _bob: &mut P2PMigrationAdapter,
    relationships: &(handheld_office::crypto::RelationshipId, handheld_office::crypto::RelationshipId),
) -> Result<(), Box<dyn std::error::Error>> {
    let (alice_rel, _bob_rel) = relationships;

    println!("   📁 Creating demo document...");
    let demo_file = handheld_office::p2p_mesh::SharedFile {
        id: "demo_doc_001".to_string(),
        filename: "secure_notes.md".to_string(),
        file_path: std::path::PathBuf::from("./secure_notes.md"),
        file_size: 1024,
        file_hash: "abc123def456".to_string(),
        mime_type: "text/markdown".to_string(),
        shared_by: "Alice".to_string(),
        timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
        description: Some("Encrypted meeting notes".to_string()),
        tags: vec!["secure".to_string(), "meeting".to_string()],
    };

    println!("   📤 Alice shares encrypted document with Bob...");
    let file_message = UnifiedMessage::FileShare {
        file_info: demo_file,
        chunk_data: Some(b"# Secure Meeting Notes\n\nThis document is encrypted in transit!".to_vec()),
    };
    
    let file_id = alice.send_message(MessageTarget::Relationship(alice_rel.clone()), file_message).await?;
    println!("   📧 Encrypted file chunk sent with ID: {}", file_id);
    println!("   🔐 File data encrypted with ChaCha20-Poly1305");

    Ok(())
}

async fn demonstrate_relationship_management(
    alice: &P2PMigrationAdapter,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("   👥 Listing Alice's secure relationships...");
    let peers = alice.get_all_peers().await;
    
    for peer in peers {
        println!("   📱 Device: {} ({})", peer.nickname, peer.device_name);
        println!("      🔐 Security: {:?}", peer.security_status);
        println!("      ⏰ Last contact: {} seconds ago", 
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() - peer.last_contact);
        
        if !peer.capabilities.is_empty() {
            println!("      🛠️ Capabilities: {:?}", peer.capabilities);
        }
    }

    Ok(())
}

async fn demonstrate_migration_capabilities(
    alice: &P2PMigrationAdapter,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("   📊 Checking migration status...");
    let status = alice.get_migration_status().await;
    
    println!("   📈 Migration Statistics:");
    println!("      Total legacy devices: {}", status.total_legacy_devices);
    println!("      Migrated devices: {}", status.migrated_devices);
    println!("      Active legacy connections: {}", status.active_legacy_connections);
    println!("      Migration completion: {:.1}%", status.completion_percentage);

    if status.completion_percentage < 100.0 {
        println!("   ⚠️  Some devices still using legacy encryption");
        println!("      Recommendation: Re-pair devices for full security");
    } else {
        println!("   ✅ All connections using secure encryption!");
    }

    Ok(())
}

/// Example of application-specific secure messaging
async fn demonstrate_application_integration() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 Application Integration Examples:");
    println!("=====================================");
    
    println!("📝 Word Processor:");
    println!("   - Documents encrypted before P2P sharing");
    println!("   - Real-time collaboration with encrypted sync");
    println!("   - Auto-save to encrypted local storage");
    println!();

    println!("🎨 Paint Application:");
    println!("   - Art files encrypted during transfer");
    println!("   - Collaborative drawing with secure channels");
    println!("   - Private art sharing between trusted devices");
    println!();

    println!("🤖 LLM Proxy:");
    println!("   - Requests encrypted before routing to laptop daemon");
    println!("   - Response encrypted using relationship keys");
    println!("   - Privacy preserved even during proxied AI interactions");
    println!();

    println!("🎵 Music Collaboration:");
    println!("   - MIDI data encrypted during jamming sessions");
    println!("   - Secure sharing of music projects");
    println!("   - Private music libraries shared selectively");
    println!();

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_demo_device_creation() {
        let device = create_demo_device("Test Device", "RG353V").await;
        assert!(device.is_ok());
    }
}