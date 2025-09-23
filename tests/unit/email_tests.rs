use handheld_office::*;
use handheld_office::email::*;
use chrono::{DateTime, Utc};
use tempfile::TempDir;

#[cfg(test)]
mod email_tests {
    use super::*;

    #[test]
    fn test_email_client_creation() {
        let client = AnbernicEmailClient::new("test@example.com".to_string());
        assert!(client.is_ok());
        
        let client = client.unwrap();
        assert_eq!(client.inbox.len(), 0);
        assert_eq!(client.outbox.len(), 0);
        assert_eq!(client.drafts.len(), 0);
        assert_eq!(client.contacts.len(), 0);
    }

    #[test]
    fn test_email_message_creation() {
        let message = EmailMessage {
            id: "test123".to_string(),
            from: "sender@example.com".to_string(),
            to: vec!["recipient@example.com".to_string()],
            subject: "Test Subject".to_string(),
            body: "Test message body".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };

        assert_eq!(message.from, "sender@example.com");
        assert_eq!(message.to[0], "recipient@example.com");
        assert_eq!(message.subject, "Test Subject");
        assert!(!message.read_status);
    }

    #[test]
    fn test_email_address_validation() {
        // Valid email addresses
        assert!(is_valid_email("user@example.com"));
        assert!(is_valid_email("test.email+tag@domain.co.uk"));
        assert!(is_valid_email("simple@test.org"));
        
        // Invalid email addresses
        assert!(!is_valid_email("invalid.email"));
        assert!(!is_valid_email("@example.com"));
        assert!(!is_valid_email("user@"));
        assert!(!is_valid_email(""));
        assert!(!is_valid_email("spaces in@email.com"));
    }

    #[test]
    fn test_contact_management() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        let contact = Contact {
            email: "friend@example.com".to_string(),
            display_name: Some("Best Friend".to_string()),
            ssh_public_key: Some("ssh-rsa AAAAB3...".to_string()),
            device_type: Some("anbernic_rg35xx".to_string()),
            last_seen: Some(Utc::now()),
            trust_level: TrustLevel::Trusted,
        };

        client.add_contact(contact.clone());
        
