use handheld_office::email::*;
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🎮 ANBERNIC EMAIL CLIENT 📧");
    println!("================================");
    println!("SSH-Encrypted Handheld Messaging");
    println!("Using Game Boy-style L-shaped display");
    println!("Radial input: A=Up, B=Down, L=Left, R=Right");
    println!("");

    let mut client = AnbernicEmailClient::new("anbernic_user".to_string())?;

    // Add some sample contacts for demo
    client.add_contact(Contact {
        name: "Alice Anbernic".to_string(),
        email: "alice@anbernic.local".to_string(),
        ssh_public_key: Some("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlice...".to_string()),
        trust_level: TrustLevel::Trusted,
        device_type: Some("Anbernic RG35XX".to_string()),
        last_seen: Some(chrono::Utc::now()),
    });

    client.add_contact(Contact {
        name: "Bob Gaming".to_string(),
        email: "bob@gaming.local".to_string(),
        ssh_public_key: Some("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBob...".to_string()),
        trust_level: TrustLevel::Verified,
        device_type: Some("Anbernic RG351P".to_string()),
        last_seen: Some(chrono::Utc::now() - chrono::Duration::hours(2)),
    });

    // Add sample encrypted messages
    let sample_encrypted_msg = EmailMessage {
        id: "msg_001".to_string(),
        from: "alice@anbernic.local".to_string(),
        to: vec!["anbernic_user@local".to_string()],
        subject: "Hey from Alice's Anbernic!".to_string(),
        body: "Just testing the encrypted messaging between our handhelds. This should auto-decrypt since we're both on Anbernic devices with SSH keys!".to_string(),
        timestamp: chrono::Utc::now() - chrono::Duration::minutes(30),
        encryption_status: EncryptionStatus::Encrypted,
        message_type: MessageType::Received,
        attachments: vec![],
        thread_id: Some("thread_alice_001".to_string()),
        read_status: false,
    };

    let sample_unencrypted_msg = EmailMessage {
        id: "msg_002".to_string(),
        from: "untrusted@external.com".to_string(),
        to: vec!["anbernic_user@local".to_string()],
        subject: "⚠️  Unencrypted message".to_string(),
        body: "This message is from an untrusted source and was not encrypted.".to_string(),
        timestamp: chrono::Utc::now() - chrono::Duration::hours(1),
        encryption_status: EncryptionStatus::Unencrypted,
        message_type: MessageType::Received,
        attachments: vec![],
        thread_id: None,
        read_status: false,
    };

    client.inbox.push(sample_encrypted_msg);
    client.inbox.push(sample_unencrypted_msg);

    loop {
        render_email_ui(&client)?;

        println!("\n📍 Navigation:");
        match client.ui_state.current_view {
            EmailView::MainMenu => {
                println!("A) 📥 Inbox ({})", client.inbox.len());
                println!("B) 📤 Outbox ({})", client.outbox.len());
                println!("L) ✏️  Compose New");
                println!("R) 👥 Contacts ({})", client.contacts.len());
            }
            EmailView::Inbox => {
                println!("A) ⬆️  Previous Message");
                println!("B) ⬇️  Next Message");
                println!("L) ⬅️  Back to Main");
                println!("R) 📖 Read Selected");
            }
            EmailView::ReadMessage => {
                println!("A) ⬆️  Scroll Up");
                println!("B) ⬇️  Scroll Down");
                println!("L) ⬅️  Back to Inbox");
                println!("R) ↩️  Reply");
            }
            EmailView::Compose => {
                println!("A) 📝 Edit Subject");
                println!("B) 📝 Edit Body");
                println!("L) ❌ Cancel");
                println!("R) 📤 Send (Auto-encrypt)");
            }
            EmailView::Contacts => {
                println!("A) ⬆️  Previous Contact");
                println!("B) ⬇️  Next Contact");
                println!("L) ⬅️  Back to Main");
                println!("R) 📧 Email Selected");
            }
        }

        print!("\n🎮 Input (A/B/L/R/Q): ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let input = input.trim().to_uppercase();

        match input.as_str() {
            "Q" => {
                println!("👋 Saving email state and exiting...");
                client.save_state()?;
                break;
            }
            "A" => handle_radial_input(&mut client, RadialButton::A)?,
            "B" => handle_radial_input(&mut client, RadialButton::B)?,
            "L" => handle_radial_input(&mut client, RadialButton::L)?,
            "R" => handle_radial_input(&mut client, RadialButton::R)?,
            _ => println!("❌ Invalid input. Use A/B/L/R or Q to quit."),
        }
    }

    Ok(())
}