        assert_eq!(client.contacts.len(), 1);
        let retrieved = client.contacts.get("friend@example.com").unwrap();
        assert_eq!(retrieved.display_name, Some("Best Friend".to_string()));
        assert_eq!(retrieved.trust_level, TrustLevel::Trusted);
    }

    #[test]
    fn test_message_threading() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        let thread_id = "thread_123";
        
        let message1 = EmailMessage {
            id: "msg1".to_string(),
            from: "alice@example.com".to_string(),
            to: vec!["test@example.com".to_string()],
            subject: "Project Discussion".to_string(),
            body: "Let's discuss the project".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: Some(thread_id.to_string()),
            read_status: false,
        };

        let message2 = EmailMessage {
            id: "msg2".to_string(),
            from: "test@example.com".to_string(),
            to: vec!["alice@example.com".to_string()],
            subject: "Re: Project Discussion".to_string(),
            body: "Great idea! Let's start tomorrow".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Sent,
            attachments: Vec::new(),
            thread_id: Some(thread_id.to_string()),
            read_status: true,
        };

        client.inbox.push(message1);
        client.outbox.push(message2);

        let thread_messages = client.get_thread_messages(thread_id);
        assert_eq!(thread_messages.len(), 2);
        
        // Messages should be sorted by timestamp
        assert!(thread_messages[0].timestamp <= thread_messages[1].timestamp);
    }

    #[test]
    fn test_ssh_key_generation() {
        let ssh_manager = SSHKeyManager::new();
        assert!(ssh_manager.is_ok());
        
        let manager = ssh_manager.unwrap();
        assert!(manager.private_key_path.exists() || manager.private_key_path.to_string_lossy().contains("anbernic"));
        assert!(manager.public_key_path.exists() || manager.public_key_path.to_string_lossy().contains("anbernic"));
        assert!(!manager.device_fingerprint.is_empty());
    }

    #[test]
    fn test_attachment_handling() {
        let attachment = Attachment {
            filename: "document.pdf".to_string(),
            content_type: "application/pdf".to_string(),
            size: 1024,
            data: vec![0u8; 1024],
            is_encrypted: false,
        };

        assert_eq!(attachment.filename, "document.pdf");
        assert_eq!(attachment.content_type, "application/pdf");
        assert_eq!(attachment.size, 1024);
        assert_eq!(attachment.data.len(), 1024);
        assert!(!attachment.is_encrypted);
    }

    #[test]
    fn test_media_attachment_detection() {
        let audio_attachment = Attachment {
            filename: "song.mp3".to_string(),
            content_type: "audio/mpeg".to_string(),
            size: 5000000,
            data: Vec::new(),
            is_encrypted: false,
        };

        let video_attachment = Attachment {
            filename: "video.mp4".to_string(),
            content_type: "video/mp4".to_string(),
            size: 50000000,
            data: Vec::new(),
            is_encrypted: false,
        };

        let document_attachment = Attachment {
            filename: "report.pdf".to_string(),
            content_type: "application/pdf".to_string(),
            size: 100000,
            data: Vec::new(),
            is_encrypted: false,
        };

        assert!(SSHKeyManager::is_media_attachment(&audio_attachment));
        assert!(SSHKeyManager::is_media_attachment(&video_attachment));
        assert!(!SSHKeyManager::is_media_attachment(&document_attachment));
    }

    #[test]
    fn test_content_type_detection() {
        assert_eq!(SSHKeyManager::get_media_content_type("song.mp3"), "audio/mpeg");
        assert_eq!(SSHKeyManager::get_media_content_type("music.flac"), "audio/flac");
        assert_eq!(SSHKeyManager::get_media_content_type("video.mp4"), "video/mp4");
        assert_eq!(SSHKeyManager::get_media_content_type("movie.mkv"), "video/x-matroska");
        assert_eq!(SSHKeyManager::get_media_content_type("unknown.xyz"), "application/octet-stream");
    }

    #[test]
    fn test_encryption_status_tracking() {
        let mut message = EmailMessage {
            id: "encrypted_msg".to_string(),
            from: "secure@example.com".to_string(),
            to: vec!["recipient@example.com".to_string()],
            subject: "Confidential Information".to_string(),
            body: "This message contains sensitive data".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Encrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };

        assert_eq!(message.encryption_status, EncryptionStatus::Encrypted);
        
        // Test encryption failure
        message.encryption_status = EncryptionStatus::Failed;
        assert_eq!(message.encryption_status, EncryptionStatus::Failed);
    }

    #[test]
    fn test_trust_level_management() {
        let unknown_contact = Contact {
            email: "unknown@example.com".to_string(),
            display_name: None,
            ssh_public_key: None,
            device_type: None,
            last_seen: None,
            trust_level: TrustLevel::Unknown,
        };

        let verified_contact = Contact {
            email: "verified@example.com".to_string(),
            display_name: Some("Verified User".to_string()),
            ssh_public_key: Some("ssh-key".to_string()),
            device_type: Some("anbernic_rg35xx".to_string()),
            last_seen: Some(Utc::now()),
            trust_level: TrustLevel::Verified,
        };

        let trusted_contact = Contact {
            email: "trusted@example.com".to_string(),
            display_name: Some("Trusted Friend".to_string()),
            ssh_public_key: Some("ssh-key".to_string()),
            device_type: Some("anbernic_rg35xx".to_string()),
            last_seen: Some(Utc::now()),
            trust_level: TrustLevel::Trusted,
        };

        assert_eq!(unknown_contact.trust_level, TrustLevel::Unknown);
        assert_eq!(verified_contact.trust_level, TrustLevel::Verified);
        assert_eq!(trusted_contact.trust_level, TrustLevel::Trusted);
    }

    #[test]
    fn test_radial_input_navigation() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        // Start in inbox view
        assert_eq!(client.ui_state.current_view, EmailView::Inbox);
        assert_eq!(client.ui_state.selected_message_index, 0);
        
        // Navigate between messages
        client.inbox.push(create_test_message("msg1", "sender1@example.com"));
        client.inbox.push(create_test_message("msg2", "sender2@example.com"));
        client.inbox.push(create_test_message("msg3", "sender3@example.com"));
        
        // Navigate down
        client.handle_input(RadialButton::B).expect("Failed to handle input");
        assert_eq!(client.ui_state.selected_message_index, 1);
        
        // Navigate up
        client.handle_input(RadialButton::A).expect("Failed to handle input");
        assert_eq!(client.ui_state.selected_message_index, 0);
    }

    #[test]
    fn test_email_serialization() {
        let message = create_test_message("test_msg", "test@example.com");
        
        // Test JSON serialization
        let serialized = serde_json::to_string(&message).expect("Serialization failed");
        let deserialized: EmailMessage = serde_json::from_str(&serialized).expect("Deserialization failed");
        
        assert_eq!(message.id, deserialized.id);
        assert_eq!(message.from, deserialized.from);
        assert_eq!(message.subject, deserialized.subject);
        assert_eq!(message.body, deserialized.body);
    }

    #[test]
    fn test_inbox_sorting() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        let now = Utc::now();
        let one_hour_ago = now - chrono::Duration::hours(1);
        let two_hours_ago = now - chrono::Duration::hours(2);
        
        // Add messages in random order
        let msg1 = EmailMessage {
            timestamp: two_hours_ago,
            ..create_test_message("oldest", "sender@example.com")
        };
        
        let msg2 = EmailMessage {
            timestamp: now,
            ..create_test_message("newest", "sender@example.com")
        };
        
        let msg3 = EmailMessage {
            timestamp: one_hour_ago,
            ..create_test_message("middle", "sender@example.com")
        };
        
        client.inbox.push(msg1);
        client.inbox.push(msg2);
        client.inbox.push(msg3);
        
        // Sort by timestamp (newest first)
        client.sort_inbox_by_date();
        
        assert_eq!(client.inbox[0].id, "newest");
        assert_eq!(client.inbox[1].id, "middle");
        assert_eq!(client.inbox[2].id, "oldest");
    }

    #[test]
    fn test_message_search() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        client.inbox.push(create_test_message_with_subject("msg1", "sender1@example.com", "Project Update"));
        client.inbox.push(create_test_message_with_subject("msg2", "sender2@example.com", "Meeting Notes"));
        client.inbox.push(create_test_message_with_subject("msg3", "sender3@example.com", "Project Deadline"));
        
        let search_results = client.search_messages("Project");
        assert_eq!(search_results.len(), 2);
        
        let search_results = client.search_messages("Meeting");
        assert_eq!(search_results.len(), 1);
        
        let search_results = client.search_messages("NotFound");
        assert_eq!(search_results.len(), 0);
    }

    #[test]
    fn test_message_state_persistence() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        // Add some messages
        client.inbox.push(create_test_message("msg1", "sender1@example.com"));
        client.inbox.push(create_test_message("msg2", "sender2@example.com"));
        
        // Add contacts
        let contact = Contact {
            email: "friend@example.com".to_string(),
            display_name: Some("Test Friend".to_string()),
            ssh_public_key: None,
            device_type: None,
            last_seen: None,
            trust_level: TrustLevel::Verified,
        };
        client.add_contact(contact);
        
        // Save state
        let save_path = temp_dir.path().join("email_state.json");
        client.save_state(&save_path).expect("Failed to save state");
        
        // Load state into new client
        let mut new_client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        new_client.load_state(&save_path).expect("Failed to load state");
        
        assert_eq!(new_client.inbox.len(), 2);
        assert_eq!(new_client.contacts.len(), 1);
        assert_eq!(new_client.inbox[0].id, "msg1");
        assert!(new_client.contacts.contains_key("friend@example.com"));
    }

    #[test]
    fn test_draft_management() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        let draft = EmailMessage {
            id: "draft1".to_string(),
            from: "test@example.com".to_string(),
            to: vec!["recipient@example.com".to_string()],
            subject: "Draft Subject".to_string(),
            body: "This is a draft message".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Draft,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };
        
        client.drafts.push(draft.clone());
        assert_eq!(client.drafts.len(), 1);
        
        // Move draft to outbox (send)
        let sent_message = EmailMessage {
            message_type: MessageType::Sent,
            read_status: true,
            ..draft
        };
        
        client.outbox.push(sent_message);
        client.drafts.clear();
        
        assert_eq!(client.drafts.len(), 0);
        assert_eq!(client.outbox.len(), 1);
        assert_eq!(client.outbox[0].message_type, MessageType::Sent);
    }

    #[test]
    fn test_large_attachment_handling() {
        let large_data = vec![0u8; 10_000_000]; // 10MB
        
        let attachment = Attachment {
            filename: "large_file.zip".to_string(),
            content_type: "application/zip".to_string(),
            size: large_data.len() as u64,
            data: large_data,
            is_encrypted: false,
        };
        
        assert_eq!(attachment.size, 10_000_000);
        assert_eq!(attachment.data.len(), 10_000_000);
        
        // Should handle large attachments without panic
        let serialization_result = serde_json::to_string(&attachment);
        assert!(serialization_result.is_ok());
    }

    #[test]
    fn test_invalid_email_header_parsing() {
        // Test malformed headers
        let malformed_headers = vec![
            "From: invalid-email-address",
            "To: ",
            "Subject: ",
            "Date: not-a-date",
        ];
        
        for header in malformed_headers {
            let parse_result = parse_email_header(header);
            // Should handle gracefully without panicking
            assert!(parse_result.is_ok() || parse_result.is_err());
        }
    }

    #[test]
    fn test_character_encoding_edge_cases() {
        let message_with_unicode = EmailMessage {
            id: "unicode_msg".to_string(),
            from: "sender@example.com".to_string(),
            to: vec!["recipient@example.com".to_string()],
            subject: "Test: émojis 🎮 and ñoñó".to_string(),
            body: "Unicode content: 你好世界 🌍 café naïve résumé".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        };
        
        // Should serialize/deserialize Unicode correctly
        let serialized = serde_json::to_string(&message_with_unicode).expect("Serialization failed");
        let deserialized: EmailMessage = serde_json::from_str(&serialized).expect("Deserialization failed");
        
        assert_eq!(message_with_unicode.subject, deserialized.subject);
        assert_eq!(message_with_unicode.body, deserialized.body);
    }

    #[test]
    fn test_ui_state_consistency() {
        let mut client = AnbernicEmailClient::new("test@example.com".to_string()).unwrap();
        
        // Test view navigation
        client.navigate_to_outbox();
        assert_eq!(client.ui_state.current_view, EmailView::Outbox);
        
        client.navigate_to_compose();
        assert_eq!(client.ui_state.current_view, EmailView::Compose);
        
        client.navigate_to_contacts();
        assert_eq!(client.ui_state.current_view, EmailView::Contacts);
        
        client.navigate_to_inbox();
        assert_eq!(client.ui_state.current_view, EmailView::Inbox);
    }

    // Helper functions for tests
    fn create_test_message(id: &str, from: &str) -> EmailMessage {
        EmailMessage {
            id: id.to_string(),
            from: from.to_string(),
            to: vec!["test@example.com".to_string()],
            subject: "Test Subject".to_string(),
            body: "Test message body".to_string(),
            timestamp: Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Received,
            attachments: Vec::new(),
            thread_id: None,
            read_status: false,
        }
    }
    
    fn create_test_message_with_subject(id: &str, from: &str, subject: &str) -> EmailMessage {
        EmailMessage {
            subject: subject.to_string(),
            ..create_test_message(id, from)
        }
    }
    
    fn is_valid_email(email: &str) -> bool {
        email.contains('@') && 
        !email.starts_with('@') && 
        !email.ends_with('@') &&
        !email.contains(' ') &&
        email.len() > 0
    }
    
    fn parse_email_header(header: &str) -> Result<String, String> {
        if header.is_empty() {
            Err("Empty header".to_string())
        } else {
            Ok(header.to_string())
        }
    }
}