fn render_email_ui(client: &AnbernicEmailClient) -> Result<(), Box<dyn std::error::Error>> {
    // Clear screen (Game Boy style)
    print!("\x1B[2J\x1B[1;1H");

    // L-shaped display header (line across top)
    println!("🎮═══════════════════════════════════════════════════════════════════════════════🎮");
    print!("📧 ANBERNIC EMAIL │ ");

    match client.ui_state.current_view {
        EmailView::MainMenu => print!("MAIN MENU"),
        EmailView::Inbox => print!("INBOX"),
        EmailView::ReadMessage => print!("READING"),
        EmailView::Compose => print!("COMPOSE"),
        EmailView::Contacts => print!("CONTACTS"),
    }

    // Show encryption status in header
    print!(" │ 🔐 SSH: ON │ ");
    println!("🔋 100%");

    // L-shaped continuation (down right side)
    println!("════════════════════════════════════════════════════════════════════════════════║");

    match client.ui_state.current_view {
        EmailView::MainMenu => render_main_menu(client),
        EmailView::Inbox => render_inbox(client),
        EmailView::ReadMessage => render_message(client),
        EmailView::Compose => render_compose(client),
        EmailView::Contacts => render_contacts(client),
    }

    println!("════════════════════════════════════════════════════════════════════════════════║");

    Ok(())
}

fn render_main_menu(client: &AnbernicEmailClient) {
    println!("                                                                                ║");
    println!(
        "   📥 INBOX        │ {} messages ({} unread)                                    ║",
        client.inbox.len(),
        client.inbox.iter().filter(|m| !m.is_read()).count()
    );
    println!(
        "   📤 OUTBOX       │ {} messages                                               ║",
        client.outbox.len()
    );
    println!("   ✏️  COMPOSE      │ New encrypted message                                     ║");
    println!(
        "   👥 CONTACTS     │ {} trusted Anbernic devices                             ║",
        client.contacts.len()
    );
    println!("                                                                                ║");
    println!("   🔐 SSH Status   │ Keys loaded, auto-encrypt enabled                        ║");
    println!("   📡 Network      │ WiFi party mode active                                   ║");
    println!("                                                                                ║");
}

fn render_inbox(client: &AnbernicEmailClient) {
    println!("                                                                                ║");
    if client.inbox.is_empty() {
        println!("   📭 Inbox is empty                                                          ║");
    } else {
        for (i, message) in client.inbox.iter().enumerate() {
            let selected = i == client.ui_state.selected_message_index;
            let prefix = if selected { "►" } else { " " };
            let encryption_icon = match message.encryption_status {
                EncryptionStatus::Encrypted => "🔐",
                EncryptionStatus::Unencrypted => "⚠️ ",
                EncryptionStatus::Failed => "❌",
            };
            let read_icon = if message.is_read() { " " } else { "●" };

            println!(
                "   {}{} {} {} │ {} │ {}{}                                              ║",
                prefix,
                read_icon,
                encryption_icon,
                message.from.chars().take(20).collect::<String>(),
                message.subject.chars().take(30).collect::<String>(),
                message.timestamp.format("%H:%M"),
                " ".repeat(20)
            );
        }
    }
    println!("                                                                                ║");
}

fn render_message(client: &AnbernicEmailClient) {
    if let Some(message) = client.get_current_message() {
        println!(
            "                                                                                ║"
        );
        println!(
            "   From: {}                                                           ║",
            message.from.chars().take(60).collect::<String>()
        );
        println!(
            "   Subject: {}                                                        ║",
            message.subject.chars().take(55).collect::<String>()
        );
        println!(
            "   Time: {}                                                                 ║",
            message.timestamp.format("%Y-%m-%d %H:%M")
        );

        let encryption_status = match message.encryption_status {
            EncryptionStatus::Encrypted => "🔐 Auto-decrypted from trusted Anbernic device",
            EncryptionStatus::Unencrypted => "⚠️  Unencrypted message from untrusted source",
            EncryptionStatus::Failed => "❌ Decryption failed - may be corrupted",
        };
        println!(
            "   Security: {}                                                    ║",
            encryption_status
        );
        println!(
            "                                                                                ║"
        );

        // Message body with word wrapping for Game Boy display
        let words: Vec<&str> = message.body.split_whitespace().collect();
        let mut current_line = String::new();

        for word in words {
            if current_line.len() + word.len() + 1 > 75 {
                println!(
                    "   {}{}║",
                    current_line,
                    " ".repeat(75 - current_line.len())
                );
                current_line = word.to_string();
            } else {
                if !current_line.is_empty() {
                    current_line.push(' ');
                }
                current_line.push_str(word);
            }
        }
        if !current_line.is_empty() {
            println!(
                "   {}{}║",
                current_line,
                " ".repeat(75 - current_line.len())
            );
        }
    }
    println!("                                                                                ║");
}

fn render_compose(_client: &AnbernicEmailClient) {
    println!("                                                                                ║");
    println!("   ✏️  COMPOSE NEW MESSAGE                                                      ║");
    println!("                                                                                ║");
    println!("   To: [Select from contacts]                                                  ║");
    println!("   Subject: [A to edit]                                                       ║");
    println!("   Body: [B to edit]                                                          ║");
    println!("                                                                                ║");
    println!("   🔐 Auto-encrypt: ENABLED                                                    ║");
    println!("   📡 Will use SSH keys from contact's Anbernic device                        ║");
    println!("                                                                                ║");
}

fn render_contacts(client: &AnbernicEmailClient) {
    println!("                                                                                ║");
    if client.contacts.is_empty() {
        println!(
            "   👥 No contacts configured                                                   ║"
        );
    } else {
        for (i, (email, contact)) in client.contacts.iter().enumerate() {
            let selected = i == client.ui_state.selected_contact_index;
            let prefix = if selected { "►" } else { " " };
            let trust_icon = match contact.trust_level {
                TrustLevel::Trusted => "🔐",
                TrustLevel::Verified => "✅",
                TrustLevel::Unknown => "❓",
            };
            let device_type = contact.device_type.as_deref().unwrap_or("Unknown");

            println!(
                "   {}{} {} │ {} │ {}{}                                               ║",
                prefix,
                trust_icon,
                contact.name.chars().take(20).collect::<String>(),
                device_type.chars().take(15).collect::<String>(),
                email.chars().take(25).collect::<String>(),
                " ".repeat(10)
            );
        }
    }
    println!("                                                                                ║");
}

fn handle_radial_input(
    client: &mut AnbernicEmailClient,
    button: RadialButton,
) -> Result<(), Box<dyn std::error::Error>> {
    match client.ui_state.current_view {
        EmailView::MainMenu => match button {
            RadialButton::A => client.navigate_to_inbox(),
            RadialButton::B => client.navigate_to_outbox(),
            RadialButton::L => client.navigate_to_compose(),
            RadialButton::R => client.navigate_to_contacts(),
        },
        EmailView::Inbox => match button {
            RadialButton::A => client.select_previous_message(),
            RadialButton::B => client.select_next_message(),
            RadialButton::L => client.navigate_to_main_menu(),
            RadialButton::R => client.navigate_to_read_message(),
        },
        EmailView::ReadMessage => match button {
            RadialButton::A => client.scroll_message_up(),
            RadialButton::B => client.scroll_message_down(),
            RadialButton::L => client.navigate_to_inbox(),
            RadialButton::R => client.start_reply(),
        },
        EmailView::Compose => match button {
            RadialButton::A => {
                println!("📝 Enter subject:");
                let mut subject = String::new();
                io::stdin().read_line(&mut subject)?;
                client.set_compose_subject(subject.trim().to_string());
            }
            RadialButton::B => {
                println!("📝 Enter message body:");
                let mut body = String::new();
                io::stdin().read_line(&mut body)?;
                client.set_compose_body(body.trim().to_string());
            }
            RadialButton::L => client.navigate_to_main_menu(),
            RadialButton::R => match client.send_current_message() {
                Ok(_) => println!("✅ Message sent with auto-encryption!"),
                Err(e) => println!("❌ Send failed: {}", e),
            },
        },
        EmailView::Contacts => match button {
            RadialButton::A => client.select_previous_contact(),
            RadialButton::B => client.select_next_contact(),
            RadialButton::L => client.navigate_to_main_menu(),
            RadialButton::R => client.compose_to_selected_contact(),
        },
    }

    Ok(())
}
